import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animation/motion_constants.dart';
import '../../l10n/app_strings.dart';
import '../../providers/sermon_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/sermon_export_service.dart';
import '../../services/sermon_import_service.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/figma_primitives.dart';
import '../trash/trash_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _importInProgress = false;
  bool _exportInProgress = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: AppSpacing.topBarHeight,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page),
          child: PillIconButton(
            icon: AppIcons.back,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        centerTitle: true,
        title: Text(
          AppStrings.settings,
          style: textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        actions: const [SizedBox(width: 72)],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          16,
          AppSpacing.page,
          AppSpacing.floatingDockBottomPadding(context),
        ),
        children: [
          LaunchFade(
            delay: Duration.zero,
            translateY: 12,
            child: _SectionHeading(label: AppStrings.appearance),
          ),
          const SizedBox(height: 8),
          LaunchFade(
            delay: const Duration(milliseconds: AppMotion.sectionStaggerMs),
            translateY: 20,
            child: _SettingsSectionCard(
              child: Column(
                children: [
                  _LiquidThemeModeRow(
                    title: AppStrings.system,
                    subtitle: AppStrings.followDevice,
                    value: ThemeMode.system,
                    selectedValue: themeMode,
                    delay: 0,
                  ),
                  const _FigmaDivider(),
                  _LiquidThemeModeRow(
                    title: AppStrings.light,
                    subtitle: AppStrings.lightAlways,
                    value: ThemeMode.light,
                    selectedValue: themeMode,
                    delay: AppMotion.cardStaggerMs,
                  ),
                  const _FigmaDivider(),
                  _LiquidThemeModeRow(
                    title: AppStrings.dark,
                    subtitle: AppStrings.darkAlways,
                    value: ThemeMode.dark,
                    selectedValue: themeMode,
                    delay: AppMotion.cardStaggerMs * 2,
                  ),
                  const _FigmaDivider(),
                  LaunchFade(
                    delay: const Duration(
                      milliseconds: AppMotion.cardStaggerMs * 3,
                    ),
                    translateY: 10,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.fontSize,
                            style: textTheme.bodyMedium?.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LiquidFontSizeSegmentedControl(value: fontSize),
                          const SizedBox(height: 16),
                          FrostedGlass(
                            borderRadius: AppRadii.card,
                            sigma: 12,
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? tokens.surface.withValues(alpha: 0.36)
                                : Colors.white.withValues(alpha: 0.45),
                            borderColor: Colors.white.withValues(alpha: 0.24),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                AppStrings.previewText,
                                style: textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          LaunchFade(
            delay: const Duration(milliseconds: AppMotion.sectionStaggerMs * 2),
            translateY: 12,
            child: _SectionHeading(label: AppStrings.dataManagement),
          ),
          const SizedBox(height: 8),
          LaunchFade(
            delay: const Duration(milliseconds: AppMotion.sectionStaggerMs * 3),
            translateY: 20,
            child: _SettingsSectionCard(
              child: Column(
                children: [
                  _SettingsActionRow(
                    icon: AppIcons.delete,
                    title: AppStrings.trash,
                    subtitle: AppStrings.openTrashHelp,
                    onTap: () => Navigator.of(
                      context,
                    ).push(AppRoutes.slideFromRight(const TrashScreen())),
                  ),
                  const _FigmaDivider(),
                  _SettingsActionRow(
                    icon: AppIcons.export,
                    title: AppStrings.exportData,
                    subtitle: AppStrings.exportDataHelp,
                    onTap: _exportInProgress
                        ? null
                        : () => _exportData(context),
                  ),
                  const _FigmaDivider(),
                  _SettingsActionRow(
                    icon: AppIcons.import,
                    title: AppStrings.importSpreadsheet,
                    subtitle: AppStrings.importDataHelp,
                    onTap: _importInProgress
                        ? null
                        : () => _importData(context),
                  ),
                  const _FigmaDivider(),
                  _SettingsActionRow(
                    icon: AppIcons.delete,
                    title: AppStrings.clearDeliveryHistory,
                    subtitle: AppStrings.clearDeliveryHistoryHelp,
                    destructive: true,
                    onTap: () => _confirmClearHistory(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              AppStrings.aboutVersion,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.mutedText.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    if (_exportInProgress) return;
    setState(() => _exportInProgress = true);
    _showExportDialog(context);
    try {
      final repo = await ref.read(sermonRepositoryProvider.future);
      final sermons = await repo.getExportSermons();
      final bytes = SermonExportService.buildWorkbookBytes(sermons);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: AppStrings.exportData,
        fileName: SermonExportService.defaultFileName(),
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: bytes,
        lockParentWindow: true,
      );
      if (!context.mounted || savedPath == null) return;
      showTimedSnackBar(
        context,
        message: AppStrings.exportSuccess,
        duration: const Duration(seconds: 4),
      );
    } catch (_) {
      if (!context.mounted) return;
      showTimedSnackBar(context, message: AppStrings.exportFailure);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (mounted) setState(() => _exportInProgress = false);
    }
  }

  Future<void> _importData(BuildContext context) async {
    if (_importInProgress) return;
    setState(() => _importInProgress = true);
    final cancelToken = SermonImportCancelToken();
    final progressNotifier = ValueNotifier<SermonImportProgress>(
      const SermonImportProgress(
        stage: SermonImportStage.reading,
        current: 0,
        total: 0,
      ),
    );
    final resultNotifier = ValueNotifier<SermonImportResult?>(null);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (!context.mounted) return;
      final file = result?.files.isEmpty ?? true ? null : result!.files.first;
      final bytes = file?.bytes;
      if (result == null) {
        showTimedSnackBar(context, message: AppStrings.importNoFile);
        return;
      }
      if (bytes == null) {
        showTimedSnackBar(context, message: AppStrings.importReadFailure);
        return;
      }

      unawaited(
        AppRoutes.showSpringDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ImportProgressDialog(
            progress: progressNotifier,
            result: resultNotifier,
            cancelToken: cancelToken,
          ),
        ),
      );
      final repo = await ref.read(sermonRepositoryProvider.future);
      final importResult = await SermonImportService(repo).importBytes(
        bytes,
        cancelToken: cancelToken,
        onProgress: (progress) => progressNotifier.value = progress,
      );
      if (!context.mounted) return;
      resultNotifier.value = importResult;
      if (importResult.cancelled) {
        Navigator.of(context, rootNavigator: true).maybePop();
        showTimedSnackBar(context, message: AppStrings.importCancelled);
      } else {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
      showTimedSnackBar(context, message: AppStrings.importReadFailure);
    } finally {
      progressNotifier.dispose();
      resultNotifier.dispose();
      if (mounted) setState(() => _importInProgress = false);
    }
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await AppRoutes.showSpringDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.clearDeliveryHistoryQuestion),
        content: const Text(AppStrings.clearDeliveryHistoryBody),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.destructive,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.moveAllToTrashConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(sermonRepositoryProvider.future);
    await repo.moveAllSermonsToTrash();
    if (!context.mounted) return;
    showTimedSnackBar(
      context,
      message: AppStrings.deliveryHistoryCleared,
      duration: const Duration(seconds: 4),
    );
  }

  void _showExportDialog(BuildContext context) {
    unawaited(
      AppRoutes.showSpringDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ExportProgressDialog(),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final glow = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.20)
        : tokens.primary.withValues(alpha: 0.20);
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(
        color: tokens.textSecondary,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        shadows: [
          Shadow(color: glow, offset: const Offset(0, 1), blurRadius: 4),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FrostedGlass(
      borderRadius: AppRadii.card,
      sigma: 20,
      color: isDark
          ? tokens.surface.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.55),
      borderColor: Colors.white.withValues(alpha: isDark ? 0.15 : 0.40),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          offset: const Offset(0, 10),
          blurRadius: 20,
          spreadRadius: -8,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          offset: const Offset(0, 4),
          blurRadius: 8,
          spreadRadius: -5,
        ),
      ],
      child: child,
    );
  }
}

class _LiquidThemeModeRow extends ConsumerWidget {
  const _LiquidThemeModeRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selectedValue,
    required this.delay,
  });

  final String title;
  final String subtitle;
  final ThemeMode value;
  final ThemeMode selectedValue;
  final int delay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = value == selectedValue;
    return LaunchFade(
      delay: Duration(milliseconds: delay),
      translateY: 10,
      child: _SettingsActionRow(
        icon: selected ? AppIcons.check : AppIcons.circle,
        title: title,
        subtitle: subtitle,
        selected: selected,
        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(value),
      ),
    );
  }
}

class _ExportProgressDialog extends StatelessWidget {
  const _ExportProgressDialog();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: tokens.primary,
            ),
          ),
          const SizedBox(width: 16),
          const Flexible(child: Text(AppStrings.exportInProgress)),
        ],
      ),
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({
    required this.progress,
    required this.result,
    required this.cancelToken,
  });

  final ValueNotifier<SermonImportProgress> progress;
  final ValueNotifier<SermonImportResult?> result;
  final SermonImportCancelToken cancelToken;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SermonImportResult?>(
      valueListenable: result,
      builder: (context, importResult, _) {
        return ValueListenableBuilder<SermonImportProgress>(
          valueListenable: progress,
          builder: (context, currentProgress, _) {
            final tokens = context.tokens;
            final color = _statusColor(tokens, importResult);
            final total = currentProgress.total;
            final value = importResult != null
                ? 1.0
                : total == 0
                ? null
                : (currentProgress.current / total).clamp(0.0, 1.0);
            return AlertDialog(
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (importResult == null) ...[
                      LinearProgressIndicator(value: value, color: color),
                      const SizedBox(height: 16),
                      Text(
                        total == 0
                            ? AppStrings.importReadingFile
                            : '${AppStrings.importOverlayCounter} '
                                  '${currentProgress.current} de $total',
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      SpringScaleIn(
                        from: 0.8,
                        spring: AppMotion.calmSpring,
                        child: Icon(AppIcons.check, size: 42, color: color),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _resultLabel(importResult),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: importResult == null
                  ? [
                      TextButton(
                        onPressed: cancelToken.cancel,
                        child: const Text(AppStrings.cancel),
                      ),
                    ]
                  : null,
            );
          },
        );
      },
    );
  }

  Color _statusColor(AppThemeTokens tokens, SermonImportResult? result) {
    if (result == null) return tokens.primary;
    if (result.importedCount == 0 && result.errorCount > 0) {
      return tokens.destructive;
    }
    if (result.errorCount > 0) return tokens.ready;
    return tokens.delivered;
  }

  String _resultLabel(SermonImportResult result) {
    if (result.importedCount == 0 && result.errorCount > 0) {
      return AppStrings.importFailure;
    }
    if (result.errorCount > 0) {
      return '${result.importedCount} importados. '
          '${result.errorCount} linhas ignoradas por erro.';
    }
    return '${result.importedCount} ${AppStrings.importSuccessSuffix}';
  }
}

class _LiquidFontSizeSegmentedControl extends ConsumerStatefulWidget {
  const _LiquidFontSizeSegmentedControl({required this.value});

  final FontSizePreference value;

  @override
  ConsumerState<_LiquidFontSizeSegmentedControl> createState() =>
      _LiquidFontSizeSegmentedControlState();
}

class _LiquidFontSizeSegmentedControlState
    extends ConsumerState<_LiquidFontSizeSegmentedControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicator;
  late int _fromIndex;
  late int _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = FontSizePreference.values.indexOf(widget.value);
    _toIndex = _fromIndex;
    _indicator = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(_LiquidFontSizeSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _fromIndex = FontSizePreference.values.indexOf(oldWidget.value);
      _toIndex = FontSizePreference.values.indexOf(widget.value);
      _indicator.animateWith(
        SpringSimulation(AppMotion.liquidSpring, 0, 1, 0),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final options = FontSizePreference.values;
          final segmentWidth = (constraints.maxWidth - 8) / options.length;
          return FrostedGlass(
            borderRadius: AppRadii.card,
            sigma: 14,
            color: isDark
                ? tokens.surface.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.42),
            borderColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.32),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _indicator,
                      builder: (context, _) {
                        final t = _indicator.value.clamp(0.0, 1.0);
                        final x =
                            (_fromIndex + ((_toIndex - _fromIndex) * t)) *
                            segmentWidth;
                        return Transform.translate(
                          offset: Offset(x, 0),
                          child: SizedBox(
                            width: segmentWidth,
                            height: 40,
                            child: FrostedGlass(
                              borderRadius: AppRadii.segmented,
                              sigma: 8,
                              color: isDark
                                  ? tokens.primary.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.70),
                              borderColor: Colors.white.withValues(alpha: 0.18),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        );
                      },
                    ),
                    Row(
                      children: options.map((option) {
                        final selected = option == widget.value;
                        return Expanded(
                          child: SpringTap(
                            onTap: () => ref
                                .read(fontSizeProvider.notifier)
                                .setFontSize(option),
                            borderRadius: AppRadii.segmented,
                            child: SizedBox(
                              height: 40,
                              child: Center(
                                child: Text(
                                  option.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: selected
                                            ? tokens.primary
                                            : tokens.textSecondary,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsActionRow extends StatefulWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool selected;
  final bool destructive;

  @override
  State<_SettingsActionRow> createState() => _SettingsActionRowState();
}

class _SettingsActionRowState extends State<_SettingsActionRow>
    with TickerProviderStateMixin {
  late final AnimationController _scale;
  late final AnimationController _chevron;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController.unbounded(vsync: this, value: 1);
    _chevron = AnimationController.unbounded(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _scale.dispose();
    _chevron.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null;

  void _animate(AnimationController controller, double target) {
    controller.animateWith(
      SpringSimulation(AppMotion.snappySpring, controller.value, target, 0),
    );
  }

  void _pressDown(TapDownDetails _) {
    if (!_enabled) return;
    _animate(_scale, AppMotion.buttonPressScale);
    _animate(_chevron, 1);
  }

  void _pressUp([Object? _]) {
    if (!_enabled) return;
    _animate(_scale, 1);
    _animate(_chevron, 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = widget.destructive
        ? context.tokens.destructive
        : widget.selected
        ? context.tokens.primary
        : context.tokens.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _pressDown,
      onTapUp: _pressUp,
      onTapCancel: _pressUp,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.destructive
                            ? tokens.destructive
                            : tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              _SpringChevron(
                controller: _chevron,
                color: widget.destructive ? tokens.destructive : tokens.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpringChevron extends StatelessWidget {
  const _SpringChevron({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(4 * t, 0),
          child: Icon(AppIcons.chevronRight, color: color),
        );
      },
    );
  }
}

class _FigmaDivider extends StatelessWidget {
  const _FigmaDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFCBC4D2),
      ),
    );
  }
}
