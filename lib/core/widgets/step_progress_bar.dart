import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A thin linear step-progress bar for multi-step flows (e.g. capture flow).
///
/// Example:
/// ```dart
/// StepProgressBar(current: 2, total: 3)  // shows 2/3 filled
/// ```
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    required this.current,
    required this.total,
    super.key,
  });

  /// 1-based current step number.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 3,
      child: Row(
        children: List.generate(total, (i) {
          final filled = i < current;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 2 : 0),
              decoration: BoxDecoration(
                color: filled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
