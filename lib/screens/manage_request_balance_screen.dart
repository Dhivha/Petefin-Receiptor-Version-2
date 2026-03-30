import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../models/request_balance.dart';

class ManageRequestBalanceScreen extends StatefulWidget {
  @override
  _ManageRequestBalanceScreenState createState() => _ManageRequestBalanceScreenState();
}

class _ManageRequestBalanceScreenState extends State<ManageRequestBalanceScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _cashbookDateController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _cashbookDate;
  
  bool _isRequesting = false;
  bool _isProcessing = false;
  bool _isLoadingRequests = false;
  List<RequestBalance> _recentRequests = [];
  Timer? _refreshTimer;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentRequests();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _cashbookDateController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });
    
    try {
      final requests = await _authService.getRecentRequestBalances(limit: 15);
      setState(() {
        _recentRequests = requests;
      });
    } catch (e) {
      print('Error loading request balances: $e');
    } finally {
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted && _hasPendingRequests()) {
        _loadRecentRequests();
      }
    });
  }

  bool _hasPendingRequests() {
    return _recentRequests.any((request) => request.status == RequestBalanceStatus.pending);
  }

  int get _pendingRequestsCount {
    return _recentRequests.where((request) => request.status == RequestBalanceStatus.pending).length;
  }

  Future<void> _selectCashbookDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(Duration(days: 1));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _cashbookDate ?? now,
      firstDate: yesterday, // Only allow from yesterday onwards
      lastDate: now.add(Duration(days: 365)), // Allow future dates
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _cashbookDate) {
      setState(() {
        _cashbookDate = picked;
        _cashbookDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitRequestBalance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_cashbookDate == null) {
      _showSnackBar('Please select a cashbook date', isError: true);
      return;
    }

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount greater than 0', isError: true);
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    try {
      final result = await _authService.requestBalance(
        cashbookDate: _cashbookDate!,
        amount: amount,
        reason: _reasonController.text.trim(),
      );

      if (result.success) {
        _showSnackBar(result.message);
        _clearForm();
        await _loadRecentRequests();
        
        // Show background processing notification
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            _showSnackBar('Request is being processed in the background...', 
                backgroundColor: Colors.blue);
          }
        });
      } else {
        _showSnackBar(result.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Request failed: $e', isError: true);
    } finally {
      setState(() {
        _isRequesting = false;
      });
    }
  }

  Future<void> _processQueuedRequests() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _authService.processQueuedRequestBalancesManually();

      if (result.success) {
        _showSnackBar(result.message);
        await _loadRecentRequests();
      } else {
        _showSnackBar(result.message, isError: true);  
      }
    } catch (e) {
      _showSnackBar('Processing failed: $e', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _deleteRequest(RequestBalance request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Request'),
        content: Text('Are you sure you want to delete this balance request?\n\n${request.formattedAmount} - ${request.formattedDate}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _authService.deleteRequestBalance(request.id!);
        
        if (result.success) {
          _showSnackBar('Request deleted successfully');
          await _loadRecentRequests();
        } else {
          _showSnackBar(result.message, isError: true);
        }
      } catch (e) {
        _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  void _clearForm() {
    _cashbookDateController.clear();
    _amountController.clear();
    _reasonController.clear();
    setState(() {
      _cashbookDate = null;
    });
  }

  void _showSnackBar(String message, {bool isError = false, Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? (isError ? Colors.red : Colors.green),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  String _getWordCount(String text) {
    if (text.trim().isEmpty) return '0/20';
    final words = text.trim().split(RegExp(r'\\s+'));
    return '${words.length}/20';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Balance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'New Request'),
            Tab(text: _pendingRequestsCount > 0 ? 'Recent Requests ($_pendingRequestsCount pending)' : 'Recent Requests'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestTab(),
          _buildRecentRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildNewRequestTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit Balance Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Cashbook Date
                    TextFormField(
                      controller: _cashbookDateController,
                      decoration: InputDecoration(
                        labelText: 'Cashbook Date',
                        hintText: 'Select date (max 1 day back)',
                        prefixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      readOnly: true,
                      onTap: () => _selectCashbookDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select cashbook date';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (USD)',
                        hintText: 'Enter amount greater than 0',
                        prefixIcon: Icon(Icons.attach_money, color: Colors.blue),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Reason
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            hintText: 'Enter reason (max 20 words)',
                            prefixIcon: Icon(Icons.description, color: Colors.blue),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {}); // Refresh word count 
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter reason';
                            }
                            final words = value.trim().split(RegExp(r'\s+'));
                            if (words.length > 20) {
                              return 'Reason cannot exceed 20 words';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Words: ${_getWordCount(_reasonController.text)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _reasonController.text.trim().split(RegExp(r'\s+')).length > 20 
                                  ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isRequesting ? null : _submitRequestBalance,
                        icon: _isRequesting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.send, color: Colors.white),
                        label: Text(
                          _isRequesting ? 'Submitting Request...' : 'Submit Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Process Queued Button
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Process Pending Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manually check for pending requests and process them now',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _processQueuedRequests,
                        icon: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.sync, color: Colors.white),
                        label: Text(
                          _isProcessing ? 'Processing...' : 'Process Now',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Info Card
            Card(
              elevation: 2,
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Request Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• Date: Cannot be more than 1 day in the past\n'
                      '• Amount: Must be greater than zero (USD)\n'
                      '• Reason: Maximum 20 words allowed\n'
                      '• Requests are processed in the background\n'
                      '• You will see status updates in Recent Requests',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
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

  Widget _buildRecentRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadRecentRequests,
      color: Colors.blue,
      child: Column(
        children: [
          // Pending Requests Status Bar
          if (_pendingRequestsCount > 0)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.0),
              color: Colors.blue[50],
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_pendingRequestsCount request${_pendingRequestsCount == 1 ? "" : "s"} being processed...',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadRecentRequests,
                    child: Text('Refresh', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),
          
          // Requests List
          Expanded(
            child: _isLoadingRequests
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blue),
                        SizedBox(height: 16),
                        Text(
                          'Loading requests...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _recentRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.request_quote, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No balance requests yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Submit your first balance request from the New Request tab',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.0),
                        itemCount: _recentRequests.length,
                        itemBuilder: (context, index) {
                          final request = _recentRequests[index];
                          return _buildRequestCard(request);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(RequestBalance request) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help;
    String statusText = 'Unknown';

    switch (request.status) {
      case RequestBalanceStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case RequestBalanceStatus.synced:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case RequestBalanceStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Animated loading indicator for pending requests
                if (request.status == RequestBalanceStatus.pending)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ),
                Icon(statusIcon, color: statusColor, size: 20),
                SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                Text(
                  'ID: ${request.id}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.formattedAmount,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Text(
                  request.formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            
            Text(
              'Branch: ${request.branchName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                'Reason: ${request.reason}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            SizedBox(height: 8),
            
            Text(
              'Requested: ${request.formattedDateTime}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            
            if (request.syncedAt != null) ...[
              SizedBox(height: 4),
              Text(
                'Completed: ${DateFormat('dd/MM/yyyy HH:mm').format(request.syncedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            if (request.status == RequestBalanceStatus.failed && request.errorMessage != null) ...[
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'Error: ${request.errorMessage}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
            
            SizedBox(height: 12),
            Row(
              children: [
                Spacer(),
                ElevatedButton(
                  onPressed: () => _deleteRequest(request),
                  child: Icon(Icons.delete, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: Size(36, 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}