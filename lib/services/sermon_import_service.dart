import 'dart:convert';

import 'package:excel/excel.dart';

import '../models/sermon.dart';
import '../providers/sermon_providers.dart';

enum SermonImportStage { reading, processing, creating, done }

class SermonImportProgress {
  const SermonImportProgress({
    required this.stage,
    required this.current,
    required this.total,
    this.hasErrors = false,
  });

  final SermonImportStage stage;
  final int current;
  final int total;
  final bool hasErrors;
}

class SermonImportReassignment {
  const SermonImportReassignment({
    required this.rowNumber,
    required this.originalId,
    required this.assignedId,
  });

  final int rowNumber;
  final int? originalId;
  final int assignedId;
}

class SermonImportResult {
  const SermonImportResult({
    required this.importedCount,
    required this.errorCount,
    required this.reassignments,
    this.cancelled = false,
  });

  final int importedCount;
  final int errorCount;
  final List<SermonImportReassignment> reassignments;
  final bool cancelled;

  bool get hasErrors => errorCount > 0;
}

typedef SermonImportProgressCallback =
    void Function(SermonImportProgress progress);

class SermonImportCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class SermonImportService {
  SermonImportService(this._repo);

  final SermonRepository _repo;

  Future<SermonImportResult> importBytes(
    List<int> bytes, {
    SermonImportProgressCallback? onProgress,
    SermonImportCancelToken? cancelToken,
  }) async {
    onProgress?.call(
      const SermonImportProgress(
        stage: SermonImportStage.reading,
        current: 0,
        total: 0,
      ),
    );

    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      return const SermonImportResult(
        importedCount: 0,
        errorCount: 1,
        reassignments: [],
      );
    }
    if (excel.tables.isEmpty) {
      return const SermonImportResult(
        importedCount: 0,
        errorCount: 1,
        reassignments: [],
      );
    }

    final sheet = excel.tables.values.first;
    final dataRows = _dataRows(sheet);

    final parsedRows = <_ParsedImportRow>[];
    var errors = 0;
    for (var i = 0; i < dataRows.length; i++) {
      if (cancelToken?.isCancelled ?? false) {
        return const SermonImportResult(
          importedCount: 0,
          errorCount: 0,
          reassignments: [],
          cancelled: true,
        );
      }
      onProgress?.call(
        SermonImportProgress(
          stage: SermonImportStage.processing,
          current: i + 1,
          total: dataRows.length,
        ),
      );
      try {
        final parsed = _parseRow(dataRows[i], i + 2);
        if (parsed.hasMeaningfulContent) {
          parsedRows.add(parsed);
        }
      } catch (_) {
        errors++;
      }
    }

    var imported = 0;
    final createdRecordIds = <int>[];
    final reassignments = <SermonImportReassignment>[];
    for (var i = 0; i < parsedRows.length; i++) {
      onProgress?.call(
        SermonImportProgress(
          stage: SermonImportStage.creating,
          current: i + 1,
          total: parsedRows.length,
        ),
      );
      if (cancelToken?.isCancelled ?? false) {
        await _repo.deleteMany(createdRecordIds);
        return const SermonImportResult(
          importedCount: 0,
          errorCount: 0,
          reassignments: [],
          cancelled: true,
        );
      }
      final row = parsedRows[i];
      try {
        final sermon = Sermon(
          sermonId: row.preferredId ?? 0,
          title: row.title ?? '',
          scheduledDate: row.date,
          texto: row.texto,
          bodyJson: _plainTextToBodyJson(row.bodyText),
          status: row.status,
          tags: row.tags,
        );
        final recordId = await _repo.createAndSaveSermon(
          sermon,
          reassignOnConflict: true,
        );
        createdRecordIds.add(recordId);
        final saved = await _repo.getById(recordId);
        if (saved != null && saved.sermonId != row.preferredId) {
          reassignments.add(
            SermonImportReassignment(
              rowNumber: row.rowNumber,
              originalId: row.preferredId,
              assignedId: saved.sermonId,
            ),
          );
        }
        imported++;
        if (cancelToken?.isCancelled ?? false) {
          await _repo.deleteMany(createdRecordIds);
          return const SermonImportResult(
            importedCount: 0,
            errorCount: 0,
            reassignments: [],
            cancelled: true,
          );
        }
      } catch (_) {
        errors++;
      }
    }

    onProgress?.call(
      SermonImportProgress(
        stage: SermonImportStage.done,
        current: imported,
        total: parsedRows.length,
      ),
    );

    return SermonImportResult(
      importedCount: imported,
      errorCount: errors,
      reassignments: reassignments,
    );
  }

  List<List<Data?>> _dataRows(Sheet sheet) {
    final rows = sheet.rows;
    if (rows.length <= 1) return const [];

    final result = <List<Data?>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (!_rowHasOriginalValue(row)) {
        if (result.isNotEmpty) break;
        continue;
      }
      result.add(row);
    }
    return result;
  }

  _ParsedImportRow _parseRow(List<Data?> row, int rowNumber) {
    final id = _parseId(_cellValue(row, 0));
    final title = _trimToNull(_parseString(_cellValue(row, 1)));
    final date = _parseDate(_cellValue(row, 2));
    final texto = _trimToNull(_parseString(_cellValue(row, 3)));
    final bodyText = _trimToNull(_parseString(_cellValue(row, 4)));
    final status = _parseStatus(_cellValue(row, 5));
    final tags = _parseTags(_cellValue(row, 6));
    return _ParsedImportRow(
      rowNumber: rowNumber,
      preferredId: id,
      title: title,
      date: date,
      texto: texto,
      bodyText: bodyText,
      status: status,
      tags: tags,
    );
  }

  bool _rowHasOriginalValue(List<Data?> row) {
    for (var index = 0; index <= 4; index++) {
      if (_parseString(_cellValue(row, index)).trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  CellValue? _cellValue(List<Data?> row, int index) {
    if (index >= row.length) return null;
    return row[index]?.value;
  }

  int? _parseId(CellValue? value) {
    return switch (value) {
      null => null,
      IntCellValue(:final value) => value > 0 ? value : null,
      DoubleCellValue(:final value) => value > 0 ? value.toInt() : null,
      TextCellValue(:final value) => parseSermonId(value.text),
      _ => parseSermonId(value.toString()),
    };
  }

  DateTime? _parseDate(CellValue? value) {
    if (value == null) return null;
    if (value case DateCellValue dateValue) {
      return dateValue.asDateTimeLocal();
    }

    final text = _parseString(value).trim();
    if (text.isEmpty) return null;
    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _parseString(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue(:final value) => value.text ?? '',
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      DateCellValue dateValue => DateFormatLike.ddMMyyyy(
        dateValue.asDateTimeLocal(),
      ),
      _ => value.toString(),
    };
  }

  String? _trimToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  SermonStatus _parseStatus(CellValue? value) {
    final normalized = _parseString(value).trim().toLowerCase();
    return switch (normalized) {
      'pronto' => SermonStatus.ready,
      'pregado' => SermonStatus.delivered,
      'rascunho' || '' => SermonStatus.draft,
      _ => SermonStatus.draft,
    };
  }

  List<String> _parseTags(CellValue? value) {
    final raw = _parseString(value).trim();
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  String? _plainTextToBodyJson(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return jsonEncode([
      {'insert': '${value.trim()}\n'},
    ]);
  }
}

class _ParsedImportRow {
  const _ParsedImportRow({
    required this.rowNumber,
    required this.preferredId,
    required this.title,
    required this.date,
    required this.texto,
    required this.bodyText,
    required this.status,
    required this.tags,
  });

  final int rowNumber;
  final int? preferredId;
  final String? title;
  final DateTime? date;
  final String? texto;
  final String? bodyText;
  final SermonStatus status;
  final List<String> tags;

  bool get hasMeaningfulContent =>
      preferredId != null ||
      (title != null && title!.isNotEmpty) ||
      date != null ||
      (texto != null && texto!.isNotEmpty) ||
      (bodyText != null && bodyText!.isNotEmpty);
}

class DateFormatLike {
  const DateFormatLike._();

  static String ddMMyyyy(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
