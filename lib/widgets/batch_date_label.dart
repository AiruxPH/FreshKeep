import 'package:flutter/material.dart';

import '../domain/date_status.dart';
import '../domain/format_remaining_duration.dart';
import '../domain/guidance/guidance_selection.dart';
import 'local_day_scope.dart';

class BatchDateLabel extends StatelessWidget {
  const BatchDateLabel({
    super.key,
    required this.printedDate,
    this.printedTime,
    this.guidance,
  });
  final String? printedDate;

  /// Optional expiry time ("HH:mm"). When set, enables the hours-left
  /// countdown chip and refines the status within the same calendar day.
  final String? printedTime;

  /// Optional calculated storage-guidance dates. Only used when [printedDate]
  /// is null; printed packaging dates always take priority.
  final BatchGuidance? guidance;

  @override
  Widget build(BuildContext context) {
    final now = LocalDayScope.of(context);
    final effectiveDate = printedDate ?? guidance?.suggestedDate;
    final effectiveTime = printedDate != null ? printedTime : null;
    final isSuggested = printedDate == null && guidance != null;
    final status = dateStatus(effectiveDate, now, time: effectiveTime);
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

    final chipLabel = formatRemainingDuration(
      effectiveDate,
      now,
      time: effectiveTime,
    );

    // Show full datetime when time is present, otherwise date or suggested window.
    final String? dateDisplay;
    if (printedDate != null) {
      dateDisplay = printedTime != null
          ? 'Printed date · $printedDate $printedTime'
          : 'Printed date · $printedDate';
    } else if (guidance != null) {
      dateDisplay = guidance!.hasRange
          ? 'Suggested date · ${guidance!.suggestedDate} (to ${guidance!.suggestedEndDate})'
          : 'Suggested date · ${guidance!.suggestedDate}';
    } else {
      dateDisplay = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dateDisplay != null) Text(dateDisplay),
        Tooltip(
          triggerMode: TooltipTriggerMode.tap,
          message: status == DateStatus.unknown
              ? 'No printed date was entered. Unknown does not mean fresh or spoiled.'
              : isSuggested
              ? 'Calculated from saved storage guidance (${guidance!.anchorEvent} ${guidance!.anchorDate}). This is not a printed date or freshness guarantee. Passing it does not record waste.'
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
