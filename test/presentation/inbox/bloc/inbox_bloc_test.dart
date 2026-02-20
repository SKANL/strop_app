import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strop_app/domain/entities/incident.dart';
import 'package:strop_app/domain/repositories/incident_repository.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_bloc.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_event.dart';
import 'package:strop_app/presentation/inbox/bloc/inbox_state.dart';

class MockIncidentRepository extends Mock implements IncidentRepository {}

void main() {
  late IncidentRepository incidentRepository;
  late InboxBloc inboxBloc;

  final incidentDate = DateTime(2023);
  final incidents = [
    Incident(
      id: '1',
      title: 'Incident 1',
      description: 'Description 1',
      location: 'Location 1',
      createdAt: incidentDate,
      syncStatus: SyncStatus.synced,
    ),
    Incident(
      id: '2',
      title: 'Incident 2',
      description: 'Description 2',
      location: 'Location 2',
      status: IncidentStatus.inReview,
      priority: IncidentPriority.critical,
      createdAt: incidentDate.add(const Duration(hours: 1)),
    ),
  ];

  setUp(() {
    incidentRepository = MockIncidentRepository();
    when(() => incidentRepository.incidentsStream).thenAnswer(
      (_) => Stream.value(incidents),
    );
    inboxBloc = InboxBloc(incidentRepository: incidentRepository);
  });

  tearDown(() async {
    await inboxBloc.close();
  });

  test('initial state is InboxInitial', () {
    expect(inboxBloc.state, isA<InboxInitial>());
  });

  blocTest<InboxBloc, InboxState>(
    'emits [InboxLoading, InboxLoaded] when SubscribeToIncidents is added',
    build: () => inboxBloc,
    act: (bloc) => bloc.add(SubscribeToIncidents()),
    expect: () => [
      isA<InboxLoading>(),
      isA<InboxLoaded>().having(
        (s) => s.incidents.length,
        'incidents count',
        1, // Only pending by default
      ),
    ],
  );

  blocTest<InboxBloc, InboxState>(
    'filters by tab when ChangeTab is added',
    build: () => inboxBloc,
    seed: () => InboxLoaded(
      incidents: incidents,
      // Initially all (incorrect state but strict check below handles logic)
      currentTab: IncidentStatus.pending,
    ),
    act: (bloc) {
      // Need to populate _allIncidents first via Subscribe or hack?
      // Since _allIncidents is internal, we must call Subscribe first.
      // But blocTest create a new bloc.
      // So let's chain acts.
      bloc
        ..add(SubscribeToIncidents())
        ..add(const ChangeTab(IncidentStatus.inReview));
    },
    skip: 2, // Skip loading and initial load
    expect: () => [
      isA<InboxLoaded>()
          .having(
            (s) => s.currentTab,
            'currentTab',
            IncidentStatus.inReview,
          )
          .having(
            (s) => s.incidents.length,
            'incidents count',
            1,
          )
          .having(
            (s) => s.incidents.first.id,
            'incident id',
            '2',
          ),
    ],
  );

  blocTest<InboxBloc, InboxState>(
    'filters by search query when SearchIncidents is added',
    build: () => inboxBloc,
    act: (bloc) async {
      bloc.add(SubscribeToIncidents());
      // Wait for stream event?
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SearchIncidents('Location 1'));
    },
    skip: 2,
    expect: () => [
      isA<InboxLoaded>()
          .having(
            (s) => s.searchQuery,
            'searchQuery',
            'Location 1',
          )
          .having(
            (s) => s.incidents.length,
            'incidents count',
            1,
          )
          .having(
            (s) => s.incidents.first.id,
            'incident id',
            '1',
          ),
    ],
  );
}
