import 'package:flutter/foundation.dart';

/// Global reactive state notifiers shared across the widget tree.
///
/// These follow the same pattern as [IncidentFormPage.isFormActive]:
/// cheap, static, cross-tree notifiers that avoid the need to lift
/// BLoC/stream providers all the way up to [AppShell].
abstract final class AppNotifiers {
  /// Number of incidents pending local→cloud synchronisation.
  /// Updated after every incident save and after each sync cycle.
  static final syncPendingCount = ValueNotifier<int>(0);
}
