import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../animation/motion_constants.dart';
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

class _FigmaFilterChip extends StatefulWidget {
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
  State<_FigmaFilterChip> createState() => _FigmaFilterChipState();
}

class _FigmaFilterChipState extends State<_FigmaFilterChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController.unbounded(
      vsync: this,
      value: widget.selected ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_FigmaFilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _fill.animateWith(
        SpringSimulation(
          AppMotion.liquidSpring,
          _fill.value,
          widget.selected ? 1 : 0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SpringTap(
      onTap: widget.onTap,
      borderRadius: AppRadii.card,
      child: AnimatedBuilder(
        animation: _fill,
        builder: (context, _) {
          final t = _fill.value.clamp(0.0, 1.0);
          final fill = tokens.selectedSurface.withValues(alpha: t);
          final border = tokens.outline.withValues(alpha: 1 - t);
          final textColor =
              Color.lerp(tokens.textSecondary, tokens.mutedText, t)!;
          return Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: tokens.textSecondary),
                  const SizedBox(width: 8),
                ],
                DefaultTextStyle.merge(
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: textColor),
                  child: widget.label,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
