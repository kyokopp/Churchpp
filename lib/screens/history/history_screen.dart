import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_strings.dart';
import '../../providers/sermon_providers.dart';
import '../../theme/app_icons.dart';

class HistoryScreen extends ConsumerWidget {
  final int sermonId;

  const HistoryScreen({super.key, required this.sermonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonAsync = ref.watch(sermonByIdProvider(sermonId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat("dd 'de' MMMM 'de' yyyy, HH:mm", 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(AppStrings.historyTitle),
      ),
      body: sermonAsync.when(
        data: (sermon) {
          if (sermon == null) {
            return Center(
              child: Text(
                AppStrings.sermonNotFound,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  sermon.title.isEmpty
                      ? AppStrings.untitledSermon
                      : sermon.title,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Expanded(
                child: sermon.deliveryHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.calendar,
                              size: 64,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppStrings.neverDelivered,
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.pulpitHistoryHelp,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sermon.deliveryHistory.length,
                        separatorBuilder: (_, _) => Divider(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final date =
                              sermon.deliveryHistory[sermon
                                      .deliveryHistory
                                      .length -
                                  1 -
                                  index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              dateFormat.format(date),
                              style: textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              _timeAgo(date),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('${AppStrings.loadErrorPrefix}: $err')),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return years == 1
          ? AppStrings.oneYearAgo
          : 'há $years ${AppStrings.yearsAgoSuffix}';
    }
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return months == 1
          ? AppStrings.oneMonthAgo
          : 'há $months ${AppStrings.monthsAgoSuffix}';
    }
    if (diff.inDays > 0) {
      return diff.inDays == 1
          ? AppStrings.oneDayAgo
          : 'há ${diff.inDays} ${AppStrings.daysAgoSuffix}';
    }
    if (diff.inHours > 0) {
      return diff.inHours == 1
          ? AppStrings.oneHourAgo
          : 'há ${diff.inHours} ${AppStrings.hoursAgoSuffix}';
    }
    if (diff.inMinutes > 0) {
      return diff.inMinutes == 1
          ? AppStrings.oneMinuteAgo
          : 'há ${diff.inMinutes} ${AppStrings.minutesAgoSuffix}';
    }
    return AppStrings.now;
  }
}
