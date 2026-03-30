import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/bluetooth_receipt_service.dart';
import '../models/client.dart';
import '../models/admin_fee.dart';
import '../models/fcb_receipt.dart';
import '../models/receipt_number.dart';

class AdminReceiptsScreen extends StatefulWidget {
  const AdminReceiptsScreen({super.key});

  @override
  State<AdminReceiptsScreen> createState() => _AdminReceiptsScreenState();
}

class _AdminReceiptsScreenState extends State<AdminReceiptsScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  late TabController _mainTabController;
  late TabController _adminTabController;
  late TabController _fcbTabController;

  // Client selection
  List<Client> _clients = [];
  Client? _selectedClient;
  bool _isLoadingClients = false;
  bool _useManualEntry = false;

  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Focus nodes for better navigation
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  // Auto receipt number (no manual selection)
  ReceiptNumber? _nextReceiptNumber;

  // State
  bool _isProcessing = false;

  // Lists for displaying data
  List<AdminFee> _queuedAdminFees = [];
  List<AdminFee> _syncedAdminFees = [];
  List<AdminFee> _cancelledAdminFees = [];
  List<FCBReceipt> _queuedFCBReceipts = [];
  List<FCBReceipt> _syncedFCBReceipts = [];
  List<FCBReceipt> _cancelledFCBReceipts = [];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _adminTabController = TabController(length: 3, vsync: this);
    _fcbTabController = TabController(length: 3, vsync: this);
    
    _loadClients();
    _loadNextReceiptNumber();
    _loadAllData();
    
    // Auto-sync pending cancellations on startup
    _syncPendingCancellations();
    
    // Set FCB amount to 1.00 by default
    _amountController.text = '1.00';
    
    _mainTabController.addListener(() {
      if (_mainTabController.index == 1) {
        // FCB tab - set amount to 1.00
        _amountController.text = '1.00';
      } else {
        // Admin tab - clear amount
        _amountController.clear();
      }
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _adminTabController.dispose();
    _fcbTabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    _amountFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoadingClients = true;
    });

    try {
      final clients = await _authService.getLocalClients();
      setState(() {
        _clients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  Future<void> _loadNextReceiptNumber() async {
    try {
      final receipts = await _authService.getUnusedReceiptNumbers();
      setState(() {
        _nextReceiptNumber = receipts.isNotEmpty ? receipts.first : null;
      });
    } catch (e) {
      print('Error loading receipt number: $e');
    }
  }

  Future<void> _loadAllData() async {
    // TODO: Load queued, synced, and cancelled admin fees and FCB receipts
    // This would typically come from your local database or API
  }

  void _onClientSelected(Client client) {
    setState(() {
      _selectedClient = client;
      _firstNameController.text = client.firstName ?? '';
      _lastNameController.text = client.lastName ?? '';
      _useManualEntry = false;
    });
    
    print('Selected client: ${client.firstName} ${client.lastName}');
    
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${client.fullName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Auto focus on amount field after short delay (if Admin tab)
    if (_mainTabController.index == 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _amountFocusNode.requestFocus();
      });
    }
  }

  void _toggleManualEntry() {
    setState(() {
      _useManualEntry = !_useManualEntry;
      _selectedClient = null;
      _searchController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      
      if (_useManualEntry) {
        // Enable text fields for manual entry
        print('Manual entry enabled');
      } else {
        // Clear and prepare for client selection
        print('Client selection mode enabled');
      }
    });
  }

  Future<void> _processAdminFee() async {
    if (!_validateForm()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final adminFee = AdminFee(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateTimeCaptured: DateTime.now(),
        amount: double.parse(_amountController.text.trim()),
        receiptNumber: _nextReceiptNumber!.receiptNum,
        barcode: 'ADM-${_nextReceiptNumber!.receiptNum}',
        branch: _authService.currentUser?.branch,
      );

      // OFFLINE-FIRST: Add to queued list immediately
      setState(() {
        _queuedAdminFees.add(adminFee);
      });
      
      // Print receipt immediately (offline-first)
      BluetoothReceiptService.autoPrintAdminFeeReceipt(adminFee);
      
      // Mark receipt number as used
      await _authService.markReceiptNumberAsUsed(_nextReceiptNumber!.receiptNum);
      
      // Show success message (always successful offline)
      _showSuccessDialog('Admin Fee Receipt', adminFee.receiptNumber);
      
      // Reset form and load new receipt number
      _resetForm();
      await _loadNextReceiptNumber();
      
      // Try to sync in background without blocking user
      _syncAdminFeeInBackground(adminFee);
      
    } catch (e) {
      _showErrorMessage('Error processing admin fee: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processFCBReceipt() async {
    if (!_validateForm()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final fcbReceipt = FCBReceipt(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateTimeCaptured: DateTime.now(),
        amount: 1.0, // Always 1.00 for FCB
        receiptNumber: _nextReceiptNumber!.receiptNum,
        barcode: 'FCB-${_nextReceiptNumber!.receiptNum}',
        branch: _authService.currentUser?.branch,
      );

      // OFFLINE-FIRST: Add to queued list immediately
      setState(() {
        _queuedFCBReceipts.add(fcbReceipt);
      });
      
      // Print receipt immediately (offline-first)
      BluetoothReceiptService.autoPrintFCBReceipt(fcbReceipt);
      
      // Mark receipt number as used
      await _authService.markReceiptNumberAsUsed(_nextReceiptNumber!.receiptNum);
      
      // Show success message (always successful offline)
      _showSuccessDialog('FCB Receipt', fcbReceipt.receiptNumber);
      
      // Reset form and load new receipt number
      _resetForm();
      await _loadNextReceiptNumber();
      
      // Try to sync in background without blocking user
      _syncFCBReceiptInBackground(fcbReceipt);
      
    } catch (e) {
      _showErrorMessage('Error processing FCB receipt: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  bool _validateForm() {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      _showErrorMessage('Please enter first name and last name');
      return false;
    }

    if (_mainTabController.index == 0 && _amountController.text.trim().isEmpty) {
      _showErrorMessage('Please enter amount for admin fee');
      return false;
    }

    // Barcode validation removed

    if (_nextReceiptNumber == null) {
      _showErrorMessage('No receipt number available');
      return false;
    }

    return true;
  }

  void _resetForm() {
    setState(() {
      _selectedClient = null;
      _useManualEntry = false;
    });
    _firstNameController.clear();
    _lastNameController.clear();
    _amountController.clear();
    
    // Set FCB amount back to 1.00 if on FCB tab
    if (_mainTabController.index == 1) {
      _amountController.text = '1.00';
    }
  }

  void _showSuccessDialog(String receiptType, String receiptNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$receiptType Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('Receipt Number: $receiptNumber'),
            const SizedBox(height: 8),
            const Text('Receipt has been auto-printed!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<Client> _getFilteredClients() {
    if (_clients.isEmpty) return [];
    
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return List.from(_clients); // Return a copy to avoid modification issues
    }
    
    try {
      return _clients.where((client) {
        final fullName = client.fullName.toLowerCase();
        final clientId = client.clientId.toLowerCase();
        return fullName.contains(query) || clientId.contains(query);
      }).toList();
    } catch (e) {
      print('Error filtering clients: $e');
      return List.from(_clients); // Return all clients if filtering fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin & FCB Receipts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Main Tab Bar (Admin vs FCB)
          Container(
            color: Colors.blue,
            child: TabBar(
              controller: _mainTabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Admin Fees'),
                Tab(text: 'FCB Receipts'),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                _buildAdminFeesTab(),
                _buildFCBReceiptsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAdminFeesTab() {
    return Column(
      children: [
        // Sub tabs for Admin (Queued/Synced/Cancelled)
        Container(
          color: Colors.grey[200],
          child: TabBar(
            controller: _adminTabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Queued'),
              Tab(text: 'Synced'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        
        Expanded(
          child: TabBarView(
            controller: _adminTabController,
            children: [
              _buildQueuedAdminFees(),
              _buildSyncedAdminFees(),
              _buildCancelledAdminFees(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFCBReceiptsTab() {
    return Column(
      children: [
        // Sub tabs for FCB (Queued/Synced/Cancelled)
        Container(
          color: Colors.grey[200],
          child: TabBar(
            controller: _fcbTabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Queued'),
              Tab(text: 'Synced'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        
        Expanded(
          child: TabBarView(
            controller: _fcbTabController,
            children: [
              _buildQueuedFCBReceipts(),
              _buildSyncedFCBReceipts(),
              _buildCancelledFCBReceipts(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQueuedAdminFees() {
    return ListView.builder(
      itemCount: _queuedAdminFees.length,
      itemBuilder: (context, index) {
        final fee = _queuedAdminFees[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('${fee.firstName} ${fee.lastName}'),
            subtitle: Text('Amount: \$${fee.amount.toStringAsFixed(2)}'),
            trailing: Text(fee.receiptNumber),
          ),
        );
      },
    );
  }

  Widget _buildSyncedAdminFees() {
    return ListView.builder(
      itemCount: _syncedAdminFees.length,
      itemBuilder: (context, index) {
        final fee = _syncedAdminFees[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('${fee.firstName} ${fee.lastName}'),
            subtitle: Text('Amount: \$${fee.amount.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fee.receiptNumber),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _cancelAdminFee(fee),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCancelledAdminFees() {
    return ListView.builder(
      itemCount: _cancelledAdminFees.length,
      itemBuilder: (context, index) {
        final fee = _cancelledAdminFees[index];
        return Card(
          margin: const EdgeInsets.all(8),
          color: Colors.red[50],
          child: ListTile(
            title: Text('${fee.firstName} ${fee.lastName}'),
            subtitle: Text('Amount: \$${fee.amount.toStringAsFixed(2)}'),
            trailing: Text(fee.receiptNumber),
          ),
        );
      },
    );
  }

  Widget _buildQueuedFCBReceipts() {
    return ListView.builder(
      itemCount: _queuedFCBReceipts.length,
      itemBuilder: (context, index) {
        final receipt = _queuedFCBReceipts[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('${receipt.firstName} ${receipt.lastName}'),
            subtitle: const Text('Amount: \$1.00'),
            trailing: Text(receipt.receiptNumber),
          ),
        );
      },
    );
  }

  Widget _buildSyncedFCBReceipts() {
    return ListView.builder(
      itemCount: _syncedFCBReceipts.length,
      itemBuilder: (context, index) {
        final receipt = _syncedFCBReceipts[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('${receipt.firstName} ${receipt.lastName}'),
            subtitle: const Text('Amount: \$1.00'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(receipt.receiptNumber),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _cancelFCBReceipt(receipt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCancelledFCBReceipts() {
    return ListView.builder(
      itemCount: _cancelledFCBReceipts.length,
      itemBuilder: (context, index) {
        final receipt = _cancelledFCBReceipts[index];
        return Card(
          margin: const EdgeInsets.all(8),
          color: Colors.red[50],
          child: ListTile(
            title: Text('${receipt.firstName} ${receipt.lastName}'),
            subtitle: const Text('Amount: \$1.00'),
            trailing: Text(receipt.receiptNumber),
          ),
        );
      },
    );
  }

  void _showCreateDialog() {
    _resetForm();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.maxFinite,
          height: 650,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create ${_mainTabController.index == 0 ? 'Admin Fee' : 'FCB'} Receipt',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: _buildCreateForm(),
              ),
              
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : () {
                      Navigator.pop(context);
                      if (_mainTabController.index == 0) {
                        _processAdminFee();
                      } else {
                        _processFCBReceipt();
                      }
                    },
                    child: _isProcessing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Create Receipt'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Printer status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BluetoothReceiptService.isConnected ? Colors.green[50] : Colors.red[50],
              border: Border.all(
                color: BluetoothReceiptService.isConnected ? Colors.green : Colors.red,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  BluetoothReceiptService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: BluetoothReceiptService.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  BluetoothReceiptService.isConnected ? 'Printer Connected' : 'No Printer Connected',
                  style: TextStyle(
                    color: BluetoothReceiptService.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Receipt number (auto)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Receipt Number: ${_nextReceiptNumber?.receiptNum ?? 'Loading...'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Manual entry toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _useManualEntry ? Colors.orange[50] : Colors.blue[50],
              border: Border.all(
                color: _useManualEntry ? Colors.orange : Colors.blue,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _useManualEntry,
                  onChanged: (value) {
                    _toggleManualEntry();
                  },
                  activeColor: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _useManualEntry ? 'MANUAL ENTRY MODE' : 'CLIENT SELECTION MODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _useManualEntry ? Colors.orange : Colors.blue,
                        ),
                      ),
                      Text(
                        _useManualEntry 
                          ? 'Enter names manually (non-client)'
                          : 'Select from existing clients',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Client selection
          if (!_useManualEntry) ...[
            _buildClientSelection(),
            const SizedBox(height: 20),
          ],

          // Name fields
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _useManualEntry ? Colors.white : Colors.grey[100],
                  ),
                  enabled: _useManualEntry,
                  style: TextStyle(
                    color: _useManualEntry ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name *',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: _useManualEntry ? Colors.white : Colors.grey[100],
                  ),
                  enabled: _useManualEntry,
                  style: TextStyle(
                    color: _useManualEntry ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount field
          TextFormField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            decoration: InputDecoration(
              labelText: _mainTabController.index == 0 ? 'Amount *' : 'Amount (Fixed)',
              border: const OutlineInputBorder(),
              prefixText: '\$',
            ),
            keyboardType: TextInputType.number,
            enabled: _mainTabController.index == 0, // Only enabled for Admin fees
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 16),

          // Note: Barcode removed per user request
        ],
      ),
    );
  }

  Widget _buildClientSelection() {
    final filteredClients = _getFilteredClients();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: const InputDecoration(
            labelText: 'Search Clients',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
            hintText: 'Type name or ID to search...',
          ),
          onChanged: (value) {
            setState(() {}); // Trigger rebuild to filter clients
          },
        ),
        const SizedBox(height: 8),
        
        // Show selected client info prominently
        if (_selectedClient != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'SELECTED CLIENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Name: ${_selectedClient!.fullName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'ID: ${_selectedClient!.clientId}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedClient = null;
                      _searchController.clear();
                      _firstNameController.clear();
                      _lastNameController.clear();
                    });
                    // Refocus on search field
                    _searchFocusNode.requestFocus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear Selection'),
                ),
              ],
            ),
          ),
        
        if (_selectedClient == null) ...[
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingClients
                ? const Center(child: CircularProgressIndicator())
                : filteredClients.isEmpty
                    ? const Center(
                        child: Text(
                          'No clients found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          if (index >= filteredClients.length) {
                            return const SizedBox(); // Safety check
                          }
                          
                          final client = filteredClients[index];
                          
                          return ListTile(
                            dense: true,
                            title: Text(
                              client.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('ID: ${client.clientId}'),
                            onTap: () => _onClientSelected(client),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          );
                        },
                      ),
          ),
        ],
      ],
    );
  }

  // Cancel methods for testing cancellation functionality
  void _cancelAdminFee(AdminFee fee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Admin Fee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel receipt ${fee.receiptNumber}?'),
            const SizedBox(height: 16),
            TextFormField(
              controller: TextEditingController(),
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _cancellationReason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processAdminCancellation(fee);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _cancelFCBReceipt(FCBReceipt receipt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel FCB Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel receipt ${receipt.receiptNumber}?'),
            const SizedBox(height: 16),
            TextFormField(
              controller: TextEditingController(),
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _cancellationReason = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processFCBCancellation(receipt);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String _cancellationReason = '';

  Future<void> _processAdminCancellation(AdminFee fee) async {
    try {
      final cancellationData = {
        "Branch": _authService.currentUser?.branch ?? "",
        "ReceiptNumber": fee.receiptNumber,
        "DateOfPayment": fee.dateTimeCaptured.toIso8601String(),
        "CancelledBy": "${_authService.currentUser?.firstName} ${_authService.currentUser?.lastName}",
        "Reason": _cancellationReason.isEmpty ? "No reason provided" : _cancellationReason,
        "Amount": fee.amount,
      };

      // Try to cancel online first
      try {
        final response = await _apiService.postCancelledAdminReceipt(cancellationData);
        
        if (response.statusCode == 200) {
          // Success - move to cancelled
          setState(() {
            _syncedAdminFees.remove(fee);
            _cancelledAdminFees.add(fee);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully cancelled ${fee.receiptNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // API error - store for offline sync
          await _storePendingCancellation('admin', cancellationData);
          _showOfflineCancellationMessage(fee.receiptNumber);
        }
      } catch (e) {
        // Network error - store for offline sync
        await _storePendingCancellation('admin', cancellationData);
        _showOfflineCancellationMessage(fee.receiptNumber);
      }
      
    } catch (e) {
      _showErrorMessage('Error cancelling receipt: $e');
    }
  }

  Future<void> _processFCBCancellation(FCBReceipt receipt) async {
    try {
      final cancellationData = {
        "Branch": _authService.currentUser?.branch ?? "",
        "ReceiptNumber": receipt.receiptNumber,
        "DateOfPayment": receipt.dateTimeCaptured.toIso8601String(),
        "CancelledBy": "${_authService.currentUser?.firstName} ${_authService.currentUser?.lastName}",
        "Reason": _cancellationReason.isEmpty ? "No reason provided" : _cancellationReason,
        "Amount": receipt.amount,
      };

      // Try to cancel online first
      try {
        final response = await _apiService.postCancelledAdminReceipt(cancellationData);
        
        if (response.statusCode == 200) {
          // Success - move to cancelled
          setState(() {
            _syncedFCBReceipts.remove(receipt);
            _cancelledFCBReceipts.add(receipt);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully cancelled ${receipt.receiptNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // API error - store for offline sync
          await _storePendingCancellation('fcb', cancellationData);
          _showOfflineCancellationMessage(receipt.receiptNumber);
        }
      } catch (e) {
        // Network error - store for offline sync
        await _storePendingCancellation('fcb', cancellationData);
        _showOfflineCancellationMessage(receipt.receiptNumber);
      }
      
    } catch (e) {
      _showErrorMessage('Error cancelling receipt: $e');
    }
  }

  Future<void> _storePendingCancellation(String type, Map<String, dynamic> data) async {
    // Store in AuthService pending cancellations
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = 'pending_cancellations_$type';
    final existing = prefs.getStringList(pendingKey) ?? [];
    existing.add(json.encode(data));
    await prefs.setStringList(pendingKey, existing);
    
    // Start background sync
    _syncPendingCancellations();
  }

  void _showOfflineCancellationMessage(String receiptNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt $receiptNumber cancelled offline. Will sync when online.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _syncPendingCancellations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sync admin cancellations
      final pendingAdmin = prefs.getStringList('pending_cancellations_admin') ?? [];
      final remainingAdmin = <String>[];
      
      for (final cancellationJson in pendingAdmin) {
        try {
          final data = json.decode(cancellationJson);
          final response = await _apiService.cancelAdminReceipt(data);
          
          if (response.statusCode != 200) {
            remainingAdmin.add(cancellationJson); // Keep for retry
          }
        } catch (e) {
          remainingAdmin.add(cancellationJson); // Keep for retry
        }
      }
      
      await prefs.setStringList('pending_cancellations_admin', remainingAdmin);
      
      // Sync FCB cancellations
      final pendingFCB = prefs.getStringList('pending_cancellations_fcb') ?? [];
      final remainingFCB = <String>[];
      
      for (final cancellationJson in pendingFCB) {
        try {
          final data = json.decode(cancellationJson);
          final response = await _apiService.cancelFCBReceipt(data);
          
          if (response.statusCode != 200) {
            remainingFCB.add(cancellationJson); // Keep for retry
          }
        } catch (e) {
          remainingFCB.add(cancellationJson); // Keep for retry
        }
      }
      
      await prefs.setStringList('pending_cancellations_fcb', remainingFCB);
      
    } catch (e) {
      print('Error syncing pending cancellations: $e');
    }
  }

  /// Sync admin fee in background without blocking UI
  Future<void> _syncAdminFeeInBackground(AdminFee adminFee) async {
    try {
      print('🔄 Background sync: Admin fee ${adminFee.receiptNumber}');
      
      // Try to sync to API
      final response = await _apiService.postAdminFeesReceipt(adminFee.toJson());
      
      if (response.statusCode == 200) {
        // Success - move from queued to synced
        if (mounted) {
          setState(() {
            _queuedAdminFees.removeWhere((fee) => fee.receiptNumber == adminFee.receiptNumber);
            _syncedAdminFees.add(adminFee);
          });
        }
        print('✅ Background sync successful: Admin fee ${adminFee.receiptNumber}');
      } else {
        print('❌ Background sync failed: Admin fee ${adminFee.receiptNumber}');
        // Stay in queued list for retry
      }
    } catch (e) {
      print('❌ Background sync error: Admin fee ${adminFee.receiptNumber} - $e');
      // Stay in queued list for retry
    }
  }

  /// Sync FCB receipt in background without blocking UI
  Future<void> _syncFCBReceiptInBackground(FCBReceipt fcbReceipt) async {
    try {
      print('🔄 Background sync: FCB receipt ${fcbReceipt.receiptNumber}');
      
      // Try to sync to API
      final response = await _apiService.postFCBReceipt(fcbReceipt.toJson());
      
      if (response.statusCode == 200) {
        // Success - move from queued to synced
        if (mounted) {
          setState(() {
            _queuedFCBReceipts.removeWhere((receipt) => receipt.receiptNumber == fcbReceipt.receiptNumber);
            _syncedFCBReceipts.add(fcbReceipt);
          });
        }
        print('✅ Background sync successful: FCB receipt ${fcbReceipt.receiptNumber}');
      } else {
        print('❌ Background sync failed: FCB receipt ${fcbReceipt.receiptNumber}');
        // Stay in queued list for retry
      }
    } catch (e) {
      print('❌ Background sync error: FCB receipt ${fcbReceipt.receiptNumber} - $e');
      // Stay in queued list for retry
    }
  }
}