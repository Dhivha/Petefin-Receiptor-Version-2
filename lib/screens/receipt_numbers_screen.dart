import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/receipt_number.dart';

class ReceiptNumbersScreen extends StatefulWidget {
  const ReceiptNumbersScreen({super.key});

  @override
  State<ReceiptNumbersScreen> createState() => _ReceiptNumbersScreenState();
}

class _ReceiptNumbersScreenState extends State<ReceiptNumbersScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  
  List<ReceiptNumber> _allReceiptNumbers = [];
  List<ReceiptNumber> _filteredUnused = [];
  List<ReceiptNumber> _filteredUsed = [];
  Map<String, int> _stats = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReceiptNumbers();
    _loadStats();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _performSearch();
  }

  Future<void> _loadReceiptNumbers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unusedNumbers = await _authService.getUnusedReceiptNumbers();
      final usedNumbers = await _authService.getUsedReceiptNumbers();
      
      setState(() {
        _allReceiptNumbers = [...unusedNumbers, ...usedNumbers];
        _filteredUnused = unusedNumbers;
        _filteredUsed = usedNumbers;
        _isLoading = false;
      });
      
      _performSearch();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load receipt numbers: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _authService.getReceiptNumbersStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      print('Error loading receipt numbers stats: $e');
    }
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredUnused = _allReceiptNumbers.where((r) => !r.isUsed).toList();
        _filteredUsed = _allReceiptNumbers.where((r) => r.isUsed).toList();
      });
      return;
    }

    setState(() {
      _filteredUnused = _allReceiptNumbers
          .where((r) => !r.isUsed && _matchesSearch(r))
          .toList();
      _filteredUsed = _allReceiptNumbers
          .where((r) => r.isUsed && _matchesSearch(r))
          .toList();
    });
  }

  bool _matchesSearch(ReceiptNumber receiptNumber) {
    final query = _searchQuery.toLowerCase();
    return receiptNumber.receiptNum.toLowerCase().contains(query) ||
           (receiptNumber.allocatedToFullName.toLowerCase().contains(query)) ||
           (receiptNumber.usedByClientName?.toLowerCase().contains(query) ?? false) ||
           (receiptNumber.usedByClientId?.toLowerCase().contains(query) ?? false) ||
           (receiptNumber.allocatedToBranch?.toLowerCase().contains(query) ?? false);
  }

  Future<void> _syncReceiptNumbers({bool forceRefresh = false}) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _authService.syncReceiptNumbers(forceRefresh: forceRefresh);
      
      if (result.success) {
        _showSuccessSnackBar(
          '${result.message}\n${result.newReceiptNumbers} new numbers added\nTotal: ${result.totalReceiptNumbers}',
        );
        await _loadReceiptNumbers();
        await _loadStats();
      } else {
        _showErrorSnackBar(result.message);
      }
    } catch (e) {
      _showErrorSnackBar('Sync failed: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _showSyncOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sync, color: Colors.blue),
              SizedBox(width: 8),
              Text('Sync Receipt Numbers'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose sync option:'),
              SizedBox(height: 16),
              Text(
                '• Incremental: Only new numbers\n• Force Refresh: Replace all numbers',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _syncReceiptNumbers(forceRefresh: false);
              },
              child: const Text('Incremental'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _syncReceiptNumbers(forceRefresh: true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Force Refresh'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Numbers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Unused (${_stats['unused'] ?? 0})',
              icon: const Icon(Icons.inventory_2_outlined),
            ),
            Tab(
              text: 'Used (${_stats['used'] ?? 0})',
              icon: const Icon(Icons.check_circle_outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _showSyncOptions,
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
            tooltip: 'Sync Receipt Numbers',
          ),
          IconButton(
            onPressed: () => _loadReceiptNumbers(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search receipt numbers, names, clients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', _stats['total'] ?? 0, Colors.blue),
                _buildStatItem('Available', _stats['unused'] ?? 0, Colors.green),
                _buildStatItem('Used', _stats['used'] ?? 0, Colors.orange),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUnusedTab(),
                      _buildUsedTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildUnusedTab() {
    if (_filteredUnused.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No unused receipt numbers match your search'
                  : 'No unused receipt numbers available',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _syncReceiptNumbers(),
                icon: const Icon(Icons.sync),
                label: const Text('Sync Receipt Numbers'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceiptNumbers,
      child: ListView.builder(
        itemCount: _filteredUnused.length,
        itemBuilder: (context, index) {
          final receiptNumber = _filteredUnused[index];
          return _buildReceiptNumberCard(receiptNumber, false);
        },
      ),
    );
  }

  Widget _buildUsedTab() {
    if (_filteredUsed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No used receipt numbers match your search'
                  : 'No receipt numbers have been used yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceiptNumbers,
      child: ListView.builder(
        itemCount: _filteredUsed.length,
        itemBuilder: (context, index) {
          final receiptNumber = _filteredUsed[index];
          return _buildReceiptNumberCard(receiptNumber, true);
        },
      ),
    );
  }

  Widget _buildReceiptNumberCard(ReceiptNumber receiptNumber, bool isUsed) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUsed ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                receiptNumber.receiptNum,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isUsed 
                    ? 'Used by ${receiptNumber.usedByClientName ?? 'Unknown'}'
                    : 'Available for ${receiptNumber.allocatedToFullName}',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          isUsed 
              ? '${receiptNumber.formattedUsedAmount} • ${receiptNumber.formattedUsedDate}'
              : '${receiptNumber.allocatedToBranch ?? 'N/A'} • ${receiptNumber.formattedAllocatedDate}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Receipt ID', receiptNumber.id.toString()),
                _buildDetailRow('Receipt Number', receiptNumber.receiptNum),
                const Divider(),
                
                // Allocation Details
                const Text(
                  'Allocation Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Allocated To', receiptNumber.allocatedToFullName),
                _buildDetailRow('Branch', receiptNumber.allocatedToBranch ?? 'N/A'),
                _buildDetailRow('Branch Code', receiptNumber.branchAbbreviation ?? 'N/A'),
                _buildDetailRow('Allocated At', receiptNumber.formattedAllocatedDate),
                
                if (isUsed) ...[
                  const Divider(),
                  const Text(
                    'Usage Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Used By Client', receiptNumber.usedByClientName ?? 'N/A'),
                  _buildDetailRow('Client ID', receiptNumber.usedByClientId ?? 'N/A'),
                  _buildDetailRow('Amount', receiptNumber.formattedUsedAmount),
                  _buildDetailRow('Currency', receiptNumber.currency ?? 'N/A'),
                  _buildDetailRow('Used At', receiptNumber.formattedUsedDate),
                ],
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
            width: 120,
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
}