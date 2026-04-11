import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/shaumsi_state.dart';
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

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  late final ShauMsiState _state;
  final GithubReleaseUpdater _releaseUpdater = GithubReleaseUpdater();
  int _currentIndex = 0;
  bool _didCheckUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = ShauMsiState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _state.performBackgroundSync();
    }
  }

  void _openSection(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.shaumsiColors;

    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        final pages = [
          DashboardScreen(state: _state),
          ImportantDatesScreen(state: _state),
          NotesScreen(state: _state),
          PreferencesScreen(state: _state),
          FilesScreen(state: _state),
          LogsScreen(),
        ];

        final isReady = !_state.isLoading && _state.errorMessage == null;
        if (isReady && !_didCheckUpdates) {
          _didCheckUpdates = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _checkForUpdates(),
          );
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.pearlWhite,
                  colors.seaFoam,
                  colors.lagoonBlue.withValues(alpha: 0.9),
                  colors.tideBlue.withValues(alpha: 0.92),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _OceanBackdropPainter(colors: colors),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: isReady
                      ? IndexedStack(index: _currentIndex, children: pages)
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
                        label: 'Início',
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
          title: const Text('Nova versão disponível'),
          content: Text(
            'Versão atual: ${update.currentVersion}\n'
            'Nova versão: ${update.latestVersion}\n\n'
            'Deseja baixar a atualização agora?',
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
          content: Text('Não foi possível abrir o link de atualização.'),
        ),
      );
    }
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

class _OceanBackdropPainter extends CustomPainter {
  const _OceanBackdropPainter({required this.colors});

  final ShauMsiColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = colors.pearlWhite.withValues(alpha: 0.32);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.14),
      size.shortestSide * 0.2,
      glowPaint,
    );

    final mistPaint = Paint()..color = colors.seaFoam.withValues(alpha: 0.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.2),
        width: size.width * 0.38,
        height: size.width * 0.22,
      ),
      mistPaint,
    );

    _drawShell(
      canvas,
      center: Offset(size.width * 0.14, size.height * 0.22),
      width: size.shortestSide * 0.18,
      height: size.shortestSide * 0.14,
      fillColor: colors.pearlWhite.withValues(alpha: 0.08),
      strokeColor: colors.pearlWhite.withValues(alpha: 0.22),
    );
    _drawShell(
      canvas,
      center: Offset(size.width * 0.84, size.height * 0.72),
      width: size.shortestSide * 0.2,
      height: size.shortestSide * 0.16,
      fillColor: colors.seaFoam.withValues(alpha: 0.08),
      strokeColor: colors.seaFoam.withValues(alpha: 0.2),
    );

    canvas.drawPath(
      _buildWavePath(
        size,
        top: size.height * 0.72,
        amplitude: 26,
        wavelength: 210,
        phase: -40,
      ),
      Paint()..color = colors.tideBlue.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      _buildWavePath(
        size,
        top: size.height * 0.8,
        amplitude: 20,
        wavelength: 180,
        phase: 30,
      ),
      Paint()..color = colors.lagoonBlue.withValues(alpha: 0.24),
    );
    canvas.drawPath(
      _buildWavePath(
        size,
        top: size.height * 0.86,
        amplitude: 12,
        wavelength: 150,
        phase: -10,
      ),
      Paint()..color = colors.pearlWhite.withValues(alpha: 0.56),
    );

    final bubbleStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = colors.pearlWhite.withValues(alpha: 0.24);
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.34),
      8,
      bubbleStroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.39),
      5,
      bubbleStroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.42),
      10,
      bubbleStroke,
    );
  }

  Path _buildWavePath(
    Size size, {
    required double top,
    required double amplitude,
    required double wavelength,
    double phase = 0,
  }) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top);

    var x = -wavelength + phase;
    while (x < size.width + wavelength) {
      path.quadraticBezierTo(
        x + wavelength * 0.25,
        top - amplitude,
        x + wavelength * 0.5,
        top,
      );
      path.quadraticBezierTo(
        x + wavelength * 0.75,
        top + amplitude,
        x + wavelength,
        top,
      );
      x += wavelength;
    }

    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  void _drawShell(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color fillColor,
    required Color strokeColor,
  }) {
    final shellPath = Path()
      ..moveTo(center.dx - width * 0.5, center.dy + height * 0.45)
      ..quadraticBezierTo(
        center.dx - width * 0.56,
        center.dy - height * 0.02,
        center.dx,
        center.dy - height * 0.55,
      )
      ..quadraticBezierTo(
        center.dx + width * 0.56,
        center.dy - height * 0.02,
        center.dx + width * 0.5,
        center.dy + height * 0.45,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy + height * 0.82,
        center.dx - width * 0.5,
        center.dy + height * 0.45,
      );

    canvas.drawPath(shellPath, Paint()..color = fillColor);
    canvas.drawPath(
      shellPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = strokeColor,
    );

    final ribPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = strokeColor;

    for (final factor in [-0.3, -0.15, 0.0, 0.15, 0.3]) {
      final ribPath = Path()
        ..moveTo(center.dx + width * factor, center.dy + height * 0.42)
        ..quadraticBezierTo(
          center.dx + width * factor * 0.4,
          center.dy - height * 0.08,
          center.dx,
          center.dy - height * 0.42,
        );
      canvas.drawPath(ribPath, ribPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OceanBackdropPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
