import 'dart:async';

import 'package:flutter/material.dart' as m show TextInputAction, TextInputType;
import 'package:flutter_animate/flutter_animate.dart';
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String _friendlyError(String? raw) {
    if (raw == null) return 'Credenciales incorrectas. Intenta de nuevo.';
    if (raw.contains('invalid_credentials') || raw.contains('Invalid login')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'Sin conexión. Verifica tu red e intenta de nuevo.';
    }
    return 'Error al iniciar sesión. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return BlocProvider(
      create: (context) => LoginCubit(sl<AuthRepository>()),
      child: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state.status == LoginStatus.success) {
            context.go('/');
          }
        },
        child: Scaffold(
          child: SingleChildScrollView(
            child: SizedBox(
              height: screenHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand hero zone ──────────────────────────────────────
                  Container(
                    height: screenHeight * 0.35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.78),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(child: _StropLogo()),
                  ),

                  // ── Login form ───────────────────────────────────────────
                  Expanded(
                    child: BlocBuilder<LoginCubit, LoginState>(
                      builder: (context, state) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Bienvenido').sans.xLarge.bold,
                              const Gap(4),
                              const Text(
                                'Ingresa tus credenciales para continuar',
                              ).sans.muted,
                              const Gap(32),

                              // Email
                              Semantics(
                                label: 'Correo electrónico',
                                child: TextField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  placeholder: const Text('Correo electrónico'),
                                  keyboardType: m.TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: m.TextInputAction.next,
                                  onSubmitted: (_) =>
                                      _passwordFocusNode.requestFocus(),
                                ),
                              ),
                              const Gap(16),

                              // Password with visibility toggle (Stack overlay)
                              Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  Semantics(
                                    label: 'Contraseña',
                                    child: TextField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      placeholder: const Text('Contraseña'),
                                      obscureText: _obscurePassword,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      textInputAction: m.TextInputAction.done,
                                      onSubmitted: (_) {
                                        if (state.status !=
                                            LoginStatus.loading) {
                                          unawaited(
                                            context
                                                .read<LoginCubit>()
                                                .logInWithEmailAndPassword(
                                                  _emailController.text,
                                                  _passwordController.text,
                                                ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: _obscurePassword
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    child: IconButton(
                                      variance: ButtonVariance.ghost,
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Gap(24),

                              // Forgot password link
                              Align(
                                alignment: Alignment.centerRight,
                                child: Button(
                                  style: const ButtonStyle.ghost(),
                                  onPressed: () => showToast(
                                    context: context,
                                    builder: (ctx, overlay) => const Card(
                                      child: Text(
                                        'Recuperación de contraseña próximamente.',
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                              const Gap(16),

                              // Error banner
                              if (state.status == LoginStatus.failure) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.destructive
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.destructive
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 16,
                                        color: theme.colorScheme.destructive,
                                      ),
                                      const Gap(8),
                                      Expanded(
                                        child: Text(
                                          _friendlyError(state.errorMessage),
                                          style: TextStyle(
                                            color:
                                                theme.colorScheme.destructive,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().shake().fadeIn(),
                                const Gap(16),
                              ],

                              // Sign In CTA
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
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Iniciar Sesión'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// STROP wordmark — shown in the brand hero zone.
class _StropLogo extends StatelessWidget {
  const _StropLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.construction_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        const Gap(12),
        const Text(
          'STROP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        const Gap(4),
        Text(
          'Plataforma operativa de construcción',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
