import 'dart:async';
import 'package:strop_app/domain/entities/user.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<User>.broadcast();

  // Mock User
  static const _mockUser = User(
    id: '123',
    email: 'worker@strop.com',
    name: 'Juan Pérez',
    avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
  );

  @override
  Stream<User> get user => _controller.stream;

  @override
  Future<User> get currentUser async {
    // Simulate checking local storage/token
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Start as logged out for demo, or return _mockUser
    // to simulate persistent login
    return User.empty;
  }

  @override
  Future<void> logInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(
      const Duration(seconds: 1),
    ); // Simulate network request

    if (password == 'error') {
      throw Exception('Invalid credentials');
    }

    _controller.add(_mockUser);
  }

  @override
  Future<void> logOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _controller.add(User.empty);
  }
}
