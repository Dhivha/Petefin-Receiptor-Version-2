import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final ClientService _clientService = ClientService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController(text: '+2637');
  final _emailController = TextEditingController();
  final _nextOfKinNameController = TextEditingController();
  final _nextOfKinContactController = TextEditingController(text: '+2637');
  final _relationshipController = TextEditingController();

  String _selectedGender = 'Male';
  Uint8List? _selectedPhotoBytes;
  String? _photoExtension;
  String? _photoPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nextOfKinNameController.dispose();
    _nextOfKinContactController.dispose();
    _relationshipController.dispose();
    super.dispose();
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

  String _formatPhoneInput(String value) {
    // Ensure the phone always starts with +2637
    if (!value.startsWith('+2637')) {
      return '+2637';
    }
    return value;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _clientService.addClient(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nationalIdNumber: _nationalIdController.text.trim(),
        gender: _selectedGender,
        nextOfKinContact: _nextOfKinContactController.text.trim(),
        nextOfKinName: _nextOfKinNameController.text.trim(),
        relationshipWithNOK: _relationshipController.text.trim(),
        whatsAppContact: _phoneController.text.trim(),
        emailAddress: _emailController.text.trim(),
        photoBytes: _selectedPhotoBytes,
        photoExtension: _photoExtension,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
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
            content: Text('Error adding client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Client'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
                    _buildSectionHeader('Personal Information'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _firstNameController,
                            labelText: 'First Name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'First name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextFormField(
                            controller: _lastNameController,
                            labelText: 'Last Name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Last name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _nationalIdController,
                            labelText: 'National ID Number',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'National ID is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildGenderDropdown()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _phoneController,
                            labelText: 'WhatsApp Contact',
                            keyboardType: TextInputType.phone,
                            onChanged: (value) {
                              final formatted = _formatPhoneInput(value);
                              if (value != formatted) {
                                _phoneController.text = formatted;
                                _phoneController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(offset: formatted.length),
                                    );
                              }
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              if (!_clientService.isValidPhoneNumber(value)) {
                                return 'Please enter a valid Zimbabwe phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextFormField(
                            controller: _emailController,
                            labelText: 'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Next of Kin Information Section
                    _buildSectionHeader('Next of Kin Information'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _nextOfKinNameController,
                            labelText: 'Next of Kin Name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Next of Kin name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextFormField(
                            controller: _nextOfKinContactController,
                            labelText: 'Next of Kin Contact',
                            keyboardType: TextInputType.phone,
                            onChanged: (value) {
                              final formatted = _formatPhoneInput(value);
                              if (value != formatted) {
                                _nextOfKinContactController.text = formatted;
                                _nextOfKinContactController.selection =
                                    TextSelection.fromPosition(
                                      TextPosition(offset: formatted.length),
                                    );
                              }
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Next of Kin contact is required';
                              }
                              if (!_clientService.isValidPhoneNumber(value)) {
                                return 'Please enter a valid Zimbabwe phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _relationshipController,
                      labelText: 'Relationship with Next of Kin',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Relationship is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Photo Section
                    _buildSectionHeader('Photo'),
                    const SizedBox(height: 16),
                    _buildPhotoSection(),

                    const SizedBox(height: 32),

                    // Branch Section (Read-only)
                    _buildSectionHeader('Branch Information'),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Branch: ${_authService.currentUser?.branch ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
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
                                'Add Client',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: 'Gender',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: ['Male', 'Female'].map((gender) {
        return DropdownMenuItem<String>(value: gender, child: Text(gender));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value!;
        });
      },
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
