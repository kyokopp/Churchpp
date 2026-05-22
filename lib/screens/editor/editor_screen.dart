import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../models/sermon.dart';
import '../../providers/sermon_providers.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/debouncer.dart';
import '../../utils/app_routes.dart';
import '../../utils/scripture_parser.dart';
import '../../utils/snackbar_helper.dart';
import '../../animation/motion_constants.dart';
import '../../widgets/figma_primitives.dart';
import '../history/history_screen.dart';
import '../pulpit/pulpit_screen.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.sermonId});

  /// Opens a blank in-memory draft that is only persisted when the user
  /// makes a meaningful edit.
  const EditorScreen.newDraft({super.key}) : sermonId = null;

  final int? sermonId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _textoController;
  late final TextEditingController _tagInputController;
  late final TextEditingController _sermonIdController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _textoFocusNode;
  late final FocusNode _tagFocusNode;
  late final FocusNode _sermonIdFocusNode;
  late final FocusNode _bodyFocusNode;
  late QuillController _quillController;

  final _saveDebouncer = Debouncer();
  final _titleValidationDebouncer = Debouncer(
    delay: Duration(milliseconds: 800),
  );
  final _scriptureDebouncer = Debouncer(delay: Duration(milliseconds: 800));
  final _scrollController = ScrollController();
  final _bodyScrollController = ScrollController();
  late final AnimationController _saveFeedbackController;
  late final Animation<double> _saveFeedbackScale;
  StreamSubscription<dynamic>? _quillChangesSubscription;

  Sermon? _sermon;
  bool _isLoaded = false;
  bool _isNewDraft = false;
  bool _hasAnimatedEntry = false;
  bool _disposed = false;
  bool _isClosing = false;
  bool _titleDuplicate = false;
  bool _duplicateSnackVisible = false;
  bool _showSavedCheck = false;
  bool _hasSaveableContent = false;
  String? _sermonIdError;
  String _lastPersistedTitle = '';
  int _lastValidSermonId = 0;
  DateTime? _scheduledDate;
  List<String> _tags = [];
  SermonStatus _status = SermonStatus.draft;
  List<ScriptureReference> _detectedScriptures = [];
  List<String> _allTextos = [];

  // Snapshot of the initial draft state for meaningful-edit detection
  int _initialSermonId = 0;
  DateTime? _initialDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController = TextEditingController();
    _textoController = TextEditingController();
    _tagInputController = TextEditingController();
    _sermonIdController = TextEditingController();
    _titleFocusNode = FocusNode();
    _textoFocusNode = FocusNode();
    _tagFocusNode = FocusNode();
    _sermonIdFocusNode = FocusNode();
    _bodyFocusNode = FocusNode();
    _sermonIdFocusNode.addListener(_handleSermonIdFocusChange);
    _quillController = QuillController.basic();
    _saveFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _saveFeedbackScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1, end: 0.9), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1), weight: 40),
        ]).animate(
          CurvedAnimation(
            parent: _saveFeedbackController,
            curve: AppSpring.snappyCurve,
          ),
        );

    if (widget.sermonId == null) {
      _initNewDraft();
    } else {
      _loadSermon();
    }

    // Mark entry animation as complete after staggered delays finish.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _hasAnimatedEntry = true);
    });
  }

  /// Initialises an in-memory draft — no DB write until meaningful edits.
  void _initNewDraft() {
    _isNewDraft = true;
    final now = DateTime.now();
    _sermon = Sermon(
      sermonId: 0,
      title: '',
      bodyJson: null,
      status: SermonStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    _initialSermonId = 0;
    _initialDate = null;
    _lastValidSermonId = 0;

    _titleController.addListener(_handleTitleChanged);
    _textoController.addListener(_onContentChanged);
    _quillChangesSubscription = _quillController.document.changes.listen((_) {
      _onContentChanged();
      _scriptureDebouncer.run(_detectScriptures);
    });

    _isLoaded = true;
    _hasSaveableContent = false;

    // Load texto suggestions after the first frame so the editor opens instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final repo = await ref.read(sermonRepositoryProvider.future);
        final nextId = await repo.generateSermonId();
        final textos = await repo.getAllTextos();
        if (mounted) {
          setState(() {
            _lastValidSermonId = nextId;
            _initialSermonId = nextId;
            _sermonIdController.text = nextId.toString();
            _allTextos = textos;
          });
        }
      } catch (_) {
        // Texto suggestions are optional; silently ignore failures.
      }
    });
  }

  Future<void> _loadSermon() async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    final sermon = await repo.getById(widget.sermonId!);
    if (sermon == null || !mounted) return;

    _sermon = sermon;
    _lastPersistedTitle = sermon.title;
    _lastValidSermonId = sermon.sermonId;
    _titleController.text = sermon.title;
    _textoController.text = sermon.texto ?? '';
    _sermonIdController.text = sermon.sermonId.toString();
    _scheduledDate = sermon.scheduledDate;
    _tags = List<String>.from(sermon.tags);
    _status = sermon.status;

    if (sermon.bodyJson != null && sermon.bodyJson!.isNotEmpty) {
      try {
        final doc = Document.fromJson(jsonDecode(sermon.bodyJson!));
        _quillController.dispose();
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _quillController.dispose();
        _quillController = QuillController.basic();
      }
    }

    _titleController.addListener(_handleTitleChanged);
    _textoController.addListener(_onContentChanged);
    _quillChangesSubscription = _quillController.document.changes.listen((_) {
      _onContentChanged();
      _scriptureDebouncer.run(_detectScriptures);
    });

    _allTextos = await repo.getAllTextos();
    _hasSaveableContent = _hasContentToSave;
    if (!mounted) return;
    setState(() => _isLoaded = true);
    _detectScriptures();
  }

  void _handleTitleChanged() {
    _onContentChanged();
    _titleValidationDebouncer.run(_validateTitle);
  }

  Future<void> _handleClose() async {
    if (_isClosing) return;
    _isClosing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _saveDebouncer.cancel();
    _titleValidationDebouncer.cancel();
    _scriptureDebouncer.cancel();

    try {
      if (_isNewDraft) {
        final shouldSave = await _confirmNewDraftClose();
        if (shouldSave == null) return;
        if (shouldSave) {
          await _flushNewDraftIfNeeded();
        }
      } else {
        await _saveExistingNow();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _isClosing = false;
    }
  }

  Future<bool?> _confirmNewDraftClose() async {
    if (!_hasMeaningfulEdits(includePendingTag: true)) return false;
    return AppRoutes.showSpringDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.saveDraftQuestion),
        content: const Text(AppStrings.saveDraftBody),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isLoaded || _disposed || _isClosing) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDebouncer.cancel();
      if (_isNewDraft) {
        unawaited(_flushNewDraftIfNeeded());
      } else {
        unawaited(_saveExistingNow());
      }
    }
  }

  Future<void> _flushNewDraftIfNeeded() async {
    final sermon = _sermon;
    if (sermon == null) return;
    if (sermon.id != null) return;

    final pendingTag = _tagInputController.text.trim();
    if (pendingTag.isNotEmpty && !_tags.contains(pendingTag)) {
      _tags.add(pendingTag);
    }

    if (!_hasMeaningfulEdits()) return;

    sermon.title = _titleController.text;
    sermon.sermonId = _lastValidSermonId;
    sermon.texto = _textoController.text.trim().isEmpty
        ? null
        : _textoController.text;
    sermon.scheduledDate = _scheduledDate;
    sermon.tags = List<String>.from(_tags);
    sermon.status = _status;
    sermon.bodyJson = jsonEncode(_quillController.document.toDelta().toJson());

    final repo = await ref.read(sermonRepositoryProvider.future);
    final id = await repo.createAndSaveSermon(sermon);
    sermon.id = id;
    _isNewDraft = false;
    _lastPersistedTitle = sermon.title;
  }

  Future<void> _saveExistingNow() async {
    await _saveSermon();
  }

  Future<void> _manualSave() async {
    if (!_hasContentToSave) return;
    _saveDebouncer.cancel();
    if (_isNewDraft) {
      await _flushNewDraftIfNeeded();
    } else {
      await _saveExistingNow();
    }
    if (!mounted) return;
    setState(() => _showSavedCheck = true);
    unawaited(_saveFeedbackController.forward(from: 0));
    showTimedSnackBar(
      context,
      message: AppStrings.sermonSaved,
      duration: const Duration(seconds: 2),
    );
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSavedCheck = false);
    });
  }

  Future<void> _validateTitle() async {
    final sermon = _sermon;
    if (sermon == null) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    final duplicate = await repo.findDuplicateTitle(
      _titleController.text,
      excludingId: sermon.id,
    );
    if (!mounted) return;
    final hasDuplicate = duplicate != null;
    if (_titleDuplicate != hasDuplicate) {
      setState(() => _titleDuplicate = hasDuplicate);
    }
    if (hasDuplicate && !_duplicateSnackVisible) {
      _duplicateSnackVisible = true;
      showTimedSnackBar(context, message: AppStrings.duplicateTitleWarning);
      Future.delayed(const Duration(seconds: 3), () {
        _duplicateSnackVisible = false;
      });
    }
  }

  void _onContentChanged() {
    _syncSaveButtonAvailability();
    // For new drafts, don't autosave to DB — only save on close if meaningful.
    if (_isNewDraft) return;
    _saveDebouncer.run(_saveSermon);
  }

  void _syncSaveButtonAvailability() {
    if (!mounted) return;
    final hasContent = _hasContentToSave;
    if (_hasSaveableContent == hasContent) return;
    setState(() => _hasSaveableContent = hasContent);
  }

  /// Returns the body text without the trailing newline that Quill always adds.
  String _getBodyText() {
    final text = _quillController.document.toPlainText();
    // Quill documents always end with '\n'; strip it for emptiness checks.
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  }

  /// Whether the user has changed anything from the default new-draft state.
  bool _hasMeaningfulEdits({bool includePendingTag = false}) {
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_lastValidSermonId != _initialSermonId) return true;
    if (_textoController.text.trim().isNotEmpty) return true;
    if (_tags.isNotEmpty) return true;
    if (includePendingTag && _tagInputController.text.trim().isNotEmpty) {
      return true;
    }
    if (_getBodyText().trim().isNotEmpty) return true;
    if (_status != SermonStatus.draft) return true;
    if (_scheduledDate != _initialDate) return true;
    return false;
  }

  bool get _hasContentToSave {
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_textoController.text.trim().isNotEmpty) return true;
    if (_tags.isNotEmpty) return true;
    if (_tagInputController.text.trim().isNotEmpty) return true;
    if (_getBodyText().trim().isNotEmpty) return true;
    if (_status != SermonStatus.draft) return true;
    if (_scheduledDate != null) return true;
    if (_lastValidSermonId > 0 && _lastValidSermonId != _initialSermonId) {
      return true;
    }
    return false;
  }

  Future<void> _saveSermon() async {
    final sermon = _sermon;
    if (sermon == null || _disposed) return;
    // New drafts are never autosaved — only flushed on close.
    if (_isNewDraft) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    if (_disposed) return;
    final incomingTitle = _titleController.text;
    final duplicate = await repo.findDuplicateTitle(
      incomingTitle,
      excludingId: sermon.id,
    );

    if (duplicate == null) {
      sermon.title = incomingTitle;
      _lastPersistedTitle = incomingTitle;
      if (_titleDuplicate && mounted) {
        setState(() => _titleDuplicate = false);
      }
    } else {
      sermon.title = _lastPersistedTitle;
      if (!_titleDuplicate && mounted) {
        setState(() => _titleDuplicate = true);
      }
    }

    sermon.sermonId = _lastValidSermonId;
    sermon.texto = _textoController.text.trim().isEmpty
        ? null
        : _textoController.text;
    sermon.scheduledDate = _scheduledDate;
    sermon.tags = List<String>.from(_tags);
    sermon.status = _status;
    sermon.bodyJson = jsonEncode(_quillController.document.toDelta().toJson());

    await repo.saveSermon(sermon);
  }

  void _detectScriptures() {
    final plainText = _quillController.document.toPlainText();
    final refs = ScriptureParser.parse(plainText);
    if (mounted && !_disposed) {
      setState(() => _detectedScriptures = refs);
    }
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    setState(() {
      _tags.add(trimmed);
      _tagInputController.clear();
    });
    _onContentChanged();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _onContentChanged();
  }

  void _cycleStatus() {
    setState(() {
      switch (_status) {
        case SermonStatus.draft:
          _status = SermonStatus.ready;
          break;
        case SermonStatus.ready:
          _status = SermonStatus.delivered;
          break;
        case SermonStatus.delivered:
          _status = SermonStatus.draft;
          break;
      }
    });
    _onContentChanged();
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (!mounted || selectedDate == null) return;
    setState(() {
      _scheduledDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
    _onContentChanged();
  }

  void _handleSermonIdFocusChange() {
    if (!_sermonIdFocusNode.hasFocus) {
      unawaited(_validateSermonIdOnBlur());
    }
  }

  Future<void> _validateSermonIdOnBlur() async {
    final sermon = _sermon;
    if (sermon == null) return;
    final candidate = int.tryParse(_sermonIdController.text.trim());
    if (candidate == null || candidate <= 0) {
      _revertSermonId(AppStrings.sermonIdInvalid);
      return;
    }

    final repo = await ref.read(sermonRepositoryProvider.future);
    final exists = await repo.sermonIdExists(candidate, excludingId: sermon.id);
    if (!mounted) return;
    if (exists) {
      _revertSermonId(AppStrings.sermonIdDuplicate);
      return;
    }

    setState(() => _sermonIdError = null);
    _lastValidSermonId = candidate;
    _sermonIdController.text = candidate.toString();
    await _saveSermon();
  }

  void _revertSermonId(String error) {
    if (!mounted) return;
    setState(() => _sermonIdError = error);
    _sermonIdController.value = TextEditingValue(
      text: _lastValidSermonId == 0 ? '' : _lastValidSermonId.toString(),
      selection: TextSelection.collapsed(
        offset: _lastValidSermonId.toString().length,
      ),
    );
  }

  Future<void> _enterPulpitMode() async {
    if (_isNewDraft) {
      await _flushNewDraftIfNeeded();
      if (!mounted || _sermon?.id == null) return;
      _isNewDraft = false;
    }
    await _saveSermon();
    if (!mounted) return;

    if (!mounted) return;
    final sermon = _sermon;
    final shouldMarkDelivered = _status == SermonStatus.ready;
    if (sermon != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(AppRoutes.duration, () async {
          if (!mounted) return;
          final repo = await ref.read(sermonRepositoryProvider.future);
          await repo.logDelivery(sermon);
          if (!mounted || !shouldMarkDelivered) return;
          setState(() => _status = SermonStatus.delivered);
        });
      });
    }
    await Navigator.of(
      context,
    ).push(AppRoutes.fade(PulpitScreen(sermonId: _sermon!.id!)));
  }

  void _openHistory() {
    if (_isNewDraft || _sermon?.id == null) return;
    Navigator.of(
      context,
    ).push(AppRoutes.slideFromRight(HistoryScreen(sermonId: _sermon!.id!)));
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _saveDebouncer.dispose();
    _saveFeedbackController.dispose();
    _titleValidationDebouncer.dispose();
    _scriptureDebouncer.dispose();
    _quillChangesSubscription?.cancel();

    _titleController.dispose();
    _textoController.dispose();
    _tagInputController.dispose();
    _sermonIdController.dispose();
    _titleFocusNode.dispose();
    _textoFocusNode.dispose();
    _tagFocusNode.dispose();
    _sermonIdFocusNode.dispose();
    _bodyFocusNode.dispose();
    _quillController.dispose();
    _scrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _saveDebouncer.cancel();
          if (_isNewDraft) {
            unawaited(_flushNewDraftIfNeeded());
          } else {
            unawaited(_saveExistingNow());
          }
        } else {
          unawaited(_handleClose());
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          toolbarHeight: AppSpacing.topBarHeight,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.page),
            child: PillIconButton(icon: AppIcons.back, onPressed: _handleClose),
          ),
          actions: [
            ScaleTransition(
              scale: _saveFeedbackScale,
              child: PillIconButton(
                icon: _showSavedCheck ? AppIcons.check : AppIcons.save,
                tooltip: AppStrings.save,
                color: _hasSaveableContent ? null : tokens.outline,
                onPressed: _hasSaveableContent ? _manualSave : null,
              ),
            ),
            const SizedBox(width: 8),
            PillIconButton(
              icon: AppIcons.history,
              tooltip: AppStrings.pulpitHistoryTooltip,
              onPressed: _isNewDraft || _sermon?.id == null
                  ? null
                  : _openHistory,
            ),
            const SizedBox(width: 8),
            PillIconButton(
              icon: AppIcons.pulpit,
              tooltip: AppStrings.pulpitModeTooltip,
              selected: true,
              onPressed: _enterPulpitMode,
            ),
            const SizedBox(width: AppSpacing.page),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                // ── Metadata header (non-scrollable, compact) ──
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _sermonIdController,
                        focusNode: _sermonIdFocusNode,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                        ],
                        decoration: InputDecoration(
                          labelText: AppStrings.sermonIdLabel,
                          errorText: _sermonIdError,
                          prefixIcon: const Icon(AppIcons.tag, size: 18),
                          isDense: true,
                          filled: false,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      _wrapLaunchFade(
                        delay: Duration.zero,
                        child: TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          style: textTheme.displaySmall?.copyWith(
                            color: tokens.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: AppStrings.titleHint,
                            hintStyle: textTheme.displaySmall?.copyWith(
                              color: tokens.outline,
                            ),
                            errorText: _titleDuplicate
                                ? AppStrings.duplicateTitleWarning
                                : null,
                            border: _titleDuplicate
                                ? UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: colorScheme.error,
                                    ),
                                  )
                                : InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _wrapLaunchFade(
                        delay: const Duration(milliseconds: 40),
                        child: RawAutocomplete<String>(
                          textEditingController: _textoController,
                          focusNode: _textoFocusNode,
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return _allTextos.where(
                              (s) => normalizeSearchText(s).contains(
                                normalizeSearchText(textEditingValue.text),
                              ),
                            );
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: tokens.textSecondary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppStrings.textoHint,
                                    hintStyle: textTheme.titleLarge?.copyWith(
                                      color: tokens.outline,
                                    ),
                                    prefixIcon: Icon(
                                      AppIcons.book,
                                      size: 18,
                                      color: tokens.textSecondary,
                                    ),
                                    border: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 180,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        dense: true,
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          onSelected: (_) => _onContentChanged(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _wrapLaunchFade(
                        delay: const Duration(milliseconds: 80),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SpringTap(
                              onTap: _cycleStatus,
                              child: _StatusChipEditor(status: _status),
                            ),
                            _EditorPill(
                              icon: AppIcons.calendar,
                              label: _scheduledDate == null
                                  ? AppStrings.noDate
                                  : dateFormat.format(_scheduledDate!),
                              onTap: _pickDate,
                            ),
                          ],
                        ),
                      ),
                      _wrapLaunchFade(
                        delay: const Duration(milliseconds: 120),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._tags.map(
                              (tag) => InputChip(
                                backgroundColor: tokens.secondarySurface,
                                shape: const StadiumBorder(),
                                side: BorderSide.none,
                                label: Text(tag),
                                onDeleted: () => _removeTag(tag),
                              ),
                            ),
                            SizedBox(
                              width: 132,
                              height: 48,
                              child: TextField(
                                controller: _tagInputController,
                                focusNode: _tagFocusNode,
                                style: textTheme.labelLarge,
                                decoration: InputDecoration(
                                  hintText: AppStrings.tagHint,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                    borderSide: BorderSide(color: tokens.outline),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                    borderSide: BorderSide(color: tokens.outline),
                                  ),
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  hintStyle: textTheme.labelLarge?.copyWith(
                                    color: tokens.primary,
                                  ),
                                ),
                                onSubmitted: _addTag,
                                textCapitalization: TextCapitalization.sentences,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_detectedScriptures.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _detectedScriptures
                                .take(5)
                                .map(
                                  (scriptureRef) => SpringScaleIn(
                                    from: 0,
                                    spring: AppMotion.defaultSpring,
                                    child: ActionChip(
                                      backgroundColor: tokens.selectedSurface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.segmented,
                                        ),
                                      ),
                                      avatar: const Icon(AppIcons.book, size: 16),
                                      label: Text(scriptureRef.displayReference),
                                      onPressed: () => _showScriptureCard(
                                        context,
                                        scriptureRef,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Rich text body (scrollable, takes remaining space) ──
                Expanded(
                  child: _wrapLaunchFade(
                    delay: const Duration(milliseconds: 160),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      child: RepaintBoundary(
                        child: QuillEditor.basic(
                          controller: _quillController,
                          focusNode: _bodyFocusNode,
                          scrollController: _bodyScrollController,
                          config: const QuillEditorConfig(
                            scrollable: true,
                            expands: true,
                            placeholder: AppStrings.editorPlaceholder,
                            padding: EdgeInsets.only(bottom: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _EditorToolbar(controller: _quillController),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScriptureCard(
    BuildContext context,
    ScriptureReference scriptureRef,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    AppRoutes.showSpringBottomSheet<void>(
      context: context,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.book, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  scriptureRef.displayReference,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.scriptureDetectedBody,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(AppStrings.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps [child] in a [LaunchFade] only during the initial entry animation.
  /// Once the staggered entry completes, returns the child directly.
  Widget _wrapLaunchFade({required Duration delay, required Widget child}) {
    if (_hasAnimatedEntry) return child;
    return LaunchFade(delay: delay, child: child);
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({required this.controller});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: SizedBox(
        height:
            AppSpacing.floatingDockHeight +
            AppSpacing.floatingDockBottomGap +
            bottomInset,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.floatingDockSideMargin,
            0,
            AppSpacing.floatingDockSideMargin,
            AppSpacing.floatingDockBottomGap + bottomInset,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: AppSpacing.floatingDockHeight,
              child: FrostedGlass(
                borderRadius: 28,
                sigma: 20,
                color: isDark
                    ? tokens.surface.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.6),
                borderColor: Colors.white.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    offset: const Offset(0, 10),
                    blurRadius: 15,
                    spreadRadius: -3,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    offset: const Offset(0, 4),
                    blurRadius: 6,
                    spreadRadius: -4,
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: QuillSimpleToolbar(
                    controller: controller,
                    config: QuillSimpleToolbarConfig(
                      multiRowsDisplay: true,
                      toolbarIconAlignment: WrapAlignment.center,
                      toolbarIconCrossAlignment: WrapCrossAlignment.center,
                      toolbarSectionSpacing: 0,
                      toolbarRunSpacing: 0,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showColorButton: true,
                      showStrikeThrough: false,
                      showInlineCode: false,
                      showBackgroundColorButton: false,
                      showClearFormat: false,
                      showAlignmentButtons: false,
                      showHeaderStyle: false,
                      showListNumbers: false,
                      showListBullets: false,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showLink: false,
                      showSearchButton: false,
                      showUndo: false,
                      showRedo: false,
                      showFontSize: false,
                      showFontFamily: false,
                      showDirection: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showSmallButton: false,
                      showDividers: false,
                      iconTheme: QuillIconTheme(
                        iconButtonUnselectedData: IconButtonData(
                          color: tokens.textSecondary,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 56,
                          ),
                          style: IconButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        iconButtonSelectedData: IconButtonData(
                          color: tokens.primary,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 56,
                          ),
                          style: IconButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: tokens.primaryTint.withValues(
                              alpha: 0.10,
                            ),
                          ),
                        ),
                      ),
                      buttonOptions: QuillSimpleToolbarButtonOptions(
                        bold: QuillToolbarToggleStyleButtonOptions(
                          iconData: AppIcons.bold,
                          afterButtonPressed: () {},
                        ),
                        italic: QuillToolbarToggleStyleButtonOptions(
                          iconData: AppIcons.italic,
                          afterButtonPressed: () {},
                        ),
                        underLine: QuillToolbarToggleStyleButtonOptions(
                          iconData: AppIcons.underline,
                          afterButtonPressed: () {},
                        ),
                        color: QuillToolbarColorButtonOptions(
                          iconData: AppIcons.textColor,
                          afterButtonPressed: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorPill extends StatelessWidget {
  const _EditorPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SpringTap(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: tokens.secondarySurface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tokens.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChipEditor extends StatelessWidget {
  const _StatusChipEditor({required this.status});

  final SermonStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SermonStatus.draft => context.tokens.outline,
      SermonStatus.ready => context.tokens.ready,
      SermonStatus.delivered => context.tokens.delivered,
    };

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
          const SizedBox(width: 4),
          Icon(AppIcons.swap, size: 14, color: color),
        ],
      ),
    );
  }
}
