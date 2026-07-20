import 'dart:async';

import 'package:circum_rider/main.dart' show CircumRider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/security/rider_app_check.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RiderWebStartupApp(
    initializer: _initializeRiderWeb,
    appBuilder: (_) => const CircumRider(),
  ));
}

Future<void> _initializeRiderWeb() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }
  final appCheckStartup = await initializeRiderAppCheck();
  if (appCheckStartup.blockStartup) {
    throw StateError(appCheckStartup.message);
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF131313),
      ),
    );
  }
}
