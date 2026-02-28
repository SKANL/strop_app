import 'package:flutter/material.dart' show Color;

/// Centralised semantic colour tokens for Strop.
/// Always prefer these over inline `Color(0xFF...)` literals.
abstract final class AppColors {
  // ── Priority ────────────────────────────────────────────────────────────
  static const Color priorityNormal = Color(0xFF1D4ED8);
  static const Color priorityUrgent = Color(0xFFC2410C);
  static const Color priorityCritical = Color(0xFFB91C1C);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color statusPending = Color(0xFF71717a);
  static const Color statusInReview = Color(0xFF2563EB);
  static const Color statusDone = Color(0xFF16a34a);

  // ── Sync ─────────────────────────────────────────────────────────────────
  static const Color syncPending = Color(0xFFf97316);
  static const Color syncSynced = Color(0xFF16a34a);
  static const Color syncError = Color(0xFFB91C1C);
  static const Color syncSyncing = Color(0xFF1D4ED8);

  // ── Feedback ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16a34a);
  static const Color error = Color(0xFFB91C1C);
  static const Color warning = Color(0xFFf97316);

  // ── Support badge ─────────────────────────────────────────────────────────
  static const Color supportBg = Color(0xFFdcfce7);
  static const Color supportIcon = Color(0xFF15803D);
}
