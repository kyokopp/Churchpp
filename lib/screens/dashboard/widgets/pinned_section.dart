import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/sermon.dart';
import '../../../providers/sermon_providers.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/figma_primitives.dart';

class PinnedSection extends ConsumerWidget {
  final void Function(Sermon sermon) onTap;

  const PinnedSection({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedSermonsProvider);

    return pinnedAsync.when(
      data: (sermons) {
        if (sermons.isEmpty) return const SizedBox.shrink();

        final textTheme = Theme.of(context).textTheme;
        final tokens = context.tokens;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Text(
                AppStrings.pinned,
                style: textTheme.titleLarge?.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: sermons.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final sermon = sermons[index];
                  return SpringTap(
                    onTap: () => onTap(sermon),
                    child: Container(
                      width: 256,
                      height: 192,
                      padding: const EdgeInsets.fromLTRB(20, 21, 20, 16),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: tokens.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (sermon.texto ?? AppStrings.textoMatch)
                                .toUpperCase(),
                            style: textTheme.labelSmall?.copyWith(
                              color: tokens.textSecondary,
                              letterSpacing: 0.55,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sermon.title.isEmpty
                                ? AppStrings.untitledSermon
                                : sermon.title,
                            style: textTheme.titleLarge?.copyWith(
                              color: tokens.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                AppIcons.calendar,
                                size: 14,
                                color: tokens.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.now,
                                style: textTheme.labelSmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
