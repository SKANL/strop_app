import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strop_app/core/network/connectivity_service.dart';
import 'package:strop_app/core/network/dio_client.dart';
import 'package:strop_app/core/network/network_info.dart';
import 'package:strop_app/core/network/token_provider.dart';
import 'package:strop_app/core/services/cache_service.dart';
import 'package:strop_app/core/services/location_service.dart';
import 'package:strop_app/data/datasources/local/local_database.dart';
import 'package:strop_app/data/datasources/sync_service.dart';
import 'package:strop_app/data/repositories/auth_repository_impl.dart';
import 'package:strop_app/data/repositories/incident_repository_impl.dart';
import 'package:strop_app/data/repositories/mock_project_repository.dart';
import 'package:strop_app/data/repositories/mock_user_repository.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:strop_app/domain/repositories/user_repository.dart';
import 'package:strop_app/presentation/auth/bloc/auth_bloc.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl
    ..registerLazySingleton(() => sharedPreferences)
    // Dio
    // Supabase & Network
    ..registerLazySingleton(() => Supabase.instance.client)
    ..registerLazySingleton(() => SupabaseTokenProvider(sl()))
    ..registerLazySingleton(
      () => DioClient(sl<SupabaseTokenProvider>().getAccessToken),
    )
    // Register Dio instance from DioClient
    ..registerLazySingleton<Dio>(() => sl<DioClient>().dio)
    // Connectivity
    ..registerLazySingleton(Connectivity.new)
    ..registerLazySingleton(() => ConnectivityService(sl()))
    //! Data Sources
    ..registerLazySingleton(() => LocalDatabase.instance)
    // Sync Service
    ..registerLazySingleton(() => SyncService(sl(), sl(), sl()))
    //! Core
    ..registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()))
    ..registerLazySingleton(LocationService.new)
    ..registerLazySingleton(CacheService.new)
    //! Features - Auth
    // Bloc
    ..registerFactory(() => AuthBloc(authRepository: sl()))
    ..registerFactory(() => InboxBloc(incidentRepository: sl()))
    // Repository
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()))
    //! Features - Core Data
    ..registerLazySingleton<IncidentRepository>(
      () => IncidentRepositoryImpl(sl(), sl()),
    ) // Assuming SyncService injection or similar
    ..registerLazySingleton<ProjectRepository>(
      MockProjectRepository.new,
    ) // Keeping mock for now if not ready
    ..registerLazySingleton<UserRepository>(MockUserRepository.new);
}
