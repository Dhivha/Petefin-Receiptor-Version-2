import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/disbursement.dart';
import '../models/repayment.dart';
import '../services/auth_service.dart';
import '../services/bluetooth_receipt_service.dart';

class RepaymentDetailScreen extends StatefulWidget {
  final Client client;
  final String currency;

  const RepaymentDetailScreen({
    super.key,
    required this.client,
    required this.currency,
  });

  @override
  State<RepaymentDetailScreen> createState() => _RepaymentDetailScreenState();
}

class _RepaymentDetailScreenState extends State<RepaymentDetailScreen> {
  final AuthService _authService = AuthService();
  List<Disbursement> _disbursements = [];
  List<Repayment> _repayments = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load disbursements and repayments in parallel
      final results = await Future.wait([
        _authService.getClientDisbursements(widget.client.clientId),
        _authService.getClientRepayments(widget.client.clientId),
      ]);

      _disbursements = results[0] as List<Disbursement>;
      _repayments = results[1] as List<Repayment>;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Try to sync disbursements from server
      final result = await _authService.syncDisbursementsForClient(
        widget.client.clientId,
      );
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result.message}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Reload local data
      await _loadData();
    } catch (e) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _showRepaymentDialog(Disbursement disbursement) {
    final amountController = TextEditingController();
    final paymentNumberController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Create ${widget.currency} Repayment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client: ${widget.client.fullName}'),
                    Text('Disbursement ID: ${disbursement.id}'),
                    Text('Currency: ${widget.currency}'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Repayment Amount',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: paymentNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Number',
                        prefixIcon: Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                            );
                            if (pickedDate != null) {
                              setModalState(() {
                                selectedDate = pickedDate;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    final paymentNumber = paymentNumberController.text.trim();

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (paymentNumber.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a payment number'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Close dialog first
                    Navigator.of(context).pop();

                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text('Creating repayment...'),
                            ],
                          ),
                        );
                      },
                    );

                    try {
                      final result = await _authService.createRepaymentWithReceiptNumber(
                        disbursementId: disbursement.id,
                        clientId: widget.client.clientId,
                        amount: amount,
                        dateOfPayment: selectedDate,
                        paymentNumber: paymentNumber,
                        currency: widget.currency,
                        clientName: widget.client.fullName,
                      );

                      // Close loading dialog
                      if (mounted) Navigator.of(context).pop();

                      if (result.success) {
                        // AUTO-PRINT RECEIPT IMMEDIATELY
                        if (result.repayment != null) {
                          BluetoothReceiptService.autoPrintReceipt(
                            result.repayment!,
                            clientName: widget.client.fullName,
                          );
                        }
                        
                        // Show success dialog with receipt number
                        _showSuccessDialog(result.receiptNumber!);
                        // Reload data to show new repayment
                        _loadData();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${result.message}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      // Close loading dialog
                      if (mounted) Navigator.of(context).pop();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating repayment: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create Repayment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(String receiptNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Repayment created successfully'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receipt Number:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receiptNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'monospace',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '✅ Saved locally\n⏳ Will sync to server when online',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: widget.currency == 'USD' ? '\$' : 'ZWG',
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.currency} Repayments'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  child: Text(
                                    widget.client.fullName.isNotEmpty
                                        ? widget.client.fullName[0]
                                              .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.client.fullName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('ID: ${widget.client.clientId}'),
                                      Text('Currency: ${widget.currency}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Disbursements Section
                    const Text(
                      'Disbursements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _disbursements.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No disbursements found'),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _refreshData,
                                    child: const Text('Tap to refresh'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: _disbursements.map((disbursement) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.blue,
                                  ),
                                  title: Text(
                                    'ID: ${disbursement.id}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount: ${_formatCurrency(disbursement.amount)}',
                                      ),
                                      Text(
                                        'Date: ${DateFormat('yyyy-MM-dd').format(disbursement.dateOfDisbursement)}',
                                      ),
                                    ],
                                  ),
                                  trailing: ElevatedButton.icon(
                                    icon: const Icon(Icons.payment, size: 16),
                                    label: const Text('Pay'),
                                    onPressed: () =>
                                        _showRepaymentDialog(disbursement),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            }).toList(),
                          ),

                    const SizedBox(height: 24),

                    // Repayments Section
                    Row(
                      children: [
                        const Text(
                          'Repayments',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_repayments.isNotEmpty)
                          Text(
                            '${_repayments.length} records',
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _repayments.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text('No repayments made yet'),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: _repayments.map((repayment) {
                              final isUSD = repayment.currency == 'USD';
                              final isSynced = repayment.isSynced;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    isSynced
                                        ? Icons.cloud_done
                                        : Icons.cloud_queue,
                                    color: isSynced
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  title: Text('${repayment.receiptNumber}'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount: ${repayment.currency} ${repayment.formattedAmount}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isUSD
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        'Date: ${DateFormat('yyyy-MM-dd').format(repayment.dateOfPayment)}',
                                      ),
                                      Text(
                                        'Payment #: ${repayment.paymentNumber}',
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            isSynced
                                                ? Icons.check_circle
                                                : Icons.schedule,
                                            size: 16,
                                            color: isSynced
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isSynced
                                                ? 'Synced'
                                                : 'Pending sync',
                                            style: TextStyle(
                                              color: isSynced
                                                  ? Colors.green
                                                  : Colors.orange,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
