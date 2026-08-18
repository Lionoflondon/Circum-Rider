import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiderBootDiagnostics {
  RiderBootDiagnostics._();

  static final RiderBootDiagnostics instance = RiderBootDiagnostics._();
  static const _checkpointKey = 'rider_boot_checkpoint';
  static const _timeKey = 'rider_boot_checkpoint_time';
  static const _errorKey = 'rider_boot_error_category';

  String current = 'APP_MOUNTED';
  String? errorCategory;
  String? previous;
  int? previousTime;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    previous = prefs.getString(_checkpointKey);
    previousTime = prefs.getInt(_timeKey);
  }

  Future<void> mark(String checkpoint) async {
    current = checkpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checkpointKey, checkpoint);
    await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> fail(Object error) async {
    errorCategory = _category(error);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_errorKey, errorCategory!);
  }

  String _category(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('type')) return 'TYPE_CAST';
    if (value.contains('firestore')) return 'FIRESTORE_READ';
    if (value.contains('auth')) return 'AUTH';
    if (value.contains('route')) return 'ROUTING';
    if (value.contains('async') || value.contains('future')) {
      return 'ASYNC_INIT';
    }
    return 'UNKNOWN';
  }
}

class RiderBootDiagnosticOverlay extends StatelessWidget {
  const RiderBootDiagnosticOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final diagnostics = RiderBootDiagnostics.instance;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: IgnorePointer(
              child: Material(
                color: const Color(0xEE111827),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    'CIRCUM RIDER DIAGNOSTIC\n${diagnostics.current}'
                    '${diagnostics.previous == null ? '' : '\nLAST: ${diagnostics.previous}'}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
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
