import 'package:shadcn_flutter/shadcn_flutter.dart';

/// STROP construction platform – warm stone/amber palette.
/// Stone evokes concrete, sand, and field materials; much more
/// characteristic for a construction industry product than generic slate.
class AppTheme {
  static final light = ThemeData(
    colorScheme: ColorSchemes.stone(ThemeMode.light),
    radius: 0.5,
  );

  static final dark = ThemeData(
    colorScheme: ColorSchemes.stone(ThemeMode.dark),
    radius: 0.5,
  );
}
