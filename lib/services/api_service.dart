import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_response.dart';

class ApiService {
  // The two URLs that should alternate when one is not working
  static const String _defaultPrimaryUrl =
      'https://recraftapi.paradigmclient.com';
  static const String _defaultSecondaryUrl =
      'https://recraftapi.paradigmclient.com';

  static const String _activeUrlKey = 'active_url';
  static const String _lastFailedUrlKey = 'last_failed_url';
  static const String _cacheBoxName = 'api_cache';

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
    ),
  )..interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
    ),
  );

  final Map<String, Future<ApiResponse>> _inFlightRequests = {};

  String _primaryUrl = _defaultPrimaryUrl;
  String _secondaryUrl = _defaultSecondaryUrl;
  String _currentUrl = _defaultPrimaryUrl;
  bool _isInitialized = false;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  /// Initialize the service and determine which URL to use
  Future<void> initialize() async {
    if (_isInitialized) return;

    _primaryUrl = dotenv.maybeGet('API_BASE_URL')?.trim().isNotEmpty == true
        ? dotenv.get('API_BASE_URL').trim()
        : _defaultPrimaryUrl;
    _secondaryUrl =
        dotenv.maybeGet('API_FALLBACK_URL')?.trim().isNotEmpty == true
        ? dotenv.get('API_FALLBACK_URL').trim()
        : _defaultSecondaryUrl;

    _currentUrl = _primaryUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUrlKey, _currentUrl);

    _isInitialized = true;
    print('ApiService FORCED to primary URL: $_currentUrl');
  }

  /// Switch to the alternative URL
  void _switchUrl() {
    _currentUrl = _currentUrl == _primaryUrl ? _secondaryUrl : _primaryUrl;
    _saveActiveUrl();
    print('Switched to URL: $_currentUrl');
  }

  /// Save the currently active URL
  Future<void> _saveActiveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUrlKey, _currentUrl);
  }

  /// Mark the current URL as failed and switch to alternative
  Future<void> _markCurrentUrlAsFailed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastFailedUrlKey, _currentUrl);
    _switchUrl();
  }

  /// Check internet connectivity
  Future<bool> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Box get _cacheBox => Hive.box(_cacheBoxName);

  String _cacheKey(String method, String endpoint, Object? body) {
    final bodyKey = body == null ? '' : jsonEncode(body.toString());
    return '$method:$_currentUrl$endpoint:$bodyKey';
  }

  ApiResponse? _readCachedResponse(String key) {
    final cached = _cacheBox.get(key);
    if (cached is! Map) return null;

    final statusCode = cached['statusCode'] as int?;
    final bodyBase64 = cached['body'] as String?;
    if (statusCode == null || bodyBase64 == null) return null;

    return ApiResponse(
      statusCode: statusCode,
      bodyBytes: Uint8List.fromList(base64Decode(bodyBase64)),
    );
  }

  Future<void> _cacheResponse(String key, ApiResponse response) async {
    if (!response.isSuccessful) return;

    await _cacheBox.put(key, {
      'statusCode': response.statusCode,
      'body': base64Encode(response.bodyBytes),
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  ApiResponse _toApiResponse(Response<List<int>> response) {
    return ApiResponse(
      statusCode: response.statusCode ?? 0,
      bodyBytes: Uint8List.fromList(response.data ?? const []),
      headers: response.headers.map.map(
        (key, value) => MapEntry(key.toLowerCase(), value.join(',')),
      ),
    );
  }

  Future<ApiResponse> _dedupe(
    String key,
    Future<ApiResponse> Function() request,
  ) {
    final existing = _inFlightRequests[key];
    if (existing != null) return existing;

    final future = request();
    _inFlightRequests[key] = future;
    future.whenComplete(() => _inFlightRequests.remove(key));
    return future;
  }

  Future<ApiResponse> _request(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    bool allowCache = false,
    bool hasRetried = false,
  }) async {
    await initialize();

    final key = _cacheKey(method, endpoint, body);
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      final cached = allowCache ? _readCachedResponse(key) : null;
      if (cached != null) return cached;
      throw Exception('No internet connection available');
    }

    return _dedupe(key, () async {
      final url = '$_currentUrl$endpoint';
      try {
        print('Making $method request to: $url');
        final response = await _dio.request<List<int>>(
          url,
          data: body,
          options: Options(
            method: method,
            headers: headers ?? {'Content-Type': 'application/json'},
          ),
        );

        final apiResponse = _toApiResponse(response);
        if (apiResponse.isSuccessful) {
          if (allowCache) await _cacheResponse(key, apiResponse);
          return apiResponse;
        }

        if (apiResponse.statusCode >= 500 && !hasRetried) {
          throw HttpException('Server error: ${apiResponse.statusCode}');
        }
        return apiResponse;
      } catch (e) {
        final cached = allowCache ? _readCachedResponse(key) : null;
        if (cached != null) return cached;

        if (!hasRetried) {
          print('Network error on $_currentUrl: $e');
          await _markCurrentUrlAsFailed();
          return _request(
            method,
            endpoint,
            headers: headers,
            body: body,
            allowCache: allowCache,
            hasRetried: true,
          );
        }

        throw Exception(
          'Both API endpoints are currently unavailable. Please try again later.',
        );
      }
    });
  }

  /// Make GET request with cache and automatic URL fallback.
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _request('GET', endpoint, headers: headers, allowCache: true);
  }

  /// Make POST request with in-flight de-duplication and URL fallback.
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _request('POST', endpoint, headers: headers, body: body);
  }

  Future<ApiResponse> _multipartPost(
    String endpoint,
    FormData formData, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await initialize();

    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }

    final url = '$_currentUrl$endpoint';
    try {
      print('Making multipart POST request to: $url');
      final response = await _dio.post<List<int>>(
        url,
        data: formData,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      final apiResponse = _toApiResponse(response);
      if (apiResponse.statusCode >= 500) {
        throw HttpException('Server error: ${apiResponse.statusCode}');
      }
      return apiResponse;
    } catch (e) {
      print('Multipart request failed on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();

      final retryUrl = '$_currentUrl$endpoint';
      final response = await _dio.post<List<int>>(
        retryUrl,
        data: formData,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      return _toApiResponse(response);
    }
  }

  /// Get the current active URL
  String getCurrentUrl() {
    return _currentUrl;
  }

  /// Force switch to the other URL (for manual testing)
  Future<void> forceSwitchUrl() async {
    _switchUrl();
    print('Manually switched to: $_currentUrl');
  }

  /// Reset to primary URL
  Future<void> resetToPrimaryUrl() async {
    _currentUrl = _primaryUrl;
    await _saveActiveUrl();
    print('Reset to primary URL: $_currentUrl');
  }


  Future<Map<String, bool>> testBothUrls() async {
    final results = <String, bool>{};

    // Test primary URL
    try {
      final response = await _dio.get<List<int>>(
        _primaryUrl,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      results[_primaryUrl] =
          (response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 400;
    } catch (e) {
      results[_primaryUrl] = false;
    }

    // Test secondary URL
    try {
      final response = await _dio.get<List<int>>(
        _secondaryUrl,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      results[_secondaryUrl] =
          (response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 400;
    } catch (e) {
      results[_secondaryUrl] = false;
    }

    return results;
  }

  /// Login with WhatsApp contact and PIN
  Future<ApiResponse> login(String whatsAppContact, String pin) async {
    final loginData = {"WhatsAppContact": whatsAppContact, "Pin": pin};

    try {
      final response = await post(
        '/api/Login',
        body: json.encode(loginData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      return response;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  /// Load clients for a specific branch
  Future<ApiResponse> loadClients(String branchName) async {
    try {
      final response = await get(
        '/api/QuickLoadClients/load-clients?branchName=${Uri.encodeComponent(branchName)}',
      );

      print('Load clients response status: ${response.statusCode}');
      print('Load clients response body length: ${response.body.length}');

      return response;
    } catch (e) {
      print('Load clients error: $e');
      rethrow;
    }
  }

  /// Test secondary URL connectivity
  Future<ApiResponse> testSecondaryUrl() async {
    try {
      final response = await _dio.get<List<int>>(
        _secondaryUrl,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return _toApiResponse(response);
    } catch (e) {
      print('Secondary URL test failed: $e');
      rethrow;
    }
  }

  /// Load disbursements for a specific client
  Future<ApiResponse> loadDisbursements(String clientId) async {
    try {
      final response = await get(
        '/api/Disbursement/get-client-disbursements?clientId=$clientId',
      );

      print('Load disbursements response status: ${response.statusCode}');
      print('Load disbursements response body length: ${response.body.length}');

      return response;
    } catch (e) {
      print('Load disbursements error: $e');
      rethrow;
    }
  }

  /// Submit USD repayment
  Future<ApiResponse> submitUSDRepayment(
    Map<String, dynamic> repaymentData,
  ) async {
    try {
      final response = await post(
        '/api/Repayment/add-repayment',
        body: json.encode(repaymentData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Submit USD repayment response status: ${response.statusCode}');
      print('Submit USD repayment response body: ${response.body}');

      return response;
    } catch (e) {
      print('Submit USD repayment error: $e');
      rethrow;
    }
  }

  /// Submit ZWG repayment
  Future<ApiResponse> submitZWGRepayment(
    Map<String, dynamic> repaymentData,
  ) async {
    try {
      // Use separate ZWG endpoint as originally designed
      final response = await post(
        '/api/ZWGRepayment/add-repayment',
        body: json.encode(repaymentData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Submit ZWG repayment response status: ${response.statusCode}');
      print('Submit ZWG repayment response body: ${response.body}');

      return response;
    } catch (e) {
      print('Submit ZWG repayment error: $e');
      rethrow;
    }
  }

  /// Load receipt numbers by branch and user
  Future<ApiResponse> loadReceiptNumbers(String branch, int userId) async {
    try {
      final response = await get(
        '/api/GenerateReceiptNumber/bybranchuser?branch=${Uri.encodeComponent(branch)}&userId=$userId',
      );

      print('Load receipt numbers response status: ${response.statusCode}');
      print(
        'Load receipt numbers response body length: ${response.body.length}',
      );

      return response;
    } catch (e) {
      print('Load receipt numbers error: $e');
      rethrow;
    }
  }

  /// Cancel a repayment
  Future<ApiResponse> cancelRepayment(
    Map<String, dynamic> cancellationData,
  ) async {
    try {
      final response = await post(
        '/api/CancelledRepayments/cancel-repayment',
        body: json.encode(cancellationData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Cancel repayment response status: ${response.statusCode}');
      print('Cancel repayment response body: ${response.body}');

      return response;
    } catch (e) {
      print('Cancel repayment error: $e');
      rethrow;
    }
  }

  /// Get cancelled repayments by branch
  Future<ApiResponse> getCancelledRepayments(String branch) async {
    try {
      final response = await get(
        '/api/CancelledRepayments/get-cancelled-repayments?branch=${Uri.encodeComponent(branch)}',
      );

      print('Get cancelled repayments response status: ${response.statusCode}');
      print(
        'Get cancelled repayments response body length: ${response.body.length}',
      );

      return response;
    } catch (e) {
      print('Get cancelled repayments error: $e');
      rethrow;
    }
  }

  /// Add penalty fee
  Future<ApiResponse> addPenaltyFee(Map<String, dynamic> penaltyFeeData) async {
    try {
      final response = await post(
        '/api/OtherIncome/add-penaltyfee',
        body: json.encode(penaltyFeeData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Add penalty fee response status: ${response.statusCode}');
      print('Add penalty fee response body: ${response.body}');

      return response;
    } catch (e) {
      print('Add penalty fee error: $e');
      rethrow;
    }
  }

  Future<ApiResponse> addFinalPenaltyFee(
    Map<String, dynamic> finalPenaltyFeeData,
  ) async {
    try {
      final response = await post(
        '/api/FinalPenaltyFees/add',
        body: json.encode(finalPenaltyFeeData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Add final penalty fee response status: ${response.statusCode}');
      print('Add final penalty fee response body: ${response.body}');

      return response;
    } catch (e) {
      print('Add final penalty fee error: $e');
      rethrow;
    }
  }

  /// Cancel penalty receipt
  Future<ApiResponse> cancelPenaltyReceipt(
    Map<String, dynamic> cancellationData,
  ) async {
    try {
      final response = await post(
        '/api/CancelPenaltyReceipts/cancel-penalty-receipt',
        body: json.encode(cancellationData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Cancel penalty receipt response status: ${response.statusCode}');
      print('Cancel penalty receipt response body: ${response.body}');

      return response;
    } catch (e) {
      print('Cancel penalty receipt error: $e');
      rethrow;
    }
  }

  /// Cancel admin receipt
  Future<ApiResponse> cancelAdminReceipt(
    Map<String, dynamic> cancellationData,
  ) async {
    try {
      final response = await post(
        '/api/CancelledAdmin/cancel-admin-receipt',
        body: json.encode(cancellationData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Cancel admin receipt response status: ${response.statusCode}');
      print('Cancel admin receipt response body: ${response.body}');

      return response;
    } catch (e) {
      print('Cancel admin receipt error: $e');
      rethrow;
    }
  }

  /// Cancel FCB receipt
  Future<ApiResponse> cancelFCBReceipt(
    Map<String, dynamic> cancellationData,
  ) async {
    try {
      final response = await post(
        '/api/CancelledAdmin/cancel-admin-receipt', // Same endpoint as admin
        body: json.encode(cancellationData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Cancel FCB receipt response status: ${response.statusCode}');
      print('Cancel FCB receipt response body: ${response.body}');

      return response;
    } catch (e) {
      print('Cancel FCB receipt error: $e');
      rethrow;
    }
  }

  /// Get cancelled penalty receipts by branch
  Future<ApiResponse> getCancelledPenaltyReceipts(String branch) async {
    try {
      final response = await get(
        '/api/CancelPenaltyReceipts/get-cancelled-penalty-receipts?branch=${Uri.encodeComponent(branch)}',
      );
      print(
        'Get cancelled penalty receipts response status: ${response.statusCode}',
      );
      print(
        'Get cancelled penalty receipts response body length: ${response.body.length}',
      );
      return response;
    } catch (e) {
      print('Get cancelled penalty receipts error: $e');
      rethrow;
    }
  }

  // ===== ADMIN FEES RECEIPT METHODS =====

  /// Post admin fees receipt
  Future<ApiResponse> postAdminFeesReceipt(
    Map<String, dynamic> adminData,
  ) async {
    try {
      final response = await post(
        '/api/AdminFeesReceipt/post-admin',
        body: json.encode(adminData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Post admin fees receipt response status: ${response.statusCode}');
      print('Post admin fees receipt response body: ${response.body}');

      return response;
    } catch (e) {
      print('Post admin fees receipt error: $e');
      rethrow;
    }
  }

  // ===== FCB RECEIPT METHODS =====

  /// Post FCB receipt
  Future<ApiResponse> postFCBReceipt(Map<String, dynamic> fcbData) async {
    try {
      final response = await post(
        '/api/FCBReceipt',
        body: json.encode(fcbData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Post FCB receipt response status: ${response.statusCode}');
      print('Post FCB receipt response body: ${response.body}');

      return response;
    } catch (e) {
      print('Post FCB receipt error: $e');
      rethrow;
    }
  }

  // ===== CANCELLATION METHODS =====

  /// Post cancellation for admin receipt
  Future<ApiResponse> postCancelledAdminReceipt(
    Map<String, dynamic> cancellationData,
  ) async {
    try {
      final response = await post(
        '/api/CancelledAdmin/cancel-admin-receipt',
        body: json.encode(cancellationData),
        headers: {'Content-Type': 'application/json'},
      );

      print(
        'Post cancelled admin receipt response status: ${response.statusCode}',
      );
      print('Post cancelled admin receipt response body: ${response.body}');

      return response;
    } catch (e) {
      print('Post cancelled admin receipt error: $e');
      rethrow;
    }
  }

  /// Get all branches
  Future<ApiResponse> getBranches() async {
    try {
      final response = await get('/api/Branch');

      print('Get branches response status: ${response.statusCode}');
      print('Get branches response body: ${response.body}');

      return response;
    } catch (e) {
      print('Get branches error: $e');
      rethrow;
    }
  }

  /// Post cancelled admin receipt without throwing exceptions (for background sync)
  Future<bool> syncCancelledAdminReceipt({
    required String receiptNumber,
    required String receiptType,
    required String reason,
    required String branch,
  }) async {
    try {
      final cancellationData = {
        'receiptNumber': receiptNumber,
        'receiptType': receiptType,
        'reason': reason,
        'branch': branch,
      };

      final response = await postCancelledAdminReceipt(cancellationData);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Background sync failed for cancellation: $e');
      return false;
    }
  }

  // ===== TRANSFER METHODS =====

  /// Submit USD Cash transfer
  Future<ApiResponse> submitUSDCashTransfer(
    Map<String, dynamic> transferData,
  ) async {
    try {
      final response = await post(
        '/api/Transfers',
        body: json.encode(transferData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Submit USD Cash transfer response status: ${response.statusCode}');
      print('Submit USD Cash transfer response body: ${response.body}');

      return response;
    } catch (e) {
      print('Submit USD Cash transfer error: $e');
      rethrow;
    }
  }

  /// Submit USD Bank transfer
  Future<ApiResponse> submitUSDBankTransfer(
    Map<String, dynamic> transferData,
  ) async {
    try {
      final response = await post(
        '/api/BankTransfers',
        body: json.encode(transferData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Submit USD Bank transfer response status: ${response.statusCode}');
      print('Submit USD Bank transfer response body: ${response.body}');

      return response;
    } catch (e) {
      print('Submit USD Bank transfer error: $e');
      rethrow;
    }
  }

  /// Submit ZWG Bank transfer
  Future<ApiResponse> submitZWGBankTransfer(
    Map<String, dynamic> transferData,
  ) async {
    try {
      final response = await post(
        '/api/ZWGTransfers',
        body: json.encode(transferData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Submit ZWG Bank transfer response status: ${response.statusCode}');
      print('Submit ZWG Bank transfer response body: ${response.body}');

      return response;
    } catch (e) {
      print('Submit ZWG Bank transfer error: $e');
      rethrow;
    }
  }

  /// Background sync for transfers - returns true if successful
  Future<bool> syncTransfer(
    Map<String, dynamic> transferData,
    String transferType,
  ) async {
    try {
      ApiResponse response;

      switch (transferType) {
        case 'USD_CASH':
          response = await submitUSDCashTransfer(transferData);
          break;
        case 'USD_BANK':
          response = await submitUSDBankTransfer(transferData);
          break;
        case 'ZWG_BANK':
          response = await submitZWGBankTransfer(transferData);
          break;
        default:
          print('Unknown transfer type: $transferType');
          return false;
      }

      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        print('Transfer sync successful for type: $transferType');
      } else {
        print(
          'Transfer sync failed for type: $transferType - Status: ${response.statusCode}',
        );
      }

      return isSuccess;
    } catch (e) {
      print('Background sync failed for transfer: $e');
      return false;
    }
  }

  // ===== EXPENSE METHODS =====

  /// Submit expense
  Future<ApiResponse> submitExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await post(
        '/api/Expenses',
        body: json.encode(expenseData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Submit expense response status: ${response.statusCode}');
      print('Submit expense response body: ${response.body}');

      return response;
    } catch (e) {
      print('Submit expense error: $e');
      rethrow;
    }
  }

  /// Background sync for expenses - returns true if successful
  Future<bool> syncExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await submitExpense(expenseData);

      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        print('Expense sync successful');
      } else {
        print('Expense sync failed - Status: ${response.statusCode}');
      }

      return isSuccess;
    } catch (e) {
      print('Background sync failed for expense: $e');
      return false;
    }
  }

  // ===== PETTY CASH METHODS =====

  /// Submit fund petty cash
  Future<ApiResponse> fundPettyCash(Map<String, dynamic> pettyCashData) async {
    try {
      final response = await post(
        '/api/FundPettyCash',
        body: json.encode(pettyCashData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Fund petty cash response status: ${response.statusCode}');
      print('Fund petty cash response body: ${response.body}');

      return response;
    } catch (e) {
      print('Fund petty cash error: $e');
      rethrow;
    }
  }

  /// Background sync for petty cash - returns true if successful
  Future<bool> syncPettyCash(Map<String, dynamic> pettyCashData) async {
    try {
      final response = await fundPettyCash(pettyCashData);

      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        print('Petty cash sync successful');
      } else {
        print('Petty cash sync failed - Status: ${response.statusCode}');
      }

      return isSuccess;
    } catch (e) {
      print('Background sync failed for petty cash: $e');
      return false;
    }
  }

  // ===== CASH COUNT METHODS =====

  /// Submit daily cash count
  Future<ApiResponse> captureDailyCashCount(
    Map<String, dynamic> cashCountData,
  ) async {
    try {
      final response = await post(
        '/api/CashCount/capture-daily-cash-count',
        body: json.encode(cashCountData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Capture cash count response status: ${response.statusCode}');
      print('Capture cash count response body: ${response.body}');

      return response;
    } catch (e) {
      print('Capture cash count error: $e');
      rethrow;
    }
  }

  /// Background sync for cash count - returns true if successful
  Future<bool> syncCashCount(Map<String, dynamic> cashCountData) async {
    try {
      final response = await captureDailyCashCount(cashCountData);

      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        print('Cash count sync successful');
      } else {
        print('Cash count sync failed - Status: ${response.statusCode}');
      }

      return isSuccess;
    } catch (e) {
      print('Background sync failed for cash count: $e');
      return false;
    }
  }

  // ===== CASHBOOK DOWNLOAD METHODS =====

  /// Download cashbook document
  Future<ApiResponse> downloadCashbookDocument(
    Map<String, dynamic> requestData,
  ) async {
    try {
      final response = await post(
        '/api/DownloadCashbookDocument/download',
        body: json.encode(requestData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Download cashbook response status: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print(
          'Download cashbook successful - Content length: ${response.contentLength}',
        );
      } else {
        print('Download cashbook response body: ${response.body}');
      }

      return response;
    } catch (e) {
      print('Download cashbook error: $e');
      rethrow;
    }
  }

  /// Background download for cashbook - returns file bytes if successful
  Future<List<int>?> downloadCashbook(Map<String, dynamic> requestData) async {
    try {
      final response = await downloadCashbookDocument(requestData);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Cashbook download successful');
        return response.bodyBytes;
      } else {
        print('Cashbook download failed - Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Background download failed for cashbook: $e');
      return null;
    }
  }

  // ===== REQUEST BALANCE METHODS =====

  /// Submit request balance
  Future<ApiResponse> requestBalance(Map<String, dynamic> requestData) async {
    try {
      final response = await post(
        '/api/RequestBalance/request-balance',
        body: json.encode(requestData),
        headers: {'Content-Type': 'application/json'},
      );

      print('Request balance response status: ${response.statusCode}');
      print('Request balance response body: ${response.body}');

      return response;
    } catch (e) {
      print('Request balance error: $e');
      rethrow;
    }
  }

  /// Background sync for request balance - returns true if successful
  Future<bool> syncRequestBalance(Map<String, dynamic> requestData) async {
    try {
      final response = await requestBalance(requestData);

      bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      if (isSuccess) {
        print('Request balance sync successful');
      } else {
        print('Request balance sync failed - Status: ${response.statusCode}');
      }

      return isSuccess;
    } catch (e) {
      print('Background sync failed for request balance: $e');
      return false;
    }
  }

  // ===== CLIENT MANAGEMENT METHODS =====

  /// Add client with file upload using multipart/form-data
  Future<ApiResponse> addClientWithFile({
    required String firstName,
    required String lastName,
    required String nationalIdNumber,
    required String gender,
    required String nextOfKinContact,
    required String nextOfKinName,
    required String relationshipWithNOK,
    required String whatsAppContact,
    required String emailAddress,
    required String branch,
    Uint8List? photoBytes,
    String? photoExtension,
  }) async {
    try {
      final formData = FormData.fromMap({
        'FirstName': firstName,
        'LastName': lastName,
        'NationalIdNumber': nationalIdNumber,
        'Gender': gender,
        'NextOfKinContact': nextOfKinContact,
        'NextOfKinName': nextOfKinName,
        'RelationshipWithNOK': relationshipWithNOK,
        'WhatsAppContact': whatsAppContact,
        'EmailAddress': emailAddress,
        'Branch': branch,
      });

      if (photoBytes != null && photoExtension != null) {
        formData.files.add(
          MapEntry(
            'Photo',
            MultipartFile.fromBytes(
              photoBytes,
              filename: 'client_photo.$photoExtension',
            ),
          ),
        );
      }

      return await _multipartPost('/api/Client/add-with-file', formData);
    } catch (e) {
      print('Add client upload error: $e');
      rethrow;
    }
  }

  /// Upload client photo
  Future<ApiResponse> uploadClientPhoto({
    required String clientId,
    required Uint8List photoBytes,
    required String photoExtension,
  }) async {
    try {
      final formData = FormData.fromMap({'ClientId': clientId});
      formData.files.add(
        MapEntry(
          'Photo',
          MultipartFile.fromBytes(
            photoBytes,
            filename: 'client_photo.$photoExtension',
          ),
        ),
      );

      final response = await _multipartPost(
        '/api/Client/upload-client-photo',
        formData,
      );

      print('Upload photo response status: ${response.statusCode}');
      print('Upload photo response body: ${response.body}');

      return response;
    } catch (e) {
      print('Upload client photo error: $e');
      rethrow;
    }
  }

  /// Get client photo URL
  Future<ApiResponse> getClientPhotoUrl(String clientId) async {
    try {
      final response = await get(
        '/api/Client/get-client-photo-url?clientId=${Uri.encodeComponent(clientId)}',
      );

      print('Get client photo URL response status: ${response.statusCode}');
      print('Get client photo URL response body: ${response.body}');

      return response;
    } catch (e) {
      print('Get client photo URL error: $e');
      rethrow;
    }
  }

  /// Submit collateral documents with file upload using multipart/form-data
  Future<ApiResponse> submitCollateralDocuments({
    required String clientId,
    required String disbursementStartDate,
    required String disbursementEndDate,
    required List<Map<String, dynamic>>
    images, // [{'bytes': Uint8List, 'extension': String}]
  }) async {
    try {
      final formData = FormData.fromMap({
        'ClientId': clientId,
        'DisbursementStartDate': disbursementStartDate,
        'DisbursementEndDate': disbursementEndDate,
      });

      for (int i = 0; i < images.length; i++) {
        final imageData = images[i];
        final photoBytes = imageData['bytes'] as Uint8List;
        final photoExtension = imageData['extension'] as String;

        formData.files.add(
          MapEntry(
            'Images',
            MultipartFile.fromBytes(
              photoBytes,
              filename: 'collateral_image_$i.$photoExtension',
            ),
          ),
        );
      }

      final response = await _multipartPost(
        '/api/ClientDocumentSubmission/submit-with-file-upload',
        formData,
        timeout: const Duration(seconds: 45),
      );

      print('Collateral submission response status: ${response.statusCode}');
      print('Collateral submission response body: ${response.body}');
      return response;
    } catch (e) {
      print('Collateral submission error: $e');
      rethrow;
    }
  }
  // ===== FILE DOWNLOAD METHODS (NO TIMEOUT) =====

  /// GET request for file downloads with Dio byte responses.
  Future<ApiResponse> getFile(String endpoint) async {
    return _request(
      'GET',
      endpoint,
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Download Branch Loan Book (Excel)
  Future<ApiResponse> downloadLoanBook(String branch) async {
    return getFile(
      '/api/MemberStatement/download-branch-loanbook-excel?branch=${Uri.encodeComponent(branch)}',
    );
  }

  /// Download Reminder PDF
  Future<ApiResponse> downloadReminderPdf(
    String branchName,
    String targetDate,
  ) async {
    return getFile(
      '/api/ForceTest/TestReminderPdf/${Uri.encodeComponent(branchName)}?targetDate=${Uri.encodeComponent(targetDate)}',
    );
  }

  /// Download Defaulters Report (PDF)
  Future<ApiResponse> downloadDefaultersReport(
    String branchName,
    String targetDate,
  ) async {
    return getFile(
      '/api/PreciseDefault/download-amount-based-report?branchName=${Uri.encodeComponent(branchName)}&targetDate=${Uri.encodeComponent(targetDate)}',
    );
  }

  /// Download Loan Book Analysis (Excel) — Accounts/Management only
  Future<ApiResponse> downloadLoanBookAnalysis(String targetDate) async {
    return getFile(
      '/api/LoanBookAnalysis/GenerateLoanBookVarianceAnalysis?targetDate=${Uri.encodeComponent(targetDate)}',
    );
  }

  /// Download Consolidated Income by Branch (Excel) — Accounts/Management only
  Future<ApiResponse> downloadConsolidatedBranch(
    String startDate,
    String endDate,
  ) async {
    return getFile(
      '/api/ConsolidatedClassBranch/DownloadAllBranchesConsolidatedIncome?startDate=${Uri.encodeComponent(startDate)}&endDate=${Uri.encodeComponent(endDate)}',
    );
  }

  /// Download Consolidated Income by Day (Excel) — Accounts/Management only
  Future<ApiResponse> downloadConsolidatedDay(
    String startDate,
    String endDate,
  ) async {
    return getFile(
      '/api/ConsolidatedClassDay/DownloadConsolidatedDay?startDate=${Uri.encodeComponent(startDate)}&endDate=${Uri.encodeComponent(endDate)}',
    );
  }

  /// Download Daily Income (Excel) — Accounts/Management only
  Future<ApiResponse> downloadDailyIncome(
    String startDate,
    String endDate,
  ) async {
    return getFile(
      '/api/DailyIncome/DownloadDailyIncome?startDate=${Uri.encodeComponent(startDate)}&endDate=${Uri.encodeComponent(endDate)}',
    );
  }

  // ===== MEMBER STATEMENT METHODS =====

  /// Get client balance summary (TotalBalance + loan summaries)
  Future<ApiResponse> getClientBalance(String clientId) async {
    try {
      final response = await get(
        '/api/MemberStatement/get-client-balance/${Uri.encodeComponent(clientId)}',
      );
      print('Get client balance response status: ${response.statusCode}');
      return response;
    } catch (e) {
      print('Get client balance error: $e');
      rethrow;
    }
  }

  /// Download member statement PDF for a client
  Future<ApiResponse> downloadClientStatementPdf(String clientId) async {
    return getFile(
      '/api/MemberStatement/download-member-statement-pdf/${Uri.encodeComponent(clientId)}',
    );
  }
}
