import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/auth/data/auth_providers.dart';

class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({
    super.key,
    required this.code,
    required this.role,
    required this.name,
  });

  final String code;
  final Role role;
  final String name;

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  bool _showQr = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final businessId = ref.watch(userBusinessIdProvider) ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Created')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Invite for ${widget.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Role: ${widget.role.name.toUpperCase()}',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.code,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Expires in 48 hours',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.copy,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _ActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () {
                      Share.share(
                        'Join our team at TSP Dashboard!\nInvite Code: ${widget.code}\nRole: ${widget.role.name.toUpperCase()}',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
              if (!_showQr)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showQr = true),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Show QR Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Builder(
                    builder: (context) {
                      final qrData = 'TSPJOIN:$businessId:${widget.code}';
                      debugPrint('GENERATED QR PAYLOAD: $qrData');
                      return QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      );
                    }
                  ),
                ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => context.go('/profile'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
