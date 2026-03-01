class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.roleCapabilities = const [],
    this.userType = 'staff',
    this.organizationId,
  });

  final String id;
  final String email;
  final String? fullName;
  final List<String> roleCapabilities;
  final String userType; // 'staff' | 'crew'
  final String? organizationId;

  bool can(String capability) => roleCapabilities.contains(capability);
}
