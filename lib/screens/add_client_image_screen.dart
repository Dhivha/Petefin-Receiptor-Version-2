import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';

class AddClientImageScreen extends StatefulWidget {
  const AddClientImageScreen({super.key});

  @override
  State<AddClientImageScreen> createState() => _AddClientImageScreenState();
}

class _AddClientImageScreenState extends State<AddClientImageScreen> {
  final ClientService _clientService = ClientService();
  final AuthService _authService = AuthService();

  List<Client> _clients = [];
  bool _isLoading = true;
  bool _isUploading = false;
  Client? _selectedClient;
  Uint8List? _selectedPhotoBytes;
  String? _photoExtension;
  String? _photoPath;
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

  Future<void> _pickPhoto() async {
    try {
      final imageData = await _clientService.pickImageFromGallery();
      if (imageData != null) {
        setState(() {
          _selectedPhotoBytes = imageData['bytes'];
          _photoExtension = imageData['extension'];
          _photoPath = imageData['path'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedPhotoBytes = null;
      _photoExtension = null;
      _photoPath = null;
    });
  }

  Future<void> _uploadPhoto() async {
    if (_selectedClient == null ||
        _selectedPhotoBytes == null ||
        _photoExtension == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a client and photo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await _clientService.uploadClientPhoto(
        clientId: _selectedClient!.clientId,
        photoBytes: _selectedPhotoBytes!,
        photoExtension: _photoExtension!,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );

          // Reset form
          setState(() {
            _selectedClient = null;
            _selectedPhotoBytes = null;
            _photoExtension = null;
            _photoPath = null;
          });

          // Reload clients to get updated data
          _loadClients();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Client Image'),
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
                            onTap: () {
                              setState(() {
                                _selectedClient = isSelected ? null : client;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Photo Section
                  _buildSectionHeader('Select Photo'),
                  const SizedBox(height: 16),
                  _buildPhotoSection(),

                  const SizedBox(height: 32),

                  // Upload Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadPhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Upload Photo',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
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
          if (_selectedPhotoBytes != null) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Change Photo'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _removePhoto,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No photo selected',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
