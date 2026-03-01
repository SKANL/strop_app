import 'package:equatable/equatable.dart';

class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.criticalIncidents = 0,
    this.isSynced = true,
    this.phaseText,
    this.contingencyBudget,
    this.isActive = true,
    this.geofenceRadiusMeters = 500,
    this.moneyAtRisk,
  });

  final String id;
  final String name;
  final String address;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final int criticalIncidents;
  final bool isSynced;
  final String? phaseText;
  final double? contingencyBudget;
  final bool isActive;
  final int geofenceRadiusMeters;
  final double? moneyAtRisk;

  @override
  List<Object?> get props => [
        id, name, address, imageUrl, latitude, longitude,
        criticalIncidents, isSynced, phaseText, contingencyBudget,
        isActive, geofenceRadiusMeters, moneyAtRisk,
      ];

  Project copyWith({
    String? name,
    String? address,
    String? imageUrl,
    double? latitude,
    double? longitude,
    int? criticalIncidents,
    bool? isSynced,
    String? phaseText,
    double? contingencyBudget,
    bool? isActive,
    int? geofenceRadiusMeters,
    double? moneyAtRisk,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      criticalIncidents: criticalIncidents ?? this.criticalIncidents,
      isSynced: isSynced ?? this.isSynced,
      phaseText: phaseText ?? this.phaseText,
      contingencyBudget: contingencyBudget ?? this.contingencyBudget,
      isActive: isActive ?? this.isActive,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      moneyAtRisk: moneyAtRisk ?? this.moneyAtRisk,
    );
  }
}
