import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';

import 'package:circum_rider/rider_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/security/rider_app_check.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _installRiderWebDiagnostics();
  runZonedGuarded(
    () => runApp(const RiderWebBootstrapGate()),
    _reportRiderWebError,
  );
}

void _installRiderWebDiagnostics() {
  FlutterError.onError = (details) {
    _reportRiderWebError(details.exception, details.stack);
  };
  // Widget-level data/render failures must stay contained. Replacing the root
  // MaterialApp here made ordinary delivery-data defects look like an App
  // Check/bootstrap outage and destroyed an otherwise healthy Rider session.
  ErrorWidget.builder = (_) => const RiderWebRenderFailure();
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportRiderWebError(error, stack);
    return true;
  };
}

void _reportRiderWebError(Object error, StackTrace? stack) {
  debugPrint('[CircumRiderRuntimeError] $error');
  if (stack != null) {
    debugPrint('[CircumRiderRuntimeStack] $stack');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }
}

class RiderWebStartupApp extends StatefulWidget {
  const RiderWebStartupApp({
    super.key,
    required this.initializer,
    required this.appBuilder,
    this.timeout = const Duration(seconds: 20),
  });

  final Future<void> Function() initializer;
  final WidgetBuilder appBuilder;
  final Duration timeout;

  @override
  State<RiderWebStartupApp> createState() => _RiderWebStartupAppState();
}

class RiderWebBootstrapGate extends StatefulWidget {
  const RiderWebBootstrapGate({super.key});

  @override
  State<RiderWebBootstrapGate> createState() => _RiderWebBootstrapGateState();
}

class _RiderWebBootstrapGateState extends State<RiderWebBootstrapGate> {
  Object? _error;
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    _startFirebase();
  }

  Future<void> _startFirebase() async {
    setState(() {
      _error = null;
      _firebaseReady = false;
    });
    try {
      await _initializeFirebase().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() => _firebaseReady = true);
    } catch (error) {
      final summary = error is FirebaseException
          ? '${error.plugin}:${error.code}'
          : error.runtimeType.toString();
      debugPrint('[RDR_WEB_FIREBASE_FAILED] type=$summary');
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _RiderWebStartupFailure(onRetry: _startFirebase);
    }
    if (!_firebaseReady) return const _RiderWebStartupHold();
    return const RiderWebSecurityGate(child: CircumRider());
  }
}

class _RiderWebStartupAppState extends State<RiderWebStartupApp> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    try {
      await widget.initializer().timeout(widget.timeout);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.appBuilder(context);
    if (_error == null) return const _RiderWebStartupHold();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Circum Rider Web could not start',
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFF87171),
                        size: 34,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Something went wrong.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF5F7FB),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We could not start Rider Web. Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9CA8B8),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reference: RDR-WEB-START-001',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                          ),
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

class _RiderWebStartupHold extends StatelessWidget {
  const _RiderWebStartupHold();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Circum Rider is starting',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Starting Circum Rider',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF5F7FB),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Preparing your Rider workspace.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9CA8B8),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RiderWebStartupFailure extends StatelessWidget {
  const _RiderWebStartupFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFF87171),
                      size: 34,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF5F7FB),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We could not start Rider Web. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9CA8B8), height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reference: RDR-WEB-BOOT-001',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum RiderWebSecurityStatus { initializing, ready, retryableFailure }

class RiderWebSecurityGate extends StatefulWidget {
  const RiderWebSecurityGate({super.key, required this.child});

  final Widget child;

  @override
  State<RiderWebSecurityGate> createState() => _RiderWebSecurityGateState();
}

class _RiderWebSecurityGateState extends State<RiderWebSecurityGate> {
  RiderWebSecurityStatus _status = RiderWebSecurityStatus.initializing;

  @override
  void initState() {
    super.initState();
    _activateAppCheck();
  }

  Future<void> _activateAppCheck() async {
    if (mounted) {
      setState(() => _status = RiderWebSecurityStatus.initializing);
    }
    final startup = await initializeRiderAppCheck();
    if (!mounted) return;
    setState(
      () => _status = startup.blockStartup
          ? RiderWebSecurityStatus.retryableFailure
          : RiderWebSecurityStatus.ready,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _status == RiderWebSecurityStatus.ready;
    if (ready) return widget.child;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_status == RiderWebSecurityStatus.initializing)
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF60A5FA),
                        ),
                      )
                    else
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFFBBF24),
                        size: 34,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _status == RiderWebSecurityStatus.initializing
                          ? 'Preparing secure Rider access'
                          : 'Security verification unavailable',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF5F7FB),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status == RiderWebSecurityStatus.initializing
                          ? 'Your Rider workspace is loading.'
                          : 'Retry to restore protected Rider actions.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CA8B8),
                        height: 1.45,
                      ),
                    ),
                    if (_status == RiderWebSecurityStatus.retryableFailure)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: FilledButton.icon(
                          onPressed: _activateAppCheck,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RiderWebRenderFailure extends StatelessWidget {
  const RiderWebRenderFailure({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF111827),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              liveRegion: true,
              label: 'This Rider panel could not render',
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFF87171),
                      size: 34,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This panel could not render.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF5F7FB),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Rider session and active delivery are still running. Reload this page to restore the panel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9CA8B8),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reference: RDR-WEB-RENDER-001',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => _reloadPage(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reload'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _reloadPage() {
  html.window.location.reload();
}
