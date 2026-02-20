import 'package:equatable/equatable.dart';
import 'package:strop_app/domain/entities/user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthUserChanged extends AuthEvent {
  const AuthUserChanged(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

class AuthLogoutRequested extends AuthEvent {}
