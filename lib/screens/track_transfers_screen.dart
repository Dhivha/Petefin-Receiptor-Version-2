import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/transfer.dart';

class TrackTransfersScreen extends StatefulWidget {
  const TrackTransfersScreen({Key? key}) : super(key: key);

  @override
  State<TrackTransfersScreen> createState() => _TrackTransfersScreenState();
}

class _TrackTransfersScreenState extends State<TrackTransfersScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  
  List<Transfer> _queuedTransfers = [];
  List<Transfer> _syncedTransfers = [];
  bool _isLoading = true;
  bool _isDeletingTransfer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransfers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final queued = await _authService.getQueuedTransfers();
      final synced = await _authService.getSyncedTransfers();
      
      if (mounted) {
        setState(() {
          _queuedTransfers = queued;
          _syncedTransfers = synced;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transfers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transfers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshTransfers() async {
    await _loadTransfers();
  }

  Future<void> _deleteTransfer(Transfer transfer) async {
    final confirmed = await _showDeleteConfirmationDialog(transfer);
    if (!confirmed) return;

    setState(() {
      _isDeletingTransfer = true;
    });

    try {
      final result = await _authService.deleteQueuedTransfer(transfer.id!);
      
      if (mounted) {
        setState(() {
          _isDeletingTransfer = false;
        });

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshTransfers(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeletingTransfer = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transfer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog(Transfer transfer) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this transfer?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transfer.typeDisplayName}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(transfer.formattedAmount),
                  Text('To: ${transfer.receivingBranch}'),
                  Text('Date: ${transfer.formattedDate}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Text(
                'This action cannot be undone. The transfer will be permanently removed.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _syncTransfers() async {
    try {
      final result = await _authService.syncQueuedTransfers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.orange,
          ),
        );
        
        if (result.syncedCount > 0) {
          await _refreshTransfers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing transfers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Track Transfers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTransfers,
            tooltip: 'Refresh',
          ),
          if (_queuedTransfers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncTransfers,
              tooltip: 'Sync Now',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Queued (${_queuedTransfers.length})',
              icon: const Icon(Icons.schedule),
            ),
            Tab(
              text: 'Synced (${_syncedTransfers.length})',
              icon: const Icon(Icons.cloud_done),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTransfers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildQueuedTransfersTab(),
                  _buildSyncedTransfersTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildQueuedTransfersTab() {
    if (_queuedTransfers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule,
        title: 'No Queued Transfers',
        subtitle: 'Transfers you create will appear here until they are synced',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _queuedTransfers.length,
      itemBuilder: (context, index) {
        final transfer = _queuedTransfers[index];
        return _buildQueuedTransferCard(transfer);
      },
    );
  }

  Widget _buildSyncedTransfersTab() {
    if (_syncedTransfers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_done,
        title: 'No Synced Transfers',
        subtitle: 'Successfully synced transfers will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _syncedTransfers.length,
      itemBuilder: (context, index) {
        final transfer = _syncedTransfers[index];
        return _buildSyncedTransferCard(transfer);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuedTransferCard(Transfer transfer) {
    final isExpired = transfer.isExpired;
    final canBeDeleted = transfer.canBeDeleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isExpired 
            ? Border.all(color: Colors.red[300]!, width: 2)
            : Border.all(color: Colors.orange[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isExpired ? 'EXPIRED' : 'QUEUED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isExpired ? Colors.red[700] : Colors.orange[700],
                    ),
                  ),
                ),
                const Spacer(),
                if (canBeDeleted && !_isDeletingTransfer)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[600]),
                    onPressed: () => _deleteTransfer(transfer),
                    tooltip: 'Delete Transfer',
                  ),
                if (_isDeletingTransfer)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getTypeColor(transfer.transferType),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  transfer.typeDisplayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transfer.formattedAmount,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildTransferDetailRow(Icons.send, 'To', transfer.receivingBranch),
            _buildTransferDetailRow(Icons.date_range, 'Date', transfer.formattedDate),
            _buildTransferDetailRow(
              Icons.access_time, 
              'Created', 
              _getTimeAgo(transfer.createdAt)
            ),
            if (isExpired) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This transfer has expired (>24 hours) and will be automatically removed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedTransferCard(Transfer transfer) {
    final syncedTime = transfer.syncedAt != null ? _getTimeAgo(transfer.syncedAt!) : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'SYNCED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.check_circle, color: Colors.green[600]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getTypeColor(transfer.transferType),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  transfer.typeDisplayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transfer.formattedAmount,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildTransferDetailRow(Icons.send, 'To', transfer.receivingBranch),
            _buildTransferDetailRow(Icons.date_range, 'Date', transfer.formattedDate),
            _buildTransferDetailRow(Icons.cloud_done, 'Synced', syncedTime),
            if (transfer.narration != null && transfer.narration!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.description, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transfer.narration!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransferDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String transferType) {
    switch (transferType) {
      case 'USD_CASH':
        return Colors.green;
      case 'USD_BANK':
        return Colors.blue;
      case 'ZWG_BANK':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}