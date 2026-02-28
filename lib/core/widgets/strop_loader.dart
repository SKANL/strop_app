import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide CircularProgressIndicator;

/// A themed loading indicator consistent with the Strop design system.
/// Use this everywhere instead of bare `CircularProgressIndicator()`.
class StropLoader extends StatelessWidget {
  const StropLoader({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color,
        ),
      ),
    );
  }
}
