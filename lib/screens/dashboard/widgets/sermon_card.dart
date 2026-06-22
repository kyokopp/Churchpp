import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/sermon.dart';
import '../../../providers/sermon_providers.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/figma_primitives.dart';

class SermonCard extends ConsumerWidget {
  const SermonCard({
    super.key,
    required this.sermon,
    required this.onTap,
    this.onArchive,
    this.onStatusCycle,
    this.onLongPress,
    this.searchMatches = const {},
    this.selected = false,
    this.dimmed = false,
    this.selectionMode = false,
  });

  final Sermon sermon;
  final VoidCallback onTap;
  final Future<bool> Function()? onArchive;
  final VoidCallback? onStatusCycle;
  final VoidCallback? onLongPress;
  final Set<SermonSearchMatch> searchMatches;
  final bool selected;
  final bool dimmed;
  final bool selectionMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final card = Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: 6,
            ),
            child: SpringTap(
              onTap: onTap,
              onLongPress: onLongPress,
              child: SizedBox(
                width: double.infinity,
                child: FrostedGlass(
                  borderRadius: AppRadii.card,
                  sigma: 10,
                  color: isDark
                      ? tokens.surface.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.8),
                  borderColor: Colors.white.withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (sermon.texto ?? AppStrings.textoMatch).toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: tokens.textSecondary,
                            letterSpacing: 0.55,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                sermon.title.isEmpty
                                    ? AppStrings.untitledSermon
                                    : sermon.title,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: sermon.title.isEmpty
                                      ? tokens.outline
                                      : tokens.textPrimary,
                                  height: 36 / 28,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusChip(status: sermon.status),
                          ],
                        ),
                        if (sermon.texto != null &&
                            sermon.texto!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            sermon.texto!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...sermon.tags
                                      .take(3)
                                      .map((tag) => _TagPill(label: tag)),
                                  if (sermon.tags.length > 3)
                                    _TagPill(
                                      label: '+${sermon.tags.length - 3}',
                                    ),
                                ],
                              ),
                            ),
                            if (sermon.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  AppIcons.pin,
                                  size: 16,
                                  color: tokens.primary,
                                ),
                              ),
                            Icon(
                              AppIcons.calendar,
                              size: 14,
                              color: tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sermon.scheduledDate == null
                                  ? AppStrings.noDate
                                  : dateFormat.format(sermon.scheduledDate!),
                              style: textTheme.labelSmall?.copyWith(
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (searchMatches.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: searchMatches
                                .map((match) => _SearchMatchChip(match: match))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: 18,
              right: 36,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tokens.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.36),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
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
    );

    return Dismissible(
      key: ValueKey(sermon.id),
      direction: sermon.isPinned || selectionMode
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.ready.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Icon(AppIcons.archive, color: tokens.ready),
      ),
      confirmDismiss: (direction) async {
        if (direction != DismissDirection.startToEnd) return false;
        return onArchive == null ? false : onArchive!();
      },
      child: sermon.isPinned
          ? Tooltip(message: AppStrings.pinnedSwipeDisabled, child: card)
          : card,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SermonStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SermonStatus.draft => context.tokens.outline,
      SermonStatus.ready => context.tokens.ready,
      SermonStatus.delivered => context.tokens.delivered,
    };
    return FigmaStatusChip(statusLabel: status.label, color: color);
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.tokens.secondarySurface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: context.tokens.textSecondary),
      ),
    );
  }
}

class _SearchMatchChip extends StatelessWidget {
  const _SearchMatchChip({required this.match});

  final SermonSearchMatch match;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (background, foreground, label) = switch (match) {
      SermonSearchMatch.id => (
        isDark ? const Color(0xFF3B315F) : const Color(0xFFE2DAFF),
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF33246B),
        AppStrings.idMatch,
      ),
      SermonSearchMatch.title => (
        isDark ? const Color(0xFF1F4D49) : const Color(0xFFD6F2EF),
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF0C4B45),
        AppStrings.titleMatch,
      ),
      SermonSearchMatch.texto => (
        isDark ? const Color(0xFF59471E) : const Color(0xFFF8E6B8),
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF654600),
        AppStrings.textoMatch,
      ),
      SermonSearchMatch.date => (
        isDark ? const Color(0xFF573343) : const Color(0xFFF4D8E4),
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF6C2244),
        AppStrings.dateMatch,
      ),
      SermonSearchMatch.tag => (
        isDark ? const Color(0xFF2F4332) : const Color(0xFFDDF2DF),
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF22512A),
        AppStrings.tagMatch,
      ),
      SermonSearchMatch.status => (
        isDark ? const Color(0xFF30384F) : const Color(0xFFDDE7FF),
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF24365E),
        AppStrings.statusMatch,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
