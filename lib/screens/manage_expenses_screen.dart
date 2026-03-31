import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';

class ManageExpensesScreen extends StatefulWidget {
  const ManageExpensesScreen({super.key});

  @override
  State<ManageExpensesScreen> createState() => _ManageExpensesScreenState();
}

class _ManageExpensesScreenState extends State<ManageExpensesScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // Form state
  String? _selectedCategory;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isSyncing = false;

  // Tab controller
  late TabController _tabController;

  // Data
  List<Expense> _queuedExpenses = [];
  List<Expense> _syncedExpenses = [];
  List<Expense> _filteredQueuedExpenses = [];
  List<Expense> _filteredSyncedExpenses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    _loadExpenses();

    // Auto-refresh expenses every 10 seconds
    Stream.periodic(const Duration(seconds: 10)).listen((_) {
      if (mounted) {
        _loadExpenses();
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

  Future<void> _loadExpenses() async {
    if (!mounted) return;

    try {
      final queuedExpenses = await _authService.getQueuedExpenses();
      final syncedExpenses = await _authService.getSyncedExpenses();

      if (mounted) {
        setState(() {
          _queuedExpenses = queuedExpenses;
          _syncedExpenses = syncedExpenses;
          _filteredQueuedExpenses = queuedExpenses;
          _filteredSyncedExpenses = syncedExpenses;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 2)),
      lastDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59), // Allow full day of today
      helpText: 'Select expense date',
      errorFormatText: 'Enter valid date',
      errorInvalidText: 'Date cannot be more than 2 days ago',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _createExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expense category')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expense date')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(amount);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.createExpense(
        category: _selectedCategory!,
        amount: amount,
        expenseDate: _selectedDate!,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.message.contains('WARNING')
                  ? Colors.orange
                  : Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          // Clear form
          _amountController.clear();
          _selectedCategory = null;
          _selectedDate = DateTime.now();
          _dateController.text = DateFormat(
            'dd/MM/yyyy',
          ).format(_selectedDate!);

          // Refresh data
          await _loadExpenses();
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
          SnackBar(
            content: Text('Error creating expense: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<bool> _showConfirmationDialog(double amount) async {
    final categoryDisplay = ExpenseCategoryHelper.getDisplayName(
      _selectedCategory!,
    );

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: $categoryDisplay'),
                Text('Amount: \$${amount.toStringAsFixed(2)}'),
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                ),
                Text(
                  'Branch: ${_authService.currentUser?.branch ?? 'Unknown'}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create this expense?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (expense.isSynced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete synced expense')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Delete ${ExpenseCategoryHelper.getDisplayName(expense.category)} expense of \$${expense.formattedAmount}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && expense.id != null) {
      try {
        final result = await _authService.deleteQueuedExpense(expense.id!);

        if (mounted) {
          if (result.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadExpenses();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete expense: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _syncExpenses() async {
    if (_queuedExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No queued expenses to sync')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _authService.syncQueuedExpenses();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          await _loadExpenses();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Create', icon: const Icon(Icons.add)),
            Tab(
              text:
                  'Track (${_queuedExpenses.length + _syncedExpenses.length})',
              icon: const Icon(Icons.list),
            ),
          ],
        ),
        actions: [
          if (_queuedExpenses.isNotEmpty)
            IconButton(
              onPressed: _isSyncing ? null : _syncExpenses,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              tooltip: 'Sync Queued Expenses',
            ),
          IconButton(
            onPressed: _loadExpenses,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCreateExpenseTab(), _buildTrackExpensesTab()],
      ),
    );
  }

  Widget _buildCreateExpenseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Expense Category *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: ExpenseCategoryHelper.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(ExpenseCategoryHelper.getDisplayName(category)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an expense category';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Amount Field
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Date Field
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Expense Date *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              readOnly: true,
              onTap: _selectDate,
              validator: (value) {
                if (_selectedDate == null) {
                  return 'Please select an expense date';
                }
                if (!_authService.isValidExpenseDate(_selectedDate!)) {
                  return 'Date cannot be more than 2 days ago or in the future';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Branch Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business),
                  const SizedBox(width: 8),
                  Text(
                    'Branch: ${_authService.currentUser?.branch ?? 'Unknown'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _isLoading ? null : _createExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Create Expense',
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Expenses are queued locally and synced automatically',
                    ),
                    const Text(
                      '• You can only select dates within the last 2 days',
                    ),
                    const Text('• Queued expenses can be deleted before sync'),
                    const Text('• Synced expenses auto-delete after 7 days'),
                    const Text(
                      '• Duplicate warnings are shown but won\'t block creation',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackExpensesTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                text: 'Queued (${_filteredQueuedExpenses.length})',
                icon: const Icon(Icons.schedule),
              ),
              Tab(
                text: 'Synced (${_filteredSyncedExpenses.length})',
                icon: const Icon(Icons.check_circle),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildQueuedExpensesView(),
                _buildSyncedExpensesView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuedExpensesView() {
    if (_filteredQueuedExpenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Queued Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Create an expense to see it here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredQueuedExpenses.length,
      itemBuilder: (context, index) {
        final expense = _filteredQueuedExpenses[index];
        return _buildExpenseCard(expense, isQueued: true);
      },
    );
  }

  Widget _buildSyncedExpensesView() {
    if (_filteredSyncedExpenses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Synced Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Synced expenses will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSyncedExpenses.length,
      itemBuilder: (context, index) {
        final expense = _filteredSyncedExpenses[index];
        return _buildExpenseCard(expense, isQueued: false);
      },
    );
  }

  Widget _buildExpenseCard(Expense expense, {required bool isQueued}) {
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
                      Text(
                        ExpenseCategoryHelper.getDisplayName(expense.category),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expense.formattedAmount,
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
                    if (isQueued && expense.canBeDeleted)
                      TextButton.icon(
                        onPressed: () => _deleteExpense(expense),
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  expense.formattedDate,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    expense.branchName,
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (!isQueued && expense.syncedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.sync, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Synced: ${DateFormat('dd/MM/yyyy HH:mm').format(expense.syncedAt!)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
