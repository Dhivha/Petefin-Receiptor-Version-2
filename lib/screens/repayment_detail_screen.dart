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
  State<RepaymentDetailScreen> createState() =>
      _RepaymentDetailScreenState();
}

class _RepaymentDetailScreenState
    extends State<RepaymentDetailScreen> {
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

      final results = await Future.wait([
        _authService.getClientDisbursements(
          widget.client.clientId,
        ),
        _authService.getClientRepayments(
          widget.client.clientId,
        ),
      ]);

      _disbursements = results[0] as List<Disbursement>;
      _repayments = results[1] as List<Repayment>;

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnack(
        'Error loading data: $e',
        Colors.red,
      );
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final result = await _authService
          .syncDisbursementsForClient(
        widget.client.clientId,
      );

      if (!mounted) return;

      _showSnack(
        result.success
            ? '✅ ${result.message}'
            : '⚠️ ${result.message}',
        result.success
            ? Colors.green
            : Colors.orange,
      );

      await _loadData();
    } catch (e) {
      await _loadData();

      if (!mounted) return;

      _showSnack(
        'Error refreshing: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showSnack(
      String message,
      Color color,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(message),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeDialog() {
    if (Navigator.of(
      context,
      rootNavigator: true,
    ).canPop()) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();
    }
  }

  Future<bool> _printSavedReceipt(
      Repayment repayment,
      ) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      final printed =
      await BluetoothReceiptService
          .printRepaymentReceipt(
        repayment,
        clientName: widget.client.fullName,
      );

      if (printed) {
        return true;
      }

      await Future.delayed(
        Duration(milliseconds: 400 * attempt),
      );
    }

    return false;
  }

  Future<void> _processRepayment({
    required Disbursement disbursement,
    required double amount,
    required DateTime paymentDate,
  }) async {
    try {
      _showLoadingDialog(
        'Saving repayment locally...',
      );

      final result = await _authService
          .createRepaymentWithReceiptNumber(
        disbursementId: disbursement.id,
        clientId: widget.client.clientId,
        amount: amount,
        dateOfPayment: paymentDate,
        paymentNumber: '',
        currency: widget.currency,
        clientName: widget.client.fullName,
      );

      _closeDialog();

      if (!mounted) return;

      if (!result.success ||
          result.repayment == null) {
        _showSnack(
          result.message,
          Colors.red,
        );
        return;
      }

      final repayment = result.repayment!;

      _showLoadingDialog(
        'Printing receipt...',
      );

      final printed =
      await _printSavedReceipt(repayment);

      _closeDialog();

      if (!mounted) return;

      await _loadData();

      _showSuccessDialog(
        receiptNumber:
        result.receiptNumber ?? '',
        printed: printed,
      );
    } catch (e) {
      _closeDialog();

      if (!mounted) return;

      _showSnack(
        'Error creating repayment: $e',
        Colors.red,
      );
    }
  }

  void _showRepaymentDialog(
      Disbursement disbursement,
      ) {
    final amountController =
    TextEditingController();

    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setModalState,
              ) {
            return AlertDialog(
              title: Text(
                'Create ${widget.currency} Repayment',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      'Client',
                      widget.client.fullName,
                    ),
                    _infoRow(
                      'Disbursement',
                      disbursement.id.toString(),
                    ),
                    _infoRow(
                      'Product',
                      disbursement
                          .productName
                          ?.trim()
                          .isNotEmpty ==
                          true
                          ? disbursement
                          .productName!
                          : 'N/A',
                    ),
                    _infoRow(
                      'Currency',
                      widget.currency,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller:
                      amountController,
                      autofocus: true,
                      decoration:
                      InputDecoration(
                        labelText:
                        'Repayment Amount',
                        prefixIcon:
                        const Icon(
                          Icons.attach_money,
                        ),
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding:
                      const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                      BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(
                          12,
                        ),
                        color: Colors
                            .grey.shade100,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .calendar_today,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'yyyy-MM-dd',
                              ).format(
                                selectedDate,
                              ),
                              style:
                              const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                () async {
                              final pickedDate =
                              await showDatePicker(
                                context:
                                context,
                                initialDate:
                                selectedDate,
                                firstDate:
                                DateTime(
                                  2000,
                                ),
                                lastDate:
                                DateTime
                                    .now()
                                    .add(
                                  const Duration(
                                    days: 1,
                                  ),
                                ),
                              );

                              if (pickedDate !=
                                  null) {
                                setModalState(
                                      () {
                                    selectedDate =
                                        pickedDate;
                                  },
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.edit,
                            ),
                            label: const Text(
                              'Change',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(
                    Icons.payment,
                  ),
                  label: const Text(
                    'Save & Print',
                  ),
                  onPressed: () async {
                    final amount =
                    double.tryParse(
                      amountController.text
                          .trim(),
                    );

                    if (amount == null ||
                        amount <= 0) {
                      _showSnack(
                        'Please enter a valid amount',
                        Colors.red,
                      );
                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop();

                    await Future.delayed(
                      const Duration(
                        milliseconds: 150,
                      ),
                    );

                    await _processRepayment(
                      disbursement:
                      disbursement,
                      amount: amount,
                      paymentDate:
                      selectedDate,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _infoRow(
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({
    required String receiptNumber,
    required bool printed,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                printed
                    ? Icons.check_circle
                    : Icons.warning_amber,
                color: printed
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 10),
              Text(
                printed
                    ? 'Completed'
                    : 'Saved',
              ),
            ],
          ),
          content: Column(
            mainAxisSize:
            MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                printed
                    ? 'Repayment saved and receipt printed successfully.'
                    : 'Repayment saved locally but receipt printing failed.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(
                  14,
                ),
                decoration:
                BoxDecoration(
                  color:
                  Colors.grey.shade100,
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color: Colors
                        .grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Text(
                      'Receipt Number',
                      style: TextStyle(
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      receiptNumber,
                      style:
                      const TextStyle(
                        fontSize: 20,
                        fontFamily:
                        'monospace',
                        fontWeight:
                        FontWeight.bold,
                        color:
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildStatusLine(
                icon: Icons.save,
                color: Colors.green,
                text: 'Saved locally',
              ),
              const SizedBox(height: 8),
              _buildStatusLine(
                icon: printed
                    ? Icons.print
                    : Icons.print_disabled,
                color: printed
                    ? Colors.green
                    : Colors.orange,
                text: printed
                    ? 'Receipt printed successfully'
                    : 'Printer unavailable or disconnected',
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusLine({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(
      double amount,
      ) {
    final formatter =
    NumberFormat.currency(
      symbol: widget.currency == 'USD'
          ? '\$'
          : 'ZWG ',
    );

    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.currency} Repayments',
        ),
        backgroundColor:
        Theme.of(context)
            .colorScheme
            .inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing
                ? null
                : _refreshData,
            icon: _isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding:
          const EdgeInsets.all(
            16,
          ),
          children: [
            Card(
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),
              child: Padding(
                padding:
                const EdgeInsets.all(
                  16,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                      Theme.of(
                        context,
                      ).primaryColor,
                      child: Text(
                        widget.client
                            .fullName
                            .isNotEmpty
                            ? widget
                            .client
                            .fullName[0]
                            .toUpperCase()
                            : '?',
                        style:
                        const TextStyle(
                          color:
                          Colors
                              .white,
                          fontSize:
                          22,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            widget.client
                                .fullName,
                            style:
                            const TextStyle(
                              fontSize:
                              18,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'ID: ${widget.client.clientId}',
                          ),
                          Text(
                            'Currency: ${widget.currency}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Disbursements',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (_disbursements.isEmpty)
              Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    32,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons
                            .account_balance_wallet_outlined,
                        size: 50,
                        color:
                        Colors.grey,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      const Text(
                        'No disbursements found',
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      ElevatedButton(
                        onPressed:
                        _refreshData,
                        child:
                        const Text(
                          'Refresh',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._disbursements.map(
                    (disbursement) {
                  return Card(
                    margin:
                    const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: Padding(
                      padding:
                      const EdgeInsets.all(
                        12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .account_balance_wallet,
                                color:
                                Colors
                                    .blue,
                              ),
                              const SizedBox(
                                width:
                                10,
                              ),
                              Expanded(
                                child:
                                Text(
                                  disbursement
                                      .productName
                                      ?.trim()
                                      .isNotEmpty ==
                                      true
                                      ? disbursement
                                      .productName!
                                      : 'Loan',
                                  style:
                                  const TextStyle(
                                    fontWeight:
                                    FontWeight.bold,
                                    fontSize:
                                    16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _infoRow(
                            'Amount',
                            _formatCurrency(
                              disbursement
                                  .amount,
                            ),
                          ),
                          _infoRow(
                            'Date',
                            DateFormat(
                              'yyyy-MM-dd',
                            ).format(
                              disbursement
                                  .dateOfDisbursement,
                            ),
                          ),
                          _infoRow(
                            'ID',
                            disbursement.id.toString(),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          SizedBox(
                            width: double
                                .infinity,
                            child:
                            ElevatedButton.icon(
                              icon:
                              const Icon(
                                Icons
                                    .payment,
                              ),
                              label:
                              const Text(
                                'Create Repayment',
                              ),
                              onPressed: () =>
                                  _showRepaymentDialog(
                                    disbursement,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            Row(
              children: [
                const Text(
                  'Repayments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight
                        .bold,
                  ),
                ),
                const Spacer(),
                if (_repayments
                    .isNotEmpty)
                  Text(
                    '${_repayments.length} records',
                    style:
                    const TextStyle(
                      color:
                      Colors.grey,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            if (_repayments.isEmpty)
              const Card(
                child: Padding(
                  padding:
                  EdgeInsets.all(
                    32,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons
                            .receipt_long_outlined,
                        size: 48,
                        color:
                        Colors.grey,
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      Text(
                        'No repayments made yet',
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._repayments.map(
                    (repayment) {
                  final isSynced =
                      repayment
                          .isSynced;

                  return Card(
                    margin:
                    const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: ListTile(
                      leading: Icon(
                        isSynced
                            ? Icons
                            .cloud_done
                            : Icons
                            .cloud_queue,
                        color: isSynced
                            ? Colors
                            .green
                            : Colors
                            .orange,
                      ),
                      title: Text(
                        repayment
                            .receiptNumber,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                      subtitle:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'Amount: ${repayment.currency} ${repayment.formattedAmount}',
                            style:
                            TextStyle(
                              color:
                              repayment.currency ==
                                  'USD'
                                  ? Colors.green
                                  : Colors.blue,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Date: ${DateFormat('yyyy-MM-dd').format(repayment.dateOfPayment)}',
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Row(
                            children: [
                              Icon(
                                isSynced
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                size:
                                16,
                                color: isSynced
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(
                                width:
                                5,
                              ),
                              Text(
                                isSynced
                                    ? 'Synced'
                                    : 'Pending sync',
                                style:
                                TextStyle(
                                  color: isSynced
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize:
                                  12,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}