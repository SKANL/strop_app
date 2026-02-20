import 'dart:async';
import 'package:flutter/material.dart' as m;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:strop_app/app/di/service_locator.dart';
import 'package:strop_app/app/theme.dart';
import 'package:strop_app/core/widgets/connectivity_listener.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:strop_app/l10n/l10n.dart';
import 'package:strop_app/presentation/auth/bloc/auth_bloc.dart';
import 'package:strop_app/presentation/auth/bloc/auth_state.dart';
import 'package:strop_app/presentation/auth/view/login_page.dart';
import 'package:strop_app/presentation/capture/view/camera_page.dart';
import 'package:strop_app/presentation/capture/view/capture_page.dart';
import 'package:strop_app/presentation/home/view/app_shell.dart';
import 'package:strop_app/presentation/home/view/home_page.dart';
import 'package:strop_app/presentation/home/view/project_dashboard_page.dart';
import 'package:strop_app/presentation/inbox/view/inbox_page.dart';
import 'package:strop_app/presentation/profile/view/profile_page.dart';

class App extends m.StatelessWidget {
  const App({super.key});

  @override
  m.Widget build(m.BuildContext context) {
    return RepositoryProvider.value(
      value: sl<AuthRepository>(),
      child: BlocProvider(
        create: (context) => AuthBloc(
          authRepository: context.read<AuthRepository>(),
        ),
        child: const AppView(),
      ),
    );
  }
}

class AppView extends m.StatelessWidget {
  const AppView({super.key});

  @override
  m.Widget build(m.BuildContext context) {
    final router = GoRouter(
      initialLocation:
          context.read<AuthBloc>().state.status == AuthStatus.authenticated
          ? '/'
          : '/login',
      refreshListenable: GoRouterRefreshStream(context.read<AuthBloc>().stream),
      redirect: (context, state) {
        final authStatus = context.read<AuthBloc>().state.status;
        final isInLoginPage = state.matchedLocation == '/login';

        if (authStatus != AuthStatus.authenticated) {
          if (isInLoginPage) {
            return null;
          }
          return '/login';
        }

        if (isInLoginPage) {
          return '/';
        }

        return null;
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return ConnectivityListener(child: child);
          },
          routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginPage(),
            ),
            GoRoute(
              path: '/camera',
              builder: (context, state) => const CameraPage(),
            ),
            GoRoute(
              path: '/project-dashboard',
              builder: (context, state) {
                final project = state.extra! as Project;
                return ProjectDashboardPage(project: project);
              },
            ),
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) {
                return AppShell(navigationShell: navigationShell);
              },
              branches: [
                // Home Branch
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (context, state) => const HomePage(),
                    ),
                  ],
                ),
                // Inbox Branch
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/inbox',
                      builder: (context, state) => const InboxPage(),
                    ),
                  ],
                ),
                // Capture Branch
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/capture',
                      builder: (context, state) => const CapturePage(),
                    ),
                  ],
                ),
                // Profile Branch
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/profile',
                      builder: (context, state) => const ProfilePage(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return shadcn.ShadcnApp.router(
      title: 'Strop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        shadcn.ShadcnLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class GoRouterRefreshStream extends m.ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
