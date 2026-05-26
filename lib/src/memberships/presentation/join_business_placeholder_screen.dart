import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tsp_dashboard/src/features/staff/providers/staff_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../business/data/business_providers.dart';
import '../../business/domain/business.dart';
import '../../features/rbac/domain/models/business_invite.dart';
import 'package:tsp_dashboard/src/auth/data/auth_providers.dart';
import '../../core/utils/password_validator.dart';
import '../../core/widgets/app_password_field.dart';
import '../../auth/presentation/widgets/password_requirements_view.dart';
import '../data/membership_providers.dart';

class JoinBusinessPlaceholderScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  const JoinBusinessPlaceholderScreen({super.key, this.initialCode});

  @override
  ConsumerState<JoinBusinessPlaceholderScreen> createState() => _JoinBusinessPlaceholderScreenState();
}

class _JoinBusinessPlaceholderScreenState extends ConsumerState<JoinBusinessPlaceholderScreen> {
  final _inviteController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _error;
  bool _isValidating = false;
  bool _isSignInMode = true;
  bool _isAuthBusy = false;
  
  // State for preview
  InviteModel? _previewInvite;
  Business? _previewBusiness;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _inviteController.text = widget.initialCode!;
      // Delay to ensure provider is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateInvite(widget.initialCode!);
      });
    }
  }

  @override
  void dispose() {
    _inviteController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setError(String? message) {
    setState(() => _error = message);
  }

  Future<void> _validateInvite(String code) async {
    setState(() {
      _isValidating = true;
      _error = null;
      _previewInvite = null;
      _previewBusiness = null;
      _nameController.clear();
    });

    try {
      final invite = await ref.read(claimInviteProvider.notifier).findInvite(code);
      if (invite == null) {
        _setError('Invalid or expired invite code.');
        return;
      }

      final business = await ref.read(businessRepositoryProvider).getBusiness(invite.businessId);
      if (business == null) {
        _setError('Business no longer exists.');
        return;
      }

      setState(() {
        _previewInvite = invite;
        _previewBusiness = business;
        // Auto-fill name from invite if available
        if (invite.staffName.isNotEmpty) {
          _nameController.text = invite.staffName;
        }
        // Default to Sign Up mode for new invited users
        _isSignInMode = false;
      });
    } catch (e) {
      debugPrint('INVITE_VALIDATION_ERROR: $e');
      _setError('Error verifying invite: $e');
    } finally {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _handleAuthAndClaim() async {
    _setError(null);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      _setError('Please fill in all required fields.');
      return;
    }

    setState(() => _isAuthBusy = true);
    debugPrint('JOIN_FLOW: START _handleAuthAndClaim for $email');

    try {
      final repo = await ref.read(authRepositoryProvider.future).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Auth service timeout. Please check your connection.'),
      );
      
      debugPrint('JOIN_FLOW: Mode: ${_isSignInMode ? 'SIGN_IN' : 'SIGN_UP'}');
      
      if (_isSignInMode) {
        debugPrint('JOIN_FLOW: Calling signInWithEmailPassword...');
        await repo.signInWithEmailPassword(email: email, password: password).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Sign in timed out.'),
        );
        debugPrint('JOIN_FLOW: Sign In Success');
      } else {
        final name = _nameController.text.trim();
        final confirmPassword = _confirmPasswordController.text;
        
        if (name.isEmpty) {
          _setError('Please enter your full name.');
          return;
        }

        final passwordResult = PasswordValidator.validate(password);
        if (!passwordResult.isValid) {
          _setError('Password does not meet requirements.');
          return;
        }
        
        if (password != confirmPassword) {
          _setError('Passwords do not match.');
          return;
        }

        debugPrint('JOIN_FLOW: Calling signUpWithEmailPassword for $email');
        await repo.signUpWithEmailPassword(
          email: email, 
          password: password, 
          name: name, 
          phoneNumber: '0000000000', 
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception('Sign up timed out. Please check your connection.'),
        );
        debugPrint('JOIN_FLOW: STEP_1_AUTH_CREATED: Account created for $email');
      }

      // After successful auth, proceed to claim immediately
      if (_previewInvite != null) {
        debugPrint('JOIN_FLOW: Proceeding to claim for Business: ${_previewInvite!.businessId}');
        final success = await _handleDirectClaim(_previewInvite!.businessId, _previewInvite!.code);
        if (!success && mounted) {
           debugPrint('JOIN_FLOW: Claim sub-process reported failure.');
        }
      } else {
        debugPrint('JOIN_FLOW: WARNING: No invite preview found after auth.');
        _setError('Invite session expired. Please re-enter your code.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('JOIN_FLOW_AUTH_ERROR: [${e.code}] ${e.message}');
      _setError(e.message ?? 'Authentication failed');
    } catch (e) {
      debugPrint('JOIN_FLOW_ERROR: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      debugPrint('JOIN_FLOW: FINISH _handleAuthAndClaim (Busy=false)');
      if (mounted) setState(() => _isAuthBusy = false);
    }
  }

  Future<bool> _handleDirectClaim(String businessId, String inviteCode) async {
    _setError(null);
    debugPrint('CLAIM_PROCESS: START _handleDirectClaim');
    try {
      debugPrint('CLAIM_PROCESS: Calling ClaimInviteNotifier.claim...');
      await ref.read(claimInviteProvider.notifier).claim(
        businessId: businessId,
        inviteCode: inviteCode,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Claim process timed out.'),
      );
      
      if (!mounted) return false;

      final state = ref.read(claimInviteProvider);
      if (state.hasError) {
        final error = state.error.toString();
        debugPrint('CLAIM_PROCESS: Provider reported error: $error');
        _setError(error.replaceAll('Exception: ', ''));
        return false;
      }

      debugPrint('CLAIM_PROCESS_SUCCESS: Joined successfully. Waiting for membership sync...');

      // Wait for memberships to refresh to prevent AuthGate race condition
      int retries = 0;
      bool synced = false;
      while (mounted && retries < 12) {
        final mAsync = ref.read(userMembershipsProvider);
        if (mAsync.hasValue && mAsync.value!.isNotEmpty) {
          debugPrint('CLAIM_PROCESS: Memberships synced successfully (found ${mAsync.value!.length} items).');
          synced = true;
          break;
        }
        debugPrint('CLAIM_PROCESS: Syncing... (attempt ${retries + 1}/12)');
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      if (!synced) {
        debugPrint('CLAIM_PROCESS: Sync warning: Memberships not found in provider after 6s.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined business successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        debugPrint('CLAIM_PROCESS: NAVIGATING TO DASHBOARD');
        context.go('/dashboard');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('CLAIM_PROCESS_CATCH: $e');
      if (mounted) {
        _setError(e.toString().replaceAll('Exception: ', ''));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _startScan() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => const _QrScannerScreen(),
      ),
    );

    if (result != null) {
      debugPrint('SCANNED QR PAYLOAD: $result');
      try {
        if (!result.startsWith('TSPJOIN:')) {
          _setError('Invalid QR format. Use a TSP Dashboard invite QR.');
          return;
        }

        final parts = result.split(':');
        if (parts.length != 3) {
          _setError('Invalid QR payload structure.');
          return;
        }

        final inviteCode = parts[2];
        _inviteController.text = inviteCode;
        await _validateInvite(inviteCode);
      } catch (e) {
        debugPrint('QR PARSE ERROR: $e');
        _setError('Failed to parse QR code.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final claimState = ref.watch(claimInviteProvider);
    final isClaiming = claimState.isLoading;
    final isLoading = _isValidating || isClaiming;
    final user = ref.watch(authStateChangesProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Business'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_previewBusiness == null) ...[
              const Text(
                'Join a Business',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your invite code or scan the QR code provided by your business admin.',
                style: TextStyle(fontSize: 16, color: cs.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _inviteController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_InviteCodeFormatter()],
                decoration: InputDecoration(
                  labelText: 'Enter invite code',
                  hintText: 'XXXX-XXXX',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  errorText: _error,
                ),
                onChanged: (_) => _setError(null),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: isLoading ? null : () => _validateInvite(_inviteController.text.trim()),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify Invite', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3), fontWeight: FontWeight.bold)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 32),
              InkWell(
                onTap: isLoading ? null : _startScan,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 48, color: cs.primary),
                      const SizedBox(height: 12),
                      const Text('Scan QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Tap to open camera', style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Business Preview
              const Icon(Icons.business_rounded, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'You are invited to join:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _previewBusiness!.businessName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Role: ${_previewInvite!.role.name.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),

              if (user == null) ...[
                // INLINE AUTH FORM
                Text(
                  _isSignInMode ? 'Sign In to Join' : 'Create Account to Join',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                if (!_isSignInMode) ...[
                  TextField(
                    controller: _nameController,
                    readOnly: _previewInvite?.staffName.isNotEmpty ?? false,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      helperText: (_previewInvite?.staffName.isNotEmpty ?? false)
                          ? 'Name provided by your business'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                
                AppPasswordField(
                  controller: _passwordController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                if (!_isSignInMode) ...[
                  PasswordRequirementsView(password: _passwordController.text),
                  const SizedBox(height: 16),
                  AppPasswordField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm Password',
                  ),
                  const SizedBox(height: 24),
                ],

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],

                FilledButton(
                  onPressed: _isAuthBusy ? null : _handleAuthAndClaim,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isAuthBusy 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isSignInMode ? 'Sign In & Join' : 'Create Account & Join'),
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => setState(() {
                    _isSignInMode = !_isSignInMode;
                    _error = null;
                  }),
                  child: Text(_isSignInMode 
                    ? "Don't have an account? Create one" 
                    : "Already have an account? Sign In"),
                ),
              ] else ...[
                // Already authenticated
                FilledButton(
                  onPressed: isLoading ? null : () => _handleDirectClaim(_previewInvite!.businessId, _previewInvite!.code),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: isClaiming
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Join Now'),
                ),
              ],
              
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() {
                  _previewBusiness = null;
                  _previewInvite = null;
                  _error = null;
                  _nameController.clear();
                  _isSignInMode = true;
                }),
                child: const Text('Use different code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow A-Z and 2-9, then force uppercase
    final text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z2-9]'), '');
    
    // Limit to 8 characters (excluding the dash)
    final truncated = text.length > 8 ? text.substring(0, 8) : text;
    
    String formatted = '';
    for (int i = 0; i < truncated.length; i++) {
      if (i == 4) formatted += '-';
      formatted += truncated[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Invite QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}
