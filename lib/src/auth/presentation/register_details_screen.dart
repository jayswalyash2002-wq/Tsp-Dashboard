import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_providers.dart';
import '../../core/widgets/app_password_field.dart';

class RegisterDetailsScreen extends ConsumerStatefulWidget {
  const RegisterDetailsScreen({
    super.key, 
    required this.email,
    required this.phoneNumber,
    this.initialName,
    this.initialPassword,
  });
  
  final String email;
  final String phoneNumber;
  final String? initialName;
  final String? initialPassword;

  @override
  ConsumerState<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends ConsumerState<RegisterDetailsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _passwordController = TextEditingController(text: widget.initialPassword);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required and password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = await ref.read(authRepositoryProvider.future);
      
      debugPrint('REGISTER_DETAILS: Finalizing signup for ${widget.email} with phone ${widget.phoneNumber}');
      
      await repo.signUpWithEmailPassword(
        email: widget.email,
        password: password,
        name: name,
        phoneNumber: widget.phoneNumber,
      );
      
      // Sync local state
      ref.read(deviceNameProvider.notifier).state = name;

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      
      // After registration, AuthGate will pick up the authenticated state 
      // and redirect to Business Setup if no memberships exist.
      context.go('/dashboard');

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = e.message ?? 'Unknown error';
      if (e.code == 'operation-not-allowed') {
        message = 'Email/Password accounts are not enabled in Firebase Console.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth Error: $message')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create your account',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              controller: _passwordController,
              onFieldSubmitted: (_) => _register(),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _register,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _busy
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Finish Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
