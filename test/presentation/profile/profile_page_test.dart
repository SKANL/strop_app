import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strop_app/core/services/cache_service.dart';
import 'package:strop_app/domain/entities/user.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/presentation/auth/bloc/auth_bloc.dart';
import 'package:strop_app/presentation/auth/bloc/auth_event.dart';
import 'package:strop_app/presentation/auth/bloc/auth_state.dart';
import 'package:strop_app/presentation/profile/view/profile_page.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockIncidentRepository extends Mock implements IncidentRepository {}

class MockCacheService extends Mock implements CacheService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockIncidentRepository mockIncidentRepository;
  late MockCacheService mockCacheService;
  late MockSharedPreferences mockSharedPreferences;
  late MockAuthBloc mockAuthBloc;

  setUp(() async {
    mockAuthRepository = MockAuthRepository();
    mockIncidentRepository = MockIncidentRepository();
    mockCacheService = MockCacheService();
    mockSharedPreferences = MockSharedPreferences();
    mockAuthBloc = MockAuthBloc();

    final sl = GetIt.instance;
    await sl.reset();
    sl
      ..registerSingleton<AuthRepository>(mockAuthRepository)
      ..registerSingleton<IncidentRepository>(mockIncidentRepository)
      ..registerSingleton<CacheService>(mockCacheService)
      ..registerSingleton<SharedPreferences>(mockSharedPreferences);

    when(
      () => mockIncidentRepository.incidentsStream,
    ).thenAnswer((_) => Stream.value([]));
    when(
      () => mockIncidentRepository.getPendingIncidentCount(),
    ).thenAnswer((_) async => 0);
    when(
      () => mockCacheService.getCacheSize(),
    ).thenAnswer((_) async => 1024 * 1024 * 50); // 50MB
    when(() => mockSharedPreferences.getBool(any())).thenReturn(true);
  });

  Widget createWidget() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const shadcn.ShadcnApp(
          home: ProfilePage(),
        ),
      ),
    );
  }

  testWidgets('ProfilePage renders correctly with user info', (tester) async {
    const user = User(id: '123', email: 'test@strop.com');
    when(
      () => mockAuthBloc.state,
    ).thenReturn(const AuthState.authenticated(user));

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('test@strop.com'), findsOneWidget);
    expect(find.text('Field Worker'), findsOneWidget);
  });

  testWidgets('ProfilePage shows cache size', (tester) async {
    const user = User(id: '123', email: 'test@strop.com');
    when(
      () => mockAuthBloc.state,
    ).thenReturn(const AuthState.authenticated(user));

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // 50MB formatted
    expect(find.text('50.0 MB'), findsOneWidget);
    expect(find.text('Local Cache'), findsOneWidget);
  });

  testWidgets('ProfilePage shows offline settings', (tester) async {
    const user = User(id: '123', email: 'test@strop.com');
    when(
      () => mockAuthBloc.state,
    ).thenReturn(const AuthState.authenticated(user));

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Auto-download Media'), findsOneWidget);
    expect(find.byType(shadcn.Switch), findsOneWidget);
  });
}
