import 'package:flutter/material.dart';

import '../domain/date_status.dart';
import 'local_day_scope.dart';

class BatchDateLabel extends StatelessWidget {
  const BatchDateLabel({
    super.key,
    required this.printedDate,
    this.printedTime,
  });
  final String? printedDate;

  /// Optional expiry time ("HH:mm"). When set, enables the hours-left
  /// countdown chip and refines the status within the same calendar day.
  final String? printedTime;

  @override
  Widget build(BuildContext context) {
    final now = LocalDayScope.of(context);
    final status = dateStatus(printedDate, now, time: printedTime);
    final (icon, background, foreground) = switch (status) {
      DateStatus.later => (
        Icons.event_outlined,
        const Color(0xFFE8EFF7),
        const Color(0xFF294B70),
      ),
      DateStatus.soon => (
        Icons.schedule,
        const Color(0xFFFFEFCB),
        const Color(0xFF674B00),
      ),
      DateStatus.hoursLeft => (
        Icons.timer_outlined,
        const Color(0xFFFFE0B2),
        const Color(0xFF7A3D00),
      ),
      DateStatus.today => (
        Icons.today,
        const Color(0xFFFFDFBE),
        const Color(0xFF743700),
      ),
      DateStatus.past => (
        Icons.event_busy,
        const Color(0xFFF8DFDF),
        const Color(0xFF822D2D),
      ),
      DateStatus.unknown => (
        Icons.help_outline,
        const Color(0xFFEAEAEA),
        const Color(0xFF424242),
      ),
    };

    // Build the countdown label for hoursLeft status.
    String chipLabel = status.label;
    if (status == DateStatus.hoursLeft &&
        printedDate != null &&
        printedTime != null) {
      final countdown = hoursLeftLabel(printedDate!, printedTime!, now);
      if (countdown != null) chipLabel = countdown;
    }

    // Show full datetime when time is present, otherwise date only.
    final dateDisplay = printedDate == null
        ? null
        : printedTime != null
            ? 'Printed date · $printedDate $printedTime'
            : 'Printed date · $printedDate';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dateDisplay != null) Text(dateDisplay),
        Tooltip(
          triggerMode: TooltipTriggerMode.tap,
          message: status == DateStatus.unknown
              ? 'No printed date was entered. Unknown does not mean fresh or spoiled.'
              : status == DateStatus.hoursLeft
                  ? 'The printed time on the packaging. This label describes the printed datetime, not freshness.'
                  : 'Compared with today on your device. This label describes the printed date, not freshness. Passing it does not record waste.',
          child: Chip(
            avatar: Icon(icon, size: 18, color: foreground),
            label: Text(chipLabel, style: TextStyle(color: foreground)),
            backgroundColor: background,
            side: BorderSide.none,
          ),
        ),
      ],
    );
  }
}
