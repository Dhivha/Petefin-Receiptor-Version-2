import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  // The two URLs that should alternate when one is not working
  static const String _primaryUrl = 'https://petefin.lergtechsolutions.co.zw';
  static const String _secondaryUrl =  'https://petefinadmin.paradigmuser.com';
     

  static const String _activeUrlKey = 'active_url';
  static const String _lastFailedUrlKey = 'last_failed_url';

  String _currentUrl = _primaryUrl;
  bool _isInitialized = false;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Initialize the service and determine which URL to use
  Future<void> initialize() async {
    if (_isInitialized) return;

    // FORCE PRIMARY URL FOR REPAYMENTS - secondary doesn't have endpoints
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
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Make HTTP GET request with automatic URL fallback
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    await initialize();

    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }

    final url = '$_currentUrl$endpoint';

    try {
      print('Making GET request to: $url');
      final response = await http
          .get(
            Uri.parse(url),
            headers: headers ?? {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Request successful
        return response;
      } else if (response.statusCode >= 500) {
        // Server error - try alternative URL
        throw HttpException('Server error: ${response.statusCode}');
      } else {
        // Client error - don't switch URLs
        return response;
      }
    } on SocketException catch (e) {
      print('Network error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryRequest(() => get(endpoint, headers: headers));
    } on HttpException catch (e) {
      print('HTTP error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryRequest(() => get(endpoint, headers: headers));
    } catch (e) {
      print('Unexpected error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryRequest(() => get(endpoint, headers: headers));
    }
  }

  /// Make HTTP POST request with automatic URL fallback
  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    await initialize();

    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }

    final url = '$_currentUrl$endpoint';

    try {
      print('Making POST request to: $url');
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers ?? {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Request successful
        return response;
      } else if (response.statusCode >= 500) {
        // Server error - try alternative URL
        throw HttpException('Server error: ${response.statusCode}');
      } else {
        // Client error - don't switch URLs
        return response;
      }
    } on SocketException catch (e) {
      print('Network error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryRequest(() => post(endpoint, headers: headers, body: body));
    } on HttpException catch (e) {
      print('HTTP error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryRequest(() => post(endpoint, headers: headers, body: body));
    } catch (e) {
      print('Unexpected error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryRequest(() => post(endpoint, headers: headers, body: body));
    }
  }

  /// Retry the request with the alternative URL (only once)
  Future<http.Response> _retryRequest(
    Future<http.Response> Function() requestFunction,
  ) async {
    try {
      print('Retrying request with alternative URL: $_currentUrl');
      return await requestFunction();
    } catch (e) {
      // Both URLs failed
      throw Exception(
        'Both API endpoints are currently unavailable. Please try again later.',
      );
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

  /// Test both URLs to see which one is working
  Future<Map<String, bool>> testBothUrls() async {
    final results = <String, bool>{};

    // Test primary URL
    try {
      final response = await http
          .get(
            Uri.parse(_primaryUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      results[_primaryUrl] =
          response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      results[_primaryUrl] = false;
    }

    // Test secondary URL
    try {
      final response = await http
          .get(
            Uri.parse(_secondaryUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      results[_secondaryUrl] =
          response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      results[_secondaryUrl] = false;
    }

    return results;
  }

  /// Login with WhatsApp contact and PIN
  Future<http.Response> login(String whatsAppContact, String pin) async {
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
  Future<http.Response> loadClients(String branchName) async {
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
  Future<http.Response> testSecondaryUrl() async {
    try {
      final response = await http
          .get(
            Uri.parse(_secondaryUrl),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      return response;
    } catch (e) {
      print('Secondary URL test failed: $e');
      rethrow;
    }
  }

  /// Load disbursements for a specific client
  Future<http.Response> loadDisbursements(String clientId) async {
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
  Future<http.Response> submitUSDRepayment(
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
  Future<http.Response> submitZWGRepayment(
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
  Future<http.Response> loadReceiptNumbers(String branch, int userId) async {
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
  Future<http.Response> cancelRepayment(
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
  Future<http.Response> getCancelledRepayments(String branch) async {
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
  Future<http.Response> addPenaltyFee(
    Map<String, dynamic> penaltyFeeData,
  ) async {
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

  Future<http.Response> addFinalPenaltyFee(
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
  Future<http.Response> cancelPenaltyReceipt(
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
  Future<http.Response> cancelAdminReceipt(
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
  Future<http.Response> cancelFCBReceipt(
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
  Future<http.Response> getCancelledPenaltyReceipts(String branch) async {
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
  Future<http.Response> postAdminFeesReceipt(
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
  Future<http.Response> postFCBReceipt(Map<String, dynamic> fcbData) async {
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
  Future<http.Response> postCancelledAdminReceipt(
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
  Future<http.Response> getBranches() async {
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
  Future<http.Response> submitUSDCashTransfer(
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
  Future<http.Response> submitUSDBankTransfer(
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
  Future<http.Response> submitZWGBankTransfer(
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
      http.Response response;

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
  Future<http.Response> submitExpense(Map<String, dynamic> expenseData) async {
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
  Future<http.Response> fundPettyCash(
    Map<String, dynamic> pettyCashData,
  ) async {
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
  Future<http.Response> captureDailyCashCount(
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
  Future<http.Response> downloadCashbookDocument(
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
  Future<http.Response> requestBalance(Map<String, dynamic> requestData) async {
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
  Future<http.Response> addClientWithFile({
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
    await initialize();

    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }

    final url = '$_currentUrl/api/Client/add-with-file';

    try {
      print('Making multipart POST request to: $url');

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add form fields
      request.fields['FirstName'] = firstName;
      request.fields['LastName'] = lastName;
      request.fields['NationalIdNumber'] = nationalIdNumber;
      request.fields['Gender'] = gender;
      request.fields['NextOfKinContact'] = nextOfKinContact;
      request.fields['NextOfKinName'] = nextOfKinName;
      request.fields['RelationshipWithNOK'] = relationshipWithNOK;
      request.fields['WhatsAppContact'] = whatsAppContact;
      request.fields['EmailAddress'] = emailAddress;
      request.fields['Branch'] = branch;

      // Add photo if provided
      if (photoBytes != null && photoExtension != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'Photo',
            photoBytes,
            filename: 'client_photo.$photoExtension',
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      } else if (response.statusCode >= 500) {
        throw HttpException('Server error: ${response.statusCode}');
      } else {
        return response;
      }
    } on SocketException catch (e) {
      print('Network error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryAddClientWithFile(
        firstName: firstName,
        lastName: lastName,
        nationalIdNumber: nationalIdNumber,
        gender: gender,
        nextOfKinContact: nextOfKinContact,
        nextOfKinName: nextOfKinName,
        relationshipWithNOK: relationshipWithNOK,
        whatsAppContact: whatsAppContact,
        emailAddress: emailAddress,
        branch: branch,
        photoBytes: photoBytes,
        photoExtension: photoExtension,
      );
    } on HttpException catch (e) {
      print('HTTP error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryAddClientWithFile(
        firstName: firstName,
        lastName: lastName,
        nationalIdNumber: nationalIdNumber,
        gender: gender,
        nextOfKinContact: nextOfKinContact,
        nextOfKinName: nextOfKinName,
        relationshipWithNOK: relationshipWithNOK,
        whatsAppContact: whatsAppContact,
        emailAddress: emailAddress,
        branch: branch,
        photoBytes: photoBytes,
        photoExtension: photoExtension,
      );
    } catch (e) {
      print('Unexpected error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryAddClientWithFile(
        firstName: firstName,
        lastName: lastName,
        nationalIdNumber: nationalIdNumber,
        gender: gender,
        nextOfKinContact: nextOfKinContact,
        nextOfKinName: nextOfKinName,
        relationshipWithNOK: relationshipWithNOK,
        whatsAppContact: whatsAppContact,
        emailAddress: emailAddress,
        branch: branch,
        photoBytes: photoBytes,
        photoExtension: photoExtension,
      );
    }
  }

  /// Retry add client with file (only once)
  Future<http.Response> _retryAddClientWithFile({
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
      print('Retrying add client with alternative URL: $_currentUrl');
      return await addClientWithFile(
        firstName: firstName,
        lastName: lastName,
        nationalIdNumber: nationalIdNumber,
        gender: gender,
        nextOfKinContact: nextOfKinContact,
        nextOfKinName: nextOfKinName,
        relationshipWithNOK: relationshipWithNOK,
        whatsAppContact: whatsAppContact,
        emailAddress: emailAddress,
        branch: branch,
        photoBytes: photoBytes,
        photoExtension: photoExtension,
      );
    } catch (e) {
      throw Exception(
        'Both API endpoints are currently unavailable. Please try again later.',
      );
    }
  }

  /// Upload client photo
  Future<http.Response> uploadClientPhoto({
    required String clientId,
    required Uint8List photoBytes,
    required String photoExtension,
  }) async {
    await initialize();

    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }

    final url = '$_currentUrl/api/Client/upload-client-photo';

    try {
      print('Making photo upload request to: $url');

      var request = http.MultipartRequest('POST', Uri.parse(url));

      request.fields['ClientId'] = clientId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'Photo',
          photoBytes,
          filename: 'client_photo.$photoExtension',
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('Upload photo response status: ${response.statusCode}');
      print('Upload photo response body: ${response.body}');

      return response;
    } catch (e) {
      print('Upload client photo error: $e');
      rethrow;
    }
  }

  /// Get client photo URL
  Future<http.Response> getClientPhotoUrl(String clientId) async {
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
  Future<http.Response> submitCollateralDocuments({
    required String clientId,
    required String disbursementStartDate,
    required String disbursementEndDate,
    required List<Map<String, dynamic>> images, // [{'bytes': Uint8List, 'extension': String}]
  }) async {
    await initialize();

    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }

    final url = '$_currentUrl/api/ClientDocumentSubmission/submit-with-file-upload';

    try {
      print('Making collateral submission request to: $url');

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Add form fields
      request.fields['ClientId'] = clientId;
      request.fields['DisbursementStartDate'] = disbursementStartDate;
      request.fields['DisbursementEndDate'] = disbursementEndDate;

      // Add multiple images
      for (int i = 0; i < images.length; i++) {
        final imageData = images[i];
        final photoBytes = imageData['bytes'] as Uint8List;
        final photoExtension = imageData['extension'] as String;
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'Images', // API expects this field name
            photoBytes,
            filename: 'collateral_image_$i.$photoExtension',
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45), // Longer timeout for multiple files
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('Collateral submission response status: ${response.statusCode}');
      print('Collateral submission response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      } else if (response.statusCode >= 500) {
        throw HttpException('Server error: ${response.statusCode}');
      } else {
        return response;
      }
    } on SocketException catch (e) {
      print('Network error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryCollateralSubmission(
        clientId: clientId,
        disbursementStartDate: disbursementStartDate,
        disbursementEndDate: disbursementEndDate,
        images: images,
      );
    } on HttpException catch (e) {
      print('HTTP error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryCollateralSubmission(
        clientId: clientId,
        disbursementStartDate: disbursementStartDate,
        disbursementEndDate: disbursementEndDate,
        images: images,
      );
    } catch (e) {
      print('Unexpected error on $_currentUrl: $e');
      await _markCurrentUrlAsFailed();
      return _retryCollateralSubmission(
        clientId: clientId,
        disbursementStartDate: disbursementStartDate,
        disbursementEndDate: disbursementEndDate,
        images: images,
      );
    }
  }

  // ===== FILE DOWNLOAD METHODS (NO TIMEOUT) =====

  /// GET request for file downloads — no timeout, streams full response
  Future<http.Response> getFile(String endpoint) async {
    await initialize();
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection available');
    }
    final url = '$_currentUrl$endpoint';
    try {
      print('Making file download request to: $url');
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers['Content-Type'] = 'application/json';
        final streamed = await client.send(request);
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode >= 200 && response.statusCode < 300) return response;
        if (response.statusCode >= 500) throw HttpException('Server error: ${response.statusCode}');
        return response;
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      print('Network error on file download: $e');
      await _markCurrentUrlAsFailed();
      return _retryGetFile(endpoint);
    } on HttpException catch (e) {
      print('HTTP error on file download: $e');
      await _markCurrentUrlAsFailed();
      return _retryGetFile(endpoint);
    } catch (e) {
      print('Unexpected error on file download: $e');
      await _markCurrentUrlAsFailed();
      return _retryGetFile(endpoint);
    }
  }

  Future<http.Response> _retryGetFile(String endpoint) async {
    try {
      final url = '$_currentUrl$endpoint';
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers['Content-Type'] = 'application/json';
        final streamed = await client.send(request);
        return await http.Response.fromStream(streamed);
      } finally {
        client.close();
      }
    } catch (e) {
      throw Exception('Both API endpoints are currently unavailable. Please try again later.');
    }
  }

  /// Download Branch Loan Book (Excel)
  Future<http.Response> downloadLoanBook(String branch) async {
    return getFile('/api/MemberStatement/download-branch-loanbook-excel?branch=${Uri.encodeComponent(branch)}');
  }

  /// Download Reminder PDF
  Future<http.Response> downloadReminderPdf(String branchName, String targetDate) async {
    return getFile('/api/ForceTest/TestReminderPdf/${Uri.encodeComponent(branchName)}?targetDate=${Uri.encodeComponent(targetDate)}');
  }

  /// Download Defaulters Report (PDF)
  Future<http.Response> downloadDefaultersReport(String branchName, String targetDate) async {
    return getFile('/api/PreciseDefault/download-amount-based-report?branchName=${Uri.encodeComponent(branchName)}&targetDate=${Uri.encodeComponent(targetDate)}');
  }

  /// Download Loan Book Analysis (Excel) — Accounts/Management only
  Future<http.Response> downloadLoanBookAnalysis(String targetDate) async {
    return getFile('/api/LoanBookAnalysis/GenerateLoanBookVarianceAnalysis?targetDate=${Uri.encodeComponent(targetDate)}');
  }

  /// Download Consolidated Income by Branch (Excel) — Accounts/Management only
  Future<http.Response> downloadConsolidatedBranch(String startDate, String endDate) async {
    return getFile('/api/ConsolidatedClassBranch/DownloadAllBranchesConsolidatedIncome?startDate=${Uri.encodeComponent(startDate)}&endDate=${Uri.encodeComponent(endDate)}');
  }

  /// Download Consolidated Income by Day (Excel) — Accounts/Management only
  Future<http.Response> downloadConsolidatedDay(String startDate, String endDate) async {
    return getFile('/api/ConsolidatedClassDay/DownloadConsolidatedDay?startDate=${Uri.encodeComponent(startDate)}&endDate=${Uri.encodeComponent(endDate)}');
  }

  /// Download Daily Income (Excel) — Accounts/Management only
  Future<http.Response> downloadDailyIncome(String startDate, String endDate) async {
    return getFile('/api/DailyIncome/DownloadDailyIncome?startDate=${Uri.encodeComponent(startDate)}&endDate=${Uri.encodeComponent(endDate)}');
  }

  /// Retry collateral submission (only once)
  Future<http.Response> _retryCollateralSubmission({
    required String clientId,
    required String disbursementStartDate,
    required String disbursementEndDate,
    required List<Map<String, dynamic>> images,
  }) async {
    try {
      print('Retrying collateral submission with alternative URL: $_currentUrl');
      return await submitCollateralDocuments(
        clientId: clientId,
        disbursementStartDate: disbursementStartDate,
        disbursementEndDate: disbursementEndDate,
        images: images,
      );
    } catch (e) {
      throw Exception(
        'Both API endpoints are currently unavailable. Please try again later.',
      );
    }
  }

  // ===== MEMBER STATEMENT METHODS =====

  /// Get client balance summary (TotalBalance + loan summaries)
  Future<http.Response> getClientBalance(String clientId) async {
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
  Future<http.Response> downloadClientStatementPdf(String clientId) async {
    return getFile(
      '/api/MemberStatement/download-member-statement-pdf/${Uri.encodeComponent(clientId)}',
    );
  }
}
