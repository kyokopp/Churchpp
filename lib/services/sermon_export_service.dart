import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/sermon.dart';

class SermonExportService {
  const SermonExportService._();

  static const headers = [
    'ID',
    'Tema',
    'Data',
    'Texto',
    'Conteúdo Principal',
    'Status',
    'Tags',
  ];

  static String defaultFileName([DateTime? now]) {
    final date = DateFormat('dd-MM-yyyy').format(now ?? DateTime.now());
    return 'OCajado_backup_$date.xlsx';
  }

  static Uint8List buildWorkbookBytes(List<Sermon> sermons) {
    final excel = Excel.createExcel();
    final sheet = excel['Sermões'];
    excel.setDefaultSheet('Sermões');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    _writeRow(sheet, 0, headers.map(TextCellValue.new).toList());
    final dateFormat = DateFormat('dd/MM/yyyy');
    for (var index = 0; index < sermons.length; index++) {
      final sermon = sermons[index];
      _writeRow(sheet, index + 1, [
        IntCellValue(sermon.sermonId),
        TextCellValue(sermon.title.trim()),
        TextCellValue(
          sermon.scheduledDate == null
              ? ''
              : dateFormat.format(sermon.scheduledDate!),
        ),
        TextCellValue(sermon.texto?.trim() ?? ''),
        TextCellValue(bodyJsonToPlainText(sermon.bodyJson)),
        TextCellValue(sermon.status.label),
        TextCellValue(sermon.tags.map((tag) => tag.trim()).join(',')),
      ]);
    }

    return Uint8List.fromList(excel.save() ?? const []);
  }

  static String bodyJsonToPlainText(String? bodyJson) {
    if (bodyJson == null || bodyJson.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(bodyJson);
      final buffer = StringBuffer();
      if (decoded is List) {
        for (final op in decoded) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert'] as String);
          }
        }
      }
      return _stripTrailingNewline(buffer.toString());
    } catch (_) {
      return '';
    }
  }

  static String _stripTrailingNewline(String value) {
    var text = value;
    while (text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  static void _writeRow(Sheet sheet, int rowIndex, List<CellValue> values) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
        values[columnIndex],
      );
    }
  }
}
