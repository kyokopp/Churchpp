import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:o_cajado/models/sermon.dart';
import 'package:o_cajado/providers/sermon_providers.dart';

void main() {
  test('sermons can share texto, tags, date, and body content', () async {
    final db = await databaseFactoryMemory.openDatabase('reuse-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final firstId = await repo.createSermon();
    final secondId = await repo.createSermon();
    final first = (await repo.getById(firstId))!
      ..title = 'Tema compartilhado A'
      ..texto = 'Romanos'
      ..tags = ['fé', 'graça']
      ..bodyJson = '[{"insert":"Texto compartilhado\\n"}]';
    final second = (await repo.getById(secondId))!
      ..title = 'Tema compartilhado B'
      ..texto = 'Romanos'
      ..tags = ['fé', 'graça']
      ..scheduledDate = first.scheduledDate
      ..bodyJson = first.bodyJson;

    await repo.saveSermon(first);
    await repo.saveSermon(second);

    final sermons = await repo.getAll();
    final sharedCount = sermons
        .where(
          (s) =>
              s.texto == 'Romanos' &&
              s.tags.join('|') == 'fé|graça' &&
              s.scheduledDate == first.scheduledDate &&
              s.bodyJson == first.bodyJson,
        )
        .length;

    expect(sharedCount, 2);
    await db.close();
  });

  test('new sermons receive sequential integer IDs starting at 1', () async {
    final db = await databaseFactoryMemory.openDatabase('sequential-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final firstRecordId = await repo.createSermon();
    final secondRecordId = await repo.createSermon();

    expect((await repo.getById(firstRecordId))!.sermonId, 1);
    expect((await repo.getById(secondRecordId))!.sermonId, 2);
    await db.close();
  });

  test('permanent delete recycles the lowest available sermon ID', () async {
    final db = await databaseFactoryMemory.openDatabase('id-reuse-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final firstRecordId = await repo.createSermon();
    final secondRecordId = await repo.createSermon();
    await repo.deleteSermon(firstRecordId);

    final thirdRecordId = await repo.createSermon();

    expect((await repo.getById(secondRecordId))!.sermonId, 2);
    expect((await repo.getById(thirdRecordId))!.sermonId, 1);
    await db.close();
  });

  test('trash does not release sermon ID', () async {
    final db = await databaseFactoryMemory.openDatabase('trash-reserve-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final firstRecordId = await repo.createSermon();
    final first = (await repo.getById(firstRecordId))!;
    await repo.moveToTrash(first);

    final secondRecordId = await repo.createSermon();

    expect(await repo.sermonIdExists(1), isTrue);
    expect((await repo.getById(secondRecordId))!.sermonId, 2);
    await db.close();
  });

  test('createAndSaveSermon reassigns conflicting imported IDs', () async {
    final db = await databaseFactoryMemory.openDatabase('conflict-import-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final existingRecordId = await repo.createSermon();
    final importedId = await repo.createAndSaveSermon(
      Sermon(
        sermonId: 1,
        title: 'Tema importado',
        texto: 'Texto importado',
        bodyJson: null,
      ),
      reassignOnConflict: true,
    );

    expect((await repo.getById(existingRecordId))!.sermonId, 1);
    expect((await repo.getById(importedId))!.sermonId, 2);
    await db.close();
  });

  test('toMap stores texto key and does not write legacy series key', () {
    final map = Sermon(sermonId: 1, texto: 'João 3:16').toMap();

    expect(map['texto'], 'João 3:16');
    expect(map.containsKey('series'), isFalse);
  });
  test(
    'moveAllSermonsToTrash moves every sermon without deleting data',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'move-all-sermons-to-trash-test',
      );
      final repo = SermonRepository(db);
      await repo.ensureMigrations();

      final firstId = await repo.createAndSaveSermon(
        Sermon(
          sermonId: 1,
          title: 'Pregado',
          deliveryHistory: [DateTime(2026, 5, 1), DateTime(2026, 5, 8)],
        ),
      );
      final secondId = await repo.createAndSaveSermon(
        Sermon(
          sermonId: 2,
          title: 'Tambem pregado',
          deliveryHistory: [DateTime(2026, 5, 15)],
        ),
      );

      await repo.moveAllSermonsToTrash();

      final first = (await repo.getById(firstId))!;
      final second = (await repo.getById(secondId))!;
      expect(first.isTrashed, isTrue);
      expect(second.isTrashed, isTrue);
      expect(first.isArchived, isFalse);
      expect(second.isArchived, isFalse);
      expect(first.deliveryHistory, hasLength(2));
      expect(second.deliveryHistory, hasLength(1));
      expect(await repo.getTrashed(), hasLength(2));
      await db.close();
    },
  );

  test('watchSermons emits when sermon records change', () async {
    final db = await databaseFactoryMemory.openDatabase('watch-sermons-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final emissions = <int>[];
    final sub = repo.watchSermons().listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    final id = await repo.createSermon();
    await Future<void>.delayed(Duration.zero);
    await repo.deleteSermon(id);
    await Future<void>.delayed(Duration.zero);

    expect(emissions.length, greaterThanOrEqualTo(2));
    await sub.cancel();
    await db.close();
  });

  test(
    'getFilteredPage returns stable pages without eager full-list callers',
    () async {
      final db = await databaseFactoryMemory.openDatabase('paged-list-test');
      final repo = SermonRepository(db);
      await repo.ensureMigrations();

      for (var i = 1; i <= 30; i++) {
        await repo.createAndSaveSermon(
          Sermon(
            sermonId: i,
            title: 'Tema $i',
            texto: i.isEven ? 'João' : null,
          ),
        );
      }

      final firstPage = await repo.getFilteredPage(limit: 25, offset: 0);
      final secondPage = await repo.getFilteredPage(limit: 25, offset: 25);
      final textoPage = await repo.getFilteredPage(
        limit: 25,
        offset: 0,
        textoFilter: 'João',
      );

      expect(firstPage, hasLength(25));
      expect(secondPage, hasLength(5));
      expect(
        firstPage
            .map((result) => result.sermon.id)
            .toSet()
            .intersection(secondPage.map((result) => result.sermon.id).toSet()),
        isEmpty,
      );
      expect(textoPage, hasLength(15));
      expect(
        textoPage.every((result) => result.sermon.texto == 'João'),
        isTrue,
      );
      await db.close();
    },
  );

  test(
    'pagination handles 200 plus sermons without overlapping pages',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'large-pagination-test',
      );
      final repo = SermonRepository(db);
      await repo.ensureMigrations();

      for (var i = 1; i <= 210; i++) {
        await repo.createAndSaveSermon(Sermon(sermonId: i, title: 'Tema $i'));
      }

      final seen = <int>{};
      for (var offset = 0; offset < 210; offset += 25) {
        final page = await repo.getFilteredPage(limit: 25, offset: offset);
        expect(page.length, offset == 200 ? 10 : 25);
        for (final result in page) {
          expect(seen.add(result.sermon.id!), isTrue);
        }
      }

      expect(seen, hasLength(210));
      await db.close();
    },
  );

  test('bulk actions update selected sermons together', () async {
    final db = await databaseFactoryMemory.openDatabase('bulk-actions-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final firstId = await repo.createAndSaveSermon(
      Sermon(sermonId: 1, title: 'Primeiro'),
    );
    final secondId = await repo.createAndSaveSermon(
      Sermon(sermonId: 2, title: 'Segundo'),
    );
    final thirdId = await repo.createAndSaveSermon(
      Sermon(sermonId: 3, title: 'Terceiro'),
    );

    await repo.cycleStatusMany([firstId, secondId]);
    expect((await repo.getById(firstId))!.status, SermonStatus.ready);
    expect((await repo.getById(secondId))!.status, SermonStatus.ready);
    expect((await repo.getById(thirdId))!.status, SermonStatus.draft);

    await repo.moveToTrashMany([firstId, secondId]);
    expect(await repo.getTrashed(), hasLength(2));

    await repo.restoreMany([firstId]);
    expect((await repo.getById(firstId))!.isTrashed, isFalse);
    expect((await repo.getById(secondId))!.isTrashed, isTrue);

    await repo.deleteMany([secondId]);
    expect(await repo.getById(secondId), isNull);
    final recycledId = await repo.createSermon();
    expect((await repo.getById(recycledId))!.sermonId, 2);
    await db.close();
  });
}
