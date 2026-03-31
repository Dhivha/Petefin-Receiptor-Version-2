import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import '../services/collateral_submission_service.dart';

class CollateralSubmissionScreen extends StatefulWidget {
  const CollateralSubmissionScreen({super.key});

  @override
  State<CollateralSubmissionScreen> createState() => _CollateralSubmissionScreenState();
}

class _CollateralSubmissionScreenState extends State<CollateralSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientService _clientService = ClientService();
  final CollateralSubmissionService _submissionService = CollateralSubmissionService();

  // Form controllers
  final TextEditingController _clientSearchController = TextEditingController();
  
  // Form data
  Client? _selectedClient;
  DateTime? _disbursementStartDate;
  DateTime? _disbursementEndDate;
  List<Map<String, dynamic>> _selectedImages = [];

  // UI state
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<Client> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      await _clientService.getSyncedClients();
    } catch (e) {
      print('Error loading clients: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchClients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    try {
      final allClients = await _clientService.getSyncedClients();
      final results = allClients.where((client) {
        final fullName = client.fullName.toLowerCase();
        final nationalId = client.nationalIdNumber.toLowerCase();
        final searchQuery = query.toLowerCase();
        
        return fullName.contains(searchQuery) || 
               nationalId.contains(searchQuery);
      }).take(10).toList();

      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
      });
    } catch (e) {
      print('Error searching clients: $e');
    }
  }

  void _selectClient(Client client) {
    setState(() {
      _selectedClient = client;
      _clientSearchController.text = '${client.fullName} (${client.nationalIdNumber})';
      _showSearchResults = false;
    });
  }

  Future<void> _selectDisbursementStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _disbursementStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Disbursement Start Date',
    );

    if (pickedDate != null) {
      setState(() {
        _disbursementStartDate = pickedDate;
        // Ensure end date is not before start date
        if (_disbursementEndDate != null && _disbursementEndDate!.isBefore(pickedDate)) {
          _disbursementEndDate = pickedDate;
        }
      });
    }
  }

  Future<void> _selectDisbursementEndDate() async {
    final DateTime firstDate = _disbursementStartDate ?? DateTime.now();
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _disbursementEndDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(2030),
      helpText: 'Select Disbursement End Date',
    );

    if (pickedDate != null) {
      setState(() => _disbursementEndDate = pickedDate);
    }
  }

  Future<void> _selectImages() async {
    try {
      final images = await _submissionService.pickImagesFromGallery(maxImages: 10);
      setState(() => _selectedImages = images);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} images selected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitCollateralDocuments() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a client'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _submissionService.submitCollateralDocuments(
        clientId: _selectedClient!.clientId,
        disbursementStartDate: _disbursementStartDate!,
        disbursementEndDate: _disbursementEndDate!,
        images: _selectedImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );

        if (result['success']) {
          // Clear form
          _formKey.currentState?.reset();
          _clientSearchController.clear();
          setState(() {
            _selectedClient = null;
            _disbursementStartDate = null;
            _disbursementEndDate = null;
            _selectedImages = [];
            _showSearchResults = false;
          });

          // Navigate back with success
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collateral Submission'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Client Search Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client Selection',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _clientSearchController,
                            decoration: const InputDecoration(
                              labelText: 'Search Client',
                              hintText: 'Enter client name or national ID',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: _searchClients,
                            validator: (value) {
                              if (_selectedClient == null) {
                                return 'Please select a client';
                              }
                              return null;
                            },
                          ),
                          if (_showSearchResults) ...[
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final client = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(client.fullName),
                                    subtitle: Text('National ID: ${client.nationalIdNumber}\\nBranch: ${client.branch}'),
                                    isThreeLine: true,
                                    onTap: () => _selectClient(client),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (_selectedClient != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Selected: ${_selectedClient!.fullName}',
                                      style: TextStyle(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Disbursement Dates Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disbursement Period',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _selectDisbursementStartDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      _disbursementStartDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_disbursementStartDate!)
                                          : 'Select start date',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _disbursementEndDate == null && _disbursementStartDate == null
                                      ? null
                                      : _selectDisbursementEndDate,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'End Date',
                                      prefixIcon: const Icon(Icons.calendar_today),
                                      border: const OutlineInputBorder(),
                                      enabled: _disbursementStartDate != null,
                                    ),
                                    child: Text(
                                      _disbursementEndDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_disbursementEndDate!)
                                          : 'Select end date',
                                      style: TextStyle(
                                        color: _disbursementStartDate == null 
                                            ? Colors.grey 
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Images Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Collateral Images',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _selectImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Select Images'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedImages.isEmpty)
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: InkWell(
                                onTap: _selectImages,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 40,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to select collateral images\\n(Max 10 images)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Text(
                              '${_selectedImages.length} images selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  final image = _selectedImages[index];
                                  final sizeInKB = (image['size'] as int) / 1024;
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image,
                                          size: 32,
                                          color: Colors.blue.shade600,
                                        ),
                                        Text(
                                          '${sizeInKB.toStringAsFixed(0)}KB',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        Text(
                                          '.${image['extension']}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitCollateralDocuments,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Collateral Documents'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }
}