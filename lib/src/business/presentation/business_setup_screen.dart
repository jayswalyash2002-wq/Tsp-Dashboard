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
import '../../core/widgets/responsive_widgets.dart';
import '../../memberships/data/membership_providers.dart';
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
  
  // Required Controllers
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  
  // Optional Controllers
  final _secondaryPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _logoUrl;
  String? _selectedType;
  bool _isLoading = false;
  String _loadingMessage = 'Saving business details...';
  Business? _existingBusiness;

  bool get _isEditMode => widget.businessId != null;

  final List<String> _businessTypes = [
    'Restaurant',
    'Cafe',
    'Bar',
    'Cloud Kitchen',
    'Food Stall',
    'Bakery',
    'Retail',
    'Service',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBusinessData());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
    }
  }

  void _prefillFromProfile() {
    final profile = ref.read(userProfileProvider).value;
    if (profile != null) {
      setState(() {
        _ownerNameController.text = profile.displayName;
        _emailController.text = profile.email;
      });
    }
  }

  Future<void> _loadBusinessData() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Fetching business data...';
    });
    try {
      final repo = ref.read(businessRepositoryProvider);
      final business = await repo.getBusiness(widget.businessId!);

      if (business != null && mounted) {
        setState(() {
          _existingBusiness = business;
          _nameController.text = business.businessName;
          _ownerNameController.text = business.ownerName;
          _emailController.text = business.officialEmail;
          _phoneController.text = business.phoneNumber;
          _secondaryPhoneController.text = business.secondaryPhoneNumber ?? '';
          _cityController.text = business.city ?? '';
          _areaController.text = business.area ?? '';
          _addressController.text = business.address ?? '';
          _gstController.text = business.gstNumber ?? '';
          _descriptionController.text = business.description ?? '';
          _logoUrl = business.logoUrl;
          _selectedType = business.businessType;
        });
      }
    } catch (e) {
      debugPrint('BUSINESS_SETUP: Error loading business: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _secondaryPhoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logo upload will be available in the next update.')),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(firebaseAuthProvider).currentUser;
    final repo = ref.read(businessRepositoryProvider);

    if (!_isEditMode) {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Checking for duplicates...';
      });
      try {
        final duplicates = await repo.softDuplicateCheck(
          name: _nameController.text.trim(),
          city: _cityController.text.trim(),
        );

        if (duplicates.isNotEmpty && context.mounted) {
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
      id: '', 
      uin: '', 
      businessName: _nameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      officialEmail: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      secondaryPhoneNumber: _secondaryPhoneController.text.trim().isEmpty ? null : _secondaryPhoneController.text.trim(),
      businessType: _selectedType ?? 'Other',
      city: _cityController.text.trim(),
      area: _areaController.text.trim(),
      address: _addressController.text.trim(),
      gstNumber: _gstController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      logoUrl: _logoUrl,
      createdAt: DateTime.now(),
    );

    if (user == null) {
      ref.read(pendingBusinessProvider.notifier).state = businessData;
      if (!context.mounted) return;
      context.push('/auth/signup');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = _isEditMode ? 'Updating Business...' : 'Creating Business...';
    });

    try {
      final profile = ref.read(userProfileProvider).value;

      if (_isEditMode && _existingBusiness != null) {
        final updatedBusiness = _existingBusiness!.copyWith(
          businessName: _nameController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          officialEmail: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          secondaryPhoneNumber: _secondaryPhoneController.text.trim().isEmpty ? null : _secondaryPhoneController.text.trim(),
          businessType: _selectedType ?? 'Other',
          city: _cityController.text.trim(),
          area: _areaController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          logoUrl: _logoUrl,
        );
        await repo.updateBusiness(updatedBusiness);

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
        setState(() => _loadingMessage = 'Creating Membership...');
        final deviceIdentity = ref.read(deviceIdentityProvider).value;

        final logTemplate = ActivityLogModel(
          activityLogId: '',
          businessId: '',
          performedBy: user.uid,
          performedByName: profile?.displayName ?? _ownerNameController.text.trim(),
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
          business: businessData,
          logTemplate: logTemplate,
        );
        
        setState(() => _loadingMessage = 'Finalizing Setup...');
      }

      // CRITICAL: Manually invalidate providers to force a refresh of the membership state
      // This overcomes sync lag that causes the "Preparing Workspace" hang.
      ref.invalidate(userProfileProvider);
      ref.invalidate(userMembershipsProvider);

      if (!context.mounted) return;
      
      // Success Feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Business updated successfully!' : 'Welcome to TSP! Business created.'),
          backgroundColor: Colors.green,
        ),
      );
      
      context.go('/dashboard');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Business Settings' : 'Business Setup'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(cs),
                      const SizedBox(height: 40),
                      _buildSectionTitle('Basic Information'),
                      const SizedBox(height: 16),
                      _buildBasicInfoFields(),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Location Details'),
                      const SizedBox(height: 16),
                      _buildLocationFields(),
                      const SizedBox(height: 32),
                      _buildSectionTitle('Additional Details (Optional)'),
                      const SizedBox(height: 16),
                      _buildOptionalFields(),
                      const SizedBox(height: 48),
                      _buildSubmitButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        if (!_isEditMode) ...[
          Text(
            'Setup Your Business',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your profile to start managing your business with TSP.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        Center(
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary.withOpacity(0.2), width: 4),
                  image: _logoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _logoUrl == null
                    ? Icon(Icons.business_rounded, size: 50, color: cs.primary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton.small(
                  onPressed: _pickLogo,
                  child: const Icon(Icons.camera_alt_rounded),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildBasicInfoFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Business Name*',
            hintText: 'e.g. Slow Pour Coffee',
            prefixIcon: Icon(Icons.store_rounded),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Business Type*',
            prefixIcon: Icon(Icons.category_rounded),
          ),
          items: _businessTypes
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (value) => setState(() => _selectedType = value),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        ResponsiveFormRow(
          children: [
            TextFormField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: 'Owner Name*',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Official Email*',
                prefixIcon: Icon(Icons.email_rounded),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Primary Business Phone*',
            prefixIcon: Icon(Icons.phone_rounded),
            hintText: '10-digit number',
          ),
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.length < 10 ? 'Enter valid phone' : null,
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      children: [
        ResponsiveFormRow(
          children: [
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City*',
                prefixIcon: Icon(Icons.location_city_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Area / Locality*',
                prefixIcon: Icon(Icons.map_rounded),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Full Address',
            prefixIcon: Icon(Icons.home_work_rounded),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildOptionalFields() {
    return Column(
      children: [
        TextFormField(
          controller: _secondaryPhoneController,
          decoration: const InputDecoration(
            labelText: 'Secondary Phone',
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _gstController,
          decoration: const InputDecoration(
            labelText: 'GST Number',
            prefixIcon: Icon(Icons.receipt_long_rounded),
            hintText: '15-digit GSTIN',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Business Description',
            prefixIcon: Icon(Icons.description_rounded),
            hintText: 'Tell us a bit about your business...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        _isEditMode ? 'Update Business' : 'Create Business',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLoadingOverlay(ColorScheme cs) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _loadingMessage,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
