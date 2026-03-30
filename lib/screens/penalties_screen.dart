import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/penalty_fee.dart';
import '../models/cancelled_penalty_fee.dart';
import '../services/auth_service.dart';
import '../services/bluetooth_receipt_service.dart';

class PenaltiesScreen extends StatefulWidget {
  const PenaltiesScreen({super.key});

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen>
    with TickerProviderStateMixin {
  List<PenaltyFee> _unsyncedPenaltyFees = [];
  List<PenaltyFee> _syncedPenaltyFees = [];
  List<CancelledPenaltyFee> _cancelledPenaltyFees = [];
  List<Client> _clients = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isCancelling = false;
  bool _isAdding = false;
  late TabController _tabController;

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Client? _selectedClient;
  bool _useManualEntry = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _reasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();

      // Load penalty fees
      final unsyncedPenaltyFees = await authService.getUnsyncedPenaltyFees();
      final syncedPenaltyFees = await authService.getSyncedPenaltyFees();

      // Load clients
      final clients = await authService.getClients();

      setState(() {
        _unsyncedPenaltyFees = unsyncedPenaltyFees;
        _syncedPenaltyFees = syncedPenaltyFees;
        _clients = clients;
      });

      // Load cancelled penalty fees
      await _loadCancelledPenaltyFees();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCancelledPenaltyFees() async {
    try {
      final authService = AuthService();
      final cancelled = await authService.getCancelledPenaltyFees();
      setState(() {
        _cancelledPenaltyFees = cancelled;
      });
    } catch (e) {
      print('Error loading cancelled penalty fees: $e');
    }
  }

  Future<void> _manualSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final authService = AuthService();
      final result = await authService.syncUnsyncedPenaltyFees();

      if (result.success) {
        await _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));
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

  Future<void> _showAddPenaltyDialog() async {
    _amountController.clear();
    _selectedClient = null;
    _useManualEntry = false;
    _searchController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Text('Add Penalty Fee'),
              const Spacer(),
              Icon(
                BluetoothReceiptService.isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: BluetoothReceiptService.isConnected
                    ? Colors.green
                    : Colors.red,
                size: 20,
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Manual entry toggle
                Row(
                  children: [
                    Checkbox(
                      value: _useManualEntry,
                      onChanged: (value) {
                        setDialogState(() {
                          _useManualEntry = value ?? false;
                          if (_useManualEntry) {
                            _selectedClient = null;
                          }
                        });
                      },
                    ),
                    const Text('Manual entry (non-client)'),
                  ],
                ),
                const SizedBox(height: 16),

                // Client selection or manual text
                if (!_useManualEntry) ...[
                  const Text(
                    'Select Client',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search clients...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(
                        () {},
                      ); // Trigger rebuild to filter clients
                    },
                  ),
                  const SizedBox(height: 8),

                  // Client list
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: _getFilteredClients().length,
                        itemBuilder: (context, index) {
                          final client = _getFilteredClients()[index];
                          return ListTile(
                            title: Text(client.fullName),
                            subtitle: Text('ID: ${client.clientId}'),
                            trailing:
                                _selectedClient?.clientId == client.clientId
                                ? const Icon(Icons.check, color: Colors.green)
                                : null,
                            onTap: () {
                              setDialogState(() {
                                _selectedClient = client;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Manual entry text
                  const Text(
                    'Client Name (Manual Entry)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedClient?.fullName ?? 'Enter client name manually',
                    style: TextStyle(
                      color: _selectedClient != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Amount field
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Penalty Amount',
                    hintText: 'Enter penalty amount...',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),

                if (BluetoothReceiptService.isConnected) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.print, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Will auto-print to connected printer',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validation
                if (!_useManualEntry && _selectedClient == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a client')),
                  );
                  return;
                }

                if (_amountController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter penalty amount'),
                    ),
                  );
                  return;
                }

                final amount = double.tryParse(_amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text(
                'Add Penalty',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount != null && amount > 0) {
        String clientName;
        if (_useManualEntry) {
          // For manual entry, we would need a way to get the name
          // For now, let's use "Manual Entry Client" as placeholder
          clientName = 'Manual Entry Client';
        } else if (_selectedClient != null) {
          // Use fullName instead of concatenating firstName + lastName
          clientName = _selectedClient!.fullName;
        } else {
          return;
        }

        await _addPenaltyFee(_selectedClient, amount, clientName);
      }
    }
  }

  Future<void> _addPenaltyFee(
    Client? client,
    double amount,
    String clientName,
  ) async {
    setState(() => _isAdding = true);

    try {
      final authService = AuthService();
      final result = await authService.createPenaltyFee(
        clientName: clientName,
        amount: amount,
      );

      if (result.success && result.penaltyFee != null) {
        // AUTO-PRINT PENALTY FEE RECEIPT IMMEDIATELY
        BluetoothReceiptService.autoPrintPenaltyFeeReceipt(result.penaltyFee!);

        await _loadAllData(); // Refresh all data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Penalty fee added: ${result.receiptNumber}'),
              backgroundColor: Colors.green,
            ),
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
            content: Text('Error adding penalty fee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _showCancelDialog(PenaltyFee penaltyFee) async {
    _reasonController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Penalty Fee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt: ${penaltyFee.receiptNumber}'),
            Text('Client: ${penaltyFee.clientName}'),
            Text('Amount: ${penaltyFee.formattedAmount}'),
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
                  const SnackBar(
                    content: Text('Please enter a cancellation reason'),
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Cancel Penalty',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _cancelPenaltyFee(penaltyFee, _reasonController.text.trim());
    }
  }

  Future<void> _cancelPenaltyFee(PenaltyFee penaltyFee, String reason) async {
    setState(() => _isCancelling = true);

    try {
      final authService = AuthService();
      final result = await authService.cancelPenaltyFee(
        penaltyFee: penaltyFee,
        reason: reason,
      );

      if (result.success) {
        await _loadAllData(); // Refresh all data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          // Switch to cancelled tab to show the cancelled penalty fee
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
            content: Text('Error cancelling penalty fee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showReceipt(PenaltyFee penaltyFee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Penalty Fee Receipt'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PETEFIN MICROFINANCE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PENALTY FEE RECEIPT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 20),
                    _buildReceiptRow('Receipt No:', penaltyFee.receiptNumber),
                    _buildReceiptRow('Date/Time:', penaltyFee.formattedDate),
                    _buildReceiptRow('Branch:', penaltyFee.branch),
                    _buildReceiptRow('Client:', penaltyFee.clientName),
                    _buildReceiptRow('Amount:', penaltyFee.formattedAmount),
                    _buildReceiptRow('Currency:', penaltyFee.currency),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        '|||| ||| |||| ||| ||||',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      '${penaltyFee.receiptNumber.replaceAll('PEN', '').substring(0, 12)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank you for your payment',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (BluetoothReceiptService.isConnected) ...[
            ElevatedButton.icon(
              onPressed: () {
                BluetoothReceiptService.autoPrintPenaltyFeeReceipt(penaltyFee);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Receipt sent to printer'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text(
                'Print Receipt',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyFeeCard(
    PenaltyFee penaltyFee, {
    bool showCancelButton = false,
  }) {
    final isUSD = penaltyFee.currency == 'USD';
    final isPending = !penaltyFee.isSynced;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          isPending ? Icons.cloud_queue : Icons.cloud_done,
          color: isPending ? Colors.orange : Colors.green,
          size: 30,
        ),
        title: Text(
          penaltyFee.receiptNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${penaltyFee.clientName}'),
            Text(
              'Amount: ${penaltyFee.formattedAmount}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isUSD ? Colors.green : Colors.blue,
              ),
            ),
            Text('Date: ${penaltyFee.formattedDate}'),
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
                _buildDetailRow('Receipt Number', penaltyFee.receiptNumber),
                _buildDetailRow('Client Name', penaltyFee.clientName),
                _buildDetailRow('Amount', penaltyFee.formattedAmount),
                _buildDetailRow('Currency', penaltyFee.currency),
                _buildDetailRow('Branch', penaltyFee.branch),
                _buildDetailRow('Date Captured', penaltyFee.formattedDate),
                if (penaltyFee.isSynced)
                  _buildDetailRow('Synced', penaltyFee.formattedSyncedDate),
                if (showCancelButton) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showReceipt(penaltyFee),
                        icon: const Icon(Icons.receipt, color: Colors.white),
                        label: const Text(
                          'View Receipt',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isCancelling
                            ? null
                            : () => _showCancelDialog(penaltyFee),
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label: const Text(
                          'Cancel Penalty',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showReceipt(penaltyFee),
                        icon: const Icon(Icons.receipt, color: Colors.white),
                        label: const Text(
                          'View Receipt',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
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

  Widget _buildCancelledPenaltyFeeCard(CancelledPenaltyFee cancelled) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: const Icon(Icons.cancel, color: Colors.red, size: 30),
        title: Text(
          cancelled.receiptNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${cancelled.clientName}'),
            Text(
              'Amount: ${cancelled.formattedAmount}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            Text('Cancelled: ${cancelled.formattedCancellationDate}'),
            Text(
              'Reason: ${cancelled.reason}',
              style: const TextStyle(
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
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
                _buildDetailRow('Client Name', cancelled.clientName),
                _buildDetailRow('Amount', cancelled.formattedAmount),
                _buildDetailRow(
                  'Original Date',
                  cancelled.formattedPaymentDate,
                ),
                _buildDetailRow('Cancellation Reason', cancelled.reason),
                _buildDetailRow('Cancelled By', cancelled.cancelledBy),
                _buildDetailRow(
                  'Cancelled At',
                  cancelled.formattedCancellationDate,
                ),
                _buildDetailRow('Branch', cancelled.branch),
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penalties Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Queued (${_unsyncedPenaltyFees.length})',
              icon: const Icon(Icons.queue),
            ),
            Tab(
              text: 'Synced (${_syncedPenaltyFees.length})',
              icon: const Icon(Icons.cloud_done),
            ),
            Tab(
              text: 'Cancelled (${_cancelledPenaltyFees.length})',
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
            onPressed: _loadAllData,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isAdding ? null : _showAddPenaltyDialog,
        backgroundColor: Colors.blue,
        child: _isAdding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Penalty Fee',
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
                      '${_unsyncedPenaltyFees.length} Pending Sync',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Penalty fees waiting to be synchronized'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Penalty Fees List
        Expanded(
          child: _unsyncedPenaltyFees.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_queue, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No pending penalty fees',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use the + button to add a penalty fee',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _unsyncedPenaltyFees.length,
                  itemBuilder: (context, index) {
                    return _buildPenaltyFeeCard(
                      _unsyncedPenaltyFees[index],
                      showCancelButton: true,
                    );
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
                      '${_syncedPenaltyFees.length} Successfully Synced',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Penalty fees synchronized with server'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Penalty Fees List
        Expanded(
          child: _syncedPenaltyFees.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No synced penalty fees',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _syncedPenaltyFees.length,
                  itemBuilder: (context, index) {
                    return _buildPenaltyFeeCard(
                      _syncedPenaltyFees[index],
                      showCancelButton: true,
                    );
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
                      '${_cancelledPenaltyFees.length} Cancelled Penalties',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Penalty fees that have been cancelled'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Cancelled Penalty Fees List
        Expanded(
          child: _cancelledPenaltyFees.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No cancelled penalty fees',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _cancelledPenaltyFees.length,
                  itemBuilder: (context, index) {
                    return _buildCancelledPenaltyFeeCard(
                      _cancelledPenaltyFees[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<Client> _getFilteredClients() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _clients;
    }

    return _clients.where((client) {
      return client.fullName.toLowerCase().contains(query) ||
          client.clientId.toLowerCase().contains(query);
    }).toList();
  }
}
