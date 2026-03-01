import 'package:equatable/equatable.dart';

enum IncidentStatus {
  open,        // OPEN in DB
  inReview,    // IN_REVIEW in DB
  closed,      // CLOSED in DB
  rejected,    // REJECTED in DB
}

enum IncidentPriority { normal, urgent, critical }

enum SyncStatus { pending, syncing, synced, error }

enum Trade {
  masonry,
  plumbing,
  electrical,
  finishing,
  other,
}

class Incident extends Equatable {
  const Incident({
    required this.id,
    required this.title,
    required this.location,
    required this.createdAt,
    this.description,
    this.projectId,
    this.specificLocation,
    this.status = IncidentStatus.open,
    this.priority = IncidentPriority.normal,
    this.syncStatus = SyncStatus.pending,
    this.photos = const [],
    this.audioPath,
    this.assignedTrade,
    this.estimatedCost,
    this.isBillable = false,
    this.assignedTo,
    this.rejectionReason,
    this.publicToken,
    this.isSynced = false,
  });
  final String id;
  final String title;
  final String? description;
  final String location; // Project name for display
  final String? projectId; // Real Supabase project UUID
  final String? specificLocation;
  final DateTime createdAt;
  final IncidentStatus status;
  final IncidentPriority priority;
  final SyncStatus syncStatus;
  final List<String> photos;
  final String? audioPath;
  final Trade? assignedTrade;
  final double? estimatedCost;
  final bool isBillable;
  final String? assignedTo;
  final String? rejectionReason;
  final String? publicToken;
  final bool isSynced;

  @override
  List<Object?> get props => [
        id, title, description, location, projectId, specificLocation,
        createdAt, status, priority, syncStatus, photos, audioPath,
        assignedTrade, estimatedCost, isBillable, assignedTo,
        rejectionReason, publicToken, isSynced,
      ];

  Incident copyWith({
    String? title,
    String? description,
    String? location,
    String? projectId,
    String? specificLocation,
    IncidentStatus? status,
    IncidentPriority? priority,
    SyncStatus? syncStatus,
    List<String>? photos,
    String? audioPath,
    Trade? assignedTrade,
    double? estimatedCost,
    bool? isBillable,
    String? assignedTo,
    String? rejectionReason,
    String? publicToken,
    bool? isSynced,
  }) {
    return Incident(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      projectId: projectId ?? this.projectId,
      specificLocation: specificLocation ?? this.specificLocation,
      createdAt: createdAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      syncStatus: syncStatus ?? this.syncStatus,
      photos: photos ?? this.photos,
      audioPath: audioPath ?? this.audioPath,
      assignedTrade: assignedTrade ?? this.assignedTrade,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      isBillable: isBillable ?? this.isBillable,
      assignedTo: assignedTo ?? this.assignedTo,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      publicToken: publicToken ?? this.publicToken,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
