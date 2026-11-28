import 'dart:async';
import 'package:flutter/material.dart';

/// Reusable tap + press-and-hold auto-repeat wrapper for quantity `-` / `+` buttons.
/// Single tap invokes [onStep] once; holding auto-repeats every [repeatInterval]
/// and stops automatically on release, cancel, dispose, or when [enabled] turns false.
class HoldRepeatButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onStep;
  final VoidCallback? onDisabledTap;
  final bool enabled;
  final Duration repeatInterval;

  const HoldRepeatButton({
    super.key,
    required this.child,
    required this.onStep,
    this.onDisabledTap,
    this.enabled = true,
    this.repeatInterval = const Duration(milliseconds: 95),
  });

  @override
  State<HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<HoldRepeatButton> {
  Timer? _timer;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _startRepeating() {
    _stop();
    if (!widget.enabled || widget.onStep == null) {
      widget.onDisabledTap?.call();
      return;
    }
    widget.onStep!();
    _timer = Timer.periodic(widget.repeatInterval, (_) {
      if (!mounted || !widget.enabled || widget.onStep == null) {
        _stop();
        return;
      }
      widget.onStep!();
    });
  }

  @override
  void didUpdateWidget(covariant HoldRepeatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.enabled) {
            widget.onStep?.call();
          } else {
            widget.onDisabledTap?.call();
          }
        },
        onLongPressStart: (_) => _startRepeating(),
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _stop,
        child: widget.child,
      ),
    );
  }
}
