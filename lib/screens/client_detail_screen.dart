import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/disbursement.dart';
import '../services/auth_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  List<Disbursement> _disbursements = [];
  bool _isLoadingDisbursements = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDisbursements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDisbursements() async {
    setState(() {
      _isLoadingDisbursements = true;
      _errorMessage = null;
    });

    try {
      // Try to load from API first, then fall back to local data
      final syncResult = await _authService.syncDisbursementsForClient(
        widget.client.clientId,
      );

      if (syncResult.success && syncResult.disbursements != null) {
        setState(() {
          _disbursements = syncResult.disbursements!;
          _isLoadingDisbursements = false;
        });
      } else {
        // Fallback to local data
        final localDisbursements = await _authService.getClientDisbursements(
          widget.client.clientId,
        );
        setState(() {
          _disbursements = localDisbursements;
          _isLoadingDisbursements = false;
          _errorMessage = syncResult.message;
        });
      }
    } catch (e) {
      // Load from local database as fallback
      final localDisbursements = await _authService.getClientDisbursements(
        widget.client.clientId,
      );
      setState(() {
        _disbursements = localDisbursements;
        _isLoadingDisbursements = false;
        _errorMessage = 'Failed to sync from server. Showing local data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.fullName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details', icon: Icon(Icons.person)),
            Tab(
              text: 'Disbursements',
              icon: Icon(Icons.account_balance_wallet),
            ),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClientDetails(),
          _buildDisbursements(),
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildClientDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client Information',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Client ID', widget.client.clientId),
                  _buildDetailRow('Full Name', widget.client.fullName),
                  _buildDetailRow('WhatsApp', widget.client.whatsAppContact),
                  _buildDetailRow('Email', widget.client.emailAddress),
                  _buildDetailRow(
                    'National ID',
                    widget.client.nationalIdNumber,
                  ),
                  _buildDetailRow('Branch', widget.client.branch),
                  _buildDetailRow('Gender', widget.client.gender),
                  _buildDetailRow('Next of Kin', widget.client.nextOfKinName),
                  _buildDetailRow(
                    'NOK Contact',
                    widget.client.nextOfKinContact,
                  ),
                  _buildDetailRow(
                    'Relationship',
                    widget.client.relationshipWithNOK,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisbursements() {
    if (_isLoadingDisbursements) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_disbursements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No disbursements found',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'This client has no loan disbursements yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDisbursements,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDisbursements,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _disbursements.length,
              itemBuilder: (context, index) {
                final disbursement = _disbursements[index];
                return _buildDisbursementCard(disbursement);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisbursementCard(Disbursement disbursement) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with amount and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currencyFormat.format(disbursement.amount),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                    ),
                    if (disbursement.productName != null)
                      Text(
                        disbursement.productName!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                _buildPaymentStatusChip(disbursement),
              ],
            ),

            const SizedBox(height: 16),

            // Key details
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    'Disbursement Date',
                    dateFormat.format(disbursement.dateOfDisbursement),
                    Icons.calendar_today,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    'Tenure',
                    '${disbursement.tenure} weeks',
                    Icons.access_time,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    'Weekly Payment',
                    currencyFormat.format(disbursement.weeklyPayment),
                    Icons.payment,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    'Total Amount',
                    currencyFormat.format(disbursement.totalAmount),
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),

            if (disbursement.nextPaymentDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: disbursement.hasOverduePayments
                      ? Colors.red[50]
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: disbursement.hasOverduePayments
                        ? Colors.red[200]!
                        : Colors.blue[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      disbursement.hasOverduePayments
                          ? Icons.warning
                          : Icons.schedule,
                      color: disbursement.hasOverduePayments
                          ? Colors.red[700]
                          : Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Next Payment: ${dateFormat.format(disbursement.nextPaymentDate!)}',
                      style: TextStyle(
                        color: disbursement.hasOverduePayments
                            ? Colors.red[700]
                            : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showPaymentSchedule(context, disbursement),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Payment Schedule'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showDisbursementDetails(context, disbursement),
                  icon: const Icon(Icons.info),
                  label: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(Disbursement disbursement) {
    final hasOverdue = disbursement.hasOverduePayments;
    final nextPayment = disbursement.nextDuePayment;

    String status;
    MaterialColor color;

    if (hasOverdue) {
      status = 'Overdue';
      color = Colors.red;
    } else if (nextPayment != null) {
      status = 'Active';
      color = Colors.green;
    } else {
      status = 'Completed';
      color = Colors.blue;
    }

    return Chip(
      label: Text(
        status,
        style: TextStyle(color: color[700], fontWeight: FontWeight.w500),
      ),
      backgroundColor: color[100],
      side: BorderSide(color: color[300]!),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return const Center(
      child: Text('Payment history will be implemented here'),
    );
  }

  void _showPaymentSchedule(BuildContext context, Disbursement disbursement) {
    showDialog(
      context: context,
      builder: (context) => PaymentScheduleDialog(disbursement: disbursement),
    );
  }

  void _showDisbursementDetails(
    BuildContext context,
    Disbursement disbursement,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          DisbursementDetailsDialog(disbursement: disbursement),
    );
  }
}

// Payment Schedule Dialog
class PaymentScheduleDialog extends StatelessWidget {
  final Disbursement disbursement;

  const PaymentScheduleDialog({super.key, required this.disbursement});

  @override
  Widget build(BuildContext context) {
    final payments = disbursement.paymentSchedule;
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Schedule',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final paymentDate = payments[index];
                  final isPaid =
                      false; // You'd need to track this from a separate payment tracking system

                  return Card(
                    color: isPaid ? Colors.green[50] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPaid ? Colors.green : Colors.grey,
                        child: Text('${index + 1}'),
                      ),
                      title: Text('Payment ${index + 1}'),
                      subtitle: Text(dateFormat.format(paymentDate)),
                      trailing: Text(
                        currencyFormat.format(disbursement.weeklyPayment),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Disbursement Details Dialog
class DisbursementDetailsDialog extends StatelessWidget {
  final Disbursement disbursement;

  const DisbursementDetailsDialog({super.key, required this.disbursement});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Disbursement Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailCard('Loan Information', [
                      _buildDetailRow(
                        'Principal Amount',
                        currencyFormat.format(disbursement.amount),
                      ),
                      _buildDetailRow(
                        'Interest Rate',
                        '${disbursement.interest}%',
                      ),
                      _buildDetailRow(
                        'Total Amount',
                        currencyFormat.format(disbursement.totalAmount),
                      ),
                      _buildDetailRow(
                        'Weekly Payment',
                        currencyFormat.format(disbursement.weeklyPayment),
                      ),
                      _buildDetailRow('Tenure', '${disbursement.tenure} weeks'),
                      _buildDetailRow(
                        'Admin Fees',
                        currencyFormat.format(disbursement.adminFees),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    _buildDetailCard('Disbursement Information', [
                      _buildDetailRow(
                        'Date of Disbursement',
                        dateFormat.format(disbursement.dateOfDisbursement),
                      ),
                      _buildDetailRow('Branch', disbursement.branch),
                      _buildDetailRow('FCB', disbursement.fcb.toString()),
                      _buildDetailRow(
                        'Grace Period',
                        '${disbursement.gracePeriodDays} days',
                      ),
                      if (disbursement.productName != null)
                        _buildDetailRow('Product', disbursement.productName!),
                      if (disbursement.description != null)
                        _buildDetailRow(
                          'Description',
                          disbursement.description!,
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
