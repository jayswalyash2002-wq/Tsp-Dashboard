import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveFormRow({
    super.key,
    required this.children,
    this.spacing = 16.0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildSpacedChildren(isColumn: true),
      );
    } else {
      return Row(
        crossAxisAlignment: crossAxisAlignment,
        children: _buildSpacedChildren(isColumn: false)
            .map((w) => w is SizedBox ? w : Expanded(child: w))
            .toList(),
      );
    }
  }

  List<Widget> _buildSpacedChildren({required bool isColumn}) {
    final List<Widget> spaced = [];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(
          isColumn ? SizedBox(height: spacing) : SizedBox(width: spacing),
        );
      }
    }
    return spaced;
  }
}
