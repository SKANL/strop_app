import 'dart:async';
import 'package:flutter/material.dart' as m show TextInputType;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:strop_app/presentation/auth/bloc/login_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(sl<AuthRepository>()),
      child: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state.status == LoginStatus.success) {
            context.go('/');
          }
        },
        child: Scaffold(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: BlocBuilder<LoginCubit, LoginState>(
                builder: (context, state) {
                  return Column(
                    // ... existing column content ...
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Welcome Back').sans.x2Large.bold.textCenter,
                      const Gap(8),
                      const Text(
                        'Enter your credentials to access your account',
                      ).sans.muted.textCenter,
                      const Gap(32),
                      TextField(
                        controller: _emailController,
                        placeholder: const Text('Email'),
                        keyboardType: m.TextInputType.emailAddress,
                      ),
                      const Gap(16),
                      TextField(
                        controller: _passwordController,
                        placeholder: const Text('Password'),
                        obscureText: true,
                      ),
                      const Gap(24),
                      Button(
                        style: const ButtonStyle.primary(),
                        onPressed: state.status == LoginStatus.loading
                            ? null
                            : () {
                                unawaited(
                                  context
                                      .read<LoginCubit>()
                                      .logInWithEmailAndPassword(
                                        _emailController.text,
                                        _passwordController.text,
                                      ),
                                );
                              },
                        child: state.status == LoginStatus.loading
                            ? const CircularProgressIndicator()
                            : const Text('Sign In'),
                      ),
                      if (state.status == LoginStatus.failure) ...[
                        const Gap(16),
                        Text(
                          state.errorMessage ?? 'Login failed',
                        ).sans.muted.textCenter,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
