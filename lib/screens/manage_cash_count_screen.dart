import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cash_count.dart';
import '../services/auth_service.dart';

class ManageCashCountScreen extends StatefulWidget {
  const ManageCashCountScreen({super.key});

  @override
  State<ManageCashCountScreen> createState() => _ManageCashCountScreenState();
}

class _ManageCashCountScreenState extends State<ManageCashCountScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // Form state
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isSyncing = false;

  // Tab controller
  late TabController _tabController;

  // Data
  List<CashCount> _queuedCashCounts = [];
  List<CashCount> _syncedCashCounts = [];
  List<CashCount> _filteredQueuedCashCounts = [];
  List<CashCount> _filteredSyncedCashCounts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    _loadCashCounts();

    // Auto-refresh cash counts every 10 seconds
    Stream.periodic(const Duration(seconds: 10)).listen((_) {
      if (mounted) {
        _loadCashCounts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCashCounts() async {
    if (!mounted) return;

    try {
      final queuedCashCounts = await _authService.getQueuedCashCounts();
      final syncedCashCounts = await _authService.getSyncedCashCounts();

      if (mounted) {
        setState(() {
          _queuedCashCounts = queuedCashCounts;
          _syncedCashCounts = syncedCashCounts;
          _filteredQueuedCashCounts = queuedCashCounts;
          _filteredSyncedCashCounts = syncedCashCounts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cash counts: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59), // Allow full day of today
      helpText: 'Select cashbook date',
      errorFormatText: 'Enter valid date',
      errorInvalidText: 'Date cannot be more than 1 day ago',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitCashCount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      final result = await _authService.captureDailyCashCount(
        amount: amount,
        cashbookDate: _selectedDate!,
      );

      if (mounted) {
        if (result.success) {
          // Clear form
          _amountController.clear();
          _selectedDate = DateTime.now();
          _dateController.text = DateFormat(
            'dd/MM/yyyy',
          ).format(_selectedDate!);

          // Reload data
          await _loadCashCounts();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncCashCounts() async {
    if (_queuedCashCounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No queued cash counts to sync')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _authService.syncQueuedCashCounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          await _loadCashCounts();
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
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _deleteCashCount(CashCount cashCount) async {
    if (cashCount.isSynced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete synced cash count')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cash Count'),
        content: Text(
          'Are you sure you want to delete this cash count entry of ${cashCount.formattedAmount}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _authService.deleteQueuedCashCount(cashCount.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          await _loadCashCounts();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting cash count: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daily Cash Count'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          actions: [
            if (_queuedCashCounts.isNotEmpty)
              IconButton(
                onPressed: _isSyncing ? null : _syncCashCounts,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.sync),
                tooltip: 'Sync Cash Counts',
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                text: 'Queued (${_filteredQueuedCashCounts.length})',
                icon: const Icon(Icons.schedule),
              ),
              Tab(
                text: 'Synced (${_filteredSyncedCashCounts.length})',
                icon: const Icon(Icons.check_circle),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Cash Count Form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Capture Daily Cash Count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount (USD)',
                              border: OutlineInputBorder(),
                              prefixText: '\$ ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter amount';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Please enter valid amount';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _dateController,
                            decoration: const InputDecoration(
                              labelText: 'Cashbook Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: _selectDate,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select date';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitCashCount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Capture Cash Count',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Tabs Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQueuedCashCountsView(),
                  _buildSyncedCashCountsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuedCashCountsView() {
    if (_filteredQueuedCashCounts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Queued Cash Counts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Capture a cash count to see it here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredQueuedCashCounts.length,
      itemBuilder: (context, index) {
        final cashCount = _filteredQueuedCashCounts[index];
        return _buildCashCountCard(cashCount, isQueued: true);
      },
    );
  }

  Widget _buildSyncedCashCountsView() {
    if (_filteredSyncedCashCounts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Synced Cash Counts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Synced cash counts will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSyncedCashCounts.length,
      itemBuilder: (context, index) {
        final cashCount = _filteredSyncedCashCounts[index];
        return _buildCashCountCard(cashCount, isQueued: false);
      },
    );
  }

  Widget _buildCashCountCard(CashCount cashCount, {required bool isQueued}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Cash Count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cashCount.formattedAmount,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isQueued ? Colors.orange : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isQueued ? 'QUEUED' : 'SYNCED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isQueued && cashCount.canBeDeleted)
                      TextButton.icon(
                        onPressed: () => _deleteCashCount(cashCount),
                        icon: const Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.business, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text(
                  cashCount.branchName,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text(
                  cashCount.formattedDate,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text(
                  'Captured by: ${cashCount.capturedBy}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
