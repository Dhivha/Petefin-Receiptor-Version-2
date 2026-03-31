import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/auth_service.dart';
import 'repayment_detail_screen.dart';

class RepaymentScreen extends StatefulWidget {
  const RepaymentScreen({super.key});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  final AuthService _authService = AuthService();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      setState(() {
        _isLoading = true;
      });

      _clients = await _authService.getClients();
      _filteredClients = List.from(_clients);

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
            content: Text('Error loading clients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshClients() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final result = await _authService.syncClientsForCurrentUser();
      if (result.success) {
        await _loadClients();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result.message}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Still load local clients even if sync failed
        await _loadClients();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      await _loadClients();
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

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        return client.fullName.toLowerCase().contains(query) ||
            client.clientId.toLowerCase().contains(query) ||
            client.whatsAppContact.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showCurrencyDialog(Client client) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: ${client.fullName}'),
              const SizedBox(height: 16),
              const Text('Choose payment currency:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RepaymentDetailScreen(client: client, currency: 'USD'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'USD (\$)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RepaymentDetailScreen(client: client, currency: 'ZWG'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ZWG',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayments'),
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
            onPressed: _isRefreshing ? null : _refreshClients,
            tooltip: 'Refresh Clients',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Clients list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No clients found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _refreshClients,
                          child: const Text('Tap to refresh'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshClients,
                    child: ListView.builder(
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                client.fullName.isNotEmpty
                                    ? client.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              client.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${client.clientId}'),
                                Text('Phone: ${client.whatsAppContact}'),
                                if (client.nationalIdNumber.isNotEmpty)
                                  Text(
                                    'National ID: ${client.nationalIdNumber}',
                                  ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.payment,
                              color: Colors.green,
                            ),
                            isThreeLine: true,
                            onTap: () => _showCurrencyDialog(client),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
