import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strop_app/core/services/location_service.dart';
import 'package:strop_app/domain/entities/project.dart';
import 'package:strop_app/domain/repositories/project_repository.dart';
import 'package:strop_app/presentation/home/bloc/project_bloc.dart';
import 'package:strop_app/presentation/home/bloc/project_event.dart';
import 'package:strop_app/presentation/home/bloc/project_state.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  late ProjectRepository projectRepository;
  late LocationService locationService;
  late ProjectBloc projectBloc;

  final projects = [
    const Project(
      id: '1',
      name: 'Project 1',
      address: 'Address 1',
      latitude: 10,
      longitude: 10,
    ),
    const Project(
      id: '2',
      name: 'Project 2',
      address: 'Address 2',
      latitude: 20,
      longitude: 20,
    ),
  ];

  final position = Position(
    longitude: 10,
    latitude: 10,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );

  setUp(() {
    projectRepository = MockProjectRepository();
    locationService = MockLocationService();
    projectBloc = ProjectBloc(
      projectRepository: projectRepository,
      locationService: locationService,
    );
  });

  tearDown(() async {
    await projectBloc.close();
  });

  test('initial state is ProjectInitial', () {
    expect(projectBloc.state, isA<ProjectInitial>());
  });

  blocTest<ProjectBloc, ProjectState>(
    'emits [ProjectLoading, ProjectLoaded] with sorted projects '
    'when location is available',
    setUp: () {
      when(
        () => locationService.getCurrentPosition(),
      ).thenAnswer((_) async => position);
      when(
        () => projectRepository.getProjects(),
      ).thenAnswer((_) async => projects);
      when(
        () => locationService.calculateDistance(any(), any(), 10, 10),
      ).thenReturn(0);
      when(
        () => locationService.calculateDistance(any(), any(), 20, 20),
      ).thenReturn(100);
    },
    build: () => projectBloc,
    act: (bloc) => bloc.add(LoadProjects()),
    expect: () => [
      isA<ProjectLoading>(),
      isA<ProjectLoaded>()
          .having((s) => s.userLocation, 'userLocation', isNotNull)
          .having(
            (s) => s.projects.first.id,
            'first project',
            '1',
          ) // Distance 0
          .having((s) => s.distances.length, 'distances count', 2),
    ],
  );

  blocTest<ProjectBloc, ProjectState>(
    'emits [ProjectLoading, ProjectLoaded] without sorting '
    'when location is unavailable',
    setUp: () {
      when(
        () => locationService.getCurrentPosition(),
      ).thenAnswer((_) async => null);
      when(
        () => projectRepository.getProjects(),
      ).thenAnswer((_) async => projects);
    },
    build: () => projectBloc,
    act: (bloc) => bloc.add(LoadProjects()),
    expect: () => [
      isA<ProjectLoading>(),
      isA<ProjectLoaded>()
          .having((s) => s.userLocation, 'userLocation', isNull)
          .having((s) => s.distances, 'distances', isEmpty),
    ],
  );

  blocTest<ProjectBloc, ProjectState>(
    'emits [ProjectLoading, ProjectError] when loading fails',
    setUp: () {
      when(
        () => locationService.getCurrentPosition(),
      ).thenAnswer((_) async => null);
      when(
        () => projectRepository.getProjects(),
      ).thenThrow(Exception('Failed to load'));
    },
    build: () => projectBloc,
    act: (bloc) => bloc.add(LoadProjects()),
    expect: () => [
      isA<ProjectLoading>(),
      isA<ProjectError>().having(
        (s) => s.message,
        'message',
        contains('Failed to load'),
      ),
    ],
  );
}
