import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          16,
          AppSpacing.page,
          AppSpacing.floatingDockBottomPadding(context),
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final item = switch (index) {
            0 => _SectionHeading(label: AppStrings.appearance),
            1 => const SizedBox(height: 8),
            2 => SectionCard(
              child: Column(
                children: [
                  _ThemeModeRow(
                    title: AppStrings.system,
                    subtitle: AppStrings.followDevice,
                    value: ThemeMode.system,
                    selectedValue: themeMode,
                  ),
                  const _FigmaDivider(),
                  _ThemeModeRow(
                    title: AppStrings.light,
                    subtitle: AppStrings.lightAlways,
                    value: ThemeMode.light,
                    selectedValue: themeMode,
                  ),
                  const _FigmaDivider(),
                  _ThemeModeRow(
                    title: AppStrings.dark,
                    subtitle: AppStrings.darkAlways,
                    value: ThemeMode.dark,
                    selectedValue: themeMode,
                  ),
                  const _FigmaDivider(),
                  Padding(
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
                        _FontSizeSegmentedControl(value: fontSize),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.secondarySurface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                          child: Text(
                            AppStrings.previewText,
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            3 => const SizedBox(height: 32),
            4 => _SectionHeading(label: AppStrings.dataManagement),
            5 => const SizedBox(height: 8),
            6 => SectionCard(
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
            7 => const SizedBox(height: 32),
            _ => Center(
              child: Text(
                AppStrings.aboutVersion,
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText.withValues(alpha: 0.6),
                ),
              ),
            ),
          };
          return RepaintBoundary(child: item);
        },
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
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: context.tokens.textPrimary),
    );
  }
}

class _ThemeModeRow extends ConsumerWidget {
  const _ThemeModeRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selectedValue,
  });

  final String title;
  final String subtitle;
  final ThemeMode value;
  final ThemeMode selectedValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = value == selectedValue;
    return _SettingsActionRow(
      icon: selected ? AppIcons.check : AppIcons.circle,
      title: title,
      subtitle: subtitle,
      selected: selected,
      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(value),
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1),
                        duration: AppRoutes.duration,
                        curve: AppRoutes.springCurve,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
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

class _FontSizeSegmentedControl extends ConsumerWidget {
  const _FontSizeSegmentedControl({required this.value});

  final FontSizePreference value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.searchSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: FontSizePreference.values.map((option) {
          final selected = option == value;
          return Expanded(
            child: SpringTap(
              onTap: () =>
                  ref.read(fontSizeProvider.notifier).setFontSize(option),
              child: AnimatedContainer(
                duration: AppRoutes.duration,
                curve: AppRoutes.springCurve,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.segmented),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? tokens.primary : tokens.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = destructive
        ? context.tokens.destructive
        : selected
        ? context.tokens.primary
        : context.tokens.textSecondary;

    return SpringTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: destructive
                          ? context.tokens.destructive
                          : context.tokens.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              color: destructive
                  ? context.tokens.destructive
                  : context.tokens.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _FigmaDivider extends StatelessWidget {
  const _FigmaDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: context.tokens.border,
    );
  }
}
