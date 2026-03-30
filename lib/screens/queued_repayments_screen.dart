import 'package:flutter/material.dart';
import '../models/repayment.dart';
import '../models/cancelled_repayment.dart';
import '../services/auth_service.dart';

class QueuedRepaymentsScreen extends StatefulWidget {
  const QueuedRepaymentsScreen({super.key});

  @override
  State<QueuedRepaymentsScreen> createState() => _QueuedRepaymentsScreenState();
}

class _QueuedRepaymentsScreenState extends State<QueuedRepaymentsScreen> with TickerProviderStateMixin {
  List<Repayment> _unsyncedRepayments = [];
  List<Repayment> _syncedRepayments = [];
  List<CancelledRepayment> _cancelledRepayments = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isCancelling = false;
  late TabController _tabController;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllRepayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRepayments() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = AuthService();
      
      // Load queued and synced repayments
      final unsyncedRepayments = await authService.getUnsyncedRepayments();
      final syncedRepayments = await authService.getSyncedRepayments();
      
      setState(() {
        _unsyncedRepayments = unsyncedRepayments;
        _syncedRepayments = syncedRepayments;
      });
      
      // Load cancelled repayments
      await _loadCancelledRepayments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading repayments: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCancelledRepayments() async {
    try {
      final authService = AuthService();
      final cancelled = await authService.getCancelledRepayments();
      setState(() {
        _cancelledRepayments = cancelled;
      });
    } catch (e) {
      print('Error loading cancelled repayments: $e');
    }
  }

  Future<void> _manualSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    
    try {
      final authService = AuthService();
      final result = await authService.syncUnyncedRepayments();
      
      if (result.success) {
        await _loadAllRepayments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        }
      } else {
        if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showCancelDialog(Repayment repayment) async {
    _reasonController.clear();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt: ${repayment.receiptNumber}'),
            Text('Client: ${repayment.clientName}'),
            Text('Amount: ${repayment.formattedAmount}'),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                hintText: 'Enter reason for cancellation...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a cancellation reason')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Receipt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _cancelRepayment(repayment, _reasonController.text.trim());
    }
  }

  Future<void> _cancelRepayment(Repayment repayment, String reason) async {
    setState(() => _isCancelling = true);
    
    try {
      final authService = AuthService();
      final result = await authService.cancelRepayment(
        repayment: repayment,
        reason: reason,
      );
      
      if (result.success) {
        await _loadAllRepayments(); // Refresh all data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          // Switch to cancelled tab to show the cancelled receipt
          _tabController.animateTo(2);
        }
      } else {
        if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _buildRepaymentCard(Repayment repayment, {bool showCancelButton = false}) {
    final isUSD = repayment.currency == 'USD';
    final isPending = !repayment.isSynced;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          isPending ? Icons.cloud_queue : Icons.cloud_done,
          color: isPending ? Colors.orange : Colors.green,
          size: 30,
        ),
        title: Text(
          repayment.receiptNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${repayment.clientName}'),
            Text(
              'Amount: ${repayment.formattedAmount}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isUSD ? Colors.green : Colors.blue,
              ),
            ),
            Text('Date: ${repayment.formattedDate}'),
            Row(
              children: [
                Icon(
                  isPending ? Icons.schedule : Icons.check_circle,
                  size: 16,
                  color: isPending ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  isPending ? 'Pending Sync' : 'Synced',
                  style: TextStyle(
                    color: isPending ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Receipt Number', repayment.receiptNumber),
                _buildDetailRow('Client Name', repayment.clientName),
                _buildDetailRow('Client ID', repayment.clientId),
                _buildDetailRow('Amount', repayment.formattedAmount),
                _buildDetailRow('Currency', repayment.currency),
                _buildDetailRow('Payment Number', repayment.paymentNumber),
                _buildDetailRow('Branch', repayment.branch),
                _buildDetailRow('Date of Payment', repayment.formattedDate),
                _buildDetailRow('Created', repayment.formattedCreatedDate),
                if (repayment.isSynced)
                  _buildDetailRow('Synced', repayment.formattedSyncedDate),
                if (showCancelButton) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isCancelling ? null : () => _showCancelDialog(repayment),
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label: const Text('Cancel Receipt', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledRepaymentCard(CancelledRepayment cancelled) {
    final isUSD = cancelled.currency == 'USD';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: const Icon(
          Icons.cancel,
          color: Colors.red,
          size: 30,
        ),
        title: Text(
          cancelled.receiptNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${cancelled.fullName}'),
            Text(
              'Amount: ${cancelled.formattedAmount}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isUSD ? Colors.green : Colors.blue,
              ),
            ),
            Text('Cancelled: ${cancelled.formattedCancellationDate}'),
            Text(
              'Reason: ${cancelled.reason}',
              style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Receipt Number', cancelled.receiptNumber),
                _buildDetailRow('Client Name', cancelled.fullName),
                _buildDetailRow('Client ID', cancelled.clientId),
                _buildDetailRow('Amount', cancelled.formattedAmount),
                _buildDetailRow('Currency', cancelled.currency),
                _buildDetailRow('Original Payment Date', cancelled.formattedPaymentDate),
                _buildDetailRow('Cancellation Reason', cancelled.reason),
                _buildDetailRow('Cancelled By', cancelled.cancelledBy),
                _buildDetailRow('Cancelled At', cancelled.formattedCancellationDate),
                _buildDetailRow('Branch', cancelled.branch),
                if (cancelled.whatsAppContact != null)
                  _buildDetailRow('WhatsApp', cancelled.whatsAppContact!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayments Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Queued (${_unsyncedRepayments.length})',
              icon: const Icon(Icons.queue),
            ),
            Tab(
              text: 'Synced (${_syncedRepayments.length})',
              icon: const Icon(Icons.cloud_done),
            ),
            Tab(
              text: 'Cancelled (${_cancelledRepayments.length})',  
              icon: const Icon(Icons.cancel),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _manualSync,
            tooltip: 'Sync All Pending',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllRepayments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Queued Tab (Unsynced)
                _buildQueuedTab(),
                // Synced Tab
                _buildSyncedTab(),
                // Cancelled Tab
                _buildCancelledTab(),
              ],
            ),
    );
  }

  Widget _buildQueuedTab() {
    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.queue, color: Colors.orange, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_unsyncedRepayments.length} Pending Sync',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('Repayments waiting to be synchronized'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Repayments List
        Expanded(
          child: _unsyncedRepayments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_queue, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No pending repayments', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _unsyncedRepayments.length,
                  itemBuilder: (context, index) {
                    return _buildRepaymentCard(_unsyncedRepayments[index], showCancelButton: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSyncedTab() {
    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.green, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_syncedRepayments.length} Successfully Synced',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('Repayments synchronized with server'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Repayments List
        Expanded(
          child: _syncedRepayments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No synced repayments', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _syncedRepayments.length,
                  itemBuilder: (context, index) {
                    return _buildRepaymentCard(_syncedRepayments[index], showCancelButton: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCancelledTab() {
    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_cancelledRepayments.length} Cancelled Repayments',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('Repayments that have been cancelled'),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Cancelled Repayments List
        Expanded(
          child: _cancelledRepayments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No cancelled repayments', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _cancelledRepayments.length,
                  itemBuilder: (context, index) {
                    return _buildCancelledRepaymentCard(_cancelledRepayments[index]);
                  },
                ),
        ),
      ],
    );
  }
}