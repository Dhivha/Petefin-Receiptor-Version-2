import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import 'add_client_screen.dart';
import 'add_client_image_screen.dart';
import 'view_client_photo_screen.dart';
import 'collateral_submission_screen.dart';

class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen>
    with SingleTickerProviderStateMixin {
  final ClientService _clientService = ClientService();

  late TabController _tabController;
  List<Map<String, dynamic>> _queuedClients = [];
  List<Client> _syncedClients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queuedClients = await _clientService.getQueuedClients();
      final syncedClients = await _clientService.getSyncedClients();

      setState(() {
        _queuedClients = queuedClients;
        _syncedClients = syncedClients;
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

  Future<void> _deleteQueuedClient(String clientId, String clientName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete "$clientName"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _clientService.deleteQueuedClient(clientId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Client deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Refresh the list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete client'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddClient() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddClientScreen()));

    if (result == true) {
      _loadData(); // Refresh if client was added
    }
  }

  Future<void> _navigateToAddClientImage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddClientImageScreen()),
    );
    _loadData(); // Refresh in case photos were updated
  }

  Future<void> _navigateToViewPhoto() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ViewClientPhotoScreen()),
    );
  }

  Future<void> _navigateToCollateralSubmission() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CollateralSubmissionScreen()),
    );
    
    if (result == true) {
      _loadData(); // Refresh in case new submissions were created
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Management'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Queued (${_queuedClients.length})',
              icon: const Icon(Icons.queue),
            ),
            Tab(
              text: 'Synced (${_syncedClients.length})',
              icon: const Icon(Icons.cloud_done),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToAddClient,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToAddClientImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Client Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToViewPhoto,
                        icon: const Icon(Icons.photo),
                        label: const Text('View Client Photos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToCollateralSubmission,
                        icon: const Icon(Icons.description),
                        label: const Text('Collateral Submission'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildQueuedClientsTab(),
                      _buildSyncedClientsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuedClientsTab() {
    if (_queuedClients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No queued clients',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Clients created offline will appear here until synced',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _queuedClients.length,
      itemBuilder: (context, index) {
        final client = _queuedClients[index];
        final syncAttempts = client['syncAttempts'] as int? ?? 0;
        final syncError = client['syncError'] as String?;
        final lastSyncAttempt = client['lastSyncAttempt'] as int?;

        String statusText = 'Queued for sync';
        Color statusColor = Colors.blue;
        IconData statusIcon = Icons.schedule;

        if (syncAttempts > 0) {
          if (syncError != null) {
            statusText = 'Sync failed ($syncAttempts attempts)';
            statusColor = Colors.red;
            statusIcon = Icons.error;
          } else {
            statusText = 'Syncing... ($syncAttempts attempts)';
            statusColor = Colors.orange;
            statusIcon = Icons.sync;
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Text(
                '${client['firstName']?[0] ?? ''}${client['lastName']?[0] ?? ''}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              client['fullName'] ?? 'Unknown Client',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: ${client['whatsAppContact'] ?? 'N/A'}'),
                Text('National ID: ${client['nationalIdNumber'] ?? 'N/A'}'),
                Text('Branch: ${client['branch'] ?? 'N/A'}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (syncError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Error: $syncError',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  ),
                ],
                if (lastSyncAttempt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last attempt: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(lastSyncAttempt))}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              onPressed: () => _deleteQueuedClient(
                client['clientId'] as String,
                client['fullName'] as String? ?? 'Unknown Client',
              ),
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete client',
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncedClientsTab() {
    if (_syncedClients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_done, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No synced clients',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Successfully synced clients will appear here for 24 hours',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _syncedClients.length,
      itemBuilder: (context, index) {
        final client = _syncedClients[index];
        final timeSinceSync = client.lastSynced != null
            ? DateTime.now().difference(client.lastSynced!)
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.2),
              child: Text(
                '${client.firstName[0]}${client.lastName[0]}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              client.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${client.clientId}'),
                Text('Phone: ${client.whatsAppContact}'),
                Text('Branch: ${client.branch}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Synced${timeSinceSync != null ? ' ${_formatDuration(timeSinceSync)} ago' : ''}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (client.photo != null) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.photo, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        'Has photo',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'just now';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m';
    } else if (duration.inDays < 1) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inDays}d';
    }
  }
}
