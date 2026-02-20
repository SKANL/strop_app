import 'package:strop_app/domain/entities/user.dart';

abstract class AuthRepository {
  Stream<User> get user;
  Future<User> get currentUser;
  Future<void> logInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> logOut();
}
