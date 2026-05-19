import '../l10n/app_strings.dart';

enum SermonStatus {
  draft,
  ready,
  delivered;

  String get label {
    switch (this) {
      case SermonStatus.draft:
        return AppStrings.statusDraft;
      case SermonStatus.ready:
        return AppStrings.statusReady;
      case SermonStatus.delivered:
        return AppStrings.statusDelivered;
    }
  }

  static SermonStatus fromString(String val) {
    return SermonStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => SermonStatus.draft,
    );
  }
}

class Sermon {
  int? id;
  int sermonId;
  String title;
  String? bodyJson;
  List<String> tags;
  String? texto;
  DateTime? scheduledDate;
  SermonStatus status;
  bool isPinned;
  bool isArchived;
  bool isTrashed;
  DateTime createdAt;
  DateTime updatedAt;
  List<DateTime> deliveryHistory;

  Sermon({
    this.id,
    this.sermonId = 0,
    this.title = '',
    this.bodyJson,
    this.tags = const [],
    this.texto,
    this.scheduledDate,
    this.status = SermonStatus.draft,
    this.isPinned = false,
    this.isArchived = false,
    this.isTrashed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deliveryHistory = const [],
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'sermonId': sermonId,
      'title': title,
      'bodyJson': bodyJson,
      'tags': tags,
      'texto': texto,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'status': status.name,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'isTrashed': isTrashed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deliveryHistory': deliveryHistory
          .map((d) => d.toIso8601String())
          .toList(),
    };
  }

  factory Sermon.fromMap(int id, Map<String, dynamic> map) {
    return Sermon(
      id: id,
      sermonId: parseSermonId(map['sermonId']) ?? 0,
      title: map['title'] as String? ?? '',
      bodyJson: map['bodyJson'] as String?,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      texto: (map['texto'] as String?) ?? (map['series'] as String?),
      scheduledDate: _parseDate(map['scheduledDate']),
      status: SermonStatus.fromString(map['status'] as String? ?? 'draft'),
      isPinned: map['isPinned'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      isTrashed: map['isTrashed'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      deliveryHistory:
          (map['deliveryHistory'] as List<dynamic>?)
              ?.map((d) => DateTime.tryParse(d as String))
              .nonNulls
              .toList() ??
          [],
    );
  }

  Sermon copyWith({
    int? id,
    int? sermonId,
    String? title,
    String? bodyJson,
    List<String>? tags,
    String? texto,
    DateTime? scheduledDate,
    SermonStatus? status,
    bool? isPinned,
    bool? isArchived,
    bool? isTrashed,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DateTime>? deliveryHistory,
  }) {
    return Sermon(
      id: id ?? this.id,
      sermonId: sermonId ?? this.sermonId,
      title: title ?? this.title,
      bodyJson: bodyJson ?? this.bodyJson,
      tags: tags ?? List<String>.from(this.tags),
      texto: texto ?? this.texto,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryHistory:
          deliveryHistory ?? List<DateTime>.from(this.deliveryHistory),
    );
  }
}

int? parseSermonId(dynamic value) {
  if (value == null) return null;
  if (value is int && value > 0) return value;
  if (value is double && value > 0) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return null;
}
