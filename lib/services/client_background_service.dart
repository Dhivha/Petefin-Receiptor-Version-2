import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'collateral_submission_service.dart';
import 'client_service.dart';

class ClientBackgroundService {
  static Timer? _syncTimer;
  static Timer? _cleanupTimer;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static bool _isRunning = false;
  static bool _isSyncing = false;
  static bool _isCleaningUp = false;

  static void start() {
    if (_isRunning) return;

    _isRunning = true;
    print('Starting Client Background Service');

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _autoSyncQueuedClients();
    });

    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldSyncedClients();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (isOnline) _autoSyncQueuedClients();
    });

    _autoSyncQueuedClients();
    _cleanupOldSyncedClients();
  }

  static void stop() {
    if (!_isRunning) return;

    print('Stopping Client Background Service');
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer = null;
    _cleanupTimer = null;
    _connectivitySubscription = null;
    _isRunning = false;
  }

  static bool get isRunning => _isRunning;

  static Future<void> syncNow() async {
    await _autoSyncQueuedClients();
  }

  static Future<void> cleanupNow() async {
    await _cleanupOldSyncedClients();
  }

  static Future<void> _autoSyncQueuedClients() async {
    if (_isSyncing) {
      print('Queued client sync already running, skipping duplicate trigger');
      return;
    }

    _isSyncing = true;
    try {
      print('Auto-syncing queued clients and collateral submissions...');

      await ClientService().autoSyncQueuedClients();
      await CollateralSubmissionService().autoSyncQueuedSubmissions();

      print('Auto-sync completed');
    } catch (e) {
      print('Auto-sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _cleanupOldSyncedClients() async {
    if (_isCleaningUp) return;

    _isCleaningUp = true;
    try {
      print('Cleaning up old synced clients...');
      await ClientService().cleanupOldSyncedClients();
      print('Cleanup completed');
    } catch (e) {
      print('Cleanup error: $e');
    } finally {
      _isCleaningUp = false;
    }
  }

  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'syncTimerActive': _syncTimer?.isActive ?? false,
      'cleanupTimerActive': _cleanupTimer?.isActive ?? false,
      'connectivityWatcherActive': _connectivitySubscription != null,
      'syncInProgress': _isSyncing,
      'cleanupInProgress': _isCleaningUp,
    };
  }
}
