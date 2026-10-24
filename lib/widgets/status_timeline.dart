import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../utils/app_theme.dart';

// ============================================================
// Ngam App — Widget Timeline Status
// Stepper menegak untuk tunjuk task ni dah sampai level mana
// ============================================================

class StatusTimeline extends StatelessWidget {
  final String currentStatus;
  final String? runnerName;

  const StatusTimeline({
    super.key,
    required this.currentStatus,
    this.runnerName,
  });

  int get _currentStep {
    switch (currentStatus) {
      case 'OPEN':
        return 0;
      case 'LOCKED':
        return 1;
      case 'IN-PROGRESS':
        return 2;
      case 'COMPLETED':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep(
        title: 'Task Posted',
        subtitle: 'Waiting for runner...',
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        isCompleted: _currentStep >= 0,
        isActive: _currentStep == 0,
      ),
      _TimelineStep(
        title: 'Runner Assigned',
        subtitle: runnerName != null
            ? '$runnerName accepted your task'
            : 'Pending confirmation',
        icon: HugeIcons.strokeRoundedLocation01,
        isCompleted: _currentStep >= 1,
        isActive: _currentStep == 1,
      ),
      _TimelineStep(
        title: 'In Progress',
        subtitle: 'Runner is on the way',
        icon: HugeIcons.strokeRoundedWorkoutRun,
        isCompleted: _currentStep >= 2,
        isActive: _currentStep == 2,
      ),
      _TimelineStep(
        title: 'Completed',
        subtitle: _currentStep >= 3
            ? 'Task delivered successfully!'
            : 'Pending confirmation',
        icon: HugeIcons.strokeRoundedCheckmarkBadge01,
        isCompleted: _currentStep >= 3,
        isActive: _currentStep == 3,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon/Indicator timeline
            Column(
              children: [
                // Bulatan
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: step.isCompleted
                        ? AppTheme.primary
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    boxShadow: step.isActive
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: HugeIcon(
                    icon: step.icon,
                    size: 18,
                    color: step.isCompleted ? Colors.white : Colors.grey.shade500,
                  ),
                ),
                // Garisan penyambung bawah
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: step.isCompleted
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Isi Kandungan
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: step.isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: step.isCompleted
                            ? null
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final bool isCompleted;
  final bool isActive;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
  });
}
