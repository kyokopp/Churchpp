/// Detects Bible references in Portuguese text.
/// Supports patterns like "João 3:16", "Salmos 23", "Mateus 5:3-12",
/// "1 Coríntios 13:4-8", "Gênesis 1:1"
class ScriptureReference {
  final String fullMatch;
  final String book;
  final int chapter;
  final int? verseStart;
  final int? verseEnd;

  const ScriptureReference({
    required this.fullMatch,
    required this.book,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
  });

  String get displayReference {
    if (verseStart == null) return '$book $chapter';
    if (verseEnd == null) return '$book $chapter:$verseStart';
    return '$book $chapter:$verseStart–$verseEnd';
  }

  @override
  String toString() => displayReference;
}

class ScriptureParser {
  static const List<String> _bookNames = [
    // Antigo Testamento
    'Gênesis', 'Êxodo', 'Levítico', 'Números', 'Deuteronômio',
    'Josué', 'Juízes', 'Rute',
    '1 Samuel', '2 Samuel', '1 Reis', '2 Reis',
    '1 Crônicas', '2 Crônicas',
    'Esdras', 'Neemias', 'Ester',
    'Jó', 'Salmos', 'Provérbios', 'Eclesiastes', 'Cantares',
    'Isaías', 'Jeremias', 'Lamentações', 'Ezequiel', 'Daniel',
    'Oséias', 'Joel', 'Amós', 'Obadias', 'Jonas', 'Miquéias',
    'Naum', 'Habacuque', 'Sofonias', 'Ageu', 'Zacarias', 'Malaquias',
    // Novo Testamento
    'Mateus', 'Marcos', 'Lucas', 'João',
    'Atos',
    'Romanos', '1 Coríntios', '2 Coríntios',
    'Gálatas', 'Efésios', 'Filipenses', 'Colossenses',
    '1 Tessalonicenses', '2 Tessalonicenses',
    '1 Timóteo', '2 Timóteo',
    'Tito', 'Filemom',
    'Hebreus', 'Tiago',
    '1 Pedro', '2 Pedro',
    '1 João', '2 João', '3 João',
    'Judas', 'Apocalipse',
  ];

  static final RegExp _pattern = _buildPattern();

  static RegExp _buildPattern() {
    // Sort by length desc so longer names match first (e.g., "1 Coríntios" before "Coríntios")
    final sorted = List<String>.from(_bookNames)
      ..sort((a, b) => b.length.compareTo(a.length));

    final bookGroup = sorted.map((b) => RegExp.escape(b)).join('|');

    // Pattern: BookName Chapter[:VerseStart[-VerseEnd]]
    return RegExp(
      '($bookGroup)\\s+(\\d{1,3})(?::(\\d{1,3})(?:[–\\-](\\d{1,3}))?)?',
      caseSensitive: false,
    );
  }

  /// Parse all scripture references from the given text.
  static List<ScriptureReference> parse(String text) {
    final matches = _pattern.allMatches(text);
    return matches.map((m) {
      return ScriptureReference(
        fullMatch: m.group(0)!,
        book: m.group(1)!,
        chapter: int.parse(m.group(2)!),
        verseStart: m.group(3) != null ? int.parse(m.group(3)!) : null,
        verseEnd: m.group(4) != null ? int.parse(m.group(4)!) : null,
      );
    }).toList();
  }
}
