import 'package:equatable/equatable.dart';

enum IncidentStatus { pending, inReview, done }

enum IncidentPriority { normal, urgent, critical }

enum SyncStatus { pending, syncing, synced, error }

enum Trade {
  masonry, // Albañilería
  plumbing, // Plomería
  electrical, // Eléctrico
  finishing, // Acabados
  other,
}

class Incident extends Equatable {

  const Incident({
    required this.id,
    required this.title,
    required this.location, required this.createdAt, this.description,
    this.specificLocation,
    this.status = IncidentStatus.pending,
    this.priority = IncidentPriority.normal,
    this.syncStatus = SyncStatus.pending,
    this.photos = const [],
    this.audioPath,
    this.assignedTrade,
  });
  final String id;
  final String title;
  final String? description;
  final String location; // Project name or address
  final String?
  specificLocation; // Specific location within project (e.g., "Level 3")
  final DateTime createdAt;
  final IncidentStatus status;
  final IncidentPriority priority;
  final SyncStatus syncStatus;
  final List<String> photos; // Paths or URLs
  final String? audioPath;
  final Trade? assignedTrade;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    location,
    specificLocation,
    createdAt,
    status,
    priority,
    syncStatus,
    photos,
    audioPath,
    assignedTrade,
  ];

  Incident copyWith({
    String? title,
    String? description,
    String? location,
    String? specificLocation,
    IncidentStatus? status,
    IncidentPriority? priority,
    SyncStatus? syncStatus,
    List<String>? photos,
    String? audioPath,
    Trade? assignedTrade,
  }) {
    return Incident(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      specificLocation: specificLocation ?? this.specificLocation,
      createdAt: createdAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      syncStatus: syncStatus ?? this.syncStatus,
      photos: photos ?? this.photos,
      audioPath: audioPath ?? this.audioPath,
      assignedTrade: assignedTrade ?? this.assignedTrade,
    );
  }
}
