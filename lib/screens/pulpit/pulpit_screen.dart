import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../l10n/app_strings.dart';
import '../../providers/sermon_providers.dart';
import '../../providers/settings_providers.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';

class PulpitScreen extends ConsumerStatefulWidget {
  final int sermonId;

  const PulpitScreen({super.key, required this.sermonId});

  @override
  ConsumerState<PulpitScreen> createState() => _PulpitScreenState();
}

class _PulpitScreenState extends ConsumerState<PulpitScreen> {
  String _title = '';
  String _plainText = '';
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _enterPulpitMode();
    _loadSermon();
  }

  Future<void> _enterPulpitMode() async {
    await WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _loadSermon() async {
    final repo = await ref.read(sermonRepositoryProvider.future);
    final sermon = await repo.getById(widget.sermonId);
    if (sermon == null || !mounted) return;

    String plainText = '';
    if (sermon.bodyJson != null && sermon.bodyJson!.isNotEmpty) {
      try {
        final doc = Document.fromJson(jsonDecode(sermon.bodyJson!));
        plainText = doc.toPlainText();
      } catch (_) {
        plainText = '';
      }
    }

    setState(() {
      _title = sermon.title;
      _plainText = plainText;
      _isLoaded = true;
    });
  }

  Future<void> _exitPulpitMode() async {
    await WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSizePref = ref.watch(fontSizeProvider);
    final scale = AppTheme.fontScales[fontSizePref.name] ?? 1.0;
    final pulpitScale = scale * AppTheme.pulpitExtraScale;
    final colorScheme = Theme.of(context).colorScheme;

    if (!_isLoaded) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight > 136
                          ? constraints.maxHeight - 136
                          : 0,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _title.isEmpty ? AppStrings.untitledSermon : _title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['Helvetica'],
                              fontSize:
                                  28 *
                                  pulpitScale /
                                  AppTheme.pulpitExtraScale *
                                  1.3,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _plainText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['Helvetica'],
                              fontSize:
                                  18 *
                                  pulpitScale /
                                  AppTheme.pulpitExtraScale *
                                  1.4,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.9,
                              ),
                              height: 1.8,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _exitPulpitMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.close,
                        size: 18,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.exitPulpitMode,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
