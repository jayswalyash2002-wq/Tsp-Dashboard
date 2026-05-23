import 'package:flutter/material.dart';
import '../../../core/utils/password_validator.dart';

class PasswordRequirementsView extends StatelessWidget {
  final String password;
  final bool showInitially;

  const PasswordRequirementsView({
    super.key,
    required this.password,
    this.showInitially = false,
  });

  @override
  Widget build(BuildContext context) {
    final result = PasswordValidator.validate(password);
    final hasStartedTyping = password.isNotEmpty;
    final showValidation = showInitially || hasStartedTyping;

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
        _RequirementItem(
          'Minimum 8 characters',
          result.hasMinLength,
          showValidation,
        ),
        _RequirementItem(
          'At least 1 uppercase letter',
          result.hasUppercase,
          showValidation,
        ),
        _RequirementItem(
          'At least 1 lowercase letter',
          result.hasLowercase,
          showValidation,
        ),
        _RequirementItem(
          'At least 1 number',
          result.hasDigits,
          showValidation,
        ),
        _RequirementItem(
          'At least 1 special character',
          result.hasSpecialCharacters,
          showValidation,
        ),
      ],
    );
  }

  Widget _RequirementItem(String text, bool isMet, bool showValidation) {
    Color color;
    IconData icon;

    if (!showValidation) {
      color = Colors.grey;
      icon = Icons.circle_outlined;
    } else if (isMet) {
      color = Colors.green;
      icon = Icons.check_circle_rounded;
    } else {
      color = Colors.red;
      icon = Icons.cancel_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
