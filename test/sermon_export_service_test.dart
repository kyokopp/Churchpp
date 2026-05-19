import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_cajado/models/sermon.dart';
import 'package:o_cajado/services/sermon_export_service.dart';

void main() {
  test(
    'builds xlsx with locked import-compatible columns and plain body text',
    () {
      final bytes = SermonExportService.buildWorkbookBytes([
        Sermon(
          sermonId: 7,
          title: '  Tema exportado  ',
          scheduledDate: DateTime(2026, 5, 16),
          texto: '  João 3:16  ',
          bodyJson:
              '[{"insert":"Primeira linha\\n"},{"insert":"Segunda linha\\n","attributes":{"bold":true}}]',
        ),
        Sermon(sermonId: 8, title: 'Sem data', bodyJson: null),
      ]);

      final sheet = Excel.decodeBytes(bytes).sheets.values.first;

      expect(_text(sheet, 0, 0), 'ID');
      expect(_text(sheet, 0, 1), 'Tema');
      expect(_text(sheet, 0, 2), 'Data');
      expect(_text(sheet, 0, 3), 'Texto');
      expect(_text(sheet, 0, 4), 'Conteúdo Principal');
      expect(_text(sheet, 1, 0), '7');
      expect(_text(sheet, 1, 1), 'Tema exportado');
      expect(_text(sheet, 1, 2), '16/05/2026');
      expect(_text(sheet, 1, 3), 'João 3:16');
      expect(_text(sheet, 1, 4), 'Primeira linha\nSegunda linha');
      expect(_text(sheet, 2, 2), '');
      expect(_text(sheet, 2, 4), '');
    },
  );

  test('default filename uses requested backup pattern', () {
    expect(
      SermonExportService.defaultFileName(DateTime(2026, 5, 16)),
      'OCajado_backup_16-05-2026.xlsx',
    );
  });
}

String _text(Sheet sheet, int row, int column) {
  final value = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
      .value;
  return switch (value) {
    null => '',
    TextCellValue(:final value) => value.text ?? '',
    IntCellValue(:final value) => value.toString(),
    DoubleCellValue(:final value) => value.toString(),
    _ => value.toString(),
  };
}
