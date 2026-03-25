import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/miwanzo_state.dart';
import '../../theme/app_theme.dart';
import '../../updates/github_release_updater.dart';
import '../widgets/glass_panel.dart';
import 'dashboard_screen.dart';
import 'files_screen.dart';
import 'important_dates_screen.dart';
import 'logs_screen.dart';
import 'notes_screen.dart';
import 'preferences_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  late final MiwanzoState _state;
  final GithubReleaseUpdater _releaseUpdater = GithubReleaseUpdater();
  int _currentIndex = 0;
  bool _didCheckUpdates = false;

  @override
  void initState() {
    super.initState();
    _state = MiwanzoState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  void _openSection(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.miwanzoColors;

    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        final pages = [
          DashboardScreen(state: _state, onOpenSection: _openSection),
          ImportantDatesScreen(state: _state),
          NotesScreen(state: _state),
          PreferencesScreen(state: _state),
          FilesScreen(state: _state),
          LogsScreen(),
        ];

        final isReady = !_state.isLoading && _state.errorMessage == null;
        if (isReady && !_didCheckUpdates) {
          _didCheckUpdates = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
        }

        Widget content;
        if (_state.isLoading) {
          content = const Center(child: CircularProgressIndicator());
        } else if (_state.errorMessage != null) {
          content = _ErrorState(
            message: _state.errorMessage!,
            onRetry: _state.refreshAll,
          );
        } else {
          content = pages[_currentIndex];
        }

        return Scaffold(
          extendBody: false,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.eggShell,
                  colors.mistRose,
                  colors.powderBlue.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -40,
                  child: _DecorativeBubble(
                    size: 190,
                    color: colors.deepLavender.withValues(alpha: 0.16),
                  ),
                ),
                Positioned(
                  bottom: 130,
                  right: -70,
                  child: _DecorativeBubble(
                    size: 240,
                    color: colors.powderBlue.withValues(alpha: 0.28),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: isReady
                      ? IndexedStack(
                          index: _currentIndex,
                          children: pages,
                        )
                      : content,
                ),
              ],
            ),
          ),
          bottomNavigationBar: isReady
              ? SafeArea(
                  top: false,
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _openSection,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Inicio',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.event_note_outlined),
                        selectedIcon: Icon(Icons.event_note),
                        label: 'Datas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.sticky_note_2_outlined),
                        selectedIcon: Icon(Icons.sticky_note_2),
                        label: 'Notas',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.favorite_border),
                        selectedIcon: Icon(Icons.favorite),
                        label: 'Gostos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.collections_outlined),
                        selectedIcon: Icon(Icons.collections),
                        label: 'Arquivos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: 'Logs',
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Future<void> _checkForUpdates() async {
    final update = await _releaseUpdater.checkForUpdates();
    if (!mounted || update == null) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nova versao disponivel'),
          content: Text(
            'Versao atual: ${update.currentVersion}\n'
            'Nova versao: ${update.latestVersion}\n\n'
            'Deseja baixar a atualizacao agora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Depois'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Atualizar'),
            ),
          ],
        );
      },
    );

    if (!(shouldUpdate ?? false)) return;

    final uri = Uri.parse(update.downloadUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir o link de atualizacao.'),
        ),
      );
    }
  }
}

class _DecorativeBubble extends StatelessWidget {
  const _DecorativeBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
