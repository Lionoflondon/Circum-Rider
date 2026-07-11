// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import 'rider_offer_card.dart';

class RiderOfferStack extends StatefulWidget {
  final List<RiderJobOffer> offers;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final ValueChanged<RiderJobOffer> onAccept;
  final bool accepting;
  final bool accepted;
  final String riderRank;

  const RiderOfferStack({
    super.key,
    required this.offers,
    required this.activeIndex,
    required this.onIndexChanged,
    required this.onAccept,
    required this.accepting,
    this.accepted = false,
    required this.riderRank,
  });

  @override
  State<RiderOfferStack> createState() => _RiderOfferStackState();
}

class _RiderOfferStackState extends State<RiderOfferStack> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    final active = widget.offers[widget.activeIndex];
    final previous =
        widget.activeIndex > 0 ? widget.offers[widget.activeIndex - 1] : null;
    final next = widget.activeIndex < widget.offers.length - 1
        ? widget.offers[widget.activeIndex + 1]
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final shouldAdvance = _dragOffset < -70 || velocity < -450;
        final shouldGoBack = _dragOffset > 70 || velocity > 450;

        if (shouldAdvance && next != null) {
          widget.onIndexChanged(widget.activeIndex + 1);
        } else if (shouldGoBack && previous != null) {
          widget.onIndexChanged(widget.activeIndex - 1);
        }
        setState(() => _dragOffset = 0);
      },
      onHorizontalDragCancel: () => setState(() => _dragOffset = 0),
      child: SizedBox(
        height: 540,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (previous != null)
              Transform.translate(
                offset: const Offset(-34, 18),
                child: Transform.scale(
                  scale: 0.92,
                  child: Opacity(
                    opacity: 0.34,
                    child: IgnorePointer(
                      child: RiderOfferCard(
                        offer: previous,
                        riderRank: widget.riderRank,
                        accepting: false,
                        accepted: false,
                        onAccept: () {},
                      ),
                    ),
                  ),
                ),
              ),
            if (next != null)
              Transform.translate(
                offset: const Offset(34, 18),
                child: Transform.scale(
                  scale: 0.92,
                  child: Opacity(
                    opacity: 0.34,
                    child: IgnorePointer(
                      child: RiderOfferCard(
                        offer: next,
                        riderRank: widget.riderRank,
                        accepting: false,
                        accepted: false,
                        onAccept: () {},
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(_dragOffset)
                ..rotateZ(_dragOffset * 0.0008),
              child: RiderOfferCard(
                offer: active,
                riderRank: widget.riderRank,
                accepting: widget.accepting,
                accepted: widget.accepted,
                onAccept: () => widget.onAccept(active),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
