import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController(); // Or dropdown if preferred
  final _areaController = TextEditingController();
  
  String? _selectedType;
  bool _isLoading = false;

  final List<String> _businessTypes = [
    'Restaurant',
    'Cafe',
    'Bar',
    'Cloud Kitchen',
    'Food Stall',
    'Bakery',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) return;

      final repo = ref.read(businessRepositoryProvider);
      
      // Step 2 — Soft duplicate check
      final duplicates = await repo.softDuplicateCheck(
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
      );

      if (duplicates.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Potential Duplicate Found'),
            content: Text(
              'A business named "${_nameController.text}" already exists in ${_cityController.text}. '
              'Are you sure you want to create a new one?'
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue Anyway')),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final profile = ref.read(userProfileProvider).value;
      
      final businessData = Business(
        id: '', // Generated in repository
        uin: '', // Generated in repository
        businessName: _nameController.text.trim(),
        ownerName: profile?.displayName ?? 'Owner',
        officialEmail: profile?.email ?? '',
        phoneNumber: _phoneController.text.trim(),
        businessType: _selectedType ?? 'Other',
        city: _cityController.text.trim(),
        area: _areaController.text.trim(),
        createdAt: DateTime.now(),
      );

      await repo.createBusiness(uid: user.uid, business: businessData);

      ref.invalidate(userProfileProvider);
      // Wait for profile to refresh so AuthGate can route to Dashboard
      
      if (mounted) {
        // In the new onboarding, we might be pushed here or shown as top level.
        // If we are in a Navigator.push, pop. If we are in AuthGate, it will rebuild.
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          // Fallback if needed
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating business: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Step 2: Business Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us about your business to complete your registration.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name*',
                  hintText: 'e.g. Slow Pour Coffee',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Business Type*',
                  border: OutlineInputBorder(),
                ),
                items: _businessTypes
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Primary Business Phone*',
                  hintText: '10-digit number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.length < 10 ? 'Enter valid phone' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City*',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Area / Locality*',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 40),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Business'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
