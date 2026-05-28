import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/auth_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/password_validator.dart';
import '../../core/widgets/app_password_field.dart';
import 'widgets/password_requirements_view.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _busy = false;
  bool _showPasswordRequirements = false;
  
  String? _initialEmail;
  String? _initialPhone;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateState);
    _phoneController.addListener(_updateState);
    _emailController.addListener(_updateState);
    _passwordController.addListener(_updateState);
    _confirmPasswordController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_updateState);
    _phoneController.removeListener(_updateState);
    _emailController.removeListener(_updateState);
    _passwordController.removeListener(_updateState);
    _confirmPasswordController.removeListener(_updateState);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  bool get _needsVerification {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return true;
    
    if (_initialEmail != null && _initialPhone != null) {
      return _emailController.text.trim() != _initialEmail ||
             _phoneController.text.trim() != _initialPhone;
    }
    
    return true; 
  }

  void _submit() async {
    final password = _passwordController.text;
    final passwordResult = PasswordValidator.validate(password);
    
    if (!passwordResult.isValid) {
      setState(() => _showPasswordRequirements = true);
      _formKey.currentState!.validate(); // Trigger UI validation errors
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    final user = ref.read(firebaseAuthProvider).currentUser;

    if (user != null && !_needsVerification) {
      setState(() => _busy = true);
      try {
        final db = ref.read(firestoreProvider);
        await db.collection('users').doc(user.uid).update({'displayName': name});
        if (mounted) context.pushReplacement('/business-setup');
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    setState(() => _busy = true);
    
    try {
      final repo = await ref.read(authRepositoryProvider.future);
      
      await repo.sendOtp(
        phone,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _busy = false);

          if (kDebugMode) {
            final otpService = ref.read(otpServiceProvider);
            final code = otpService.lastGeneratedCode;
            if (code != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Development OTP: $code'),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  duration: const Duration(seconds: 15),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              );
            }
          }
          
          context.push(
            Uri(
              path: '/auth/otp',
              queryParameters: {
                'email': email,
                'phone': phone,
                'name': name,
                'password': password,
                'verificationId': verificationId,
              },
            ).toString(),
          );
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          setState(() => _busy = false);
          final message = e is FirebaseAuthException ? e.message : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: $message')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate verification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    
    if (user != null && !_initialized) {
      // Fetch profile data once when user is detected
      ref.read(firestoreProvider).collection('users').doc(user.uid).get().then((doc) {
        if (mounted && doc.exists) {
          final data = doc.data()!;
          setState(() {
            _initialEmail = data['email'] as String?;
            _initialPhone = data['phoneNumber'] as String?;
            _nameController.text = data['displayName'] as String? ?? '';
            _emailController.text = _initialEmail ?? '';
            _phoneController.text = _initialPhone ?? '';
            _initialized = true;
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(user == null ? 'Create Account' : 'Confirm Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                user == null ? 'Step 1: Account Creation' : 'Step 1: Confirm Details',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                user == null 
                  ? 'Tell us about yourself. We will send a verification code to your mobile number.'
                  : 'Review your details. If you change your email or phone, you will need to re-verify.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v == null || v.length < 10 ? 'Enter valid phone number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'This email will be used to sign in to your business account. It cannot be changed later without re-authentication.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber[400],
                ),
              ),
              const SizedBox(height: 16),
              AppPasswordField(
                controller: _passwordController,
                validator: PasswordValidator.getError,
              ),
              const SizedBox(height: 16),
              PasswordRequirementsView(
                password: _passwordController.text,
                forceShow: _showPasswordRequirements,
              ),
              const SizedBox(height: 16),
              AppPasswordField(
                controller: _confirmPasswordController,
                labelText: 'Confirm Password',
                validator: (v) {
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _busy 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(user != null && !_needsVerification ? 'Continue' : 'Send Verification Code'),
              ),
            ],
          ),
        ),
      ),
    );

  }
}
