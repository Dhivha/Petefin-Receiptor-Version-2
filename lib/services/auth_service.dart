import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/client.dart';
import '../models/disbursement.dart';
import '../models/repayment.dart';
import '../models/receipt_number.dart';
import '../models/cancelled_repayment.dart';
import '../models/penalty_fee.dart';
import '../models/cancelled_penalty_fee.dart';
import '../models/branch.dart';
import '../models/transfer.dart';
import '../models/expense.dart';
import '../models/petty_cash.dart';
import '../models/cash_count.dart';
import '../models/cashbook_download.dart';
import '../models/request_balance.dart';
import 'api_service.dart';
import 'database_helper.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  Timer? _backgroundSyncTimer;

  /// Get the current logged-in user
  User? get currentUser => _currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _currentUser?.isAuthenticated ?? false;

  /// Initialize the authentication service and check if user is already logged in
  Future<void> initialize() async {
    try {
      _currentUser = await _databaseHelper.getUser();
      print('AuthService initialized. User logged in: ${isLoggedIn}');
      
      // Start background sync timer if user is logged in
      if (isLoggedIn) {
        _startBackgroundSync();
      }
    } catch (e) {
      print('Error initializing AuthService: $e');
      _currentUser = null;
    }
  }

  /// Login with WhatsApp contact and PIN
  Future<LoginResult> login(String whatsAppContact, String pin) async {
    try {
      // Validate input
      if (whatsAppContact.isEmpty || pin.isEmpty) {
        return LoginResult(
          success: false,
          message: 'WhatsApp contact and PIN are required',
        );
      }

      // Call API
      final response = await _apiService.login(whatsAppContact, pin);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Check if login was successful
        if (responseData['IsAuthenticated'] == true) {
          // Create user object
          final user = User.fromJson(responseData);

          // Save user to database
          await _databaseHelper.deleteUser(); // Clear any existing user
          await _databaseHelper.insertUser(user);

          // Update current user
          _currentUser = user;

          print('Login successful for user: ${user.fullName}');
          
          // Start background sync for offline-first functionality
          _startBackgroundSync();

          return LoginResult(
            success: true,
            message: responseData['Message'] ?? 'Login successful',
            user: user,
          );
        } else {
          return LoginResult(
            success: false,
            message: responseData['Message'] ?? 'Login failed',
          );
        }
      } else {
        // Handle HTTP error responses
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['Message'] ??
              'Login failed. Please check your credentials.';
        } catch (e) {
          errorMessage =
              'Login failed. Server returned status: ${response.statusCode}';
        }

        return LoginResult(success: false, message: errorMessage);
      }
    } catch (e) {
      print('Login error: $e');
      return LoginResult(
        success: false,
        message:
            'Failed to connect to server. Please check your internet connection.',
      );
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    try {
      // Stop background sync timer
      _stopBackgroundSync();
      
      // Clear user from database
      await _databaseHelper.deleteUser();

      // Clear current user
      _currentUser = null;

      print('User logged out successfully');
    } catch (e) {
      print('Error during logout: $e');
      // Still clear current user even if database operation fails
      _currentUser = null;
    }
  }

  /// Load and sync clients for the current user's branch
  Future<ClientSyncResult> syncClientsForCurrentUser() async {
    if (!isLoggedIn || _currentUser == null) {
      return ClientSyncResult(
        success: false,
        message: 'User not logged in',
        clientsLoaded: 0,
      );
    }

    return await syncClients(_currentUser!.branch);
  }

  /// Load and sync clients for a specific branch
  Future<ClientSyncResult> syncClients(String branchName) async {
    try {
      print('Syncing clients for branch: $branchName');

      // Call API to load clients
      final response = await _apiService.loadClients(branchName);

      if (response.statusCode == 200) {
        final List<dynamic> clientsData = json.decode(response.body);

        // Convert to Client objects
        final clients = clientsData
            .map((data) => Client.fromJson(data))
            .toList();

        // Save to database
        await _databaseHelper.insertMultipleClients(clients);

        print(
          'Successfully synced ${clients.length} clients for branch: $branchName',
        );

        return ClientSyncResult(
          success: true,
          message: 'Successfully synced ${clients.length} clients',
          clientsLoaded: clients.length,
          clients: clients,
        );
      } else {
        print('Failed to load clients. Status: ${response.statusCode}');
        return ClientSyncResult(
          success: false,
          message: 'Failed to load clients from server',
          clientsLoaded: 0,
        );
      }
    } catch (e) {
      print('Error syncing clients: $e');
      return ClientSyncResult(
        success: false,
        message:
            'Failed to sync clients. Please check your internet connection.',
        clientsLoaded: 0,
      );
    }
  }

  /// Auto-sync clients in the background
  Future<void> autoSyncClients() async {
    if (!isLoggedIn || _currentUser == null) {
      return;
    }

    try {
      // Check if we need to sync (e.g., if it's been more than 1 hour since last sync)
      final lastSync = await _databaseHelper.getLastClientSyncTime();
      final now = DateTime.now();

      if (lastSync == null || now.difference(lastSync).inHours >= 1) {
        print('Auto-syncing clients...');
        await syncClientsForCurrentUser();
      } else {
        print('Clients recently synced. Skipping auto-sync.');
      }
    } catch (e) {
      print('Error during auto-sync: $e');
    }
  }

  /// Get all clients from local database
  Future<List<Client>> getLocalClients() async {
    return await _databaseHelper.getAllClients();
  }

  /// Search clients locally
  Future<List<Client>> searchClients(String query) async {
    return await _databaseHelper.searchClients(query);
  }

  /// Get client by ID from local database
  Future<Client?> getClientById(String clientId) async {
    return await _databaseHelper.getClientById(clientId);
  }

  /// Get clients count
  Future<int> getClientsCount() async {
    return await _databaseHelper.getClientsCount();
  }

  /// Refresh user data from local storage
  Future<void> refreshUser() async {
    _currentUser = await _databaseHelper.getUser();
  }

  /// Clear all local data (for debugging/reset purposes)
  Future<void> clearAllData() async {
    await _databaseHelper.deleteUser();
    await _databaseHelper.deleteAllClients();
    await _databaseHelper.deleteAllDisbursements();
    await _databaseHelper.deleteAllRepayments();
    _currentUser = null;
    print('All local data cleared');
  }

  /// Create and store a repayment locally
  Future<RepaymentResult> createRepayment({
    required int disbursementId,
    required String clientId,
    required double amount,
    required DateTime dateOfPayment,
    required String paymentNumber,
    required String currency,
    required String clientName,
    bool force = true,
  }) async {
    if (_currentUser == null) {
      return RepaymentResult(
        success: false,
        message: 'User not logged in',
        receiptNumber: null,
      );
    }

    try {
      // Generate receipt number
      final receiptNumber = Repayment.generateReceiptNumber();

      // Create repayment object
      final repayment = Repayment(
        disbursementId: disbursementId,
        clientId: clientId,
        amount: amount,
        branch: _currentUser!.branch,
        dateOfPayment: dateOfPayment,
        paymentNumber: paymentNumber,
        force: force,
        receiptNumber: receiptNumber,
        currency: currency,
        clientName: clientName,
        createdAt: DateTime.now(),
      );

      // Store locally
      await _databaseHelper.insertRepayment(repayment);

      print('Repayment created locally: $receiptNumber for $currency $amount');

      // Try to sync immediately if we have internet (with small delay to ensure DB write completes)
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoSyncRepayments();
      });

      return RepaymentResult(
        success: true,
        message: 'Repayment created successfully',
        receiptNumber: receiptNumber,
        repayment: repayment,
      );
    } catch (e) {
      print('Error creating repayment: $e');
      return RepaymentResult(
        success: false,
        message: 'Failed to create repayment: $e',
        receiptNumber: null,
      );
    }
  }

  /// Auto-sync unsynced repayments in background
  Future<void> _autoSyncRepayments() async {
    try {
      final unsyncedRepayments = await _databaseHelper.getUnsyncedRepayments();
      if (unsyncedRepayments.isEmpty) {
        print('No unsynced repayments to sync');
        return;
      }

      print('Auto-syncing ${unsyncedRepayments.length} repayments...');

      for (final repayment in unsyncedRepayments) {
        try {
          late http.Response response;

          if (repayment.currency == 'USD') {
            response = await _apiService.submitUSDRepayment(repayment.toJson());
          } else {
            response = await _apiService.submitZWGRepayment(repayment.toJson());
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            // Success - mark as synced
            await _databaseHelper.updateRepaymentSyncStatus(
              repayment.receiptNumber,
              true,
              syncResponse: 'Success: ${response.statusCode}',
            );
            print('✅ Synced repayment ${repayment.receiptNumber}');
          } else {
            // Server error - update sync response but keep as unsynced
            await _databaseHelper.updateRepaymentSyncStatus(
              repayment.receiptNumber,
              false,
              syncResponse: 'Error: ${response.statusCode} - ${response.body}',
            );
            print(
              '❌ Failed to sync repayment ${repayment.receiptNumber}: ${response.statusCode}',
            );
          }
        } catch (e) {
          // Network error - update sync response but keep as unsynced
          await _databaseHelper.updateRepaymentSyncStatus(
            repayment.receiptNumber,
            false,
            syncResponse: 'Network Error: $e',
          );
          print(
            '❌ Network error syncing repayment ${repayment.receiptNumber}: $e',
          );
          // Continue with other repayments even if one fails
          continue;
        }
      }
    } catch (e) {
      print('Error in auto-sync repayments: $e');
    }
  }

  /// Manually sync unsynced repayments
  Future<RepaymentSyncResult> syncUnyncedRepayments() async {
    if (!isLoggedIn || _currentUser == null) {
      return RepaymentSyncResult(
        success: false,
        message: 'User not logged in',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final unsyncedRepayments = await _databaseHelper.getUnsyncedRepayments();

      if (unsyncedRepayments.isEmpty) {
        return RepaymentSyncResult(
          success: true,
          message: 'No repayments to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      int syncedCount = 0;
      int failedCount = 0;

      for (final repayment in unsyncedRepayments) {
        try {
          late http.Response response;

          if (repayment.currency == 'USD') {
            response = await _apiService.submitUSDRepayment(repayment.toJson());
          } else {
            response = await _apiService.submitZWGRepayment(repayment.toJson());
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            await _databaseHelper.updateRepaymentSyncStatus(
              repayment.receiptNumber,
              true,
              syncResponse: 'Success: ${response.statusCode}',
            );
            syncedCount++;
          } else {
            await _databaseHelper.updateRepaymentSyncStatus(
              repayment.receiptNumber,
              false,
              syncResponse: 'Error: ${response.statusCode} - ${response.body}',
            );
            failedCount++;
          }
        } catch (e) {
          await _databaseHelper.updateRepaymentSyncStatus(
            repayment.receiptNumber,
            false,
            syncResponse: 'Network Error: $e',
          );
          failedCount++;
        }
      }

      return RepaymentSyncResult(
        success: syncedCount > 0,
        message: 'Synced $syncedCount repayments, $failedCount failed',
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      print('Error syncing repayments: $e');
      return RepaymentSyncResult(
        success: false,
        message: 'Failed to sync repayments: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    }
  }

  /// Get repayments by client ID
  Future<List<Repayment>> getClientRepayments(String clientId) async {
    return await _databaseHelper.getRepaymentsByClientId(clientId);
  }

  /// Get all unsynced repayments
  Future<List<Repayment>> getUnsyncedRepayments() async {
    return await _databaseHelper.getUnsyncedRepayments();
  }

  /// Get all synced repayments
  Future<List<Repayment>> getSyncedRepayments() async {
    return await _databaseHelper.getSyncedRepayments();
  }

  /// Get repayments count
  Future<int> getRepaymentsCount() async {
    return await _databaseHelper.getRepaymentsCount();
  }

  /// Get unsynced repayments count
  Future<int> getUnsyncedRepaymentsCount() async {
    return await _databaseHelper.getUnsyncedRepaymentsCount();
  }

  /// Get clients with repayment summary
  Future<List<Map<String, dynamic>>> getClientsWithRepaymentSummary() async {
    return await _databaseHelper.getClientsWithRepaymentSummary();
  }

  /// Load and sync disbursements for a specific client
  Future<DisbursementSyncResult> syncDisbursementsForClient(
    String clientId,
  ) async {
    if (!isLoggedIn || _currentUser == null) {
      return DisbursementSyncResult(
        success: false,
        message: 'User not logged in',
        disbursementsLoaded: 0,
      );
    }

    try {
      print('Loading disbursements for client: $clientId');

      final response = await _apiService.loadDisbursements(clientId);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Parse disbursements from the response
        final disbursementsList = responseData as List<dynamic>;
        final disbursements = disbursementsList
            .map((item) => Disbursement.fromJson(item as Map<String, dynamic>))
            .toList();

        // Save disbursements to local database
        if (disbursements.isNotEmpty) {
          await _databaseHelper.insertMultipleDisbursements(disbursements);
        }

        print(
          'Successfully synced ${disbursements.length} disbursements for client $clientId',
        );

        return DisbursementSyncResult(
          success: true,
          message: 'Successfully synced ${disbursements.length} disbursements',
          disbursementsLoaded: disbursements.length,
          disbursements: disbursements,
        );
      } else {
        print('Failed to load disbursements. Status: ${response.statusCode}');
        return DisbursementSyncResult(
          success: false,
          message: 'Failed to load disbursements from server',
          disbursementsLoaded: 0,
        );
      }
    } catch (e) {
      print('Error syncing disbursements: $e');
      return DisbursementSyncResult(
        success: false,
        message:
            'Failed to sync disbursements. Please check your internet connection.',
        disbursementsLoaded: 0,
      );
    }
  }

  /// Get all clients from local database
  Future<List<Client>> getClients() async {
    return await _databaseHelper.getAllClients();
  }

  /// Get disbursements for a client from local database
  Future<List<Disbursement>> getClientDisbursements(String clientId) async {
    return await _databaseHelper.getDisbursementsByClientId(clientId);
  }

  /// Get all disbursements from local database
  Future<List<Disbursement>> getAllDisbursements() async {
    return await _databaseHelper.getAllDisbursements();
  }

  /// Get disbursements count
  Future<int> getDisbursementsCount() async {
    return await _databaseHelper.getDisbursementsCount();
  }

  /// Get disbursements count for a specific client
  Future<int> getClientDisbursementsCount(String clientId) async {
    return await _databaseHelper.getDisbursementsCountByClientId(clientId);
  }

  /// Get clients with their disbursement count
  Future<List<Map<String, dynamic>>> getClientsWithDisbursementCount() async {
    return await _databaseHelper.getClientsWithDisbursementCount();
  }

  // Receipt Number operations
  
  /// Sync receipt numbers from server
  Future<ReceiptNumberSyncResult> syncReceiptNumbers({bool forceRefresh = false}) async {
    if (_currentUser == null) {
      return ReceiptNumberSyncResult(
        success: false,
        message: 'User not logged in',
        newReceiptNumbers: 0,
        totalReceiptNumbers: 0,
      );
    }

    try {
      await _apiService.initialize();
      
      // Get existing receipt numbers count
      final existingCount = await _databaseHelper.getTotalReceiptNumbersCount();
      
      print('🔄 Syncing receipt numbers for branch: ${_currentUser!.branch}, userId: ${_currentUser!.currentUserId}...');
      
      // Call API to get receipt numbers
      final response = await _apiService.loadReceiptNumbers(_currentUser!.branch, _currentUser!.currentUserId);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> jsonResponse = json.decode(response.body);
        
        // Parse receipt numbers from API
        final List<ReceiptNumber> apiReceiptNumbers = jsonResponse
            .map((json) => ReceiptNumber.fromApiJson(json))
            .toList();
        
        if (forceRefresh) {
          // Clear existing and insert all
          await _databaseHelper.deleteAllReceiptNumbers();
          await _databaseHelper.insertMultipleReceiptNumbers(apiReceiptNumbers);
        } else {
          // Find new additions only
          final existingReceiptNumbers = await _databaseHelper.getAllReceiptNumbers();
          final existingIds = existingReceiptNumbers.map((r) => r.id).toSet();
          
          final newReceiptNumbers = apiReceiptNumbers
              .where((r) => !existingIds.contains(r.id))
              .toList();
          
          if (newReceiptNumbers.isNotEmpty) {
            await _databaseHelper.insertMultipleReceiptNumbers(newReceiptNumbers);
          }
        }
        
        final newCount = await _databaseHelper.getTotalReceiptNumbersCount();
        final addedCount = newCount - (forceRefresh ? 0 : existingCount);
        
        print('✅ Receipt numbers sync successful: $addedCount new, $newCount total');
        
        return ReceiptNumberSyncResult(
          success: true,
          message: 'Receipt numbers synced successfully',
          newReceiptNumbers: addedCount,
          totalReceiptNumbers: newCount,
          receiptNumbers: apiReceiptNumbers,
        );
      } else {
        print('❌ Receipt numbers sync failed: ${response.statusCode} - ${response.body}');
        return ReceiptNumberSyncResult(
          success: false,
          message: 'Failed to sync receipt numbers: ${response.statusCode}',
          newReceiptNumbers: 0,
          totalReceiptNumbers: await _databaseHelper.getTotalReceiptNumbersCount(),
        );
      }
    } catch (e) {
      print('❌ Receipt numbers sync error: $e');
      return ReceiptNumberSyncResult(
        success: false,
        message: 'Receipt numbers sync failed: $e',
        newReceiptNumbers: 0,
        totalReceiptNumbers: await _databaseHelper.getTotalReceiptNumbersCount(),
      );
    }
  }
  
  /// Get unused receipt numbers
  Future<List<ReceiptNumber>> getUnusedReceiptNumbers() async {
    return await _databaseHelper.getUnusedReceiptNumbers();
  }
  
  /// Get used receipt numbers
  Future<List<ReceiptNumber>> getUsedReceiptNumbers() async {
    return await _databaseHelper.getUsedReceiptNumbers();
  }
  
  /// Mark receipt number as used by receipt number string
  Future<bool> markReceiptNumberAsUsed(String receiptNum) async {
    try {
      // Find the unused receipt number by receipt number string
      final unusedReceipts = await _databaseHelper.getUnusedReceiptNumbers();
      final targetReceipt = unusedReceipts.firstWhere(
        (receipt) => receipt.receiptNum == receiptNum,
        orElse: () => throw Exception('Receipt number not found: $receiptNum'),
      );
      
      // Mark it as used
      await _databaseHelper.markReceiptNumberAsUsed(
        targetReceipt.id,
        clientId: 'ADMIN_FCB',
        clientName: 'Admin/FCB Receipt',
        amount: 0.0,
        currency: 'USD',
      );
      
      return true;
    } catch (e) {
      print('Error marking receipt number as used: $e');
      return false;
    }
  }
  
  /// Get next available receipt number and mark as used
  Future<ReceiptNumber?> getAndUseNextReceiptNumber({
    required String clientId,
    required String clientName,
    required double amount,
    required String currency,
  }) async {
    final nextReceiptNumber = await _databaseHelper.getNextUnusedReceiptNumber();
    
    if (nextReceiptNumber != null) {
      await _databaseHelper.markReceiptNumberAsUsed(
        nextReceiptNumber.id,
        clientId: clientId,
        clientName: clientName,
        amount: amount,
        currency: currency,
      );
      
      // Return the updated receipt number
      return await _databaseHelper.getReceiptNumberById(nextReceiptNumber.id);
    }
    
    return null;
  }
  
  /// Search receipt numbers
  Future<List<ReceiptNumber>> searchReceiptNumbers(String query) async {
    return await _databaseHelper.searchReceiptNumbers(query);
  }
  
  /// Get receipt numbers stats
  Future<Map<String, int>> getReceiptNumbersStats() async {
    return await _databaseHelper.getReceiptNumbersStats();
  }
  
  /// Modified repayment creation to use receipt numbers
  Future<RepaymentResult> createRepaymentWithReceiptNumber({
    required int disbursementId,
    required String clientId,
    required double amount,
    required DateTime dateOfPayment,
    required String paymentNumber,
    required String currency,
    required String clientName,
    bool force = true,
  }) async {
    if (_currentUser == null) {
      return RepaymentResult(
        success: false,
        message: 'User not logged in',
        receiptNumber: null,
      );
    }

    try {
      // Get next unused receipt number
      final receiptNumber = await getAndUseNextReceiptNumber(
        clientId: clientId,
        clientName: clientName,
        amount: amount,
        currency: currency,
      );
      
      if (receiptNumber == null) {
        return RepaymentResult(
          success: false,
          message: 'No unused receipt numbers available. Please sync receipt numbers first.',
          receiptNumber: null,
        );
      }

      // Create repayment object with system receipt number
      final repayment = Repayment(
        disbursementId: disbursementId,
        clientId: clientId,
        amount: amount,
        branch: _currentUser!.branch,
        dateOfPayment: dateOfPayment,
        paymentNumber: paymentNumber,
        force: force,
        receiptNumber: receiptNumber.receiptNum, // Use system receipt number
        currency: currency,
        clientName: clientName,
        createdAt: DateTime.now(),
      );

      // Store locally
      await _databaseHelper.insertRepayment(repayment);

      print('✅ Repayment created with system receipt number: ${receiptNumber.receiptNum} for $currency $amount');

      // Try to sync immediately
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoSyncRepayments();
      });

      return RepaymentResult(
        success: true,
        message: 'Repayment created successfully with system receipt number',
        receiptNumber: receiptNumber.receiptNum,
        repayment: repayment,
      );
    } catch (e) {
      print('❌ Error creating repayment with receipt number: $e');
      return RepaymentResult(
        success: false,
        message: 'Failed to create repayment: $e',
        receiptNumber: null,
      );
    }
  }

  // Repayment Cancellation operations

  /// Cancel a repayment
  Future<CancellationResult> cancelRepayment({
    required Repayment repayment,
    required String reason,
  }) async {
    if (_currentUser == null) {
      return CancellationResult(
        success: false,
        message: 'User not logged in',
      );
    }

    try {
      await _apiService.initialize();
      
      // Build cancellation payload according to API spec
      final cancellationData = {
        'ClientId': repayment.clientId,
        'Amount': repayment.amount,
        'ReceiptNumber': repayment.receiptNumber,
        'DateOfPayment': repayment.dateOfPayment.toIso8601String(),
        'Reason': reason.trim(),
        'Branch': _currentUser!.branch,
        'CancelledBy': _currentUser!.fullName,
      };

      print('🔄 Cancelling repayment: ${repayment.receiptNumber}...');
      
      // Call API to cancel repayment
      final response = await _apiService.cancelRepayment(cancellationData);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        
        print('✅ Repayment cancelled successfully: ${repayment.receiptNumber}');
        
        return CancellationResult(
          success: true,
          message: responseData['message'] ?? 'Repayment cancelled successfully',
          cancellationId: responseData['cancellationId'],
          smsNotification: responseData['smsNotification'],
        );
      } else if (response.statusCode == 409) {
        // Already cancelled
        final responseData = json.decode(response.body);
        return CancellationResult(
          success: false,
          message: responseData['message'] ?? 'Repayment is already cancelled',
        );
      } else if (response.statusCode == 404) {
        // Client not found
        final responseData = json.decode(response.body);
        return CancellationResult(
          success: false,
          message: responseData['message'] ?? 'Client not found',
        );
      } else {
        // Other server errors
        final responseData = json.decode(response.body);
        print('❌ Failed to cancel repayment: ${response.statusCode} - ${response.body}');
        return CancellationResult(
          success: false,
          message: responseData['message'] ?? 'Failed to cancel repayment: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Repayment cancellation error: $e');
      return CancellationResult(
        success: false,
        message: 'Cancellation failed: $e',
      );
    }
  }

  /// Get cancelled repayments for current user's branch
  Future<List<CancelledRepayment>> getCancelledRepayments() async {
    if (_currentUser == null) {
      print('❌ User not logged in - cannot get cancelled repayments');
      return [];
    }

    try {
      await _apiService.initialize();
      
      print('🔄 Loading cancelled repayments for branch: ${_currentUser!.branch}...');
      
      final response = await _apiService.getCancelledRepayments(_currentUser!.branch);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        final List<dynamic> cancelledList = responseData['cancelledRepayments'] ?? [];
        
        final cancelledRepayments = cancelledList
            .map((json) => CancelledRepayment.fromJson(json))
            .toList();
        
        print('✅ Loaded ${cancelledRepayments.length} cancelled repayments');
        return cancelledRepayments;
      } else {
        print('❌ Failed to load cancelled repayments: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading cancelled repayments: $e');
      return [];
    }
  }

  // Penalty Fee operations
  Future<PenaltyFeeResult> createPenaltyFee({
    required String clientName,
    required double amount,
  }) async {
    if (_currentUser == null) {
      return PenaltyFeeResult(
        success: false,
        message: 'User not logged in',
        receiptNumber: '',
      );
    }

    try {
      final db = _databaseHelper;
      
      // Get next available receipt number from unused receipts
      final unusedReceipts = await getUnusedReceiptNumbers();
      if (unusedReceipts.isEmpty) {
        return PenaltyFeeResult(
          success: false,
          message: 'No unused receipt numbers available',
          receiptNumber: '',
        );
      }
      
      final nextReceipt = unusedReceipts.first;
      final receiptNumber = nextReceipt.receiptNum;
      
      // Create penalty fee record
      final penaltyFee = PenaltyFee(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        branch: _currentUser!.branch,
        amount: amount,
        clientName: clientName,
        dateTimeCaptured: DateTime.now(),
        receiptNumber: receiptNumber,
        isSynced: false,
      );
      
      // Save to local database
      await db.insertPenaltyFee(penaltyFee);
      
      // Mark receipt number as used
      await markReceiptNumberAsUsed(receiptNumber);
      
      print('✅ Penalty fee created locally: $receiptNumber');
      
      // Try to sync immediately if online (don't let this fail the penalty fee creation)
      try {
        await _autoSyncPenaltyFees();
      } catch (syncError) {
        print('⚠️ Auto-sync failed, will retry later: $syncError');
      }
      
      return PenaltyFeeResult(
        success: true,
        message: 'Penalty fee recorded successfully',
        receiptNumber: receiptNumber,
        penaltyFee: penaltyFee,
      );
      
    } catch (e) {
      print('❌ Error creating penalty fee: $e');
      return PenaltyFeeResult(
        success: false,
        message: 'Failed to create penalty fee: $e',
        receiptNumber: '',
      );
    }
  }

  /// Auto-sync penalty fees when internet is available
  Future<void> _autoSyncPenaltyFees() async {
    if (!isLoggedIn) return;
    
    try {
      final unsyncedPenaltyFees = await _databaseHelper.getUnsyncedPenaltyFees();
      if (unsyncedPenaltyFees.isEmpty) return;

      await _apiService.initialize();
      
      for (final penaltyFee in unsyncedPenaltyFees) {
        try {
          print('🔄 Auto-syncing penalty fee: ${penaltyFee.receiptNumber}...');
          
          // Step 1: Sync to primary penalty fee endpoint
          final response = await _apiService.addPenaltyFee(penaltyFee.toApiJson());
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            print('✅ Primary penalty fee auto-sync successful: ${penaltyFee.receiptNumber}');
            
            try {
              // Step 2: Get unused receipt number
              final unusedReceipt = await _databaseHelper.getNextUnusedReceiptNumber();
              
              if (unusedReceipt != null) {
                print('🎫 Auto-sync using receipt number: ${unusedReceipt.receiptNum}');
                
                // Step 3: Sync to final penalty fee endpoint with receipt number
                final finalPenaltyData = {
                  'Branch': penaltyFee.branch,
                  'Amount': penaltyFee.amount,
                  'ClientId': 'PEN${penaltyFee.clientName.replaceAll(' ', '').toUpperCase()}',
                  'ClientName': penaltyFee.clientName,
                  'DateTimeCaptured': penaltyFee.dateTimeCaptured.toIso8601String(),
                  'ReceiptNumber': unusedReceipt.receiptNum,
                };
                
                final finalResponse = await _apiService.addFinalPenaltyFee(finalPenaltyData);
                
                if (finalResponse.statusCode >= 200 && finalResponse.statusCode < 300) {
                  // Step 4: Mark receipt as used and penalty fee as synced
                  await _databaseHelper.markReceiptNumberAsUsed(
                    unusedReceipt.id,
                    clientId: penaltyFee.id,
                    clientName: penaltyFee.clientName,
                    amount: penaltyFee.amount,
                    currency: penaltyFee.currency,
                  );
                  await _databaseHelper.markPenaltyFeeAsSynced(penaltyFee.id);
                  
                  print('✅ Auto-synced penalty fee with receipt: ${penaltyFee.receiptNumber} → ${unusedReceipt.receiptNum}');
                } else {
                  print('❌ Failed to auto-sync final penalty fee ${penaltyFee.receiptNumber}: ${finalResponse.statusCode}');
                }
              } else {
                print('❌ No unused receipt numbers available for auto-sync: ${penaltyFee.receiptNumber}');
              }
            } catch (finalError) {
              print('❌ Error in final penalty fee auto-sync ${penaltyFee.receiptNumber}: $finalError');
            }
          }
        } catch (e) {
          print('❌ Failed to auto-sync penalty fee ${penaltyFee.receiptNumber}: $e');
          // Continue with next penalty fee
        }
      }
    } catch (e) {
      print('❌ Auto-sync penalty fees error: $e');
    }
  }

  Future<PenaltySyncResult> syncUnsyncedPenaltyFees() async {
    if (!isLoggedIn) {
      return PenaltySyncResult(
        success: false,
        message: 'User not logged in',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final unsyncedPenaltyFees = await _databaseHelper.getUnsyncedPenaltyFees();
      
      if (unsyncedPenaltyFees.isEmpty) {
        return PenaltySyncResult(
          success: true,
          message: 'No penalty fees to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      await _apiService.initialize();
      
      int syncedCount = 0;
      int failedCount = 0;

      for (final penaltyFee in unsyncedPenaltyFees) {
        try {
          print('🔄 Syncing penalty fee: ${penaltyFee.receiptNumber}...');
          
          // Step 1: Sync to primary penalty fee endpoint
          final response = await _apiService.addPenaltyFee(penaltyFee.toApiJson());
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            print('✅ Primary penalty fee sync successful: ${penaltyFee.receiptNumber}');
            
            try {
              // Step 2: Get unused receipt number
              final unusedReceipt = await _databaseHelper.getNextUnusedReceiptNumber();
              
              if (unusedReceipt != null) {
                print('🎫 Using receipt number: ${unusedReceipt.receiptNum}');
                
                // Step 3: Sync to final penalty fee endpoint with receipt number
                final finalPenaltyData = {
                  'Branch': penaltyFee.branch,
                  'Amount': penaltyFee.amount,
                  'ClientId': 'PEN${penaltyFee.clientName.replaceAll(' ', '').toUpperCase()}',
                  'ClientName': penaltyFee.clientName,
                  'DateTimeCaptured': penaltyFee.dateTimeCaptured.toIso8601String(),
                  'ReceiptNumber': unusedReceipt.receiptNum,
                };
                
                final finalResponse = await _apiService.addFinalPenaltyFee(finalPenaltyData);
                
                if (finalResponse.statusCode >= 200 && finalResponse.statusCode < 300) {
                  // Step 4: Mark receipt as used and penalty fee as synced
                  await _databaseHelper.markReceiptNumberAsUsed(
                    unusedReceipt.id,
                    clientId: penaltyFee.id,
                    clientName: penaltyFee.clientName,
                    amount: penaltyFee.amount,
                    currency: penaltyFee.currency,
                  );
                  await _databaseHelper.markPenaltyFeeAsSynced(penaltyFee.id);
                  
                  syncedCount++;
                  print('✅ Fully synced penalty fee with receipt: ${penaltyFee.receiptNumber} → ${unusedReceipt.receiptNum}');
                } else {
                  failedCount++;
                  print('❌ Failed to sync final penalty fee ${penaltyFee.receiptNumber}: ${finalResponse.statusCode}');
                }
              } else {
                failedCount++;
                print('❌ No unused receipt numbers available for penalty fee: ${penaltyFee.receiptNumber}');
              }
            } catch (finalError) {
              failedCount++;
              print('❌ Error in final penalty fee sync ${penaltyFee.receiptNumber}: $finalError');
            }
          } else {
            failedCount++;
            print('❌ Failed to sync primary penalty fee ${penaltyFee.receiptNumber}: ${response.statusCode}');
          }
        } catch (e) {
          failedCount++;
          print('❌ Error syncing penalty fee ${penaltyFee.receiptNumber}: $e');
        }
      }

      final success = failedCount == 0;
      final message = success 
          ? 'Successfully synced $syncedCount penalty fees'
          : 'Synced $syncedCount penalty fees, $failedCount failed';

      return PenaltySyncResult(
        success: success,
        message: message,
        syncedCount: syncedCount,
        failedCount: failedCount,
      );

    } catch (e) {
      print('❌ Sync penalty fees error: $e');
      return PenaltySyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    }
  }

  Future<List<PenaltyFee>> getUnsyncedPenaltyFees() async {
    return await _databaseHelper.getUnsyncedPenaltyFees();
  }

  Future<List<PenaltyFee>> getSyncedPenaltyFees() async {
    return await _databaseHelper.getSyncedPenaltyFees();
  }

  Future<List<PenaltyFee>> getAllPenaltyFees() async {
    return await _databaseHelper.getAllPenaltyFees();
  }

  Future<int> getPenaltyFeesCount() async {
    return await _databaseHelper.getPenaltyFeesCount();
  }

  Future<int> getUnsyncedPenaltyFeesCount() async {
    return await _databaseHelper.getUnsyncedPenaltyFeesCount();
  }

  Future<CancellationResult> cancelPenaltyFee({
    required PenaltyFee penaltyFee,
    required String reason,
  }) async {
    if (_currentUser == null) {
      return CancellationResult(
        success: false,
        message: 'User not logged in',
      );
    }

    try {
      await _apiService.initialize();
      
      print('🔄 Cancelling penalty fee: ${penaltyFee.receiptNumber}...');
      
      final cancellationData = {
        'Branch': _currentUser!.branch,
        'ReceiptNumber': penaltyFee.receiptNumber,
        'ClientName': penaltyFee.clientName,
        'Amount': penaltyFee.amount,
        'DateOfPayment': penaltyFee.dateTimeCaptured.toIso8601String(),
        'CancelledBy': _currentUser!.fullName,
        'Reason': reason,
      };
      
      final response = await _apiService.cancelPenaltyReceipt(cancellationData);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        
        // Store cancelled penalty fee locally
        final cancelledPenaltyFee = CancelledPenaltyFee.fromJson(responseData);
        await _databaseHelper.insertCancelledPenaltyFee(cancelledPenaltyFee);
        
        // Remove original penalty fee
        await _databaseHelper.deletePenaltyFee(penaltyFee.id);
        
        print('✅ Penalty fee cancelled successfully: ${penaltyFee.receiptNumber}');
        return CancellationResult(
          success: true,
          message: responseData['message'] ?? 'Penalty fee cancelled successfully',
        );
      } else {
        print('❌ Failed to cancel penalty fee: ${response.statusCode}');
        return CancellationResult(
          success: false,
          message: 'Failed to cancel penalty fee',
        );
      }
      
    } catch (e) {
      print('❌ Error cancelling penalty fee: $e');
      return CancellationResult(
        success: false,
        message: 'Error cancelling penalty fee: $e',
      );
    }
  }

  Future<List<CancelledPenaltyFee>> getCancelledPenaltyFees() async {
    if (!isLoggedIn) return [];
    
    try {
      await _apiService.initialize();
      
      print('🔄 Loading cancelled penalty fees for branch: ${_currentUser!.branch}...');
      
      final response = await _apiService.getCancelledPenaltyReceipts(_currentUser!.branch);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        final List<dynamic> cancelledList = responseData['cancelledPenaltyReceipts'] ?? [];
        
        final cancelledPenaltyFees = cancelledList
            .map((json) => CancelledPenaltyFee.fromJson(json))
            .toList();
        
        print('✅ Loaded ${cancelledPenaltyFees.length} cancelled penalty fees');
        return cancelledPenaltyFees;
      } else {
        print('❌ Failed to load cancelled penalty fees: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading cancelled penalty fees: $e');
      return [];
    }
  }

  /// Store cancelled receipt locally for offline sync
  Future<void> storeCancellationLocally({
    required String receiptNumber,
    required String receiptType,
    required String reason,
    required String branch,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cancellationData = {
        'receiptNumber': receiptNumber,
        'receiptType': receiptType,
        'reason': reason,
        'branch': branch,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final existingCancellations = prefs.getStringList('pending_cancellations') ?? [];
      existingCancellations.add(json.encode(cancellationData));
      
      await prefs.setStringList('pending_cancellations', existingCancellations);
      print('📱 Stored cancellation locally: $receiptNumber');
    } catch (e) {
      print('❌ Error storing cancellation locally: $e');
    }
  }

  /// Sync pending cancellations when online
  Future<void> syncPendingCancellations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCancellations = prefs.getStringList('pending_cancellations') ?? [];
      
      if (pendingCancellations.isEmpty) {
        print('📱 No pending cancellations to sync');
        return;
      }

      print('🔄 Syncing ${pendingCancellations.length} pending cancellations...');
      
      final List<String> remainingCancellations = [];
      
      for (final cancellationJson in pendingCancellations) {
        try {
          final cancellationData = json.decode(cancellationJson);
          
          final response = await _apiService.postCancelledAdminReceipt(cancellationData);
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            print('✅ Synced cancellation: ${cancellationData['receiptNumber']}');
          } else {
            print('❌ Failed to sync cancellation: ${cancellationData['receiptNumber']}');
            remainingCancellations.add(cancellationJson);
          }
        } catch (e) {
          print('❌ Error syncing individual cancellation: $e');
          remainingCancellations.add(cancellationJson);
        }
      }
      
      // Update the pending list with only the ones that failed
      await prefs.setStringList('pending_cancellations', remainingCancellations);
      
      print('📱 Sync complete. ${remainingCancellations.length} cancellations remain pending.');
    } catch (e) {
      print('❌ Error syncing pending cancellations: $e');
    }
  }

  /// Start background sync timer for offline-first functionality
  void _startBackgroundSync() {
    // Cancel existing timer if any
    _stopBackgroundSync();
    
    print('🔄 Starting background sync timer (every 30 seconds)');
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _performBackgroundSync();
    });
    
    // Also perform initial sync
    _performBackgroundSync();
  }

  /// Stop background sync timer
  void _stopBackgroundSync() {
    if (_backgroundSyncTimer != null) {
      _backgroundSyncTimer!.cancel();
      _backgroundSyncTimer = null;
      print('⏹️ Background sync timer stopped');
    }
  }

  /// Perform background sync for all unsynced data
  Future<void> _performBackgroundSync() async {
    if (!isLoggedIn) return;

    try {
      print('🔄 Background sync: Checking for unsynced data...');
      
      // Check connectivity first by trying a quick API call
      bool hasInternet = await _checkInternetConnectivity();
      if (!hasInternet) {
        print('📡 No internet connection - skipping sync');
        return;
      }

      print('📡 Internet connected - syncing unsynced data');
      
      // Sync penalty fees
      try {
        final unsyncedPenalties = await _databaseHelper.getUnsyncedPenaltyFeesCount();
        if (unsyncedPenalties > 0) {
          print('🔄 Background sync: $unsyncedPenalties unsynced penalty fees');
          await _autoSyncPenaltyFees();
        }
      } catch (e) {
        print('❌ Background sync penalty fees failed: $e');
      }

      // Sync repayments
      try {
        final unsyncedRepayments = await _databaseHelper.getUnsyncedRepaymentsCount();
        if (unsyncedRepayments > 0) {
          print('🔄 Background sync: $unsyncedRepayments unsynced repayments');
          await _autoSyncRepayments();
        }
      } catch (e) {
        print('❌ Background sync repayments failed: $e');
      }

      // Sync transfers
      try {
        final unsyncedTransfers = await _databaseHelper.getQueuedTransfersCount();
        if (unsyncedTransfers > 0) {
          print('🔄 Background sync: $unsyncedTransfers queued transfers');
          await _autoSyncTransfers();
        }
      } catch (e) {
        print('❌ Background sync transfers failed: $e');
      }

      // Sync expenses
      try {
        final unsyncedExpenses = await _databaseHelper.getQueuedExpensesCount();
        if (unsyncedExpenses > 0) {
          print('🔄 Background sync: $unsyncedExpenses queued expenses');
          await _autoSyncExpenses();
        }
      } catch (e) {
        print('❌ Background sync expenses failed: $e');
      }

      // Sync petty cash
      try {
        final queuedPettyCash = await _databaseHelper.getQueuedPettyCash();
        if (queuedPettyCash.isNotEmpty) {
          print('🔄 Background sync: ${queuedPettyCash.length} queued petty cash entries');
          await _autoSyncPettyCash();
        }
      } catch (e) {
        print('❌ Background sync petty cash failed: $e');
      }

      // Sync cash counts
      try {
        final queuedCashCounts = await _databaseHelper.getQueuedCashCounts();
        if (queuedCashCounts.isNotEmpty) {
          print('🔄 Background sync: ${queuedCashCounts.length} queued cash count entries');
          await _autoSyncCashCounts();
        }
      } catch (e) {
        print('❌ Background sync cash counts failed: $e');
      }

      // Sync request balances
      try {
        final queuedRequestBalances = await _databaseHelper.getPendingRequestBalances();
        if (queuedRequestBalances.isNotEmpty) {
          print('🔄 Background sync: ${queuedRequestBalances.length} queued request balance entries');
          await _syncRequestBalancesInBackground();
        }
      } catch (e) {
        print('❌ Background sync request balances failed: $e');
      }

      // Process pending cashbook downloads
      try {
        final pendingDownloads = await _databaseHelper.getPendingCashbookDownloads();
        if (pendingDownloads.isNotEmpty) {
          print('🔄 Background processing: ${pendingDownloads.length} pending cashbook downloads');
          await _processQueuedDownloads();
        }
      } catch (e) {
        print('❌ Background cashbook downloads failed: $e');
      }

      // Clean up expired transfers
      try {
        await _databaseHelper.cleanupTransfersData();
      } catch (e) {
        print('❌ Transfer cleanup failed: $e');
      }

      // Clean up expired expenses
      try {
        await _databaseHelper.cleanupExpensesData();
      } catch (e) {
        print('❌ Expenses cleanup failed: $e');
      }

      // Clean up expired petty cash
      try {
        await _databaseHelper.cleanupPettyCashData();
      } catch (e) {
        print('❌ Petty cash cleanup failed: $e');
      }

      // Clean up expired cash counts
      try {
        await _databaseHelper.cleanupCashCountData();
      } catch (e) {
        print('❌ Cash count cleanup failed: $e');
      }

      // Clean up old cashbook downloads
      try {
        await _databaseHelper.cleanupCashbookDownloadsData();
      } catch (e) {
        print('❌ Cashbook downloads cleanup failed: $e');
      }

      // Clean up old request balances
      try {
        await _databaseHelper.cleanupOldRequestBalances();
      } catch (e) {
        print('❌ Request balances cleanup failed: $e');
      }

      // Sync disbursements - only sync for client if implemented
      try {
        // For now, skip disbursement background sync
        // Will implement If needed later
        print('📋 Background sync: Disbursement sync not implemented yet');
      } catch (e) {
        print('❌ Background sync disbursements failed: $e');
      }

      // Sync pending cancellations
      try {
        await syncPendingCancellations();
      } catch (e) {
        print('❌ Background sync cancellations failed: $e');
      }

      print('✅ Background sync completed');
    } catch (e) {
      print('❌ Background sync error: $e');
    }
  }

  /// Check internet connectivity by making a simple API call
  Future<bool> _checkInternetConnectivity() async {
    try {
      await _apiService.initialize();
      
      // Try any simple GET request that should exist
      final response = await _apiService.get('/api/QuickLoadClients/load-clients?branchName=test').timeout(Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 500; // Even 404 means server is reachable
    } catch (e) {
      return false;
    }
  }

  // Branch operations
  /// Sync branches from server
  Future<BranchSyncResult> syncBranches() async {
    try {
      print('🔄 Syncing branches from server...');
      await _apiService.initialize();
      
      final response = await _apiService.getBranches();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body) as List<dynamic>;
        
        final branches = responseData
            .map((branchJson) => Branch.fromJson(branchJson as Map<String, dynamic>))
            .toList();
        
        if (branches.isNotEmpty) {
          // Delete all existing branches and insert new ones
          await _databaseHelper.deleteAllBranches();
          await _databaseHelper.insertMultipleBranches(branches);
        }
        
        print('✅ Successfully synced ${branches.length} branches');
        
        return BranchSyncResult(
          success: true,
          message: 'Successfully synced ${branches.length} branches',
          branchesLoaded: branches.length,
          branches: branches,
        );
      } else {
        print('❌ Failed to sync branches: ${response.statusCode}');
        return BranchSyncResult(
          success: false,
          message: 'Failed to sync branches from server',
          branchesLoaded: 0,
        );
      }
    } catch (e) {
      print('❌ Error syncing branches: $e');
      return BranchSyncResult(
        success: false,
        message: 'Failed to sync branches: $e',
        branchesLoaded: 0,
      );
    }
  }

  /// Get all branches from local database
  Future<List<Branch>> getAllBranches() async {
    return await _databaseHelper.getAllBranches();
  }

  /// Get branches count
  Future<int> getBranchesCount() async {
    return await _databaseHelper.getBranchesCount();
  }

  /// Get last branch sync time
  Future<DateTime?> getLastBranchSyncTime() async {
    return await _databaseHelper.getLastBranchSyncTime();
  }

  // ===== TRANSFER MANAGEMENT METHODS =====

  /// Create a new transfer (offline-first)
  Future<TransferResult> createTransfer({
    required double amount,
    required DateTime transferDate,
    required int receivingBranchId,
    required String receivingBranch,
    required String transferType, // 'USD_CASH', 'USD_BANK', 'ZWG_BANK'
  }) async {
    if (!isLoggedIn || _currentUser == null) {
      return TransferResult(
        success: false,
        message: 'User not logged in',
        transfer: null,
      );
    }

    try {
      // Validate amount
      if (amount <= 0) {
        return TransferResult(
          success: false,
          message: 'Amount must be greater than zero',
          transfer: null,
        );
      }

      // Validate date (not more than 2 days ago, not in future)
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(Duration(days: 2));
      
      if (transferDate.isBefore(twoDaysAgo)) {
        return TransferResult(
          success: false,
          message: 'Transfer date cannot be more than 2 days ago',
          transfer: null,
        );
      }
      
      if (transferDate.isAfter(now)) {
        return TransferResult(
          success: false,
          message: 'Transfer date cannot be in the future',
          transfer: null,
        );
      }

      // Validate receiving branch (can't be same as user's branch)
      if (receivingBranchId == _currentUser!.branchId) {
        return TransferResult(
          success: false,
          message: 'Cannot transfer to your own branch',
          transfer: null,
        );
      }

      // Check if user can create transfer (prevent spam)
      final canCreate = await _databaseHelper.canUserCreateTransfer(_currentUser!.branchId);
      if (!canCreate) {
        return TransferResult(
          success: false,
          message: 'Too many pending transfers. Please wait or try again later.',
          transfer: null,
        );
      }

      // Create transfer object
      final transfer = Transfer(
        amount: amount,
        transferDate: transferDate,
        sendingBranchId: _currentUser!.branchId,
        sendingBranch: _currentUser!.branch,
        receivingBranchId: receivingBranchId,
        receivingBranch: receivingBranch,
        transferType: transferType,
        isSynced: false,
        createdAt: DateTime.now(),
      );

      // Store locally
      final transferId = await _databaseHelper.insertTransfer(transfer);
      final storedTransfer = await _databaseHelper.getTransferById(transferId);

      print('✅ Transfer created locally: ${transferType} \$${amount.toStringAsFixed(2)} to ${receivingBranch}');

      // Try to sync immediately if we have internet (with small delay)
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoSyncTransfers();
      });

      return TransferResult(
        success: true,
        message: 'Transfer created successfully - queued for sync',
        transfer: storedTransfer,
      );
    } catch (e) {
      print('Error creating transfer: $e');
      return TransferResult(
        success: false,
        message: 'Failed to create transfer: $e',
        transfer: null,
      );
    }
  }

  /// Auto-sync queued transfers in background - ONLY mark as synced on TRUE SUCCESS
  Future<void> _autoSyncTransfers() async {
    try {
      final queuedTransfers = await _databaseHelper.getQueuedTransfers();
      if (queuedTransfers.isEmpty) {
        return; // No queued transfers to sync
      }

      print('🔄 Auto-syncing ${queuedTransfers.length} transfers...');
      await _apiService.initialize();

      for (final transfer in queuedTransfers) {
        try {
          // Check if transfer is expired (24+ hours old)
          if (transfer.isExpired && !transfer.isSynced) {
            print('⏰ Transfer expired, deleting: ${transfer.id}');
            await _databaseHelper.deleteTransfer(transfer.id!);
            continue;
          }

          // Prepare API payload (excluding narration as required)
          final transferData = transfer.toJson();
          
          print('🔄 Auto-syncing ${transfer.transferType} transfer ${transfer.id}: \$${transfer.amount.toStringAsFixed(2)}');

          // Call appropriate API endpoint based on transfer type and validate response
          http.Response response;
          bool syncSuccess = false;

          switch (transfer.transferType) {
            case 'USD_CASH':
              response = await _apiService.submitUSDCashTransfer(transferData);
              break;
            case 'USD_BANK':
              response = await _apiService.submitUSDBankTransfer(transferData);
              break;
            case 'ZWG_BANK':
              response = await _apiService.submitZWGBankTransfer(transferData);
              break;
            default:
              print('❌ Unknown transfer type: ${transfer.transferType}');
              continue;
          }

          // Validate response - ONLY mark as synced if we get 201 with valid response containing Id
          if (response.statusCode == 201) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response contains required fields (Id, Amount, etc.)
              if (responseData is Map<String, dynamic> && 
                  responseData.containsKey('Id') && 
                  responseData['Id'] != null &&
                  responseData['Id'] is int &&
                  responseData['Id'] > 0) {
                
                syncSuccess = true;
                print('✅ Transfer ${transfer.id} synced successfully with API ID: ${responseData['Id']}');
                print('✅ Response: Amount=${responseData['Amount']}, SendingBranch=${responseData['SendingBranch']}, ReceivingBranch=${responseData['ReceivingBranch']}');
              } else {
                print('❌ Transfer ${transfer.id} - Invalid response structure or missing Id field');
                print('❌ Response body: ${response.body}');
              }
            } catch (e) {
              print('❌ Transfer ${transfer.id} - Error parsing response JSON: $e');
              print('❌ Response body: ${response.body}');
            }
          } else {
            print('❌ Transfer ${transfer.id} - Unexpected status code: ${response.statusCode}');
            print('❌ Response body: ${response.body}');
          }

          // Only mark as synced if we had true success
          if (syncSuccess) {
            await _databaseHelper.updateTransferSyncStatus(transfer.id!, true);
            print('✅ Transfer ${transfer.id} marked as synced in database');
          } else {
            print('❌ Transfer ${transfer.id} NOT marked as synced - sync failed');
          }

        } catch (e) {
          print('❌ Error syncing transfer ${transfer.id}: $e');
          // Continue with other transfers even if one fails
          continue;
        }
      }

      // Clean up old transfers after sync attempt
      await _databaseHelper.cleanupTransfersData();
    } catch (e) {
      print('❌ Error in auto-sync transfers: $e');
    }
  }

  /// Manually sync queued transfers
  Future<TransferSyncResult> syncQueuedTransfers() async {
    if (!isLoggedIn || _currentUser == null) {
      return TransferSyncResult(
        success: false,
        message: 'User not logged in',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final queuedTransfers = await _databaseHelper.getQueuedTransfers();

      if (queuedTransfers.isEmpty) {
        return TransferSyncResult(
          success: true,
          message: 'No queued transfers to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      await _apiService.initialize();

      int syncedCount = 0;
      int failedCount = 0;
      List<String> syncErrors = [];

      for (final transfer in queuedTransfers) {
        try {
          // Check if transfer is expired
          if (transfer.isExpired) {
            await _databaseHelper.deleteTransfer(transfer.id!);
            failedCount++;
            syncErrors.add('Transfer ${transfer.id} expired and removed');
            continue;
          }

          print('🔄 Syncing transfer: ${transfer.transferType} \$${transfer.amount.toStringAsFixed(2)}...');

          final transferData = transfer.toJson();
          
          // Call appropriate API endpoint based on transfer type and validate response
          http.Response response;
          bool syncSuccess = false;

          switch (transfer.transferType) {
            case 'USD_CASH':
              response = await _apiService.submitUSDCashTransfer(transferData);
              break;
            case 'USD_BANK':
              response = await _apiService.submitUSDBankTransfer(transferData);
              break;
            case 'ZWG_BANK':
              response = await _apiService.submitZWGBankTransfer(transferData);
              break;
            default:
              failedCount++;
              syncErrors.add('Transfer ${transfer.id}: Unknown transfer type');
              continue;
          }

          // Validate response - ONLY mark as synced if we get 201 with valid response containing Id
          if (response.statusCode == 201) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response contains required fields (Id, Amount, etc.)
              if (responseData is Map<String, dynamic> && 
                  responseData.containsKey('Id') && 
                  responseData['Id'] != null &&
                  responseData['Id'] is int &&
                  responseData['Id'] > 0) {
                
                syncSuccess = true;
                print('✅ Transfer ${transfer.id} synced successfully with API ID: ${responseData['Id']}');
              } else {
                syncErrors.add('Transfer ${transfer.id}: Invalid response structure or missing Id field');
              }
            } catch (e) {
              syncErrors.add('Transfer ${transfer.id}: Error parsing response JSON - $e');
            }
          } else {
            syncErrors.add('Transfer ${transfer.id}: Unexpected status code ${response.statusCode}');
          }

          // Only mark as synced and count as success if we had true success
          if (syncSuccess) {
            await _databaseHelper.updateTransferSyncStatus(transfer.id!, true);
            syncedCount++;
            print('✅ Synced transfer ${transfer.id}');
          } else {
            failedCount++;
            print('❌ Failed to sync transfer ${transfer.id}');
          }
        } catch (e) {
          failedCount++;
          syncErrors.add('Transfer ${transfer.id}: $e');
          print('❌ Error syncing transfer ${transfer.id}: $e');
        }
      }

      String message = '$syncedCount transfers synced successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      return TransferSyncResult(
        success: syncedCount > 0 || failedCount == 0,
        message: message,
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      print('Error syncing queued transfers: $e');
      return TransferSyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    }
  }

  /// Get all transfers
  Future<List<Transfer>> getAllTransfers() async {
    return await _databaseHelper.getAllTransfers();
  }

  /// Get queued transfers (not synced)
  Future<List<Transfer>> getQueuedTransfers() async {
    return await _databaseHelper.getQueuedTransfers();
  }

  /// Get synced transfers
  Future<List<Transfer>> getSyncedTransfers() async {
    return await _databaseHelper.getSyncedTransfers();
  }

  /// Get transfers by type
  Future<List<Transfer>> getTransfersByType(String transferType) async {
    return await _databaseHelper.getTransfersByType(transferType);
  }

  /// Delete a queued transfer
  Future<TransferResult> deleteQueuedTransfer(int transferId) async {
    if (!isLoggedIn) {
      return TransferResult(
        success: false,
        message: 'User not logged in',
        transfer: null,
      );
    }

    try {
      final transfer = await _databaseHelper.getTransferById(transferId);
      if (transfer == null) {
        return TransferResult(
          success: false,
          message: 'Transfer not found',
          transfer: null,
        );
      }

      if (transfer.isSynced) {
        return TransferResult(
          success: false,
          message: 'Cannot delete synced transfer',
          transfer: null,
        );
      }

      if (transfer.isExpired) {
        return TransferResult(
          success: false,
          message: 'Transfer has expired and cannot be deleted',
          transfer: null,
        );
      }

      final deleted = await _databaseHelper.deleteTransfer(transferId);
      if (deleted > 0) {
        print('🗑️ Deleted queued transfer: ${transferId}');
        return TransferResult(
          success: true,
          message: 'Transfer deleted successfully',
          transfer: transfer,
        );
      } else {
        return TransferResult(
          success: false,
          message: 'Failed to delete transfer',
          transfer: null,
        );
      }
    } catch (e) {
      print('Error deleting transfer: $e');
      return TransferResult(
        success: false,
        message: 'Error deleting transfer: $e',
        transfer: null,
      );
    }
  }

  /// Get transfer counts
  Future<Map<String, int>> getTransferCounts() async {
    final queuedCount = await _databaseHelper.getQueuedTransfersCount();
    final syncedCount = await _databaseHelper.getSyncedTransfersCount();
    
    return {
      'queued': queuedCount,
      'synced': syncedCount,
      'total': queuedCount + syncedCount,
    };
  }

  /// Get available receiving branches (excluding user's branch)
  Future<List<Branch>> getAvailableReceivingBranches() async {
    if (!isLoggedIn || _currentUser == null) {
      return [];
    }

    final allBranches = await _databaseHelper.getAllBranches();
    
    // Filter out user's own branch
    return allBranches.where((branch) => branch.branchId != _currentUser!.branchId).toList();
  }

  /// Validate transfer date (helper method)
  bool isValidTransferDate(DateTime date) {
    final now = DateTime.now();
    final twoDaysAgo = now.subtract(Duration(days: 2));
    
    return date.isAfter(twoDaysAgo) && !date.isAfter(now);
  }

  /// Get transfer summary for reporting
  Future<Map<String, dynamic>> getTransferSummary() async {
    try {
      final transfers = await getAllTransfers();
      final queuedTransfers = transfers.where((t) => !t.isSynced).toList();
      final syncedTransfers = transfers.where((t) => t.isSynced).toList();
      
      // Calculate totals by type
      double totalUSDCash = 0;
      double totalUSDBank = 0;
      double totalZWGBank = 0;
      
      for (final transfer in syncedTransfers) {
        switch (transfer.transferType) {
          case 'USD_CASH':
            totalUSDCash += transfer.amount;
            break;
          case 'USD_BANK':
            totalUSDBank += transfer.amount;
            break;
          case 'ZWG_BANK':
            totalZWGBank += transfer.amount;
            break;
        }
      }
      
      return {
        'totalTransfers': transfers.length,
        'queuedTransfers': queuedTransfers.length,
        'syncedTransfers': syncedTransfers.length,
        'expiredTransfers': queuedTransfers.where((t) => t.isExpired).length,
        'totalUSDCash': totalUSDCash,
        'totalUSDBank': totalUSDBank,
        'totalZWGBank': totalZWGBank,
      };
    } catch (e) {
      print('Error getting transfer summary: $e');
      return {};
    }
  }

  // ===== END TRANSFER MANAGEMENT METHODS =====

  // ===== EXPENSE MANAGEMENT METHODS =====

  /// Create a new expense (offline-first)
  Future<ExpenseResult> createExpense({
    required String category,
    required double amount,
    required DateTime expenseDate,
  }) async {
    if (!isLoggedIn || _currentUser == null) {
      return ExpenseResult(
        success: false,
        message: 'User not logged in',
        expense: null,
      );
    }

    try {
      // Validate amount
      if (amount <= 0) {
        return ExpenseResult(
          success: false,
          message: 'Amount must be greater than zero',
          expense: null,
        );
      }

      // Validate date (not more than 2 days ago, not in future)
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(Duration(days: 2));
      
      if (expenseDate.isBefore(twoDaysAgo)) {
        return ExpenseResult(
          success: false,
          message: 'Expense date cannot be more than 2 days ago',
          expense: null,
        );
      }
      
      if (expenseDate.isAfter(now)) {
        return ExpenseResult(
          success: false,
          message: 'Expense date cannot be in the future',
          expense: null,
        );
      }

      // Validate category
      if (!ExpenseCategoryHelper.categories.contains(category)) {
        return ExpenseResult(
          success: false,
          message: 'Invalid expense category',
          expense: null,
        );
      }

      // Create expense object
      final expense = Expense(
        branchName: _currentUser!.branch,
        category: category,
        amount: amount,
        expenseDate: expenseDate,
        isSynced: false,
        createdAt: DateTime.now(),
      );

      // Check for potential duplicates (WARNING only, don't block)
      final similarExpenses = await _databaseHelper.findSimilarExpenses(expense);
      String warningMessage = '';
      
      if (similarExpenses.isNotEmpty) {
        warningMessage = '\n⚠️ WARNING: Similar expense found (${ExpenseCategoryHelper.getDisplayName(category)}, \$${amount.toStringAsFixed(2)}, ${expense.formattedDate})';
      }

      // Store locally
      final expenseId = await _databaseHelper.insertExpense(expense);
      final storedExpense = await _databaseHelper.getExpenseById(expenseId);

      print('✅ Expense created locally: ${ExpenseCategoryHelper.getDisplayName(category)} \$${amount.toStringAsFixed(2)} for ${_currentUser!.branch}');

      // Try to sync immediately if we have internet (with small delay)
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoSyncExpenses();
      });

      return ExpenseResult(
        success: true,
        message: 'Expense created successfully - queued for sync${warningMessage}',
        expense: storedExpense,
      );
    } catch (e) {
      print('Error creating expense: $e');
      return ExpenseResult(
        success: false,
        message: 'Failed to create expense: $e',
        expense: null,
      );
    }
  }

  /// Auto-sync queued expenses in background - ONLY mark as synced on TRUE SUCCESS
  Future<void> _autoSyncExpenses() async {
    try {
      final queuedExpenses = await _databaseHelper.getQueuedExpenses();
      if (queuedExpenses.isEmpty) {
        return; // No queued expenses to sync
      }

      print('🔄 Auto-syncing ${queuedExpenses.length} expenses...');
      await _apiService.initialize();

      for (final expense in queuedExpenses) {
        try {
          // Prepare API payload
          final expenseData = expense.toJson();
          
          print('🔄 Auto-syncing ${ExpenseCategoryHelper.getDisplayName(expense.category)} expense ${expense.id}: \$${expense.amount.toStringAsFixed(2)}');

          // Call expense API endpoint and validate response
          final response = await _apiService.submitExpense(expenseData);
          bool syncSuccess = false;

          // Validate response - ONLY mark as synced if we get 200 with valid response containing Id
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response contains required fields (Id, Amount, etc.)
              if (responseData is Map<String, dynamic> && 
                  responseData.containsKey('Id') && 
                  responseData['Id'] != null &&
                  responseData['Id'] is int &&
                  responseData['Id'] > 0) {
                
                syncSuccess = true;
                print('✅ Expense ${expense.id} synced successfully with API ID: ${responseData['Id']}');
                print('✅ Response: Amount=${responseData['Amount']}, BranchName=${responseData['BranchName']}, Category=${responseData['Category']}');
              } else {
                print('❌ Expense ${expense.id} - Invalid response structure or missing Id field');
                print('❌ Response body: ${response.body}');
              }
            } catch (e) {
              print('❌ Expense ${expense.id} - Error parsing response JSON: $e');
              print('❌ Response body: ${response.body}');
            }
          } else {
            print('❌ Expense ${expense.id} - Unexpected status code: ${response.statusCode}');
            print('❌ Response body: ${response.body}');
          }

          // Only mark as synced if we had true success
          if (syncSuccess) {
            await _databaseHelper.updateExpenseSyncStatus(expense.id!, true);
            print('✅ Expense ${expense.id} marked as synced in database');
          } else {
            print('❌ Expense ${expense.id} NOT marked as synced - sync failed');
          }

        } catch (e) {
          print('❌ Error syncing expense ${expense.id}: $e');
          // Continue with other expenses even if one fails
          continue;
        }
      }

      // Clean up old expenses after sync attempt
      await _databaseHelper.cleanupExpensesData();
    } catch (e) {
      print('❌ Error in auto-sync expenses: $e');
    }
  }

  /// Manually sync queued expenses
  Future<ExpenseSyncResult> syncQueuedExpenses() async {
    if (!isLoggedIn || _currentUser == null) {
      return ExpenseSyncResult(
        success: false,
        message: 'User not logged in',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final queuedExpenses = await _databaseHelper.getQueuedExpenses();

      if (queuedExpenses.isEmpty) {
        return ExpenseSyncResult(
          success: true,
          message: 'No queued expenses to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      await _apiService.initialize();

      int syncedCount = 0;
      int failedCount = 0;
      List<String> syncErrors = [];

      for (final expense in queuedExpenses) {
        try {
          print('🔄 Syncing expense: ${ExpenseCategoryHelper.getDisplayName(expense.category)} \$${expense.amount.toStringAsFixed(2)}...');

          final expenseData = expense.toJson();
          final response = await _apiService.submitExpense(expenseData);
          bool syncSuccess = false;

          // Validate response - ONLY mark as synced if we get 200 with valid response containing Id
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response contains required fields (Id, Amount, etc.)
              if (responseData is Map<String, dynamic> && 
                  responseData.containsKey('Id') && 
                  responseData['Id'] != null &&
                  responseData['Id'] is int &&
                  responseData['Id'] > 0) {
                
                syncSuccess = true;
                print('✅ Expense ${expense.id} synced successfully with API ID: ${responseData['Id']}');
              } else {
                syncErrors.add('Expense ${expense.id}: Invalid response structure or missing Id field');
              }
            } catch (e) {
              syncErrors.add('Expense ${expense.id}: Error parsing response JSON - $e');
            }
          } else {
            syncErrors.add('Expense ${expense.id}: Unexpected status code ${response.statusCode}');
          }

          // Only mark as synced and count as success if we had true success
          if (syncSuccess) {
            await _databaseHelper.updateExpenseSyncStatus(expense.id!, true);
            syncedCount++;
            print('✅ Synced expense ${expense.id}');
          } else {
            failedCount++;
            print('❌ Failed to sync expense ${expense.id}');
          }
        } catch (e) {
          failedCount++;
          syncErrors.add('Expense ${expense.id}: $e');
          print('❌ Error syncing expense ${expense.id}: $e');
        }
      }

      String message = '$syncedCount expenses synced successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      return ExpenseSyncResult(
        success: syncedCount > 0 || failedCount == 0,
        message: message,
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      print('Error syncing queued expenses: $e');
      return ExpenseSyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    }
  }

  /// Get all expenses
  Future<List<Expense>> getAllExpenses() async {
    return await _databaseHelper.getAllExpenses();
  }

  /// Get queued expenses (not synced)
  Future<List<Expense>> getQueuedExpenses() async {
    return await _databaseHelper.getQueuedExpenses();
  }

  /// Get synced expenses (not expired)
  Future<List<Expense>> getSyncedExpenses() async {
    return await _databaseHelper.getSyncedExpenses();
  }

  /// Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    return await _databaseHelper.getExpensesByCategory(category);
  }

  /// Delete a queued expense
  Future<ExpenseResult> deleteQueuedExpense(int expenseId) async {
    if (!isLoggedIn) {
      return ExpenseResult(
        success: false,
        message: 'User not logged in',
        expense: null,
      );
    }

    try {
      final expense = await _databaseHelper.getExpenseById(expenseId);
      if (expense == null) {
        return ExpenseResult(
          success: false,
          message: 'Expense not found',
          expense: null,
        );
      }

      if (expense.isSynced) {
        return ExpenseResult(
          success: false,
          message: 'Cannot delete synced expense',
          expense: null,
        );
      }

      final deleted = await _databaseHelper.deleteExpense(expenseId);
      if (deleted > 0) {
        print('🗑️ Deleted queued expense: ${expenseId}');
        return ExpenseResult(
          success: true,
          message: 'Expense deleted successfully',
          expense: expense,
        );
      } else {
        return ExpenseResult(
          success: false,
          message: 'Failed to delete expense',
          expense: null,
        );
      }
    } catch (e) {
      print('Error deleting expense: $e');
      return ExpenseResult(
        success: false,
        message: 'Error deleting expense: $e',
        expense: null,
      );
    }
  }

  /// Get expense counts
  Future<Map<String, int>> getExpenseCounts() async {
    final queuedCount = await _databaseHelper.getQueuedExpensesCount();
    final syncedCount = await _databaseHelper.getSyncedExpensesCount();
    
    return {
      'queued': queuedCount,
      'synced': syncedCount,
      'total': queuedCount + syncedCount,
    };
  }

  /// Validate expense date (helper method)
  bool isValidExpenseDate(DateTime date) {
    final now = DateTime.now();
    final twoDaysAgo = now.subtract(Duration(days: 2));
    
    return date.isAfter(twoDaysAgo) && !date.isAfter(now);
  }

  /// Get expense categories (helper method)
  List<String> getExpenseCategories() {
    return ExpenseCategoryHelper.categories;
  }

  /// Get expense category display names (helper method)
  Map<String, String> getExpenseCategoryDisplayNames() {
    return ExpenseCategoryHelper.categoryDisplayNames;
  }

  /// Check for duplicate expenses (warning only)
  Future<List<Expense>> checkForSimilarExpenses(Expense expense) async {
    return await _databaseHelper.findSimilarExpenses(expense);
  }

  /// Get expense summary for reporting
  Future<Map<String, dynamic>> getExpenseSummary() async {
    try {
      final expenses = await getAllExpenses();
      final queuedExpenses = expenses.where((e) => !e.isSynced).toList();
      final syncedExpenses = expenses.where((e) => e.isSynced && !e.isExpired).toList();
      
      // Calculate totals by category
      Map<String, double> totalsByCategory = {};
      
      for (final expense in syncedExpenses) {
        totalsByCategory[expense.category] = 
            (totalsByCategory[expense.category] ?? 0) + expense.amount;
      }
      
      return {
        'totalExpenses': expenses.length,
        'queuedExpenses': queuedExpenses.length,
        'syncedExpenses': syncedExpenses.length,
        'totalsByCategory': totalsByCategory,
        'grandTotal': syncedExpenses.fold<double>(0, (sum, expense) => sum + expense.amount),
      };
    } catch (e) {
      print('Error getting expense summary: $e');
      return {};
    }
  }

  /// Get expenses for date range
  Future<List<Expense>> getExpensesForDateRange(DateTime startDate, DateTime endDate) async {
    if (!isLoggedIn || _currentUser == null) {
      return [];
    }
    
    return await _databaseHelper.getExpensesForDateRange(startDate, endDate, branchName: _currentUser!.branch);
  }

  // ===== END EXPENSE MANAGEMENT METHODS =====

  // ===== FUND PETTY CASH MANAGEMENT METHODS =====

  /// Fund petty cash (offline-first)
  Future<PettyCashResult> fundPettyCash({
    required double amount,
    required DateTime dateApplicable,
  }) async {
    if (!isLoggedIn || _currentUser == null) {
      return PettyCashResult(
        success: false,
        message: 'User not logged in',
        pettyCash: null,
      );
    }

    try {
      // Validate amount
      if (amount <= 0) {
        return PettyCashResult(
          success: false,
          message: 'Amount must be greater than zero',
          pettyCash: null,
        );
      }

      // Validate date (not more than 2 days ago, not in future)
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(Duration(days: 2));
      
      if (dateApplicable.isBefore(twoDaysAgo)) {
        return PettyCashResult(
          success: false,
          message: 'Date applicable cannot be more than 2 days ago',
          pettyCash: null,
        );
      }
      
      if (dateApplicable.isAfter(now)) {
        return PettyCashResult(
          success: false,
          message: 'Date applicable cannot be in the future',
          pettyCash: null,
        );
      }

      // Create petty cash object
      final pettyCash = PettyCash(
        branchName: _currentUser!.branch,
        amount: amount,
        dateApplicable: dateApplicable,
        isSynced: false,
        createdAt: DateTime.now(),
      );

      // Check for potential duplicates (WARNING only, don't block)
      final similarEntries = await _databaseHelper.findSimilarPettyCash(pettyCash);
      String warningMessage = '';
      
      if (similarEntries.isNotEmpty) {
        warningMessage = '\n⚠️ WARNING: Similar petty cash funding found (${pettyCash.formattedAmount}, ${pettyCash.formattedDate})';
      }

      // Store locally
      final pettyCashId = await _databaseHelper.insertPettyCash(pettyCash);
      final storedPettyCash = await _databaseHelper.getPettyCashById(pettyCashId);

      print('✅ Petty cash funded locally: ${pettyCash.formattedAmount} for ${_currentUser!.branch}');

      // Try to sync immediately if we have internet (with small delay)
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoSyncPettyCash();
      });

      return PettyCashResult(
        success: true,
        message: 'Petty cash funded successfully - queued for sync${warningMessage}',
        pettyCash: storedPettyCash,
      );
    } catch (e) {
      print('Error funding petty cash: $e');
      return PettyCashResult(
        success: false,
        message: 'Failed to fund petty cash: $e',
        pettyCash: null,
      );
    }
  }

  /// Auto-sync queued petty cash in background - ONLY mark as synced on TRUE SUCCESS
  Future<void> _autoSyncPettyCash() async {
    try {
      final queuedPettyCash = await _databaseHelper.getQueuedPettyCash();
      if (queuedPettyCash.isEmpty) {
        return; // No queued petty cash to sync
      }

      print('🔄 Auto-syncing ${queuedPettyCash.length} petty cash entries...');
      await _apiService.initialize();

      for (final pettyCash in queuedPettyCash) {
        try {
          // Prepare API payload
          final pettyCashData = pettyCash.toJson();
          
          print('🔄 Auto-syncing petty cash ${pettyCash.id}: ${pettyCash.formattedAmount}');

          // Call fund petty cash API endpoint and validate response
          final response = await _apiService.fundPettyCash(pettyCashData);
          bool syncSuccess = false;

          // Validate response - ONLY mark as synced if we get 200 with valid response
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response indicates success
              if (responseData is Map<String, dynamic>) {
                // Based on the expected response: { success = true, message = "Petty cash funded successfully.", data = record }
                if (responseData.containsKey('success') && responseData['success'] == true) {
                  syncSuccess = true;
                  print('✅ Petty cash ${pettyCash.id} synced successfully');
                  print('✅ Response message: ${responseData['message']}');
                } else {
                  print('❌ Petty cash ${pettyCash.id}: API returned success=false or invalid structure');
                }
              } else {
                print('❌ Petty cash ${pettyCash.id}: Invalid response structure');
              }
            } catch (e) {
              print('❌ Error parsing response for petty cash ${pettyCash.id}: $e');
            }
          } else {
            print('❌ Petty cash ${pettyCash.id}: Unexpected status code ${response.statusCode}');
          }

          // Only mark as synced and continue background processing if we had true success
          if (syncSuccess) {
            await _databaseHelper.updatePettyCashSyncStatus(pettyCash.id!, true);
            print('✅ Auto-synced petty cash ${pettyCash.id}');
          } else {
            print('❌ Failed to auto-sync petty cash ${pettyCash.id} - will retry later');
            // Don't mark as failed, just leave queued for retry
          }
        } catch (e) {
          print('❌ Error auto-syncing petty cash ${pettyCash.id}: $e');
          // Don't update sync status on error, leave queued for retry
        }
      }

      // Clean up expired synced data
      await _databaseHelper.cleanupPettyCashData();
    } catch (e) {
      print('❌ Error in auto-sync petty cash: $e');
    }
  }

  /// Manually sync queued petty cash
  Future<PettyCashSyncResult> syncQueuedPettyCash() async {
    if (!isLoggedIn || _currentUser == null) {
      return PettyCashSyncResult(
        success: false,
        message: 'User not logged in',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final queuedPettyCash = await _databaseHelper.getQueuedPettyCash();

      if (queuedPettyCash.isEmpty) {
        return PettyCashSyncResult(
          success: true,
          message: 'No queued petty cash to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      await _apiService.initialize();

      int syncedCount = 0;
      int failedCount = 0;
      List<String> syncErrors = [];

      for (final pettyCash in queuedPettyCash) {
        try {
          print('🔄 Syncing petty cash: ${pettyCash.formattedAmount}...');

          final pettyCashData = pettyCash.toJson();
          final response = await _apiService.fundPettyCash(pettyCashData);
          bool syncSuccess = false;

          // Validate response - ONLY mark as synced if we get 200 with valid response
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response indicates success
              if (responseData is Map<String, dynamic> && 
                  responseData.containsKey('success') && 
                  responseData['success'] == true) {
                
                syncSuccess = true;
                print('✅ Petty cash ${pettyCash.id} synced successfully');
              } else {
                syncErrors.add('Petty cash ${pettyCash.id}: Invalid response structure or success=false');
              }
            } catch (e) {
              syncErrors.add('Petty cash ${pettyCash.id}: Error parsing response JSON - $e');
            }
          } else {
            syncErrors.add('Petty cash ${pettyCash.id}: Unexpected status code ${response.statusCode}');
          }

          // Only mark as synced and count as success if we had true success
          if (syncSuccess) {
            await _databaseHelper.updatePettyCashSyncStatus(pettyCash.id!, true);
            syncedCount++;
            print('✅ Synced petty cash ${pettyCash.id}');
          } else {
            failedCount++;
            print('❌ Failed to sync petty cash ${pettyCash.id}');
          }
        } catch (e) {
          failedCount++;
          syncErrors.add('Petty cash ${pettyCash.id}: $e');
          print('❌ Error syncing petty cash ${pettyCash.id}: $e');
        }
      }

      String message = '$syncedCount petty cash entries synced successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      return PettyCashSyncResult(
        success: syncedCount > 0 || failedCount == 0,
        message: message,
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      print('Error syncing queued petty cash: $e');
      return PettyCashSyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    }
  }

  /// Get all petty cash entries
  Future<List<PettyCash>> getAllPettyCash() async {
    return await _databaseHelper.getAllPettyCash();
  }

  /// Get queued petty cash entries (not synced)
  Future<List<PettyCash>> getQueuedPettyCash() async {
    return await _databaseHelper.getQueuedPettyCash();
  }

  /// Get synced petty cash entries (not expired)
  Future<List<PettyCash>> getSyncedPettyCash() async {
    return await _databaseHelper.getSyncedPettyCash();
  }

  /// Delete a queued petty cash entry
  Future<PettyCashResult> deleteQueuedPettyCash(int pettyCashId) async {
    if (!isLoggedIn) {
      return PettyCashResult(
        success: false,
        message: 'User not logged in',
        pettyCash: null,
      );
    }

    try {
      final pettyCash = await _databaseHelper.getPettyCashById(pettyCashId);
      if (pettyCash == null) {
        return PettyCashResult(
          success: false,
          message: 'Petty cash entry not found',
          pettyCash: null,
        );
      }

      if (pettyCash.isSynced) {
        return PettyCashResult(
          success: false,
          message: 'Cannot delete synced petty cash entry',
          pettyCash: null,
        );
      }

      final deleted = await _databaseHelper.deletePettyCash(pettyCashId);
      if (deleted > 0) {
        print('🗑️ Deleted queued petty cash: ${pettyCashId}');
        return PettyCashResult(
          success: true,
          message: 'Petty cash entry deleted successfully',
          pettyCash: pettyCash,
        );
      } else {
        return PettyCashResult(
          success: false,
          message: 'Failed to delete petty cash entry',
          pettyCash: null,
        );
      }
    } catch (e) {
      print('Error deleting petty cash entry: $e');
      return PettyCashResult(
        success: false,
        message: 'Error deleting petty cash entry: $e',
        pettyCash: null,
      );
    }
  }

  /// Validate petty cash date (helper method)
  bool isValidPettyCashDate(DateTime date) {
    final now = DateTime.now();
    final twoDaysAgo = now.subtract(Duration(days: 2));
    
    return date.isAfter(twoDaysAgo) && !date.isAfter(now);
  }

  /// Check for duplicate petty cash entries (warning only)
  Future<List<PettyCash>> checkForSimilarPettyCash(PettyCash pettyCash) async {
    return await _databaseHelper.findSimilarPettyCash(pettyCash);
  }

  /// Get petty cash entries for date range
  Future<List<PettyCash>> getPettyCashForDateRange(DateTime startDate, DateTime endDate) async {
    if (!isLoggedIn || _currentUser == null) {
      return [];
    }
    
    return await _databaseHelper.getPettyCashForDateRange(startDate, endDate, branchName: _currentUser!.branch);
  }

  // ===== END FUND PETTY CASH MANAGEMENT METHODS =====

  // ===== DAILY CASH COUNT MANAGEMENT METHODS =====

  /// Capture daily cash count (offline-first)
  Future<CashCountResult> captureDailyCashCount({
    required double amount,
    required DateTime cashbookDate,
  }) async {
    if (!isLoggedIn || _currentUser == null) {
      return CashCountResult(
        success: false,
        message: 'User not logged in',
        cashCount: null,
      );
    }

    try {
      // Validate amount
      if (amount <= 0) {
        return CashCountResult(
          success: false,
          message: 'Amount must be greater than zero',
          cashCount: null,
        );
      }

      // Validate date (not more than 1 day ago, not in future)
      final now = DateTime.now();
      final oneDayAgo = now.subtract(Duration(days: 1));
      
      if (cashbookDate.isBefore(oneDayAgo)) {
        return CashCountResult(
          success: false,
          message: 'Cashbook date cannot be more than 1 day ago',
          cashCount: null,
        );
      }
      
      if (cashbookDate.isAfter(now)) {
        return CashCountResult(
          success: false,
          message: 'Cashbook date cannot be in the future',
          cashCount: null,
        );
      }

      // Create cash count object
      final cashCount = CashCount(
        branchName: _currentUser!.branch,
        capturedBy: _currentUser!.fullName,
        amount: amount,
        cashbookDate: cashbookDate,
        isSynced: false,
        createdAt: DateTime.now(),
      );

      // Check for potential duplicates (WARNING only, don't block)
      final similarEntries = await _databaseHelper.findSimilarCashCounts(cashCount);
      String warningMessage = '';
      
      if (similarEntries.isNotEmpty) {
        warningMessage = '\n⚠️ WARNING: Similar cash count found for ${cashCount.formattedDate}';
      }

      // Store locally
      final cashCountId = await _databaseHelper.insertCashCount(cashCount);
      final storedCashCount = await _databaseHelper.getCashCountById(cashCountId);

      print('✅ Cash count captured locally: ${cashCount.formattedAmount} for ${_currentUser!.branch}');

      // Try to sync immediately if we have internet (with small delay)
      Future.delayed(const Duration(milliseconds: 500), () {
        _autoSyncCashCounts();
      });

      return CashCountResult(
        success: true,
        message: 'Cash count captured successfully - queued for sync${warningMessage}',
        cashCount: storedCashCount,
      );
    } catch (e) {
      print('Error capturing cash count: $e');
      return CashCountResult(
        success: false,
        message: 'Failed to capture cash count: $e',
        cashCount: null,
      );
    }
  }

  /// Auto-sync queued cash counts in background - ONLY mark as synced on TRUE SUCCESS
  Future<void> _autoSyncCashCounts() async {
    try {
      final queuedCashCounts = await _databaseHelper.getQueuedCashCounts();
      if (queuedCashCounts.isEmpty) {
        return; // No queued cash counts to sync
      }

      print('🔄 Auto-syncing ${queuedCashCounts.length} cash count entries...');
      await _apiService.initialize();

      for (final cashCount in queuedCashCounts) {
        try {
          // Prepare API payload
          final cashCountData = cashCount.toJson();
          
          print('🔄 Auto-syncing cash count ${cashCount.id}: ${cashCount.formattedAmount}');

          // Call cash count API endpoint and validate response
          final response = await _apiService.captureDailyCashCount(cashCountData);
          bool syncSuccess = false;

          // Validate response - ONLY mark as synced if we get 200 with valid response
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response indicates success
              if (responseData is Map<String, dynamic>) {
                // Based on the expected response: { m = "Cash count captured successfully" }
                if (responseData.containsKey('m') && responseData['m'].toString().contains('successfully')) {
                  syncSuccess = true;
                  print('✅ Cash count ${cashCount.id} synced successfully');
                  print('✅ Response message: ${responseData['m']}');
                } else {
                  print('❌ Cash count ${cashCount.id}: API returned unexpected response structure');
                }
              } else {
                print('❌ Cash count ${cashCount.id}: Invalid response structure');
              }
            } catch (e) {
              print('❌ Error parsing response for cash count ${cashCount.id}: $e');
            }
          } else {
            print('❌ Cash count ${cashCount.id}: Unexpected status code ${response.statusCode}');
          }

          // Only mark as synced and continue background processing if we had true success
          if (syncSuccess) {
            await _databaseHelper.updateCashCountSyncStatus(cashCount.id!, true);
            print('✅ Auto-synced cash count ${cashCount.id}');
          } else {
            print('❌ Failed to auto-sync cash count ${cashCount.id} - will retry later');
            // Don't mark as failed, just leave queued for retry
          }
        } catch (e) {
          print('❌ Error auto-syncing cash count ${cashCount.id}: $e');
          // Don't update sync status on error, leave queued for retry
        }
      }

      // Clean up expired synced data
      await _databaseHelper.cleanupCashCountData();
    } catch (e) {
      print('❌ Error in auto-sync cash counts: $e');
    }
  }

  /// Manually sync queued cash counts
  Future<CashCountSyncResult> syncQueuedCashCounts() async {
    if (!isLoggedIn || _currentUser == null) {
      return CashCountSyncResult(
        success: false,
        message: 'User not logged in',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final queuedCashCounts = await _databaseHelper.getQueuedCashCounts();

      if (queuedCashCounts.isEmpty) {
        return CashCountSyncResult(
          success: true,
          message: 'No queued cash counts to sync',
          syncedCount: 0,
          failedCount: 0,
        );
      }

      await _apiService.initialize();

      int syncedCount = 0;
      int failedCount = 0;
      List<String> syncErrors = [];

      for (final cashCount in queuedCashCounts) {
        try {
          print('🔄 Syncing cash count: ${cashCount.formattedAmount}...');

          final cashCountData = cashCount.toJson();
          final response = await _apiService.captureDailyCashCount(cashCountData);
          bool syncSuccess = false;

          // Validate response - ONLY mark as synced if we get 200 with valid response
          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              
              // Check if response indicates success
              if (responseData is Map<String, dynamic> && 
                  responseData.containsKey('m') && 
                  responseData['m'].toString().contains('successfully')) {
                
                syncSuccess = true;
                print('✅ Cash count ${cashCount.id} synced successfully');
              } else {
                syncErrors.add('Cash count ${cashCount.id}: Invalid response structure or missing success message');
              }
            } catch (e) {
              syncErrors.add('Cash count ${cashCount.id}: Error parsing response JSON - $e');
            }
          } else {
            syncErrors.add('Cash count ${cashCount.id}: Unexpected status code ${response.statusCode}');
          }

          // Only mark as synced and count as success if we had true success
          if (syncSuccess) {
            await _databaseHelper.updateCashCountSyncStatus(cashCount.id!, true);
            syncedCount++;
            print('✅ Synced cash count ${cashCount.id}');
          } else {
            failedCount++;
            print('❌ Failed to sync cash count ${cashCount.id}');
          }
        } catch (e) {
          failedCount++;
          syncErrors.add('Cash count ${cashCount.id}: $e');
          print('❌ Error syncing cash count ${cashCount.id}: $e');
        }
      }

      String message = '$syncedCount cash count entries synced successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      return CashCountSyncResult(
        success: syncedCount > 0 || failedCount == 0,
        message: message,
        syncedCount: syncedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      print('Error syncing queued cash counts: $e');
      return CashCountSyncResult(
        success: false,
        message: 'Sync failed: $e',
        syncedCount: 0,
        failedCount: 0,
      );
    }
  }

  /// Get all cash count entries
  Future<List<CashCount>> getAllCashCounts() async {
    return await _databaseHelper.getAllCashCounts();
  }

  /// Get queued cash count entries (not synced)
  Future<List<CashCount>> getQueuedCashCounts() async {
    return await _databaseHelper.getQueuedCashCounts();
  }

  /// Get synced cash count entries (not expired)
  Future<List<CashCount>> getSyncedCashCounts() async {
    return await _databaseHelper.getSyncedCashCounts();
  }

  /// Delete a queued cash count entry
  Future<CashCountResult> deleteQueuedCashCount(int cashCountId) async {
    if (!isLoggedIn) {
      return CashCountResult(
        success: false,
        message: 'User not logged in',
        cashCount: null,
      );
    }

    try {
      final cashCount = await _databaseHelper.getCashCountById(cashCountId);
      if (cashCount == null) {
        return CashCountResult(
          success: false,
          message: 'Cash count entry not found',
          cashCount: null,
        );
      }

      if (cashCount.isSynced) {
        return CashCountResult(
          success: false,
          message: 'Cannot delete synced cash count entry',
          cashCount: null,
        );
      }

      final deleted = await _databaseHelper.deleteCashCount(cashCountId);
      if (deleted > 0) {
        print('🗑️ Deleted queued cash count: ${cashCountId}');
        return CashCountResult(
          success: true,
          message: 'Cash count entry deleted successfully',
          cashCount: cashCount,
        );
      } else {
        return CashCountResult(
          success: false,
          message: 'Failed to delete cash count entry',
          cashCount: null,
        );
      }
    } catch (e) {
      print('Error deleting cash count entry: $e');
      return CashCountResult(
        success: false,
        message: 'Error deleting cash count entry: $e',
        cashCount: null,
      );
    }
  }

  /// Validate cash count date (helper method)
  bool isValidCashCountDate(DateTime date) {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(Duration(days: 1));
    
    return date.isAfter(oneDayAgo) && !date.isAfter(now);
  }

  /// Check for duplicate cash count entries (warning only)
  Future<List<CashCount>> checkForSimilarCashCounts(CashCount cashCount) async {
    return await _databaseHelper.findSimilarCashCounts(cashCount);
  }

  /// Get cash count entries for date range
  Future<List<CashCount>> getCashCountsForDateRange(DateTime startDate, DateTime endDate) async {
    if (!isLoggedIn || _currentUser == null) {
      return [];
    }
    
    return await _databaseHelper.getCashCountsForDateRange(startDate, endDate, branchName: _currentUser!.branch);
  }

  // ===== END DAILY CASH COUNT MANAGEMENT METHODS =====

  // ===== CASHBOOK DOWNLOAD MANAGEMENT METHODS =====

  /// Request cashbook download (offline-first)
  Future<CashbookDownloadResult> requestCashbookDownload({
    required DateTime cashbookDate,
  }) async {
    if (!isLoggedIn || _currentUser == null) {
      return CashbookDownloadResult(
        success: false,
        message: 'User not logged in',
        download: null,
      );
    }

    try {
      // Validate date (cannot be in the future)
      final now = DateTime.now();
      if (cashbookDate.isAfter(now)) {
        return CashbookDownloadResult(
          success: false,
          message: 'Cashbook date cannot be in the future',
          download: null,
        );
      }

      // Create download request
      final download = CashbookDownload(
        branchName: _currentUser!.branch,
        cashbookDate: cashbookDate,
        status: DownloadStatus.pending,
        requestedAt: DateTime.now(),
      );

      // Store locally
      final downloadId = await _databaseHelper.insertCashbookDownload(download);
      final storedDownload = await _databaseHelper.getCashbookDownloadById(downloadId);

      print('✅ Cashbook download requested: ${storedDownload!.formattedDate}');

      // Try to start download immediately if we have internet
      Future.delayed(const Duration(milliseconds: 500), () {
        _processQueuedDownloads();
      });

      return CashbookDownloadResult(
        success: true,
        message: 'Cashbook download requested - processing in background',
        download: storedDownload,
      );
    } catch (e) {
      print('Error requesting cashbook download: $e');
      return CashbookDownloadResult(
        success: false,
        message: 'Failed to request download: $e',
        download: null,
      );
    }
  }

  /// Process queued downloads in background
  Future<void> _processQueuedDownloads() async {
    try {
      final pendingDownloads = await _databaseHelper.getPendingCashbookDownloads();
      if (pendingDownloads.isEmpty) {
        return;
      }

      print('🔄 Processing ${pendingDownloads.length} pending cashbook downloads...');
      await _apiService.initialize();

      for (final download in pendingDownloads) {
        await _processSingleDownload(download);
      }

      // Clean up old download records
      await _databaseHelper.cleanupCashbookDownloadsData();
    } catch (e) {
      print('❌ Error in processing queued downloads: $e');
    }
  }

  /// Process a single download
  Future<void> _processSingleDownload(CashbookDownload download) async {
    try {
      // Mark as downloading
      await _databaseHelper.updateCashbookDownloadStatus(
        download.id!,
        DownloadStatus.downloading,
      );

      // Prepare API request
      final requestData = {
        'BranchName': download.branchName,
        'CashbookDate': download.cashbookDate.toIso8601String(),
      };

      print('🔄 Downloading cashbook: ${download.formattedDate}');

      // Call download API
      final fileBytes = await _apiService.downloadCashbook(requestData);

      if (fileBytes != null) {
        // Save file to local storage
        final filePath = await _saveCashbookFile(download, fileBytes);
        
        if (filePath != null) {
          // Mark as completed
          await _databaseHelper.updateCashbookDownloadStatus(
            download.id!,
            DownloadStatus.completed,
            filePath: filePath,
          );
          print('✅ Cashbook download completed: ${download.formattedDate}');
        } else {
          // Mark as failed
          await _databaseHelper.updateCashbookDownloadStatus(
            download.id!,
            DownloadStatus.failed,
            errorMessage: 'Failed to save file',
          );
        }
      } else {
        // Mark as failed
        await _databaseHelper.updateCashbookDownloadStatus(
          download.id!,
          DownloadStatus.failed,
          errorMessage: 'Download failed - no data received',
        );
      }
    } catch (e) {
      print('❌ Error processing download ${download.id}: $e');
      
      // Mark as failed
      await _databaseHelper.updateCashbookDownloadStatus(
        download.id!,
        DownloadStatus.failed,
        errorMessage: 'Download error: $e',
      );
    }
  }

  /// Save cashbook file to local storage
  Future<String?> _saveCashbookFile(CashbookDownload download, List<int> fileBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cashbookDir = Directory('${directory.path}/cashbooks');
      
      // Create directory if it doesn't exist
      if (!await cashbookDir.exists()) {
        await cashbookDir.create(recursive: true);
      }

      // Generate filename
      final dateStr = "${download.cashbookDate.year}-${download.cashbookDate.month.toString().padLeft(2, '0')}-${download.cashbookDate.day.toString().padLeft(2, '0')}";
      final filename = '${download.branchName}_Cashbook_${dateStr}.pdf';
      
      final file = File('${cashbookDir.path}/$filename');
      
      // Write file
      await file.writeAsBytes(fileBytes);
      
      print('💾 Cashbook saved: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Error saving cashbook file: $e');
      return null;
    }
  }

  /// Get recent cashbook downloads
  Future<List<CashbookDownload>> getRecentCashbookDownloads({int limit = 5}) async {
    return await _databaseHelper.getRecentCashbookDownloads(limit: limit);
  }

  /// Get all cashbook downloads
  Future<List<CashbookDownload>> getAllCashbookDownloads() async {
    return await _databaseHelper.getAllCashbookDownloads();
  }

  /// Delete a cashbook download and its file
  Future<CashbookDownloadResult> deleteCashbookDownload(int downloadId) async {
    if (!isLoggedIn) {
      return CashbookDownloadResult(
        success: false,
        message: 'User not logged in',
        download: null,
      );
    }

    try {
      final download = await _databaseHelper.getCashbookDownloadById(downloadId);
      if (download == null) {
        return CashbookDownloadResult(
          success: false,
          message: 'Download record not found',
          download: null,
        );
      }

      // Delete file if it exists
      if (download.filePath != null && download.filePath!.isNotEmpty) {
        try {
          final file = File(download.filePath!);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Deleted file: ${download.filePath}');
          }
        } catch (e) {
          print('⚠️ Error deleting file: $e');
          // Continue with database deletion even if file deletion fails
        }
      }

      // Delete database record
      final deleted = await _databaseHelper.deleteCashbookDownload(downloadId);
      if (deleted > 0) {
        print('🗑️ Deleted cashbook download: ${downloadId}');
        return CashbookDownloadResult(
          success: true,
          message: 'Download deleted successfully',
          download: download,
        );
      } else {
        return CashbookDownloadResult(
          success: false,
          message: 'Failed to delete download record',
          download: null,
        );
      }
    } catch (e) {
      print('Error deleting cashbook download: $e');
      return CashbookDownloadResult(
        success: false,
        message: 'Delete failed: $e',
        download: null,
      );
    }
  }

  /// Manually process pending downloads
  Future<CashbookDownloadSyncResult> processQueuedDownloadsManually() async {
    if (!isLoggedIn || _currentUser == null) {
      return CashbookDownloadSyncResult(
        success: false,
        message: 'User not logged in',
        completedCount: 0,
        failedCount: 0,
      );
    }

    try {
      final pendingDownloads = await _databaseHelper.getPendingCashbookDownloads();

      if (pendingDownloads.isEmpty) {
        return CashbookDownloadSyncResult(
          success: true,
          message: 'No pending downloads',
          completedCount: 0,
          failedCount: 0,
        );
      }

      await _apiService.initialize();

      int completedCount = 0;
      int failedCount = 0;

      for (final download in pendingDownloads) {
        try {
          await _processSingleDownload(download);
          
          // Check final status
          final updatedDownload = await _databaseHelper.getCashbookDownloadById(download.id!);
          if (updatedDownload?.status == DownloadStatus.completed) {
            completedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          print('❌ Error processing download ${download.id}: $e');
        }
      }

      String message = '$completedCount downloads completed successfully';
      if (failedCount > 0) {
        message += ', $failedCount failed';
      }

      return CashbookDownloadSyncResult(
        success: completedCount > 0 || failedCount == 0,
        message: message,
        completedCount: completedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      print('Error processing queued downloads: $e');
      return CashbookDownloadSyncResult(
        success: false,
        message: 'Processing failed: $e',
        completedCount: 0,
        failedCount: 0,
      );
    }
  }

  // ===== REQUEST BALANCE MANAGEMENT METHODS =====

  /// Request a balance request with validation
  Future<RequestBalanceResult> requestBalance({
    required DateTime cashbookDate,
    required double amount,
    required String reason,
  }) async {
    if (!isLoggedIn || _currentUser == null) {
      return RequestBalanceResult(
        success: false,
        message: 'User not logged in',
        request: null,
      );
    }

    try {
      // Validate date (cannot be more than 1 day back datable)
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      if (cashbookDate.isBefore(DateTime(yesterday.year, yesterday.month, yesterday.day))) {
        return RequestBalanceResult(
          success: false,
          message: 'Cashbook date cannot be more than 1 day in the past',
          request: null,
        );
      }

      // Validate amount (must be positive)
      if (amount <= 0) {
        return RequestBalanceResult(
          success: false,
          message: 'Amount must be greater than zero',
          request: null,
        );
      }

      // Validate reason (max 20 words)
      final wordCount = reason.trim().split(RegExp(r'\s+')).length;
      if (wordCount > 20) {
        return RequestBalanceResult(
          success: false,
          message: 'Reason cannot exceed 20 words',
          request: null,
        );
      }

      if (reason.trim().isEmpty) {
        return RequestBalanceResult(
          success: false,
          message: 'Reason is required',
          request: null,
        );
      }

      // Create request balance record
      final requestBalance = RequestBalance(
        branchName: _currentUser!.branch,
        cashbookDate: cashbookDate,
        amount: amount,
        reason: reason.trim(),
        requestedAt: DateTime.now(),
      );

      // Save to database (offline-first approach)
      final requestId = await _databaseHelper.insertRequestBalance(requestBalance);
      final savedRequest = requestBalance.copyWith(id: requestId);

      print('✅ Request balance saved locally: ${savedRequest.formattedAmount} for ${savedRequest.formattedDate}');

      // Queue for background sync
      _queueRequestBalanceForSync();

      return RequestBalanceResult(
        success: true,
        message: 'Balance request submitted successfully and queued for processing',
        request: savedRequest,
      );
    } catch (e) {
      print('Error creating request balance: $e');
      return RequestBalanceResult(
        success: false,
        message: 'Request failed: $e',
        request: null,
      );
    }
  }

  /// Queue request balance for background sync
  void _queueRequestBalanceForSync() {
    // Add a delay to allow for immediate UI feedback
    Timer(Duration(seconds: 2), () {
      _syncRequestBalancesInBackground();
    });
  }

  /// Background sync for request balances
  Future<void> _syncRequestBalancesInBackground() async {
    if (!isLoggedIn) return;

    try {
      final pendingRequests = await _databaseHelper.getPendingRequestBalances();
      
      if (pendingRequests.isEmpty) {
        print('📝 No pending request balances to sync');
        return;
      }

      await _apiService.initialize();

      for (final request in pendingRequests) {
        try {
          print('🔄 Syncing request balance: ${request.formattedAmount} for ${request.formattedDate}');

          final apiPayload = request.toApiPayload();
          final syncSuccess = await _apiService.syncRequestBalance(apiPayload);

          if (syncSuccess) {
            await _databaseHelper.updateRequestBalanceStatus(
              request.id!,
              RequestBalanceStatus.synced,
              syncedAt: DateTime.now(),
            );
            print('✅ Request balance synced successfully: ${request.id}');
          } else {
            await _databaseHelper.updateRequestBalanceStatus(
              request.id!,
              RequestBalanceStatus.failed,
              errorMessage: 'API sync failed',
            );
            print('❌ Request balance sync failed: ${request.id}');
          }
        } catch (e) {
          await _databaseHelper.updateRequestBalanceStatus(
            request.id!,
            RequestBalanceStatus.failed,
            errorMessage: e.toString(),
          );
          print('❌ Request balance sync error: $e');
        }
      }

      // Clean up old synced records
      await _databaseHelper.cleanupOldRequestBalances();
    } catch (e) {
      print('❌ Error in request balance background sync: $e');
    }
  }

  /// Get recent request balances
  Future<List<RequestBalance>> getRecentRequestBalances({int limit = 20}) async {
    return await _databaseHelper.getRecentRequestBalances(limit: limit);
  }

  /// Get pending request balance count
  Future<int> getPendingRequestBalanceCount() async {
    return await _databaseHelper.getRequestBalanceCountByStatus(RequestBalanceStatus.pending);
  }

  /// Delete a request balance
  Future<RequestBalanceResult> deleteRequestBalance(int requestId) async {
    if (!isLoggedIn) {
      return RequestBalanceResult(
        success: false,
        message: 'User not logged in',
        request: null,
      );
    }

    try {
      final deleted = await _databaseHelper.deleteRequestBalance(requestId);
      if (deleted > 0) {
        return RequestBalanceResult(
          success: true,
          message: 'Request balance deleted successfully',
          request: null,
        );
      } else {
        return RequestBalanceResult(
          success: false,
          message: 'Request balance not found',
          request: null,
        );
      }
    } catch (e) {
      print('Error deleting request balance: $e');
      return RequestBalanceResult(
        success: false,
        message: 'Delete failed: $e',
        request: null,
      );
    }
  }

  /// Manually process pending request balances
  Future<RequestBalanceResult> processQueuedRequestBalancesManually() async {
    if (!isLoggedIn || _currentUser == null) {
      return RequestBalanceResult(
        success: false,
        message: 'User not logged in',
        request: null,
      );
    }

    try {
      final pendingRequests = await _databaseHelper.getPendingRequestBalances();

      if (pendingRequests.isEmpty) {
        return RequestBalanceResult(
          success: true,
          message: 'No pending request balances',
          request: null,
        );
      }

      await _apiService.initialize();
      int processedCount = 0;

      for (final request in pendingRequests) {
        try {
          final apiPayload = request.toApiPayload();
          final syncSuccess = await _apiService.syncRequestBalance(apiPayload);

          if (syncSuccess) {
            await _databaseHelper.updateRequestBalanceStatus(
              request.id!,
              RequestBalanceStatus.synced,
              syncedAt: DateTime.now(),
            );
            processedCount++;
          } else {
            await _databaseHelper.updateRequestBalanceStatus(
              request.id!,
              RequestBalanceStatus.failed,
              errorMessage: 'Manual sync failed',
            );
          }
        } catch (e) {
          await _databaseHelper.updateRequestBalanceStatus(
            request.id!,
            RequestBalanceStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }

      return RequestBalanceResult(
        success: processedCount > 0,
        message: '$processedCount requests processed successfully',
        request: null,
      );
    } catch (e) {
      print('Error processing queued request balances: $e');
      return RequestBalanceResult(
        success: false,
        message: 'Processing failed: $e',
        request: null,
      );
    }
  }

  // ===== END CASHBOOK DOWNLOAD MANAGEMENT METHODS =====
}

/// Result object for login operations
class LoginResult {
  final bool success;
  final String message;
  final User? user;

  LoginResult({required this.success, required this.message, this.user});

  @override
  String toString() {
    return 'LoginResult{success: $success, message: $message, user: ${user?.fullName}}';
  }
}

/// Result object for client sync operations
class ClientSyncResult {
  final bool success;
  final String message;
  final int clientsLoaded;
  final List<Client>? clients;

  ClientSyncResult({
    required this.success,
    required this.message,
    required this.clientsLoaded,
    this.clients,
  });

  @override
  String toString() {
    return 'ClientSyncResult{success: $success, message: $message, clientsLoaded: $clientsLoaded}';
  }
}

/// Result object for disbursement sync operations
class DisbursementSyncResult {
  final bool success;
  final String message;
  final int disbursementsLoaded;
  final List<Disbursement>? disbursements;

  DisbursementSyncResult({
    required this.success,
    required this.message,
    required this.disbursementsLoaded,
    this.disbursements,
  });

  @override
  String toString() {
    return 'DisbursementSyncResult{success: $success, message: $message, disbursementsLoaded: $disbursementsLoaded}';
  }
}

/// Result object for repayment operations
class RepaymentResult {
  final bool success;
  final String message;
  final String? receiptNumber;
  final Repayment? repayment;

  RepaymentResult({
    required this.success,
    required this.message,
    required this.receiptNumber,
    this.repayment,
  });

  @override
  String toString() {
    return 'RepaymentResult{success: $success, message: $message, receiptNumber: $receiptNumber}';
  }
}

/// Result object for repayment sync operations
class RepaymentSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  RepaymentSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'RepaymentSyncResult{success: $success, message: $message, syncedCount: $syncedCount, failedCount: $failedCount}';
  }
}

/// Result object for penalty fee operations
class PenaltyFeeResult {
  final bool success;
  final String message;
  final String receiptNumber;
  final PenaltyFee? penaltyFee;

  PenaltyFeeResult({
    required this.success,
    required this.message,
    required this.receiptNumber,
    this.penaltyFee,
  });

  @override
  String toString() {
    return 'PenaltyFeeResult{success: $success, message: $message, receiptNumber: $receiptNumber}';
  }
}

/// Result object for penalty fee sync operations
class PenaltySyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  PenaltySyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'PenaltySyncResult{success: $success, message: $message, syncedCount: $syncedCount, failedCount: $failedCount}';
  }
}

/// Result object for branch sync operations
class BranchSyncResult {
  final bool success;
  final String message;
  final int branchesLoaded;
  final List<Branch>? branches;

  BranchSyncResult({
    required this.success,
    required this.message,
    required this.branchesLoaded,
    this.branches,
  });

  @override
  String toString() {
    return 'BranchSyncResult{success: $success, message: $message, branchesLoaded: $branchesLoaded}';
  }
}

/// Result object for transfer operations
class TransferResult {
  final bool success;
  final String message;
  final Transfer? transfer;

  TransferResult({
    required this.success,
    required this.message,
    this.transfer,
  });

  @override
  String toString() {
    return 'TransferResult{success: $success, message: $message}';
  }
}

/// Result object for transfer sync operations
class TransferSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  TransferSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'TransferSyncResult{success: $success, message: $message, syncedCount: $syncedCount, failedCount: $failedCount}';
  }
}

/// Result object for expense operations
class ExpenseResult {
  final bool success;
  final String message;
  final Expense? expense;

  ExpenseResult({
    required this.success,
    required this.message,
    this.expense,
  });

  @override
  String toString() {
    return 'ExpenseResult{success: $success, message: $message}';
  }
}

/// Result object for expense sync operations
class ExpenseSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  ExpenseSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'ExpenseSyncResult{success: $success, message: $message, syncedCount: $syncedCount, failedCount: $failedCount}';
  }
}

/// Result object for petty cash operations
class PettyCashResult {
  final bool success;
  final String message;
  final PettyCash? pettyCash;

  PettyCashResult({
    required this.success,
    required this.message,
    this.pettyCash,
  });

  @override
  String toString() {
    return 'PettyCashResult{success: $success, message: $message}';
  }
}

/// Result object for petty cash sync operations
class PettyCashSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  PettyCashSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'PettyCashSyncResult{success: $success, message: $message, syncedCount: $syncedCount, failedCount: $failedCount}';
  }
}

/// Result object for cash count operations
class CashCountResult {
  final bool success;
  final String message;
  final CashCount? cashCount;

  CashCountResult({
    required this.success,
    required this.message,
    this.cashCount,
  });

  @override
  String toString() {
    return 'CashCountResult{success: $success, message: $message}';
  }
}

/// Result object for cash count sync operations
class CashCountSyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  CashCountSyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'CashCountSyncResult{success: $success, message: $message, syncedCount: $syncedCount, failedCount: $failedCount}';
  }
}

/// Result object for cashbook download operations
class CashbookDownloadResult {
  final bool success;
  final String message;
  final CashbookDownload? download;

  CashbookDownloadResult({
    required this.success,
    required this.message,
    this.download,
  });

  @override
  String toString() {
    return 'CashbookDownloadResult{success: $success, message: $message}';
  }
}

/// Result object for cashbook download sync operations
class CashbookDownloadSyncResult {
  final bool success;
  final String message;
  final int completedCount;
  final int failedCount;

  CashbookDownloadSyncResult({
    required this.success,
    required this.message,
    required this.completedCount,
    required this.failedCount,
  });

  @override
  String toString() {
    return 'CashbookDownloadSyncResult{success: $success, message: $message, completedCount: $completedCount, failedCount: $failedCount}';
  }
}
