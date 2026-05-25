import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/business_providers.dart';
import '../domain/business.dart';
import '../../auth/data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/data/models/activity_log_model.dart';
import '../../core/device/device_providers.dart';
import 'package:flutter/foundation.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  final String? businessId;
  const BusinessSetupScreen({super.key, this.businessId});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _fssaiController = TextEditingController();
  
  String? _logoUrl;
  String? _selectedType;
  bool _isLoading = false;
  Business? _existingBusiness;

  bool get _isEditMode => widget.businessId != null;

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
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint(
          'BUSINESS_SETUP: Screen initialized. isEditMode: $_isEditMode, businessId: ${widget.businessId}');
    }
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBusinessData());
    }
  }

  Future<void> _loadBusinessData() async {
    setState(() => _isLoading = true);
    try {
      if (kDebugMode) {
        debugPrint(
            'BUSINESS_SETUP: Fetching business document for ${widget.businessId}');
      }
      final repo = ref.read(businessRepositoryProvider);
      final business = await repo.getBusiness(widget.businessId!);

      if (business != null && mounted) {
        if (kDebugMode) {
          debugPrint(
              'BUSINESS_SETUP: Business data fetched successfully: ${business.businessName}');
        }
        setState(() {
          _existingBusiness = business;
          _nameController.text = business.businessName;
          _phoneController.text = business.phoneNumber;
          _secondaryPhoneController.text = business.secondaryPhoneNumber ?? '';
          _cityController.text = business.city ?? '';
          _areaController.text = business.area ?? '';
          _addressController.text = business.address ?? '';
          _gstController.text = business.gstNumber ?? '';
          _fssaiController.text = business.fssaiNumber ?? '';
          _logoUrl = business.logoUrl;
          _selectedType = business.businessType;

          if (kDebugMode) {
            debugPrint(
                'BUSINESS_SETUP: Form prefill state updated. Name: ${_nameController.text}, Type: $_selectedType');
          }
        });
      } else {
        if (kDebugMode) {
          debugPrint(
              'BUSINESS_SETUP: Business not found for id ${widget.businessId}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BUSINESS_SETUP: Error loading business: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _secondaryPhoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _fssaiController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    // Placeholder for actual image picking logic (e.g. image_picker package)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picker coming soon. Logo URL preservation kept.')),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    final repo = ref.read(businessRepositoryProvider);

    if (!_isEditMode) {
      // Step 2 — Soft duplicate check (only for NEW businesses)
      setState(() => _isLoading = true);
      try {
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
                  'Are you sure you want to create a new one?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Go Back')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue Anyway')),
              ],
            ),
          );
          if (proceed != true) {
            setState(() => _isLoading = false);
            return;
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    final businessData = Business(
      id: '', // Generated in repository
      uin: '', // Generated in repository
      businessName: _nameController.text.trim(),
      ownerName: 'Owner', // Updated in repository or after auth
      officialEmail: '', // Updated in repository or after auth
      phoneNumber: _phoneController.text.trim(),
      secondaryPhoneNumber: _secondaryPhoneController.text.trim().isEmpty ? null : _secondaryPhoneController.text.trim(),
      businessType: _selectedType ?? 'Other',
      city: _cityController.text.trim(),
      area: _areaController.text.trim(),
      address: _addressController.text.trim(),
      gstNumber: _gstController.text.trim(),
      fssaiNumber: _fssaiController.text.trim().isEmpty ? null : _fssaiController.text.trim(),
      logoUrl: _logoUrl,
      createdAt: DateTime.now(),
    );

    if (user == null) {
      // Unauthenticated flow: Store details and go to Sign Up
      ref.read(pendingBusinessProvider.notifier).state = businessData;
      context.push('/auth/signup');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = ref.read(userProfileProvider).value;

      if (_isEditMode && _existingBusiness != null) {
        if (kDebugMode) {
          debugPrint(
              'BUSINESS_SETUP: Updating existing business ${widget.businessId}');
        }
        final updatedBusiness = _existingBusiness!.copyWith(
          businessName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          secondaryPhoneNumber: _secondaryPhoneController.text.trim().isEmpty ? null : _secondaryPhoneController.text.trim(),
          businessType: _selectedType ?? 'Other',
          city: _cityController.text.trim(),
          area: _areaController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstController.text.trim(),
          fssaiNumber: _fssaiController.text.trim().isEmpty ? null : _fssaiController.text.trim(),
          logoUrl: _logoUrl,
        );
        await repo.updateBusiness(updatedBusiness);

        // Log Update
        unawaited(
          ref.read(logActivityUseCaseProvider).execute(
            action: ActivityAction.businessUpdated,
            category: ActivityCategory.business,
            targetType: 'business',
            targetId: widget.businessId,
            targetName: updatedBusiness.businessName,
          ),
        );
      } else {
        if (kDebugMode) {
          debugPrint('BUSINESS_SETUP: Creating new business');
        }
        final deviceIdentity = ref.read(deviceIdentityProvider).value;

        final logTemplate = ActivityLogModel(
          activityLogId: '',
          businessId: '',
          performedBy: user.uid,
          performedByName: profile?.displayName ?? 'Owner',
          performedByRole: 'owner',
          action: ActivityAction.businessCreated,
          category: ActivityCategory.business,
          metadata: {
            'businessType': _selectedType ?? 'Other',
            'city': _cityController.text.trim(),
            'area': _areaController.text.trim(),
          },
          appVersion: deviceIdentity?.appVersion ?? 'unknown',
          platform: deviceIdentity?.platform ?? 'unknown',
        );

        await repo.createBusiness(
          uid: user.uid,
          business: businessData.copyWith(
            ownerName: profile?.displayName ?? 'Owner',
            officialEmail: profile?.email ?? '',
          ),
          logTemplate: logTemplate,
        );
      }

      ref.invalidate(userProfileProvider);
      ref.invalidate(currentBusinessProvider);

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving business: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/onboarding');
            }
          },
        ),
        title: Text(_isEditMode ? 'Edit Business' : 'Business Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditMode
                    ? 'Update Business Details'
                    : 'Step 3: Business Profile',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isEditMode
                    ? 'Keep your business information up to date.'
                    : 'Final Step: Tell us about your business to complete your registration.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              // Logo Selection UI
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.outlineVariant, width: 2),
                        image: _logoUrl != null ? DecorationImage(
                          image: NetworkImage(_logoUrl!),
                          fit: BoxFit.cover,
                        ) : null,
                      ),
                      child: _logoUrl == null ? Icon(Icons.business_rounded, size: 40, color: cs.onSurfaceVariant) : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                      label: const Text('Select Business Logo'),
                    ),
                  ],
                ),
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
                key: ValueKey(_selectedType),
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Business Type*',
                  border: OutlineInputBorder(),
                ),
                items: _businessTypes
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
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
                validator: (v) =>
                    v == null || v.length < 10 ? 'Enter valid phone' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secondaryPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Secondary Number (Optional)',
                  hintText: '10-digit number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length < 10) {
                    return 'Enter valid phone';
                  }
                  return null;
                },
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Full Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number (Optional)',
                  hintText: '15-digit GSTIN',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fssaiController,
                decoration: const InputDecoration(
                  labelText: 'FSSAI Number (Optional)',
                  hintText: '14-digit FSSAI number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditMode ? 'Update Business' : 'Create Business'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
