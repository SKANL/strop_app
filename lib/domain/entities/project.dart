import 'package:equatable/equatable.dart';

class Project extends Equatable {

  const Project({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude, required this.longitude, this.imageUrl,
    this.criticalIncidents = 0,
    this.isSynced = true,
  });
  final String id;
  final String name;
  final String address;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final int criticalIncidents;
  final bool isSynced;

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    imageUrl,
    latitude,
    longitude,
    criticalIncidents,
    isSynced,
  ];
}
