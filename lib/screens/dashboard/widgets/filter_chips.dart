import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_strings.dart';
import '../../../models/sermon.dart';
import '../../../providers/sermon_providers.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/figma_primitives.dart';

class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(statusFilterProvider);
    final textoFilter = ref.watch(textoFilterProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final allTags = ref.watch(allTagsProvider).valueOrNull ?? [];
    final allTextos = ref.watch(allTextosProvider).valueOrNull ?? [];
    final chips = <Widget>[
      _FigmaFilterChip(
        selected:
            statusFilter == null && textoFilter == null && tagFilter == null,
        label: const Text(AppStrings.all),
        onTap: () {
          ref.read(statusFilterProvider.notifier).state = null;
          ref.read(textoFilterProvider.notifier).state = null;
          ref.read(tagFilterProvider.notifier).state = null;
        },
      ),
      ...SermonStatus.values.map(
        (status) => _FigmaFilterChip(
          selected: statusFilter == status,
          label: Text(status.label),
          onTap: () {
            ref.read(statusFilterProvider.notifier).state =
                statusFilter == status ? null : status;
          },
        ),
      ),
      ...allTextos.map(
        (s) => _FigmaFilterChip(
          selected: textoFilter == s,
          label: Text(s),
          onTap: () {
            ref.read(textoFilterProvider.notifier).state = textoFilter == s
                ? null
                : s;
          },
        ),
      ),
      ...allTags.map(
        (t) => _FigmaFilterChip(
          selected: tagFilter == t,
          icon: AppIcons.tag,
          label: Text(t),
          onTap: () {
            ref.read(tagFilterProvider.notifier).state = tagFilter == t
                ? null
                : t;
          },
        ),
      ),
    ];

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: chips.length,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: chips[index],
        ),
      ),
    );
  }
}

class _FigmaFilterChip extends StatelessWidget {
  const _FigmaFilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final bool selected;
  final Widget label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SpringTap(
      onTap: onTap,
      borderRadius: AppRadii.card,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: AppSpring.curve,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? tokens.selectedSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? Colors.transparent : tokens.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: tokens.textSecondary),
              const SizedBox(width: 8),
            ],
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? tokens.mutedText : tokens.textSecondary,
              ),
              child: label,
            ),
          ],
        ),
      ),
    );
  }
}
