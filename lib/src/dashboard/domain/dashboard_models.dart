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
    required this.message,
    required this.context,
    required this.level,
  });

  final String message;
  final String context;
  final AlertLevel level;
}

class SchoolEvent {
  const SchoolEvent({
    required this.day,
    required this.month,
    required this.title,
    required this.category,
  });

  final String day;
  final String month;
  final String title;
  final String category;
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
    required this.academicYear,
    required this.lastUpdated,
    required this.metrics,
    required this.admissions,
    required this.alerts,
    required this.events,
    required this.activities,
    required this.attendance,
    required this.fees,
  });

  final String schoolName;
  final String administratorName;
  final String term;
  final String academicYear;
  final DateTime lastUpdated;
  final List<DashboardMetric> metrics;
  final List<AdmissionGroup> admissions;
  final List<SchoolAlert> alerts;
  final List<SchoolEvent> events;
  final List<RecentActivity> activities;
  final AttendanceSummary attendance;
  final FeeSummary fees;
}
