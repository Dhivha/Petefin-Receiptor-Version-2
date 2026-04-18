import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/client.dart';
import 'client_detail_screen.dart';
import 'downloaded_statements_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = false;
  String _searchQuery = '';

  // Balance cache: key not present = not loaded, null value = failed, double = loaded
  final Map<String, double?> _clientBalances = {};
  final Map<String, List<dynamic>> _loanSummaries = {};
  final Set<String> _loadingBalances = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
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

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await _authService.getLocalClients();
      setState(() {
        _allClients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredClients = _allClients;
      });
      return;
    }

    try {
      final results = await _authService.searchClients(_searchQuery);
      setState(() {
        _filteredClients = results;
      });
    } catch (e) {
      print('Search error: $e');
    }
  }

  Future<void> _refreshClients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.syncClientsForCurrentUser();

      if (result.success) {
        await _loadClients();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showClientDetails(Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client.fullName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Client ID', client.clientId),
              _buildDetailRow('Branch', client.branch),
              _buildDetailRow('WhatsApp', client.whatsAppContact),
              _buildDetailRow(
                'Email',
                client.emailAddress.isEmpty
                    ? 'Not provided'
                    : client.emailAddress,
              ),
              _buildDetailRow('National ID', client.nationalIdNumber),
              _buildDetailRow('Gender', client.gender),
              _buildDetailRow('Next of Kin', client.nextOfKinName),
              _buildDetailRow('NOK Contact', client.nextOfKinContact),
              _buildDetailRow('Relationship', client.relationshipWithNOK),
              _buildDetailRow('PIN', client.pin),
              _buildDetailRow('Captured By', client.capturedBy),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _makePhoneCall(client.whatsAppContact);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.trim();
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open dialer for $cleaned'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openWhatsApp(String phoneNumber) async {
    // Strip spaces and ensure number is clean for wa.me (no + needed in path)
    final cleaned = phoneNumber.trim().replaceAll(' ', '').replaceAll('-', '');
    // wa.me expects number without leading +, but with country code
    final waNumber = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$waNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on this device'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewDisbursements(Client client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClientDetailScreen(client: client),
      ),
    );
  }

  void _viewDownloadedStatements() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DownloadedStatementsScreen(),
      ),
    );
  }

  /// Fetch and cache the client balance from the API (lazy, per-card)
  Future<void> _loadClientBalance(String clientId) async {
    if (_clientBalances.containsKey(clientId)) return;
    if (_loadingBalances.contains(clientId)) return;
    _loadingBalances.add(clientId);
    try {
      final response = await _apiService.getClientBalance(clientId);
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final balance = (data['TotalBalance'] as num?)?.toDouble() ?? 0.0;
        final summaries = (data['LoanSummaries'] as List<dynamic>?) ?? [];
        setState(() {
          _clientBalances[clientId] = balance;
          _loanSummaries[clientId] = summaries;
          _loadingBalances.remove(clientId);
        });
      } else if (mounted) {
        setState(() {
          _clientBalances[clientId] = null;
          _loadingBalances.remove(clientId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _clientBalances[clientId] = null;
          _loadingBalances.remove(clientId);
        });
      }
    }
  }

  /// Download the client statement PDF and save it locally
  Future<void> _downloadClientStatement(Client client) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Downloading statement...')),
          ],
        ),
      ),
    );
    try {
      final response =
          await _apiService.downloadClientStatementPdf(client.clientId);
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final base = await getApplicationDocumentsDirectory();
        final dir = Directory('${base.path}/client_statements');
        if (!await dir.exists()) await dir.create(recursive: true);

        String fileName;
        final cd = response.headers['content-disposition'] ?? '';
        final match =
            RegExp(r'filename[^;=\n]*=([^;\n]*)').firstMatch(cd);
        if (match != null) {
          fileName = match.group(1)!.replaceAll('"', '').trim();
        } else {
          final ts = DateTime.now()
              .toIso8601String()
              .replaceAll(':', '-')
              .substring(0, 19);
          final safeName = client.fullName
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .replaceAll(' ', '_');
          fileName =
              'Statement_${client.clientId}_${safeName}_$ts.pdf';
        }

        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Statement downloaded successfully!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  await OpenFile.open(file.path);
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No loan records found for this client.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Download failed (${response.statusCode}). Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Only pop if dialog is still showing
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }
      final msg = e.toString().toLowerCase().contains('internet') ||
              e.toString().toLowerCase().contains('connection')
          ? 'No internet access. Please connect to the internet to download.'
          : 'Download failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show balance breakdown dialog with per-loan summaries
  void _showBalanceBreakdown(Client client) {
    final summaries = _loanSummaries[client.clientId];
    final balance = _clientBalances[client.clientId];

    if (!_clientBalances.containsKey(client.clientId) || balance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Balance not loaded yet. Please wait a moment and try again.'),
          duration: Duration(seconds: 3),
        ),
      );
      _loadingBalances.remove(client.clientId);
      _clientBalances.remove(client.clientId);
      _loadClientBalance(client.clientId);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(client.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Total Balance: \$${balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: balance >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
        ),
        content: (summaries == null || summaries.isEmpty)
            ? const Text('No loan records found.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: summaries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final loan = summaries[i] as Map<String, dynamic>;
                    final loanBalance =
                        (loan['LoanBalance'] as num?)?.toDouble() ?? 0.0;
                    final product =
                        (loan['ProductName'] as String?)?.isNotEmpty == true
                            ? loan['ProductName'] as String
                            : 'Loan #${loan['LoanId']}';
                    final disbDate = loan['DateOfDisbursement'] != null
                        ? DateTime.tryParse(
                            loan['DateOfDisbursement'] as String)
                        : null;
                    final dateStr = disbDate != null
                        ? '${disbDate.day}/${disbDate.month}/${disbDate.year}'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                if (dateStr.isNotEmpty)
                                  Text(dateStr,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(
                            '\$${loanBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: loanBalance >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Downloaded Statements',
            onPressed: _viewDownloadedStatements,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search clients by name, ID, or phone...',
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
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_filteredClients.length} clients',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      Text(
                        'Filtered results',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Client List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshClients,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredClients.length,
                      itemBuilder: (context, index) {
                        final client = _filteredClients[index];
                        return _buildClientCard(client);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshClients,
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.sync, color: Colors.white),
        tooltip: 'Sync Clients',
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No clients found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No clients available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh or sync clients',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshClients,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildClientCard(Client client) {
    // Lazy-load balance when card is built
    if (!_clientBalances.containsKey(client.clientId) &&
        !_loadingBalances.contains(client.clientId)) {
      _loadClientBalance(client.clientId);
    }

    final double? balance = _clientBalances[client.clientId];
    final bool balanceLoading =
        _loadingBalances.contains(client.clientId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            client.firstName.isNotEmpty
                ? client.firstName[0].toUpperCase()
                : 'C',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          client.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    client.clientId,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    client.branch,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    client.whatsAppContact,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Balance row
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                if (balanceLoading && !_clientBalances.containsKey(client.clientId))
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.grey.shade500),
                  )
                else if (!_clientBalances.containsKey(client.clientId))
                  Text('Balance: --',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500))
                else if (balance == null)
                  Text('Balance: N/A',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500))
                else
                  Text(
                    'Balance: \$${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: balance >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'disbursements':
                _viewDisbursements(client);
                break;
              case 'details':
                _showClientDetails(client);
                break;
              case 'call':
                _makePhoneCall(client.whatsAppContact);
                break;
              case 'whatsapp':
                _openWhatsApp(client.whatsAppContact);
                break;
              case 'download_statement':
                _downloadClientStatement(client);
                break;
              case 'balance_breakdown':
                _showBalanceBreakdown(client);
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'disbursements',
              child: ListTile(
                leading: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.green,
                ),
                title: Text('View Disbursements'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.info, color: Colors.blue),
                title: Text('View Details'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'download_statement',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Download Client Statement'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'balance_breakdown',
              child: ListTile(
                leading: Icon(Icons.bar_chart, color: Colors.purple),
                title: Text('Balance Breakdown'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'call',
              child: ListTile(
                leading: Icon(Icons.phone, color: Colors.orange),
                title: Text('Call'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'whatsapp',
              child: ListTile(
                leading: Icon(Icons.message, color: Colors.green),
                title: Text('WhatsApp'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () => _viewDisbursements(client),
      ),
    );
  }
}
