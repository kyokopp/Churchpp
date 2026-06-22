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
import '../editor/editor_screen.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(archivedSermonsProvider);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page),
          child: PillIconButton(
            icon: AppIcons.back,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          AppStrings.archivedSermons,
          style: textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        actions: const [SizedBox(width: 72)],
      ),
      body: RefreshIndicator(
        color: tokens.primary,
        onRefresh: () async {
          final repo = await ref.read(sermonRepositoryProvider.future);
          await repo.getAll(archived: true);
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
                      icon: AppIcons.archive,
                      label: AppStrings.noArchivedSermons,
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
              itemCount: sermons.length,
              itemBuilder: (context, index) {
                final sermon = sermons[index];
                return RepaintBoundary(
                  child: _ArchivedCard(
                    sermon: sermon,
                    onTap: () {
                      Navigator.of(context).push(
                        AppRoutes.slideFromRight(
                          EditorScreen(sermonId: sermon.id!),
                        ),
                      );
                    },
                    onRestore: () => _restore(context, ref, sermon),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Sermon sermon,
  ) async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.restoreSermon(sermon);
    if (!context.mounted) return;
    showTimedSnackBar(context, message: AppStrings.restored);
  }
}

class _ArchivedCard extends StatelessWidget {
  const _ArchivedCard({
    required this.sermon,
    required this.onTap,
    required this.onRestore,
  });

  final Sermon sermon;
  final VoidCallback onTap;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

    return Dismissible(
      key: ValueKey('archive_${sermon.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: tokens.delivered.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Icon(AppIcons.restore, color: tokens.delivered),
      ),
      confirmDismiss: (_) async {
        onRestore();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SpringTap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: tokens.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(AppIcons.archive, color: tokens.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sermon.title.isEmpty
                            ? AppStrings.untitledSermon
                            : sermon.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppStrings.archiveDatePrefix} ${dateFormat.format(sermon.updatedAt)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: AppStrings.restore,
                  child: IconTap(
                    onTap: onRestore,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(AppIcons.restore, color: tokens.delivered),
                    ),
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
