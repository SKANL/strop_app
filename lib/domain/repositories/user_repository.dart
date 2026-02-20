import 'package:strop_app/domain/entities/user.dart';

abstract class UserRepository {
  Future<User> getUserProfile();
  Future<void> updateUserProfile(User user);
  Future<Map<String, dynamic>>
  getSyncStatus(); // Returns {pendingIncidents: int, pendingPhotos: int}
}
