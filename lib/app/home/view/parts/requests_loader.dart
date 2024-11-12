import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../utils/theme/theme.dart';

class RidesLoader extends StatelessWidget {
  const RidesLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppText.text('Awaiting requests',
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Container(
            width: double.maxFinite,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.grey.withOpacity(0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Shimmer.fromColors(
                baseColor: const Color.fromARGB(255, 112, 112, 113),
                highlightColor: const Color(0xFFDBDBDB).withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      decoration: const BoxDecoration(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 140,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 100,
                      height: 14,
                      decoration: const BoxDecoration(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 140,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.white),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(color: Colors.white),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 30,
                              height: 10,
                              decoration:
                                  const BoxDecoration(color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 80,
                              height: 10,
                              decoration:
                                  const BoxDecoration(color: Colors.white),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                            child: Container(
                          width: 0,
                          height: 40,
                          decoration: const BoxDecoration(color: Colors.white),
                        )),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Container(
                          width: 0,
                          height: 40,
                          decoration: const BoxDecoration(color: Colors.white),
                        )),
                      ],
                    )
                  ],
                ))),
      ],
    );
  }
}
