import 'dart:async';
import 'dart:isolate';
import '../services/client_service.dart';
import '../services/collateral_submission_service.dart';

class ClientBackgroundService {
  static Timer? _syncTimer;
  static Timer? _cleanupTimer;
  static bool _isRunning = false;

  /// Start the background service for client management
  static void start() {
    if (_isRunning) return;

    _isRunning = true;
    print('🚀 Starting Client Background Service');

    // Auto-sync queued clients every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _autoSyncQueuedClients();
    });

    // Clean up old synced clients every hour
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupOldSyncedClients();
    });

    // Run initial sync and cleanup
    _autoSyncQueuedClients();
    _cleanupOldSyncedClients();
  }

  /// Stop the background service
  static void stop() {
    if (!_isRunning) return;

    print('🛑 Stopping Client Background Service');
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _syncTimer = null;
    _cleanupTimer = null;
    _isRunning = false;
  }

  /// Check if the service is running
  static bool get isRunning => _isRunning;

  /// Manually trigger a sync of queued clients
  static Future<void> syncNow() async {
    await _autoSyncQueuedClients();
  }

  /// Manually trigger cleanup of old synced clients
  static Future<void> cleanupNow() async {
    await _cleanupOldSyncedClients();
  }

  /// Auto-sync queued clients (internal method)
  static Future<void> _autoSyncQueuedClients() async {
    try {
      print('🔄 Auto-syncing queued clients and collateral submissions...');
      
      final clientService = ClientService();
      await clientService.autoSyncQueuedClients();
      
      final collateralService = CollateralSubmissionService();
      await collateralService.autoSyncQueuedSubmissions();
      
      print('✅ Auto-sync completed');
    } catch (e) {
      print('❌ Auto-sync error: $e');
    }
  }

  /// Clean up old synced clients (internal method)
  static Future<void> _cleanupOldSyncedClients() async {
    try {
      print('🧹 Cleaning up old synced clients...');
      final clientService = ClientService();
      await clientService.cleanupOldSyncedClients();
      print('✅ Cleanup completed');
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }

  /// Get service status information
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'syncTimerActive': _syncTimer?.isActive ?? false,
      'cleanupTimerActive': _cleanupTimer?.isActive ?? false,
      'nextSyncIn': _syncTimer != null
          ? '${5 - (DateTime.now().minute % 5)} minutes'
          : 'N/A',
      'nextCleanupIn': _cleanupTimer != null
          ? '${60 - DateTime.now().minute} minutes'
          : 'N/A',
    };
  }
}
