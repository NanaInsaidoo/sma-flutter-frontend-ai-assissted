import 'package:flutter/material.dart';

enum AlertLevel { critical, warning, info }

class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.value,
    required this.caption,
    required this.change,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final String change;
  final IconData icon;
  final Color color;
}

class AdmissionGroup {
  const AdmissionGroup(this.label, this.value);
  final String label;
  final int value;
}

class SchoolAlert {
  const SchoolAlert({
    required this.title,
    required this.message,
    required this.context,
    required this.level,
  });

  final String title;
  final String message;
  final String context;
  final AlertLevel level;
}

class SchoolEvent {
  const SchoolEvent({
    this.id,
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.category,
    this.eventTypeId,
    this.academicTermId,
    this.description = '',
    this.isSchoolDay = true,
  });

  final String? id;
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final String category;
  final int? eventTypeId;
  final int? academicTermId;
  final String description;
  final bool isSchoolDay;

  String get day => startDate.day.toString().padLeft(2, '0');
  String get month => _shortMonth(startDate.month);

  static String _shortMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }
}

class CalendarEventType {
  const CalendarEventType({required this.id, required this.name});

  final int id;
  final String name;
}

class CalendarEventPayload {
  const CalendarEventPayload({
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.eventTypeId,
    required this.isSchoolDay,
    this.academicTermId,
  });

  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int eventTypeId;
  final bool isSchoolDay;
  final int? academicTermId;
}

class RecentActivity {
  const RecentActivity({
    required this.initials,
    required this.name,
    required this.detail,
    required this.time,
  });

  final String initials;
  final String name;
  final String detail;
  final String time;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
  });

  final int total;
  final int present;
  final int absent;
  final int late;

  double get percentage => total == 0 ? 0 : present / total;
}

class FeeSummary {
  const FeeSummary({
    required this.collected,
    required this.outstanding,
    required this.waivers,
  });

  final double collected;
  final double outstanding;
  final double waivers;

  double get collectionRate {
    final total = collected + outstanding;
    return total == 0 ? 0 : collected / total;
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.schoolName,
    required this.administratorName,
    required this.term,
    this.academicTermId,
    required this.academicYear,
    required this.termStartDate,
    required this.termEndDate,
    required this.lastUpdated,
    required this.metrics,
    required this.admissions,
    required this.alerts,
    required this.events,
    required this.calendarEvents,
    required this.activities,
    required this.attendance,
    required this.fees,
  });

  final String schoolName;
  final String administratorName;
  final String term;
  final int? academicTermId;
  final String academicYear;
  final String termStartDate;
  final String termEndDate;
  final DateTime lastUpdated;
  final List<DashboardMetric> metrics;
  final List<AdmissionGroup> admissions;
  final List<SchoolAlert> alerts;
  final List<SchoolEvent> events;
  final List<SchoolEvent> calendarEvents;
  final List<RecentActivity> activities;
  final AttendanceSummary attendance;
  final FeeSummary fees;

  String get termLabel {
    final termParts = [
      if (term.trim().isNotEmpty) term.trim(),
      if (academicYear.trim().isNotEmpty) academicYear.trim(),
    ];
    return termParts.isEmpty ? 'Current term' : termParts.join(' · ');
  }

  String get termDateRange {
    if (termStartDate.trim().isEmpty || termEndDate.trim().isEmpty) {
      return '';
    }
    return '$termStartDate to $termEndDate';
  }
}
