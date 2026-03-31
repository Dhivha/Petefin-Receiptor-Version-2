import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';
import 'add_receipt_screen.dart';
import 'receipt_detail_screen.dart';
import '../widgets/receipt_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ReceiptService _receiptService = ReceiptService();
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  String? _errorMessage;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReceipts();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final receipts = await _receiptService.getReceipts();
      setState(() {
        _receipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        // Show some dummy data for demo purposes when API is not available
        _receipts = _getDummyReceipts();
      });
    }
  }

  List<Receipt> _getDummyReceipts() {
    return [
      Receipt(
        id: '1',
        title: 'Office Supplies',
        amount: 45.99,
        description: 'Pens, paper, and notebooks for the office',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: ReceiptStatus.pending,
        category: 'Office',
      ),
      Receipt(
        id: '2',
        title: 'Lunch Meeting',
        amount: 89.50,
        description: 'Client lunch at The Garden Restaurant',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        status: ReceiptStatus.approved,
        category: 'Meals',
      ),
      Receipt(
        id: '3',
        title: 'Taxi Fare',
        amount: 25.00,
        description: 'Trip to airport for business travel',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        status: ReceiptStatus.processing,
        category: 'Transport',
      ),
    ];
  }

  List<Receipt> _getReceiptsByStatus(ReceiptStatus status) {
    return _receipts.where((receipt) => receipt.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petefin ZWG Receiptor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.receipt)),
            Tab(text: 'Pending', icon: Icon(Icons.schedule)),
            Tab(text: 'Approved', icon: Icon(Icons.check_circle)),
            Tab(text: 'Processing', icon: Icon(Icons.hourglass_empty)),
          ],
        ),
      ),
      body: Column(
        children: [
          // API Status Indicator
          _buildApiStatusBanner(),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReceiptList(_receipts),
                      _buildReceiptList(
                        _getReceiptsByStatus(ReceiptStatus.pending),
                      ),
                      _buildReceiptList(
                        _getReceiptsByStatus(ReceiptStatus.approved),
                      ),
                      _buildReceiptList(
                        _getReceiptsByStatus(ReceiptStatus.processing),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddReceipt(),
        tooltip: 'Add Receipt',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildApiStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _errorMessage != null
          ? Colors.orange.withOpacity(0.1)
          : Colors.green.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            _errorMessage != null ? Icons.warning : Icons.cloud_done,
            color: _errorMessage != null ? Colors.orange : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage != null
                  ? 'Using demo data - API: ${_receiptService.getCurrentApiUrl()}'
                  : 'Connected to: ${_receiptService.getCurrentApiUrl()}',
              style: TextStyle(
                fontSize: 12,
                color: _errorMessage != null
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
          if (_errorMessage != null)
            TextButton(
              onPressed: _loadReceipts,
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptList(List<Receipt> receipts) {
    if (receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No receipts found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first receipt',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReceipts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: receipts.length,
        itemBuilder: (context, index) {
          final receipt = receipts[index];
          return ReceiptCard(
            receipt: receipt,
            onTap: () => _navigateToReceiptDetail(receipt),
            onDelete: () => _deleteReceipt(receipt),
          );
        },
      ),
    );
  }

  void _navigateToAddReceipt() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddReceiptScreen()),
    );

    if (result == true) {
      _loadReceipts();
    }
  }

  void _navigateToReceiptDetail(Receipt receipt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailScreen(receiptId: receipt.id),
      ),
    );

    if (result == true) {
      _loadReceipts();
    }
  }

  void _deleteReceipt(Receipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: Text('Are you sure you want to delete "${receipt.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _receiptService.deleteReceipt(receipt.id);
        _loadReceipts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete receipt: $e')),
          );
        }
      }
    }
  }
}
