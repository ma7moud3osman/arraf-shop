import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '_fakes.dart';

void main() {
  late FakeAuditRepository repo;
  late AuditsListProvider provider;

  setUp(() {
    repo = FakeAuditRepository();
    provider = AuditsListProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  test('initial state is AppStatus.initial with an empty list', () {
    expect(provider.status, AppStatus.initial);
    expect(provider.sessions, isEmpty);
    expect(provider.errorMessage, isNull);
  });

  test('load: sets loading then success with paged items', () async {
    final sessionA = makeSession(uuid: 'a');
    final sessionB = makeSession(uuid: 'b');
    repo.listHandler =
        ({int page = 1, String? status}) async => Right(
          Paginated(
            items: [sessionA, sessionB],
            currentPage: 1,
            perPage: 20,
            total: 2,
            lastPage: 1,
          ),
        );

    final seen = <AppStatus>[];
    provider.addListener(() => seen.add(provider.status));

    await provider.load();

    expect(seen.first, AppStatus.loading);
    expect(provider.status, AppStatus.success);
    expect(provider.sessions.map((s) => s.uuid), ['a', 'b']);
  });

  test('load: sets failure + errorMessage on Left', () async {
    repo.listHandler =
        ({int page = 1, String? status}) async =>
            const Left(ServerFailure('network down'));

    await provider.load();

    expect(provider.status, AppStatus.failure);
    expect(provider.errorMessage, 'network down');
    expect(provider.sessions, isEmpty);
  });

  test('refresh: replaces the list with the new fetch', () async {
    repo.listHandler =
        ({int page = 1, String? status}) async => Right(
          Paginated(
            items: [makeSession(uuid: 'old')],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
        );
    await provider.load();
    expect(provider.sessions.single.uuid, 'old');

    repo.listHandler =
        ({int page = 1, String? status}) async => Right(
          Paginated(
            items: [makeSession(uuid: 'new')],
            currentPage: 1,
            perPage: 20,
            total: 1,
            lastPage: 1,
          ),
        );

    await provider.refresh();

    expect(provider.sessions.single.uuid, 'new');
    expect(provider.status, AppStatus.success);
  });

  test(
    'startNew: on success prepends the new session and exposes it',
    () async {
      final existing = makeSession(uuid: 'existing');
      repo.listHandler =
          ({int page = 1, String? status}) async => Right(
            Paginated(
              items: [existing],
              currentPage: 1,
              perPage: 20,
              total: 1,
              lastPage: 1,
            ),
          );
      await provider.load();

      final created = makeSession(uuid: 'brand-new', notes: 'Q2');
      repo.startHandler = ({String? notes}) async => Right(created);

      await provider.startNew(notes: 'Q2');

      expect(provider.startStatus, AppStatus.success);
      expect(provider.sessions.first.uuid, 'brand-new');
      expect(provider.sessions.last.uuid, 'existing');
      expect(provider.lastStarted?.uuid, 'brand-new');
    },
  );

  test('consumeLastStarted returns-and-clears exactly once', () async {
    repo.startHandler =
        ({String? notes}) async => Right(makeSession(uuid: 'x'));
    await provider.startNew();

    expect(provider.consumeLastStarted()?.uuid, 'x');
    expect(provider.consumeLastStarted(), isNull);
  });

  test(
    'startNew: failure sets startStatus=failure + errorMessage, list unchanged',
    () async {
      final existing = makeSession(uuid: 'existing');
      repo.listHandler =
          ({int page = 1, String? status}) async => Right(
            Paginated(
              items: [existing],
              currentPage: 1,
              perPage: 20,
              total: 1,
              lastPage: 1,
            ),
          );
      await provider.load();

      repo.startHandler =
          ({String? notes}) async => const Left(ServerFailure('boom'));

      await provider.startNew(notes: 'x');

      expect(provider.startStatus, AppStatus.failure);
      expect(provider.errorMessage, 'boom');
      expect(provider.sessions.single.uuid, 'existing');
      expect(provider.lastStarted, isNull);
    },
  );
}
