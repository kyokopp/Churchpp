import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animation/motion_constants.dart';
import '../../l10n/app_strings.dart';
import '../../models/sermon.dart';
import '../../providers/sermon_providers.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/debouncer.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/figma_primitives.dart';
import '../archive/archive_screen.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';
import '../trash/trash_screen.dart';
import 'widgets/filter_chips.dart';
import 'widgets/pinned_section.dart';
import 'widgets/sermon_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _pageSize = 25;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 300));
  final _scrollController = ScrollController();

  final List<SermonSearchResult> _results = [];
  final Set<int> _selectedIds = {};
  _DashboardQuerySignature? _lastSignature;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  bool _animateFirstPage = true;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebouncer.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingPage || !_hasMore) return;
    if (_scrollController.position.extentAfter < 420) {
      final signature = _lastSignature;
      if (signature != null) {
        unawaited(_loadNextPage(signature));
      }
    }
  }

  void _scheduleReloadIfNeeded(_DashboardQuerySignature signature) {
    if (_lastSignature == signature) return;
    _lastSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadFirstPage(signature));
      }
    });
  }

  Future<void> _loadFirstPage(_DashboardQuerySignature signature) async {
    setState(() {
      _results.clear();
      _selectedIds.clear();
      _hasMore = true;
      _isLoadingPage = true;
      _animateFirstPage = true;
    });
    final page = await _fetchPage(signature, offset: 0);
    if (!mounted || _lastSignature != signature) return;
    setState(() {
      _results.addAll(page);
      _hasMore = page.length == _pageSize;
      _isLoadingPage = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _lastSignature == signature) {
        setState(() => _animateFirstPage = false);
      }
    });
  }

  Future<void> _loadNextPage(_DashboardQuerySignature signature) async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() => _isLoadingPage = true);
    final page = await _fetchPage(signature, offset: _results.length);
    if (!mounted || _lastSignature != signature) return;
    setState(() {
      _results.addAll(page);
      _hasMore = page.length == _pageSize;
      _isLoadingPage = false;
    });
  }

  Future<List<SermonSearchResult>> _fetchPage(
    _DashboardQuerySignature signature, {
    required int offset,
  }) async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    return repo.getFilteredPage(
      limit: _pageSize,
      offset: offset,
      archived: signature.showArchived,
      query: signature.query,
      statusFilter: signature.statusFilter,
      textoFilter: signature.textoFilter,
      tagFilter: signature.tagFilter,
    );
  }

  void _exitSelectionMode() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  void _toggleSelection(Sermon sermon) {
    final id = sermon.id;
    if (id == null) return;
    setState(() {
      if (!_selectedIds.add(id)) {
        _selectedIds.remove(id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_results.map((result) => result.sermon.id).nonNulls);
    });
  }

  /// Removes focus from the search field and any other focused widget
  /// so the keyboard is dismissed before navigation.
  void _unfocusSearch() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _navigateToEditor(Sermon sermon) {
    if (_selectionMode) {
      _toggleSelection(sermon);
      return;
    }
    _unfocusSearch();
    Navigator.of(
      context,
    ).push(AppRoutes.slideFromRight(EditorScreen(sermonId: sermon.id!)));
  }

  Future<void> _createNewSermon() async {
    _unfocusSearch();
    await Navigator.of(
      context,
    ).push(AppRoutes.slideFromRight(EditorScreen.newDraft()));
  }

  Future<bool> _archiveSermon(Sermon sermon) async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.archiveSermon(sermon);
    if (!mounted) return true;
    showTimedSnackBar(
      context,
      message: AppStrings.sermonArchived,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: AppStrings.undo,
        onPressed: () async {
          await repo.restoreSermon(sermon);
        },
      ),
    );
    return true;
  }

  Future<void> _cycleStatus(Sermon sermon) async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.cycleStatus(sermon);
  }

  Future<void> _moveSelectedToTrash() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final count = ids.length;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.moveToTrashMany(ids);
    _exitSelectionMode();
    if (!mounted) return;
    showTimedSnackBar(
      context,
      message: '$count ${AppStrings.bulkMovedToTrashSuffix}',
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: AppStrings.undo,
        onPressed: () async {
          await repo.restoreMany(ids);
        },
      ),
    );
  }

  Future<void> _cycleSelectedStatus() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.cycleStatusMany(ids);
    _exitSelectionMode();
  }

  void _openSettings() {
    if (_selectionMode) {
      _exitSelectionMode();
      return;
    }
    _unfocusSearch();
    Navigator.of(
      context,
    ).push(AppRoutes.slideFromBottom(const SettingsScreen()));
  }

  void _openTrash() {
    if (_selectionMode) {
      _exitSelectionMode();
      return;
    }
    _unfocusSearch();
    Navigator.of(context).push(AppRoutes.slideFromRight(const TrashScreen()));
  }

  void _openArchive() {
    if (_selectionMode) {
      _exitSelectionMode();
      return;
    }
    _unfocusSearch();
    Navigator.of(context).push(AppRoutes.slideFromRight(const ArchiveScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final signature = _DashboardQuerySignature(
      showArchived: false,
      revision: ref.watch(sermonChangesProvider).valueOrNull ?? 0,
      query: ref.watch(searchQueryProvider),
      statusFilter: ref.watch(statusFilterProvider),
      textoFilter: ref.watch(textoFilterProvider),
      tagFilter: ref.watch(tagFilterProvider),
    );
    _scheduleReloadIfNeeded(signature);
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          toolbarHeight: AppSpacing.topBarHeight,
          surfaceTintColor: Colors.transparent,
          leading: _selectionMode
              ? LaunchFade(
                  child: PillIconButton(
                    icon: AppIcons.close,
                    onPressed: _exitSelectionMode,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: LaunchFade(
                    child: PillIconButton(
                      icon: AppIcons.archive,
                      onPressed: _openArchive,
                    ),
                  ),
                ),
          leadingWidth: 72,
          centerTitle: true,
          title: LaunchFade(
            delay: const Duration(milliseconds: 30),
            child: Text(
              _selectionMode
                  ? '${_selectedIds.length} ${AppStrings.selectedSuffix}'
                  : AppStrings.dashboardTitle,
              style:
                  (_selectionMode
                          ? textTheme.titleLarge
                          : textTheme.headlineLarge)
                      ?.copyWith(
                        color: _selectionMode
                            ? tokens.textPrimary
                            : tokens.primary,
                      ),
            ),
          ),
          actions: _selectionMode
              ? [
                  TextButton(
                    onPressed: _selectAllVisible,
                    child: const Text(AppStrings.selectAll),
                  ),
                  const SizedBox(width: 12),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: LaunchFade(
                      delay: const Duration(milliseconds: 60),
                      child: PillIconButton(
                        icon: AppIcons.settings,
                        onPressed: _openSettings,
                      ),
                    ),
                  ),
                ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                32,
                AppSpacing.page,
                0,
              ),
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  enabled: !_selectionMode,
                  style: textTheme.bodyLarge?.copyWith(
                    color: tokens.textPrimary,
                    height: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchHint,
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      color: tokens.textSecondary,
                      height: 1,
                    ),
                    filled: true,
                    fillColor: tokens.searchSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      AppIcons.search,
                      color: tokens.textSecondary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconTap(
                            onTap: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                              setState(() {});
                            },
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(AppIcons.close),
                            ),
                          )
                        : null,
                  ),
                  onTap: _exitSelectionMode,
                  onChanged: (value) {
                    setState(() {});
                    _searchDebouncer.run(() {
                      ref.read(searchQueryProvider.notifier).state = value;
                    });
                  },
                ),
              ),
            ),
            if (!_selectionMode) const SizedBox(height: 32),
            if (!_selectionMode) const FilterChipsRow(),
            const SizedBox(height: 32),
            Expanded(
              child: RefreshIndicator(
                color: tokens.primary,
                onRefresh: () async {
                  final signature = _lastSignature;
                  if (signature != null) {
                    await _loadFirstPage(signature);
                  }
                },
                child: _DashboardPagedList(
                  controller: _scrollController,
                  results: _results,
                  showArchived: false,
                  isLoading: _isLoadingPage,
                  hasMore: _hasMore,
                  animateFirstPage: _animateFirstPage,
                  selectedIds: _selectedIds,
                  onPinnedTap: _navigateToEditor,
                  onTap: _navigateToEditor,
                  onArchive: _archiveSermon,
                  onStatusCycle: _cycleStatus,
                  onSelect: _toggleSelection,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: AppRoutes.duration,
          switchInCurve: AppRoutes.springCurve,
          switchOutCurve: AppRoutes.springCurve,
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
          child: _selectionMode
              ? _SelectionActionBar(
                  key: const ValueKey('selection-actions'),
                  onMoveToTrash: _moveSelectedToTrash,
                  onChangeStatus: _cycleSelectedStatus,
                )
              : LaunchFade(
                  key: const ValueKey('dashboard-actions'),
                  delay: const Duration(milliseconds: 30),
                  child: _DashboardActionBar(
                    onCreate: _createNewSermon,
                    onTrash: _openTrash,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DashboardPagedList extends StatelessWidget {
  const _DashboardPagedList({
    required this.controller,
    required this.results,
    required this.showArchived,
    required this.isLoading,
    required this.hasMore,
    required this.animateFirstPage,
    required this.selectedIds,
    required this.onPinnedTap,
    required this.onTap,
    required this.onArchive,
    required this.onStatusCycle,
    required this.onSelect,
  });

  final ScrollController controller;
  final List<SermonSearchResult> results;
  final bool showArchived;
  final bool isLoading;
  final bool hasMore;
  final bool animateFirstPage;
  final Set<int> selectedIds;
  final ValueChanged<Sermon> onPinnedTap;
  final ValueChanged<Sermon> onTap;
  final Future<bool> Function(Sermon sermon) onArchive;
  final ValueChanged<Sermon> onStatusCycle;
  final ValueChanged<Sermon> onSelect;

  bool get selectionMode => selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty && isLoading) {
      return ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 1,
        itemBuilder: (_, _) => const Column(
          children: [
            SizedBox(height: 240),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: AppSpacing.floatingDockBottomPadding(context),
        ),
        itemCount: 1,
        itemBuilder: (_, _) => Column(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            _EmptyDashboardState(showArchived: showArchived),
          ],
        ),
      );
    }

    final extraTopItems = showArchived ? 1 : 1;
    final itemCount =
        extraTopItems + results.length + ((isLoading || hasMore) ? 1 : 0);

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.only(
        bottom: AppSpacing.floatingDockBottomPadding(context),
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return showArchived
              ? const _ArchivedHeader()
              : IgnorePointer(
                  ignoring: selectionMode,
                  child: PinnedSection(onTap: onPinnedTap),
                );
        }

        final resultIndex = index - extraTopItems;
        if (resultIndex >= results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final result = results[resultIndex];
        final sermon = result.sermon;
        final selected = selectedIds.contains(sermon.id);
        final dimmed = selectionMode && !selected;
        final card = RepaintBoundary(
          child: showArchived
              ? _ArchivedSermonCard(sermon: sermon, onTap: () => onTap(sermon))
              : SermonCard(
                  sermon: sermon,
                  searchMatches: result.matches,
                  selected: selected,
                  dimmed: dimmed,
                  selectionMode: selectionMode,
                  onTap: () => selectionMode ? onSelect(sermon) : onTap(sermon),
                  onArchive: selectionMode ? null : () => onArchive(sermon),
                  onStatusCycle: () => onStatusCycle(sermon),
                  onLongPress: () => onSelect(sermon),
                ),
        );

        if (!animateFirstPage || resultIndex >= 25 || showArchived) {
          return card;
        }
        return _StaggeredFadeIn(delay: resultIndex * 30, child: card);
      },
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState({required this.showArchived});

  final bool showArchived;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: showArchived ? AppIcons.archive : AppIcons.search,
      label: showArchived
          ? AppStrings.noArchivedSermons
          : AppStrings.noSermonsFound,
      description: showArchived ? null : AppStrings.createFirstSermon,
    );
  }
}

class _ArchivedHeader extends StatelessWidget {
  const _ArchivedHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(
            AppIcons.archive,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 8),
          Text(
            AppStrings.archivedSermons,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.animateWith(
          SpringSimulation(AppMotion.listSpring, 0, 1, 0),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, AppMotion.cardEntranceOffset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    super.key,
    required this.onMoveToTrash,
    required this.onChangeStatus,
  });

  final VoidCallback onMoveToTrash;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final tokens = context.tokens;
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          AppSpacing.floatingDockSideMargin,
          0,
          AppSpacing.floatingDockSideMargin,
          AppSpacing.floatingDockBottomGap + bottomInset,
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(24),
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
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.destructive,
                  shadowColor: tokens.destructive.withValues(alpha: 0.45),
                  elevation: 4,
                ),
                onPressed: onMoveToTrash,
                icon: const Icon(AppIcons.delete),
                label: const Text(AppStrings.bulkMoveToTrash),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.primary,
                  side: BorderSide(color: tokens.border),
                ),
                onPressed: onChangeStatus,
                icon: const Icon(AppIcons.swap),
                label: const Text(AppStrings.changeStatus),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardQuerySignature {
  const _DashboardQuerySignature({
    required this.showArchived,
    required this.revision,
    required this.query,
    required this.statusFilter,
    required this.textoFilter,
    required this.tagFilter,
  });

  final bool showArchived;
  final int revision;
  final String query;
  final SermonStatus? statusFilter;
  final String? textoFilter;
  final String? tagFilter;

  @override
  bool operator ==(Object other) {
    return other is _DashboardQuerySignature &&
        other.showArchived == showArchived &&
        other.revision == revision &&
        other.query == query &&
        other.statusFilter == statusFilter &&
        other.textoFilter == textoFilter &&
        other.tagFilter == tagFilter;
  }

  @override
  int get hashCode => Object.hash(
    showArchived,
    revision,
    query,
    statusFilter,
    textoFilter,
    tagFilter,
  );
}

class _ArchivedSermonCard extends ConsumerWidget {
  const _ArchivedSermonCard({required this.sermon, required this.onTap});

  final Sermon sermon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey('archived_${sermon.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.restore, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              AppStrings.restore,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final repo = await ref.read(sermonRepositoryProvider.future);
        await repo.restoreSermon(sermon);
        if (!context.mounted) return false;
        showTimedSnackBar(context, message: AppStrings.restored);
        return true;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  AppIcons.archive,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sermon.title.isEmpty
                        ? AppStrings.untitledSermon
                        : sermon.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardActionBar extends StatelessWidget {
  const _DashboardActionBar({required this.onCreate, required this.onTrash});

  final VoidCallback onCreate;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.floatingDockSideMargin,
          0,
          AppSpacing.floatingDockSideMargin,
          AppSpacing.floatingDockBottomGap + bottomInset,
        ),
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
              child: Row(
                children: [
                  _BottomAction(
                    icon: AppIcons.book,
                    label: AppStrings.sermons,
                    onTap: () {},
                    selected: true,
                  ),
                  _DockFab(onTap: onCreate),
                  _BottomAction(
                    icon: AppIcons.delete,
                    label: AppStrings.trash,
                    onTap: onTrash,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockFab extends StatefulWidget {
  const _DockFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DockFab> createState() => _DockFabState();
}

class _DockFabState extends State<_DockFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pulse.animateWith(
      SpringSimulation(AppMotion.snappySpring, _pulse.value, AppMotion.fabPulseMin, 0),
    );
  }

  void _onTapUp([Object? _]) {
    // Overshoot to 1.08 then settle to 1.0
    _pulse.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 400, damping: 18),
        _pulse.value,
        1.0,
        // Positive velocity causes overshoot past target
        3.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapUp,
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tokens.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tokens.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                AppIcons.plus,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatefulWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicator;

  @override
  void initState() {
    super.initState();
    _indicator = AnimationController.unbounded(
      vsync: this,
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_BottomAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _indicator.animateWith(
        SpringSimulation(
          AppMotion.liquidSpring,
          _indicator.value,
          widget.selected ? 1.0 : 0.0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _indicator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      child: IconTap(
        onTap: widget.onTap,
        child: SizedBox(
          height: 56,
          child: AnimatedBuilder(
            animation: _indicator,
            builder: (context, _) {
              final t = _indicator.value.clamp(0.0, 1.0);
              final iconColor =
                  Color.lerp(tokens.textSecondary, tokens.primary, t)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 32,
                    constraints: const BoxConstraints(minWidth: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: tokens.selectedSurface.withValues(alpha: t),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Icon(widget.icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: iconColor,
                      fontWeight:
                          t > 0.5 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
