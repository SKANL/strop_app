import 'package:strop_app/domain/entities/user.dart';
import 'package:strop_app/domain/repositories/user_repository.dart';

class MockUserRepository implements UserRepository {
  User _currentUser = const User(
    id: '123',
    email: 'worker@strop.com',
    name: 'Juan Pérez',
    avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
  );

  @override
  Future<User> getUserProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _currentUser;
  }

  @override
  Future<void> updateUserProfile(User user) async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    _currentUser = user;
  }

  @override
  Future<Map<String, dynamic>> getSyncStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return {
      'pendingIncidents': 3,
      'pendingPhotos': 5,
      'lastSync': DateTime.now()
          .subtract(const Duration(minutes: 15))
          .toIso8601String(),
    };
  }
}
