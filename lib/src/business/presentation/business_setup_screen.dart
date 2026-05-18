import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../data/business_providers.dart';
import '../domain/business.dart';
import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _fssaiController = TextEditingController();
  
  String? _selectedType;
  String? _selectedCity;
  bool _isGstRegistered = false;
  bool _isFssaiRegistered = false;
  File? _logoFile;
  String? _existingLogoUrl;
  bool _isLoading = false;
  bool _isInitialized = false;

  final List<String> _businessTypes = [
    'Cafe',
    'Restaurant',
    'Cafe & Restaurant',
    'Cloud Kitchen',
    'Beverage Bar',
    'Dessert Shop',
    'Other',
  ];

  final List<String> _cities = [
    'Ahmedabad',
    'Mumbai',
    'Delhi',
    'Surat',
    'Pune',
    'Bangalore',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;

    final businessAsync = ref.watch(currentBusinessProvider);

    businessAsync.whenData((business) {
      if (business != null) {
        _isInitialized = true;
        _nameController.text = business.businessName;
        _emailController.text = business.officialEmail;
        _phoneController.text = business.phoneNumber;
        _addressController.text = business.address ?? '';
        _gstController.text = business.gstNumber ?? '';
        _fssaiController.text = business.fssaiNumber ?? '';
        _selectedType = _businessTypes.contains(business.businessType) ? business.businessType : 'Other';
        _selectedCity = _cities.contains(business.city) ? business.city : (business.city != null ? 'Other' : null);
        _isGstRegistered = business.isGstRegistered;
        _isFssaiRegistered = business.isFssaiRegistered;
        _existingLogoUrl = business.logoUrl;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _fssaiController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _logoFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) return;

      final repo = ref.read(businessRepositoryProvider);
      final existingBusiness = ref.read(currentBusinessProvider).value;
      final profile = ref.read(userProfileProvider).value;
      
      String? logoUrl = _existingLogoUrl;
      
      final businessData = Business(
        id: existingBusiness?.id ?? '',
        uin: existingBusiness?.uin ?? '',
        businessName: _nameController.text.trim(),
        ownerName: profile?.displayName ?? 'Owner',
        officialEmail: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        businessType: _selectedType ?? 'Other',
        city: _selectedCity,
        gstNumber: _isGstRegistered ? _gstController.text.trim() : null,
        isFssaiRegistered: _isFssaiRegistered,
        fssaiNumber: _isFssaiRegistered ? _fssaiController.text.trim() : null,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        logoUrl: logoUrl,
        createdAt: existingBusiness?.createdAt ?? DateTime.now(),
      );

      Business finalBusinessData;
      if (existingBusiness == null) {
        finalBusinessData = await repo.createBusiness(uid: user.uid, business: businessData);
      } else {
        finalBusinessData = businessData;
        await repo.updateBusiness(businessData);
      }
      
      if (_logoFile != null) {
        logoUrl = await repo.uploadLogo(finalBusinessData.id, _logoFile!);
        if (logoUrl != null) {
          finalBusinessData = finalBusinessData.copyWith(logoUrl: logoUrl);
          await repo.updateBusiness(finalBusinessData);
        }
      }

      ref.invalidate(userProfileProvider);
      
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting up business: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewSetup = ref.watch(currentBusinessProvider).value == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewSetup ? 'Business Setup' : 'Edit Business'),
        automaticallyImplyLeading: !isNewSetup,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to TSP Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up your business identity to get started with reports and invoices.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              // Logo Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: _logoFile != null
                          ? FileImage(_logoFile!)
                          : (_existingLogoUrl != null ? NetworkImage(_existingLogoUrl!) : null) as ImageProvider?,
                      child: _logoFile == null && _existingLogoUrl == null
                          ? const Icon(Icons.business, size: 40, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Business Logo (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name*',
                  hintText: 'e.g. Slow Pour Coffee',
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Official Business Email*',
                  hintText: 'contact@business.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) return 'Invalid email format';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number*',
                  hintText: '10-digit mobile number',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 10) return 'Invalid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Business Type*'),
                items: _businessTypes
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: const InputDecoration(
                  labelText: 'Business City*',
                  hintText: 'Select city for UIN generation',
                ),
                items: _cities
                    .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCity = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Business Address (Optional)',
                  hintText: 'Street, City, ZIP',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              SwitchListTile(
                title: const Text('GST Registered?'),
                subtitle: const Text('Enable to include GST details on invoices'),
                value: _isGstRegistered,
                onChanged: (value) => setState(() => _isGstRegistered = value),
                contentPadding: EdgeInsets.zero,
              ),

              if (_isGstRegistered) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gstController,
                  decoration: const InputDecoration(
                    labelText: 'GST Number*',
                    hintText: '22AAAAA0000A1Z5',
                  ),
                  validator: (value) =>
                      _isGstRegistered && (value == null || value.isEmpty) ? 'Required if GST enabled' : null,
                ),
              ],

              const SizedBox(height: 24),

              SwitchListTile(
                title: const Text('FSSAI Registered?'),
                subtitle: const Text('Required for cafés, restaurants, and food businesses'),
                value: _isFssaiRegistered,
                onChanged: (value) => setState(() => _isFssaiRegistered = value),
                contentPadding: EdgeInsets.zero,
              ),

              if (_isFssaiRegistered) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fssaiController,
                  decoration: const InputDecoration(
                    labelText: 'FSSAI License Number*',
                    hintText: '14-digit numeric value',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isFssaiRegistered) return null;
                    if (value == null || value.isEmpty) return 'Required if FSSAI enabled';
                    if (value.length != 14 || !RegExp(r'^\d+$').hasMatch(value)) {
                      return 'Enter valid 14-digit FSSAI number';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 40),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Complete Setup'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
