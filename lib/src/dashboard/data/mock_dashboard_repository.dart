import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_repository.dart';

class MockDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    return DashboardSnapshot(
      schoolName: 'Akwaaba Hills School',
      administratorName: 'Kwame',
      term: 'Term 2',
      academicYear: '2025/26',
      lastUpdated: DateTime.now(),
      metrics: const [
        DashboardMetric(
          label: 'Students enrolled',
          value: '648',
          caption: 'All active students',
          change: '+12 this term',
          icon: Icons.groups_rounded,
          color: AppColors.green,
        ),
        DashboardMetric(
          label: 'Attendance today',
          value: '87.5%',
          caption: '567 of 648 present',
          change: '+1.8% this week',
          icon: Icons.fact_check_rounded,
          color: AppColors.blue,
        ),
        DashboardMetric(
          label: 'Fees collected',
          value: 'GH\u20b584,200',
          caption: 'This term',
          change: '75% collected',
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.amber,
        ),
        DashboardMetric(
          label: 'Outstanding fees',
          value: 'GH\u20b528,000',
          caption: 'Across 96 students',
          change: '23 overdue 30+ days',
          icon: Icons.receipt_long_rounded,
          color: AppColors.red,
        ),
      ],
      admissions: const [
        AdmissionGroup('KG', 12),
        AdmissionGroup('B1-3', 18),
        AdmissionGroup('B4-6', 14),
        AdmissionGroup('JHS 1', 9),
        AdmissionGroup('JHS 2', 6),
        AdmissionGroup('JHS 3', 3),
      ],
      alerts: const [
        SchoolAlert(
          message: '23 students have outstanding fees for over 30 days',
          context: 'Fees & requirements · now',
          level: AlertLevel.critical,
        ),
        SchoolAlert(
          message: 'JHS 2A attendance is below 75% this week',
          context: 'Attendance · 2 hours ago',
          level: AlertLevel.warning,
        ),
        SchoolAlert(
          message: 'Term 2 report card submission deadline is in 5 days',
          context: 'Assessments · today',
          level: AlertLevel.warning,
        ),
        SchoolAlert(
          message: '4 parent or guardian registrations need approval',
          context: 'People · yesterday',
          level: AlertLevel.info,
        ),
      ],
      events: const [
        SchoolEvent(
          day: '28',
          month: 'APR',
          title: 'Mid-term examinations begin',
          category: 'Exam',
        ),
        SchoolEvent(
          day: '02',
          month: 'MAY',
          title: 'Parent-teacher association meeting',
          category: 'Meeting',
        ),
        SchoolEvent(
          day: '09',
          month: 'MAY',
          title: 'Term 2 fee deadline',
          category: 'Payment',
        ),
        SchoolEvent(
          day: '16',
          month: 'MAY',
          title: 'Sports and cultural day',
          category: 'School event',
        ),
      ],
      activities: const [
        RecentActivity(
          initials: 'AA',
          name: 'Ama Asare',
          detail: 'recorded a fee payment of GH\u20b5450',
          time: '8 min ago',
        ),
        RecentActivity(
          initials: 'KO',
          name: 'Kweku Osei',
          detail: 'was admitted to Basic 1A',
          time: '42 min ago',
        ),
        RecentActivity(
          initials: 'MK',
          name: 'Mr Mensah Kojo',
          detail: 'marked attendance for JHS 3A',
          time: '1 hr ago',
        ),
      ],
      attendance: const AttendanceSummary(
        total: 648,
        present: 567,
        absent: 61,
        late: 20,
      ),
      fees: const FeeSummary(
        collected: 84200,
        outstanding: 28000,
        waivers: 3600,
      ),
    );
  }
}
