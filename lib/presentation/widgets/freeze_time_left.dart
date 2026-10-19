import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// How long a freeze still holds: "3 days left" for a week or month frozen,
/// "13 hours left" on the day, then "42 min left" in its last hour.
String freezeTimeLeft(Duration left) {
  if (left <= Duration.zero) return '0 min left';
  if (left < const Duration(hours: 1)) {
    // Rounded up (the last seconds still say 1 min), never "60 min"
    final minutes = (left.inSeconds / 60).ceil().clamp(1, 59);
    return '$minutes min left';
  }
  if (left < const Duration(hours: 48)) {
    final hours = left.inHours;
    return hours == 1 ? '1 hour left' : '$hours hours left';
  }
  return '${left.inDays} days left';
}

/// [freezeTimeLeft] until [ends], kept up to date (every minute) while it
/// shows. [format] dresses it up ("Frozen · 13 hours left").
class FreezeTimeLeft extends StatefulWidget {
  final DateTime ends;
  final String Function(String left) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  const FreezeTimeLeft({super.key, required this.ends, required this.format, this.style, this.textAlign});

  @override
  State<FreezeTimeLeft> createState() => _FreezeTimeLeftState();
}

class _FreezeTimeLeftState extends State<FreezeTimeLeft> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Next redraw on the next whole minute, so "42 min" changes as the
  /// clock does.
  void _schedule() {
    final now = clock.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        widget.format(freezeTimeLeft(widget.ends.difference(clock.now()))),
        style: widget.style,
        textAlign: widget.textAlign,
      );
}
