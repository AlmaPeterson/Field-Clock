import 'package:flutter/material.dart';
import '../models/session.dart';
import '../utils/time_utils.dart';
import '../theme/app_theme.dart';

class SessionEditDialog extends StatefulWidget {
  final Session session;

  const SessionEditDialog({super.key, required this.session});

  @override
  State<SessionEditDialog> createState() =>
      _SessionEditDialogState();
}

class _SessionEditDialogState extends State<SessionEditDialog> {
  late DateTime _clockIn;
  late DateTime? _clockOut;

  @override
  void initState() {
    super.initState();
    _clockIn = widget.session.clockInTime;
    _clockOut = widget.session.clockOutTime;
  }

  Future<void> _pickTime({required bool isClockIn}) async {
    final current =
        isClockIn ? _clockIn : (_clockOut ?? DateTime.now());

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor:
                Theme.of(context).cardColor,
            hourMinuteColor:
                Theme.of(context).dividerColor,
            hourMinuteTextColor:
                Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.color,
            dayPeriodColor:
                Theme.of(context).dividerColor,
            dayPeriodTextColor:
                Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.color,
            dialBackgroundColor:
                Theme.of(context).dividerColor,
            dialHandColor:
                Theme.of(context).colorScheme.primary,
            dialTextColor:
                Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.color,
            entryModeIconColor:
                Theme.of(context).colorScheme.primary,
          ),
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(
                primary:
                    Theme.of(context).colorScheme.primary,
              ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    setState(() {
      final base = isClockIn
          ? _clockIn
          : (_clockOut ?? DateTime.now());
      final updated = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (isClockIn) {
        _clockIn = updated;
      } else {
        _clockOut = updated;
      }
    });
  }

  int get _roundedMinutes {
    if (_clockOut == null) return 0;
    final raw = _clockOut!.difference(_clockIn);
    return TimeUtils.roundToNearest15(raw).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final bodyColor =
        Theme.of(context).textTheme.bodyLarge?.color;
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color;

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EDIT SESSION',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge),
            const SizedBox(height: 20),

            // Clock In row
            _TimeEditRow(
              label: 'Clock In',
              time: _clockIn,
              color: AppColors.success,
              onTap: () => _pickTime(isClockIn: true),
            ),
            const SizedBox(height: 12),

            // Clock Out row
            _TimeEditRow(
              label: 'Clock Out',
              time: _clockOut,
              color: AppColors.error,
              placeholder: 'Active',
              onTap: widget.session.clockOutTime != null
                  ? () => _pickTime(isClockIn: false)
                  : null,
            ),

            // Duration preview
            if (_clockOut != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Duration (rounded)',
                        style: TextStyle(
                            color: mutedColor,
                            fontSize: 13)),
                    Text(
                      TimeUtils.formatDuration(
                          Duration(
                              minutes: _roundedMinutes)),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, null),
                    child: Text('Cancel',
                        style:
                            TextStyle(color: mutedColor)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, {
                      'clockIn': _clockIn,
                      'clockOut': _clockOut,
                    }),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time Edit Row ─────────────────────────────────────────────────────────────

class _TimeEditRow extends StatelessWidget {
  final String label;
  final DateTime? time;
  final Color color;
  final String placeholder;
  final VoidCallback? onTap;

  const _TimeEditRow({
    required this.label,
    required this.time,
    required this.color,
    this.placeholder = 'Not set',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: canEdit
                ? color.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canEdit
                        ? color
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                      fontSize: 14,
                    )),
              ],
            ),
            Row(
              children: [
                Text(
                  time != null
                      ? TimeUtils.formatTime(time!)
                      : placeholder,
                  style: TextStyle(
                    color: canEdit
                        ? color
                        : Colors.grey,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  canEdit
                      ? Icons.edit
                      : Icons.lock_outline,
                  size: 14,
                  color: canEdit
                      ? color
                      : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}