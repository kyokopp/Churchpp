import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../models/sermon.dart';
import '../../providers/sermon_providers.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/figma_primitives.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final Set<int> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

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

  void _selectAll(List<Sermon> sermons) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(sermons.map((sermon) => sermon.id).nonNulls);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sermonsAsync = ref.watch(trashedSermonsProvider);
    final tokens = context.tokens;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          leading: PillIconButton(
            icon: _selectionMode ? AppIcons.close : AppIcons.back,
            onPressed: _selectionMode
                ? _exitSelectionMode
                : () => Navigator.of(context).pop(),
          ),
          title: Text(
            _selectionMode
                ? '${_selectedIds.length} ${AppStrings.selectedSuffix}'
                : AppStrings.trash,
          ),
          actions: [
            sermonsAsync.maybeWhen(
              data: (sermons) => _selectionMode
                  ? TextButton(
                      onPressed: () => _selectAll(sermons),
                      child: const Text(AppStrings.selectAll),
                    )
                  : PillIconButton(
                      icon: AppIcons.delete,
                      tooltip: AppStrings.emptyTrash,
                      onPressed: () => _confirmEmptyTrash(context, ref),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: tokens.primary,
          onRefresh: () async {
            final repo = await ref.read(sermonRepositoryProvider.future);
            await repo.getTrashed();
          },
          child: sermonsAsync.when(
            loading: () => ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: 1,
              itemBuilder: (_, _) => const Column(
                children: [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            error: (err, _) =>
                Center(child: Text('${AppStrings.errorPrefix}: $err')),
            data: (sermons) {
              if (sermons.isEmpty) {
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: 1,
                  itemBuilder: (_, _) => const Column(
                    children: [
                      SizedBox(height: 180),
                      EmptyState(
                        icon: AppIcons.delete,
                        label: AppStrings.trashEmpty,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  AppSpacing.floatingDockBottomPadding(context),
                ),
                addRepaintBoundaries: true,
                itemCount: sermons.length,
                itemBuilder: (context, index) {
                  final sermon = sermons[index];
                  final selected = _selectedIds.contains(sermon.id);
                  return RepaintBoundary(
                    child: _TrashCard(
                      sermon: sermon,
                      selected: selected,
                      dimmed: _selectionMode && !selected,
                      selectionMode: _selectionMode,
                      onTap: () =>
                          _selectionMode ? _toggleSelection(sermon) : null,
                      onLongPress: () => _toggleSelection(sermon),
                      onRestore: () => _restoreOne(context, sermon),
                      onDelete: () => _confirmDelete(context, sermon),
                    ),
                  );
                },
              );
            },
          ),
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
              ? _TrashBulkActionBar(
                  key: const ValueKey('trash-bulk-actions'),
                  onDelete: () => _confirmDeleteSelected(context),
                  onRestore: () => _restoreSelected(context),
                )
              : const SizedBox.shrink(key: ValueKey('trash-actions-empty')),
        ),
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppRoutes.showSpringDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.emptyTrashQuestion),
        content: const Text(AppStrings.emptyTrashBody),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.emptyTrash();
  }

  Future<void> _restoreOne(BuildContext context, Sermon sermon) async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.restoreSermon(sermon);
    if (!context.mounted) return;
    showTimedSnackBar(context, message: AppStrings.restored);
  }

  Future<void> _confirmDelete(BuildContext context, Sermon sermon) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await AppRoutes.showSpringDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${AppStrings.deletePermanently}?'),
        content: const Text(AppStrings.cannotUndo),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.deleteSermon(sermon.id!);
  }

  Future<void> _restoreSelected(BuildContext context) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final count = ids.length;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.restoreMany(ids);
    _exitSelectionMode();
    if (!context.mounted) return;
    showTimedSnackBar(
      context,
      message: '$count ${AppStrings.bulkRestoredSuffix}',
    );
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await AppRoutes.showSpringDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir ${ids.length} sermões permanentemente?'),
        content: const Text(AppStrings.cannotUndo),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.deleteMany(ids);
    _exitSelectionMode();
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    required this.sermon,
    required this.selected,
    required this.dimmed,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onRestore,
    required this.onDelete,
  });

  final Sermon sermon;
  final bool selected;
  final bool dimmed;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

    return Dismissible(
      key: ValueKey('trash_${sermon.id}'),
      direction: selectionMode
          ? DismissDirection.none
          : DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.restore, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              AppStrings.restore,
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(AppIcons.delete, color: colorScheme.error),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onRestore();
        } else if (direction == DismissDirection.endToStart) {
          onDelete();
        }
        return false;
      },
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: Stack(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sermon.title.isEmpty
                                  ? AppStrings.untitledSermon
                                  : sermon.title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${AppStrings.trashDatePrefix} ${dateFormat.format(sermon.updatedAt)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.58,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: AppStrings.deletePermanently,
                        child: IconTap(
                          onTap: onDelete,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              AppIcons.delete,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6F3CC3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AppIcons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrashBulkActionBar extends StatelessWidget {
  const _TrashBulkActionBar({
    super.key,
    required this.onDelete,
    required this.onRestore,
  });

  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final colorScheme = Theme.of(context).colorScheme;
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
                  backgroundColor: colorScheme.error,
                  shadowColor: colorScheme.error.withValues(alpha: 0.55),
                  elevation: 4,
                ),
                onPressed: onDelete,
                icon: const Icon(AppIcons.delete),
                label: const Text(AppStrings.deletePermanently),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shadowColor: Colors.green.withValues(alpha: 0.55),
                  elevation: 4,
                ),
                onPressed: onRestore,
                icon: const Icon(AppIcons.restore),
                label: const Text(AppStrings.restore),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
