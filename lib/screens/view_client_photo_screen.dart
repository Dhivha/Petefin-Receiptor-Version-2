import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';

class ViewClientPhotoScreen extends StatefulWidget {
  const ViewClientPhotoScreen({super.key});

  @override
  State<ViewClientPhotoScreen> createState() => _ViewClientPhotoScreenState();
}

class _ViewClientPhotoScreenState extends State<ViewClientPhotoScreen> {
  final ClientService _clientService = ClientService();

  List<Client> _clients = [];
  bool _isLoading = true;
  bool _isLoadingPhoto = false;
  Client? _selectedClient;
  String? _photoUrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await _clientService.getSyncedClients();
      setState(() {
        _clients = clients;
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

  Future<void> _loadClientPhoto(Client client) async {
    setState(() {
      _selectedClient = client;
      _isLoadingPhoto = true;
      _photoUrl = null;
    });

    try {
      final photoUrl = await _clientService.getClientPhotoUrl(client.clientId);
      setState(() {
        _photoUrl = photoUrl;
        _isLoadingPhoto = false;
      });

      if (photoUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No photo found for this client'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingPhoto = false;
        _photoUrl = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Client> get _filteredClients {
    if (_searchQuery.isEmpty) {
      return _clients;
    }
    return _clients.where((client) {
      final query = _searchQuery.toLowerCase();
      return client.fullName.toLowerCase().contains(query) ||
          client.clientId.toLowerCase().contains(query) ||
          client.whatsAppContact.toLowerCase().contains(query) ||
          client.nationalIdNumber.toLowerCase().contains(query);
    }).toList();
  }

  void _showFullScreenPhoto() {
    if (_photoUrl != null && _selectedClient != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenPhotoView(
            photoUrl: _photoUrl!,
            clientName: _selectedClient!.fullName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Client Photo'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Section
                  _buildSectionHeader('Select Client'),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Clients',
                      hintText: 'Search by name, ID, or phone',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Client Selection
                  if (_filteredClients.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No clients found'
                            : 'No clients match your search',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ] else ...[
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          final isSelected =
                              _selectedClient?.clientId == client.clientId;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blue.shade50,
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade300,
                              child: Text(
                                client.fullName
                                    .split(' ')
                                    .map(
                                      (name) => name.isNotEmpty ? name[0] : '',
                                    )
                                    .join(''),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              client.fullName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${client.clientId}'),
                                Text('Phone: ${client.whatsAppContact}'),
                                Text('Branch: ${client.branch}'),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.blue.shade600,
                                  )
                                : null,
                            onTap: () => _loadClientPhoto(client),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Photo Display Section
                  if (_selectedClient != null) ...[
                    _buildSectionHeader('Client Photo'),
                    const SizedBox(height: 16),
                    _buildPhotoSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade600,
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Client Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedClient!.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Client ID: ${_selectedClient!.clientId}'),
                Text('Phone: ${_selectedClient!.whatsAppContact}'),
                Text('Branch: ${_selectedClient!.branch}'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Photo Display
          if (_isLoadingPhoto) ...[
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          ] else if (_photoUrl != null) ...[
            GestureDetector(
              onTap: _showFullScreenPhoto,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _photoUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 48, color: Colors.red),
                            SizedBox(height: 8),
                            Text('Failed to load photo'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showFullScreenPhoto,
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('View Full Screen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No photo available for this client',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullScreenPhotoView extends StatelessWidget {
  final String photoUrl;
  final String clientName;

  const _FullScreenPhotoView({
    required this.photoUrl,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(clientName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            photoUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load photo',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
