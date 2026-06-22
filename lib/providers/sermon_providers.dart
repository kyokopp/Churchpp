import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sembast/sembast.dart';

import '../models/sermon.dart';
import '../services/database_service.dart';

final _sermonStore = intMapStoreFactory.store('sermons');
final _metadataStore = stringMapStoreFactory.store('metadata');
const _availableSermonIdsKey = 'available_sermon_ids';

final databaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseService.instance;
});

class DuplicateSermonIdException implements Exception {
  const DuplicateSermonIdException(this.sermonId);

  final int sermonId;

  @override
  String toString() => 'ID de sermão duplicado: $sermonId';
}

enum SermonSearchMatch { id, title, texto, date, tag, status }

class SermonSearchResult {
  const SermonSearchResult({required this.sermon, required this.matches});

  final Sermon sermon;
  final Set<SermonSearchMatch> matches;
}

class SermonRepository {
  SermonRepository(this._db);

  final Database _db;

  Future<void> ensureMigrations() async {
    final records = await _sermonStore.find(_db);
    final usedIds = <int>{};
    final availableIds = await _readAvailableIds();

    for (final record in records) {
      final map = Map<String, dynamic>.from(record.value);
      var changed = false;

      if (map.containsKey('series')) {
        map['texto'] ??= map['series'];
        map.remove('series');
        changed = true;
      }

      final parsedId = parseSermonId(map['sermonId']);
      if (parsedId == null || usedIds.contains(parsedId)) {
        final nextId = _lowestAvailableIdFromSets(
          usedIds: usedIds,
          availableIds: availableIds,
        );
        map['sermonId'] = nextId;
        usedIds.add(nextId);
        availableIds.remove(nextId);
        changed = true;
      } else {
        map['sermonId'] = parsedId;
        usedIds.add(parsedId);
        availableIds.remove(parsedId);
        if (map['sermonId'] != parsedId) changed = true;
      }

      if (map['isTrashed'] == null) {
        map['isTrashed'] = false;
        changed = true;
      }

      if (!map.containsKey('scheduledDate')) {
        map['scheduledDate'] = null;
        changed = true;
      }

      if (changed) {
        await _sermonStore.record(record.key).put(_db, map);
      }
    }

    await _writeAvailableIds(availableIds.where((id) => !usedIds.contains(id)));
  }

  Future<List<Sermon>> getAll({bool archived = false}) async {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('isArchived', archived),
        Filter.equals('isTrashed', false),
      ]),
      sortOrders: [SortOrder('updatedAt', false)],
    );
    final records = await _sermonStore.find(_db, finder: finder);
    return records.map((r) => Sermon.fromMap(r.key, r.value)).toList();
  }

  Stream<int> watchSermons() {
    var revision = 0;
    return _sermonStore.query().onSnapshots(_db).map((_) => revision++);
  }

  Future<List<SermonSearchResult>> getFilteredPage({
    required int limit,
    required int offset,
    bool archived = false,
    String query = '',
    SermonStatus? statusFilter,
    String? textoFilter,
    String? tagFilter,
  }) async {
    final normalizedQuery = normalizeSearchText(query);
    final dateFormat = DateFormat("d 'de' MMMM 'de' yyyy");
    final results = <SermonSearchResult>[];
    var matchedBeforePage = 0;
    var rawOffset = 0;
    const scanChunkSize = 50;

    while (results.length < limit) {
      final records = await _sermonStore.find(
        _db,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('isArchived', archived),
            Filter.equals('isTrashed', false),
          ]),
          sortOrders: [SortOrder('updatedAt', false)],
          offset: rawOffset,
          limit: scanChunkSize,
        ),
      );
      if (records.isEmpty) break;

      for (final record in records) {
        final result = _searchResultForRecord(
          record,
          query: normalizedQuery,
          statusFilter: statusFilter,
          textoFilter: textoFilter,
          tagFilter: tagFilter,
          dateFormat: dateFormat,
        );
        if (result == null) continue;
        if (matchedBeforePage < offset) {
          matchedBeforePage++;
          continue;
        }
        results.add(result);
        if (results.length == limit) break;
      }

      rawOffset += records.length;
      if (records.length < scanChunkSize) break;
    }

    return results;
  }

  Future<List<Sermon>> getTrashedPage({
    required int limit,
    required int offset,
  }) async {
    final records = await _sermonStore.find(
      _db,
      finder: Finder(
        filter: Filter.equals('isTrashed', true),
        sortOrders: [SortOrder('updatedAt', false)],
        offset: offset,
        limit: limit,
      ),
    );
    return records.map((r) => Sermon.fromMap(r.key, r.value)).toList();
  }

  Future<List<Sermon>> getExportSermons() async {
    final records = await _sermonStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('sermonId')]),
    );
    return records.map((r) => Sermon.fromMap(r.key, r.value)).toList();
  }

  Future<Sermon?> getById(int id) async {
    final record = await _sermonStore.record(id).get(_db);
    if (record == null) return null;
    return Sermon.fromMap(id, record);
  }

  Future<List<Sermon>> getPinned() async {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('isPinned', true),
        Filter.equals('isArchived', false),
        Filter.equals('isTrashed', false),
      ]),
      sortOrders: [SortOrder('updatedAt', false)],
    );
    final records = await _sermonStore.find(_db, finder: finder);
    return records.map((r) => Sermon.fromMap(r.key, r.value)).toList();
  }

  Future<List<Sermon>> getTrashed() async {
    final finder = Finder(
      filter: Filter.equals('isTrashed', true),
      sortOrders: [SortOrder('updatedAt', false)],
    );
    final records = await _sermonStore.find(_db, finder: finder);
    return records.map((r) => Sermon.fromMap(r.key, r.value)).toList();
  }

  Future<int> createSermon() async {
    final now = DateTime.now();
    final sermon = Sermon(
      sermonId: await generateSermonId(),
      title: '',
      bodyJson: null,
      status: SermonStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    return _sermonStore.add(_db, sermon.toMap());
  }

  Future<int> generateSermonId() {
    return _allocateSermonId();
  }

  Future<int> createAndSaveSermon(
    Sermon sermon, {
    bool reassignOnConflict = false,
  }) async {
    final preferredId = sermon.sermonId > 0 ? sermon.sermonId : null;
    final duplicateId =
        preferredId != null && await sermonIdExists(preferredId);
    if (duplicateId && !reassignOnConflict) {
      throw DuplicateSermonIdException(preferredId);
    }

    sermon.sermonId = await _allocateSermonId(
      preferredId: duplicateId ? null : preferredId,
    );
    sermon.scheduledDate = _dateOnlyOrNull(sermon.scheduledDate);
    sermon.updatedAt = DateTime.now();
    return _sermonStore.add(_db, sermon.toMap());
  }

  Future<void> saveSermon(Sermon sermon) async {
    final id = sermon.id;
    if (id == null) return;
    if (sermon.sermonId <= 0) {
      sermon.sermonId = await _allocateSermonId();
    }
    final duplicateId = await sermonIdExists(sermon.sermonId, excludingId: id);
    if (duplicateId) {
      throw DuplicateSermonIdException(sermon.sermonId);
    }
    sermon.scheduledDate = _dateOnlyOrNull(sermon.scheduledDate);
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(id).put(_db, sermon.toMap());
  }

  Future<bool> togglePin(Sermon sermon) async {
    if (!sermon.isPinned) {
      final pinnedCount = (await getPinned()).length;
      if (pinnedCount >= 5) return false;
    }
    sermon.isPinned = !sermon.isPinned;
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(sermon.id!).put(_db, sermon.toMap());
    return true;
  }

  Future<void> archiveSermon(Sermon sermon) async {
    sermon.isArchived = true;
    sermon.isPinned = false;
    sermon.isTrashed = false;
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(sermon.id!).put(_db, sermon.toMap());
  }

  Future<void> restoreSermon(Sermon sermon) async {
    sermon.isArchived = false;
    sermon.isTrashed = false;
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(sermon.id!).put(_db, sermon.toMap());
  }

  Future<void> restoreMany(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    await _db.transaction((txn) async {
      for (final id in uniqueIds) {
        final map = await _sermonStore.record(id).get(txn);
        if (map == null) continue;
        final sermon = Sermon.fromMap(id, map)
          ..isArchived = false
          ..isTrashed = false
          ..updatedAt = DateTime.now();
        await _sermonStore.record(id).put(txn, sermon.toMap());
      }
    });
  }

  Future<void> moveToTrash(Sermon sermon) async {
    sermon.isTrashed = true;
    sermon.isArchived = false;
    sermon.isPinned = false;
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(sermon.id!).put(_db, sermon.toMap());
  }

  Future<void> moveToTrashMany(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    await _db.transaction((txn) async {
      for (final id in uniqueIds) {
        final map = await _sermonStore.record(id).get(txn);
        if (map == null) continue;
        final sermon = Sermon.fromMap(id, map)
          ..isTrashed = true
          ..isArchived = false
          ..isPinned = false
          ..updatedAt = DateTime.now();
        await _sermonStore.record(id).put(txn, sermon.toMap());
      }
    });
  }

  Future<void> moveAllSermonsToTrash() async {
    final records = await _sermonStore.find(_db);
    await _db.transaction((txn) async {
      for (final record in records) {
        final sermon = Sermon.fromMap(record.key, record.value)
          ..isTrashed = true
          ..isArchived = false
          ..isPinned = false
          ..updatedAt = DateTime.now();
        await _sermonStore.record(record.key).put(txn, sermon.toMap());
      }
    });
  }

  Future<void> deleteSermon(int id) async {
    final sermon = await getById(id);
    await _sermonStore.record(id).delete(_db);
    if (sermon != null) {
      await _releaseSermonId(sermon.sermonId);
    }
  }

  Future<void> deleteMany(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    final sermons = <Sermon>[];
    await _db.transaction((txn) async {
      for (final id in uniqueIds) {
        final map = await _sermonStore.record(id).get(txn);
        if (map == null) continue;
        sermons.add(Sermon.fromMap(id, map));
        await _sermonStore.record(id).delete(txn);
      }
    });
    for (final sermon in sermons) {
      await _releaseSermonId(sermon.sermonId);
    }
  }

  Future<void> emptyTrash() async {
    final trashed = await getTrashed();
    await _db.transaction((txn) async {
      for (final sermon in trashed) {
        await _sermonStore.record(sermon.id!).delete(txn);
      }
    });
    for (final sermon in trashed) {
      await _releaseSermonId(sermon.sermonId);
    }
  }

  Future<void> cycleStatus(Sermon sermon) async {
    switch (sermon.status) {
      case SermonStatus.draft:
        sermon.status = SermonStatus.ready;
        break;
      case SermonStatus.ready:
        sermon.status = SermonStatus.delivered;
        break;
      case SermonStatus.delivered:
        sermon.status = SermonStatus.draft;
        break;
    }
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(sermon.id!).put(_db, sermon.toMap());
  }

  Future<void> cycleStatusMany(Iterable<int> ids) async {
    final uniqueIds = ids.toSet();
    await _db.transaction((txn) async {
      for (final id in uniqueIds) {
        final map = await _sermonStore.record(id).get(txn);
        if (map == null) continue;
        final sermon = Sermon.fromMap(id, map);
        sermon.status = _nextStatus(sermon.status);
        sermon.updatedAt = DateTime.now();
        await _sermonStore.record(id).put(txn, sermon.toMap());
      }
    });
  }

  Future<void> logDelivery(Sermon sermon) async {
    sermon.deliveryHistory = [...sermon.deliveryHistory, DateTime.now()];
    if (sermon.status == SermonStatus.ready) {
      sermon.status = SermonStatus.delivered;
    }
    sermon.updatedAt = DateTime.now();
    await _sermonStore.record(sermon.id!).put(_db, sermon.toMap());
  }

  Future<void> clearDeliveryHistory() async {
    final records = await _sermonStore.find(_db);
    await _db.transaction((txn) async {
      for (final record in records) {
        final sermon = Sermon.fromMap(record.key, record.value);
        if (sermon.deliveryHistory.isEmpty) continue;
        sermon.deliveryHistory = [];
        sermon.updatedAt = DateTime.now();
        await _sermonStore.record(record.key).put(txn, sermon.toMap());
      }
    });
  }

  Future<List<String>> getAllTags() async {
    final sermons = await getAll();
    final tags = <String>{};
    for (final s in sermons) {
      tags.addAll(s.tags);
    }
    return tags.toList()..sort();
  }

  Future<List<String>> getAllTextos() async {
    final sermons = await getAll();
    final textos = <String>{};
    for (final s in sermons) {
      final value = s.texto;
      if (value != null && value.isNotEmpty) {
        textos.add(value);
      }
    }
    return textos.toList()..sort();
  }

  Future<Sermon?> findDuplicateTitle(String title, {int? excludingId}) async {
    final normalizedTitle = normalizeSearchText(title.trim());
    if (normalizedTitle.isEmpty) return null;
    final records = await _sermonStore.find(_db);
    for (final record in records) {
      if (record.key == excludingId) continue;
      final sermon = Sermon.fromMap(record.key, record.value);
      if (normalizeSearchText(sermon.title.trim()) == normalizedTitle) {
        return sermon;
      }
    }
    return null;
  }

  Future<bool> sermonIdExists(int sermonId, {int? excludingId}) async {
    if (sermonId <= 0) return false;
    final records = await _sermonStore.find(_db);
    for (final record in records) {
      if (record.key == excludingId) continue;
      final existingId = parseSermonId(record.value['sermonId']);
      if (existingId == sermonId) return true;
    }
    return false;
  }

  Future<int> _allocateSermonId({int? preferredId}) async {
    final availableIds = await _readAvailableIds();
    if (preferredId != null &&
        preferredId > 0 &&
        !await sermonIdExists(preferredId)) {
      availableIds.remove(preferredId);
      await _writeAvailableIds(availableIds);
      return preferredId;
    }

    final usablePool = <int>[];
    for (final id in availableIds) {
      if (!await sermonIdExists(id)) usablePool.add(id);
    }
    usablePool.sort();
    if (usablePool.isNotEmpty) {
      final id = usablePool.first;
      availableIds.remove(id);
      await _writeAvailableIds(availableIds);
      return id;
    }

    final usedIds = await _usedSermonIds();
    var nextId = 1;
    while (usedIds.contains(nextId)) {
      nextId++;
    }
    return nextId;
  }

  Future<void> _releaseSermonId(int sermonId) async {
    if (sermonId <= 0 || await sermonIdExists(sermonId)) return;
    final availableIds = await _readAvailableIds();
    availableIds.add(sermonId);
    await _writeAvailableIds(availableIds);
  }

  Future<Set<int>> _usedSermonIds() async {
    final records = await _sermonStore.find(_db);
    return records
        .map((record) => parseSermonId(record.value['sermonId']))
        .nonNulls
        .toSet();
  }

  Future<Set<int>> _readAvailableIds() async {
    final map = await _metadataStore.record(_availableSermonIdsKey).get(_db);
    final ids = map?['ids'] as List<dynamic>?;
    return ids?.map(parseSermonId).nonNulls.where((id) => id > 0).toSet() ?? {};
  }

  Future<void> _writeAvailableIds(Iterable<int> ids) async {
    final sorted = ids.where((id) => id > 0).toSet().toList()..sort();
    await _metadataStore.record(_availableSermonIdsKey).put(_db, {
      'ids': sorted,
    });
  }

  int _lowestAvailableIdFromSets({
    required Set<int> usedIds,
    required Set<int> availableIds,
  }) {
    final sortedPool =
        availableIds.where((id) => !usedIds.contains(id)).toList()..sort();
    if (sortedPool.isNotEmpty) return sortedPool.first;

    var id = 1;
    while (usedIds.contains(id)) {
      id++;
    }
    return id;
  }

  SermonSearchResult? _searchResultForRecord(
    RecordSnapshot<int, Map<String, dynamic>> record, {
    required String query,
    required SermonStatus? statusFilter,
    required String? textoFilter,
    required String? tagFilter,
    required DateFormat dateFormat,
  }) {
    final sermon = Sermon.fromMap(record.key, record.value);
    if (statusFilter != null && sermon.status != statusFilter) return null;
    if (textoFilter != null && sermon.texto != textoFilter) return null;
    if (tagFilter != null && !sermon.tags.contains(tagFilter)) return null;

    final matches = _searchMatchesForSermon(
      sermon,
      query: query,
      dateFormat: dateFormat,
    );
    if (query.isNotEmpty && matches.isEmpty) return null;

    return SermonSearchResult(sermon: sermon, matches: matches);
  }
}

final sermonRepositoryProvider = FutureProvider<SermonRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final repo = SermonRepository(db);
  await repo.ensureMigrations();
  return repo;
});

final sermonChangesProvider = StreamProvider<int>((ref) async* {
  final repo = await ref.watch(sermonRepositoryProvider.future);
  yield 0;
  yield* repo.watchSermons();
});

final sermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getAll();
});

final archivedSermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getAll(archived: true);
});

final trashedSermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getTrashed();
});

final pinnedSermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getPinned();
});

final sermonByIdProvider = FutureProvider.family<Sermon?, int>((ref, id) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getById(id);
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final statusFilterProvider = StateProvider<SermonStatus?>((ref) => null);
final textoFilterProvider = StateProvider<String?>((ref) => null);
final tagFilterProvider = StateProvider<String?>((ref) => null);
final showArchivedProvider = StateProvider<bool>((ref) => false);

final allTagsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getAllTags();
});

final allTextosProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(sermonChangesProvider);
  final repo = await ref.watch(sermonRepositoryProvider.future);
  return repo.getAllTextos();
});

final filteredSermonResultsProvider = FutureProvider<List<SermonSearchResult>>((
  ref,
) async {
  final showArchived = ref.watch(showArchivedProvider);
  final sermons = showArchived
      ? await ref.watch(archivedSermonsProvider.future)
      : await ref.watch(sermonsProvider.future);
  final query = normalizeSearchText(ref.watch(searchQueryProvider));
  final statusFilter = ref.watch(statusFilterProvider);
  final textoFilter = ref.watch(textoFilterProvider);
  final tagFilter = ref.watch(tagFilterProvider);
  final dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

  return sermons
      .where((s) {
        if (statusFilter != null && s.status != statusFilter) return false;
        if (textoFilter != null && s.texto != textoFilter) return false;
        if (tagFilter != null && !s.tags.contains(tagFilter)) return false;
        return true;
      })
      .map((sermon) {
        final matches = _searchMatchesForSermon(
          sermon,
          query: query,
          dateFormat: dateFormat,
        );
        return SermonSearchResult(sermon: sermon, matches: matches);
      })
      .where((result) {
        return query.isEmpty || result.matches.isNotEmpty;
      })
      .toList();
});

Set<SermonSearchMatch> _searchMatchesForSermon(
  Sermon sermon, {
  required String query,
  required DateFormat dateFormat,
}) {
  final matches = <SermonSearchMatch>{};
  if (query.isEmpty) return matches;

  if (sermon.sermonId.toString().contains(query)) {
    matches.add(SermonSearchMatch.id);
  }
  if (normalizeSearchText(sermon.title).contains(query)) {
    matches.add(SermonSearchMatch.title);
  }
  if (normalizeSearchText(sermon.texto ?? '').contains(query)) {
    matches.add(SermonSearchMatch.texto);
  }
  if (sermon.tags.any((tag) => normalizeSearchText(tag).contains(query))) {
    matches.add(SermonSearchMatch.tag);
  }
  if (normalizeSearchText(sermon.status.label).contains(query)) {
    matches.add(SermonSearchMatch.status);
  }

  final scheduledDate = sermon.scheduledDate;
  if (scheduledDate != null) {
    final formattedDate = dateFormat.format(scheduledDate);
    final compactDate = DateFormat('dd/MM/yyyy').format(scheduledDate);
    if (normalizeSearchText('$formattedDate $compactDate').contains(query)) {
      matches.add(SermonSearchMatch.date);
    }
  }

  return matches;
}

final filteredSermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  final results = await ref.watch(filteredSermonResultsProvider.future);
  return results.map((result) => result.sermon).toList();
});

DateTime? _dateOnlyOrNull(DateTime? date) {
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day);
}

SermonStatus _nextStatus(SermonStatus status) {
  return switch (status) {
    SermonStatus.draft => SermonStatus.ready,
    SermonStatus.ready => SermonStatus.delivered,
    SermonStatus.delivered => SermonStatus.draft,
  };
}

String normalizeSearchText(String value) {
  final lower = value.toLowerCase().trim();
  const accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final codePoint in lower.runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(accents[char] ?? char);
  }
  return buffer.toString();
}
