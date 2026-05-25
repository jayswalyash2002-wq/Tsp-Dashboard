import 'package:flutter/material.dart';
import '../../../core/utils/password_validator.dart';

class PasswordRequirementsView extends StatelessWidget {
  final String password;
  final bool forceShow;

  const PasswordRequirementsView({
    super.key,
    required this.password,
    this.forceShow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!forceShow) return const SizedBox.shrink();

    final result = PasswordValidator.validate(password);
    
    // If everything is met, hide completely even if forceShow is true
    if (result.isValid) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password must contain:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        if (!result.hasMinLength)
          _RequirementItem('Minimum 8 characters'),
        if (!result.hasUppercase)
          _RequirementItem('At least 1 uppercase letter'),
        if (!result.hasLowercase)
          _RequirementItem('At least 1 lowercase letter'),
        if (!result.hasDigits)
          _RequirementItem('At least 1 number'),
        if (!result.hasSpecialCharacters)
          _RequirementItem('At least 1 special character'),
      ],
    );
  }

  Widget _RequirementItem(String text) {
    const color = Colors.red;
    const icon = Icons.cancel_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
