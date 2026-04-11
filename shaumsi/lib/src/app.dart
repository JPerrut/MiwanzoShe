import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart';
import 'ui/screens/root_shell.dart';
import 'ui/widgets/glass_panel.dart';

class ShauMsiApp extends StatelessWidget {
  const ShauMsiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shauku ya msimu',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: const AppLockGate(child: RootShell()),
    );
  }
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const String _appPassword = '21032026';

  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLocked = true;
  bool _hasUnlockedOnce = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusPasswordField();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lockApp();
    }
  }

  void _focusPasswordField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isLocked) return;
      _passwordFocusNode.requestFocus();
    });
  }

  void _lockApp() {
    if (!_hasUnlockedOnce && _isLocked) {
      return;
    }

    setState(() {
      _isLocked = true;
      _errorText = null;
      _passwordController.clear();
      _obscurePassword = true;
    });
    _focusPasswordField();
  }

  void _unlockApp() {
    final password = _passwordController.text.trim();

    if (password != _appPassword) {
      setState(() {
        _errorText = 'Senha incorreta. Tente novamente.';
        _passwordController.clear();
      });
      _focusPasswordField();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLocked = false;
      _hasUnlockedOnce = true;
      _errorText = null;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasUnlockedOnce)
          Offstage(offstage: _isLocked, child: widget.child),
        if (_isLocked)
          _AppLockScreen(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscurePassword: _obscurePassword,
            errorText: _errorText,
            onToggleObscurePassword: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            onSubmit: _unlockApp,
          ),
      ],
    );
  }
}

class _AppLockScreen extends StatelessWidget {
  const _AppLockScreen({
    required this.controller,
    required this.focusNode,
    required this.obscurePassword,
    required this.errorText,
    required this.onToggleObscurePassword,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscurePassword;
  final String? errorText;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.shaumsiColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.pearlWhite,
              colors.seaFoam,
              colors.lagoonBlue.withValues(alpha: 0.95),
              colors.tideBlue.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset + 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: colors.deepOcean,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ShauMsi protegido',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Digite a senha para acessar o aplicativo e liberar todas as funcionalidades.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        obscureText: obscurePassword,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        onSubmitted: (_) => onSubmit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          hintText: 'Digite a senha',
                          errorText: errorText,
                          suffixIcon: IconButton(
                            onPressed: onToggleObscurePassword,
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onSubmit,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Entrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
