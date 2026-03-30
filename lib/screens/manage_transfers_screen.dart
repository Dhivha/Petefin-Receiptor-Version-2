import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/branch.dart';
import '../models/transfer.dart';
import 'track_transfers_screen.dart';

class ManageTransfersScreen extends StatefulWidget {
  const ManageTransfersScreen({Key? key}) : super(key: key);

  @override
  State<ManageTransfersScreen> createState() => _ManageTransfersScreenState();
}

class _ManageTransfersScreenState extends State<ManageTransfersScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  List<Branch> _availableBranches = [];
  Branch? _selectedReceivingBranch;
  String _selectedTransferType = 'USD_CASH';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isCreatingTransfer = false;

  final List<String> _transferTypes = [
    'USD_CASH',
    'USD_BANK', 
    'ZWG_BANK',
  ];

  final Map<String, String> _transferTypeDisplayNames = {
    'USD_CASH': 'USD Cash Transfer',
    'USD_BANK': 'USD Bank Transfer',
    'ZWG_BANK': 'ZWG Bank Transfer',
  };

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final branches = await _authService.getAllBranches();
      final currentUser = _authService.currentUser;
      
      if (currentUser != null) {
        // Filter out user's own branch - can't transfer to self
        final availableBranches = branches.where((branch) => 
          branch.branchId != currentUser.branchId
        ).toList();
        
        if (mounted) {
          setState(() {
            _availableBranches = availableBranches;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error loading branches: $e');
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final twoDaysAgo = now.subtract(Duration(days: 2));
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: twoDaysAgo,
      lastDate: now,
      helpText: 'Select Transfer Date',
      errorFormatText: 'Enter a valid date',
      errorInvalidText: 'Enter a date within the allowed range',
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _selectedDate = selectedDate;
      });
    }
  }

  Future<void> _createTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReceivingBranch == null) {
      _showErrorDialog('Please select a receiving branch');
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isCreatingTransfer = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      
      final result = await _authService.createTransfer(
        amount: amount,
        transferDate: _selectedDate,
        receivingBranchId: _selectedReceivingBranch!.branchId,
        receivingBranch: _selectedReceivingBranch!.branchName,
        transferType: _selectedTransferType,
      );

      if (mounted) {
        setState(() => _isCreatingTransfer = false);
        
        if (result.success) {
          _showSuccessDialog(result.message);
          _resetForm();
        } else {
          _showErrorDialog(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingTransfer = false);
        _showErrorDialog('Error creating transfer: $e');
      }
    }
  }

  void _resetForm() {
    _amountController.clear();
    setState(() {
      _selectedReceivingBranch = null;
      _selectedTransferType = 'USD_CASH';
      _selectedDate = DateTime.now();
    });
    _formKey.currentState?.reset();
  }

  Future<bool> _showConfirmationDialog() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return false;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transfer Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Type: ${_transferTypeDisplayNames[_selectedTransferType]}'),
            Text('Amount: ${_getAmountDisplay()}'),
            Text('From: ${currentUser.branch}'),
            Text('To: ${_selectedReceivingBranch?.branchName ?? 'Unknown'}'),
            Text('Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
            SizedBox(height: 12),
            Text(
              'This transfer will be queued and synced automatically when internet is available.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirm Transfer'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToTrackTransfers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => TrackTransfersScreen()),
    );
  }

  String _getAmountDisplay() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final currencySymbol = _selectedTransferType.startsWith('USD') ? '\$' : 'ZWG ';
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Transfers'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Current user info card
                  if (currentUser != null) ...[
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sending From:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    currentUser.branch,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'User: ${currentUser.fullName}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Transfer form
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Create New Transfer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Transfer type dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedTransferType,
                              decoration: InputDecoration(
                                labelText: 'Transfer Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_horiz),
                              ),
                              items: _transferTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(_transferTypeDisplayNames[type] ?? type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedTransferType = value);
                                }
                              },
                              validator: (value) =>
                                  value == null ? 'Please select transfer type' : null,
                            ),
                            SizedBox(height: 16),

                            // Amount field
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                suffixText: _selectedTransferType.startsWith('USD') ? 'USD' : 'ZWG',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter amount';
                                }
                                final amount = double.tryParse(value.trim());
                                if (amount == null || amount <= 0) {
                                  return 'Please enter a valid amount greater than 0';
                                }
                                return null;
                              },
                              onChanged: (value) => setState(() {}), // Refresh display
                            ),
                            SizedBox(height: 16),

                            // Receiving branch dropdown
                            DropdownButtonFormField<Branch>(
                              value: _selectedReceivingBranch,
                              decoration: InputDecoration(
                                labelText: 'Receiving Branch',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              hint: Text('Select receiving branch'),
                              items: _availableBranches.map((branch) {
                                return DropdownMenuItem(
                                  value: branch,
                                  child: Text(branch.branchName),
                                );
                              }).toList(),
                              onChanged: (branch) {
                                setState(() => _selectedReceivingBranch = branch);
                              },
                              validator: (value) =>
                                  value == null ? 'Please select receiving branch' : null,
                            ),
                            SizedBox(height: 16),

                            // Transfer date selector
                            InkWell(
                              onTap: _selectDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Transfer Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Note: Date cannot be more than 2 days ago or in the future',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Create transfer button
                            ElevatedButton.icon(
                              onPressed: _isCreatingTransfer ? null : _createTransfer,
                              icon: _isCreatingTransfer
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(Icons.send),
                              label: Text(_isCreatingTransfer ? 'Creating...' : 'Create Transfer'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Track transfers button
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.track_changes, color: Colors.green),
                      title: Text('Track Transfers'),
                      subtitle: Text('View queued and synced transfers'),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: _navigateToTrackTransfers,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}