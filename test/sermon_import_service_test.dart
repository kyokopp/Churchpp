import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:o_cajado/providers/sermon_providers.dart';
import 'package:o_cajado/models/sermon.dart';
import 'package:o_cajado/services/sermon_export_service.dart';
import 'package:o_cajado/services/sermon_import_service.dart';

void main() {
  test(
    'imports first sheet, trims fields, parses dates, and skips blank rows',
    () async {
      final db = await databaseFactoryMemory.openDatabase('import-basic-test');
      final repo = SermonRepository(db);
      await repo.ensureMigrations();

      final bytes = _workbookBytes([
        ['ID', 'Tema', 'Data', 'Texto'],
        [1.0, '  Graça  ', '14/05/2026', '  João 3:16  '],
        [2.0, 'Esperança', DateTime(2026, 5, 15), 'Romanos 5'],
        [null, null, null, null],
      ]);

      final result = await SermonImportService(repo).importBytes(bytes);
      final sermons = await repo.getAll();

      expect(result.importedCount, 2);
      expect(result.errorCount, 0);
      expect(sermons.map((s) => s.sermonId), [2, 1]);
      expect(sermons.firstWhere((s) => s.sermonId == 1).title, 'Graça');
      expect(sermons.firstWhere((s) => s.sermonId == 1).texto, 'João 3:16');
      expect(
        sermons.firstWhere((s) => s.sermonId == 1).scheduledDate,
        DateTime(2026, 5, 14),
      );
      expect(
        sermons.firstWhere((s) => s.sermonId == 2).scheduledDate,
        DateTime(2026, 5, 15),
      );
      expect(sermons.every((s) => s.bodyJson == null), isTrue);
      await db.close();
    },
  );

  test(
    'conflicting and invalid import IDs receive next available IDs',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'import-conflict-test',
      );
      final repo = SermonRepository(db);
      await repo.ensureMigrations();
      await repo.createSermon();

      final bytes = _workbookBytes([
        ['ID', 'Tema', 'Data', 'Texto'],
        [1.0, 'Conflito', '14/05/2026', 'Texto A'],
        ['abc', 'Sem ID válido', 'data inválida', 'Texto B'],
      ]);

      final result = await SermonImportService(repo).importBytes(bytes);
      final sermons = await repo.getAll();

      expect(result.importedCount, 2);
      expect(result.reassignments.length, 2);
      expect(sermons.map((s) => s.sermonId).toSet(), {1, 2, 3});
      expect(sermons.firstWhere((s) => s.title == 'Conflito').sermonId, 2);
      expect(sermons.firstWhere((s) => s.title == 'Sem ID válido').sermonId, 3);
      expect(
        sermons.firstWhere((s) => s.title == 'Sem ID válido').scheduledDate,
        isNull,
      );
      await db.close();
    },
  );

  test('exported main body text is preserved when reimported', () async {
    final sourceDb = await databaseFactoryMemory.openDatabase(
      'import-export-source-test',
    );
    final sourceRepo = SermonRepository(sourceDb);
    await sourceRepo.ensureMigrations();
    await sourceRepo.createAndSaveSermon(
      Sermon(
        sermonId: 1,
        title: 'Tema com corpo',
        texto: 'Joao 10',
        bodyJson: '[{"insert":"Conteudo principal\\n"}]',
      ),
    );

    final bytes = SermonExportService.buildWorkbookBytes(
      await sourceRepo.getExportSermons(),
    );
    await sourceDb.close();

    final targetDb = await databaseFactoryMemory.openDatabase(
      'import-export-target-test',
    );
    final targetRepo = SermonRepository(targetDb);
    await targetRepo.ensureMigrations();

    final result = await SermonImportService(targetRepo).importBytes(bytes);
    final imported = await targetRepo.getAll();

    expect(result.importedCount, 1);
    expect(
      SermonExportService.bodyJsonToPlainText(imported.single.bodyJson),
      'Conteudo principal',
    );
    await targetDb.close();
  });

  test('imports optional status and tags columns when present', () async {
    final db = await databaseFactoryMemory.openDatabase(
      'import-status-tags-test',
    );
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final bytes = _workbookBytes([
      ['ID', 'Tema', 'Data', 'Texto', 'Conteúdo Principal', 'Status', 'Tags'],
      [
        1.0,
        'Com status',
        null,
        'João 10',
        '',
        '  pReGaDo  ',
        'Psalm23, Comfort, , Sermão Especial ',
      ],
      [2.0, 'Status inválido', null, '', '', 'desconhecido', ''],
    ]);

    final result = await SermonImportService(repo).importBytes(bytes);
    final sermons = await repo.getAll();

    expect(result.importedCount, 2);
    final delivered = sermons.firstWhere((s) => s.sermonId == 1);
    expect(delivered.status, SermonStatus.delivered);
    expect(delivered.tags, ['Psalm23', 'Comfort', 'Sermão Especial']);

    final fallback = sermons.firstWhere((s) => s.sermonId == 2);
    expect(fallback.status, SermonStatus.draft);
    expect(fallback.tags, isEmpty);
    await db.close();
  });

  test('old five-column imports default status and tags safely', () async {
    final db = await databaseFactoryMemory.openDatabase(
      'import-backward-compatible-test',
    );
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final bytes = _workbookBytes([
      ['ID', 'Tema', 'Data', 'Texto', 'Conteúdo Principal'],
      [1.0, 'Formato antigo', null, '', 'Conteúdo'],
    ]);

    final result = await SermonImportService(repo).importBytes(bytes);
    final imported = (await repo.getAll()).single;

    expect(result.importedCount, 1);
    expect(imported.status, SermonStatus.draft);
    expect(imported.tags, isEmpty);
    await db.close();
  });

  test(
    'malformed xlsx bytes return an import error instead of throwing',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'malformed-import-test',
      );
      final repo = SermonRepository(db);
      await repo.ensureMigrations();

      final result = await SermonImportService(repo).importBytes([1, 2, 3, 4]);

      expect(result.importedCount, 0);
      expect(result.errorCount, 1);
      await db.close();
    },
  );

  test('status and tags alone never create blank sermons', () async {
    final db = await databaseFactoryMemory.openDatabase('id-only-import-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();

    final bytes = _workbookBytes([
      ['ID', 'Tema', 'Data', 'Texto', 'Conteúdo Principal', 'Status', 'Tags'],
      [null, '   ', null, ' ', '', 'Pregado', 'Tag solta'],
      [2.0, 'Tema válido', null, '', ''],
    ]);

    final result = await SermonImportService(repo).importBytes(bytes);
    final sermons = await repo.getAll();

    expect(result.importedCount, 1);
    expect(sermons, hasLength(1));
    expect(sermons.single.title, 'Tema válido');
    await db.close();
  });

  test('cancelled imports roll back partially created sermons', () async {
    final db = await databaseFactoryMemory.openDatabase('cancel-import-test');
    final repo = SermonRepository(db);
    await repo.ensureMigrations();
    final cancelToken = SermonImportCancelToken();

    final bytes = _workbookBytes([
      ['ID', 'Tema', 'Data', 'Texto', 'Conteúdo Principal'],
      [1.0, 'Primeiro', null, '', ''],
      [2.0, 'Segundo', null, '', ''],
    ]);

    final result = await SermonImportService(repo).importBytes(
      bytes,
      cancelToken: cancelToken,
      onProgress: (progress) {
        if (progress.stage == SermonImportStage.creating &&
            progress.current == 2) {
          cancelToken.cancel();
        }
      },
    );

    expect(result.cancelled, isTrue);
    expect(result.importedCount, 0);
    expect(await repo.getAll(), isEmpty);
    await db.close();
  });
}

List<int> _workbookBytes(List<List<Object?>> rows) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final value = row[columnIndex];
      sheet.updateCell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
        _cellValue(value),
      );
    }
  }
  return excel.save()!;
}

CellValue? _cellValue(Object? value) {
  return switch (value) {
    null => null,
    String value => TextCellValue(value),
    int value => IntCellValue(value),
    double value => DoubleCellValue(value),
    DateTime value => DateCellValue.fromDateTime(value),
    _ => TextCellValue(value.toString()),
  };
}
