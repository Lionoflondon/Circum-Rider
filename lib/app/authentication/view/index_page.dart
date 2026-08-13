import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090F),
      body: Center(
        child: Semantics(
          liveRegion: true,
          label: 'Circum Rider is restoring your session',
          child: const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF60A5FA),
            ),
          ),
        ),
      ),
    );
  }
}
