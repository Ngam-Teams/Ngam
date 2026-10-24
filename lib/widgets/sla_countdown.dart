import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

// ============================================================
// Ngam App — Widget Countdown Masa SLA
// Timer beranimasi untuk track berapa minit je tinggal untuk siapkan job
// ============================================================

class SlaCountdown extends StatefulWidget {
  final String category;
  final DateTime startTime;
  final VoidCallback? onExpired;

  const SlaCountdown({
    super.key,
    required this.category,
    required this.startTime,
    this.onExpired,
  });

  @override
  State<SlaCountdown> createState() => _SlaCountdownState();
}

class _SlaCountdownState extends State<SlaCountdown>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _remaining;
  late Duration _total;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    final slaMins = SlaDuration.forCategory(widget.category);
    _total = Duration(minutes: slaMins);

    final elapsed = DateTime.now().difference(widget.startTime);
    _remaining = _total - elapsed;
    if (_remaining.isNegative) _remaining = Duration.zero;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining.isNegative) {
          _remaining = Duration.zero;
          _timer.cancel();
          _pulseController.repeat(reverse: true);
          widget.onExpired?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hrs = d.inHours.toString().padLeft(2, '0');
      return '$hrs:$mins:$secs';
    }
    return '$mins:$secs';
  }

  double get _progress {
    if (_total.inSeconds == 0) return 0;
    return _remaining.inSeconds / _total.inSeconds;
  }

  Color get _timerColor {
    if (_progress > 0.5) return AppTheme.success;
    if (_progress > 0.2) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining.inSeconds <= 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _timerColor.withValues(alpha: isExpired ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _timerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: isExpired ? HugeIcons.strokeRoundedAlert02 : HugeIcons.strokeRoundedTime02,
                    color: _timerColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpired ? 'SLA EXPIRED' : 'ETA Countdown',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _timerColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Ruang display masa tu
              Text(
                isExpired ? 'OVERDUE' : _formatDuration(_remaining),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _timerColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 10),

              // Bar loading timeline
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: _timerColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(_timerColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'SLA: ${SlaDuration.forCategory(widget.category)} minutes',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
