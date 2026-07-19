import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../attendance/data/attendance_api_client.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../config/api_config.dart';
import '../../fees/data/fee_api_client.dart';
import '../../fees/domain/fee_models.dart' as fee_models;
import '../../theme/app_theme.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_repository.dart';

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository({
    required this.accessToken,
    required this.administratorName,
    this.schoolName,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final String administratorName;
  final String? schoolName;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    if (schoolId.trim().isEmpty) {
      throw const DashboardApiException(
        'Your account is not linked to a school yet.',
      );
    }

    final feeApi = FeeApiClient(
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
      client: _client,
    );
    final attendanceApi = AttendanceApiClient(
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
      client: _client,
    );

    try {
      final results = await Future.wait<Object>([
        _getSchoolStatistics(schoolId),
        feeApi.getCurrentTerm(schoolId),
        feeApi.getFeeManagementOverview(customSchoolId: schoolId),
        attendanceApi.getOverview(schoolId),
      ]);
      accessToken = feeApi.accessToken ?? attendanceApi.accessToken;

      final statistics = results[0] as Map<String, dynamic>;
      final term = results[1] as fee_models.CurrentAcademicTerm;
      final feeOverview = results[2] as fee_models.FeeManagementOverview;
      final attendance = results[3] as AttendanceDashboardOverview;
      final termParts = term.name
          .split('·')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      final termName = termParts.isEmpty ? 'Current term' : termParts.first;
      final academicYear = termParts.length > 1 ? termParts.last : '';
      final totalStudents = _integer(statistics['totalStudents']);
      final activeClasses = _integer(statistics['totalActiveClasses']);
      final totalClasses = _integer(statistics['totalClasses']);
      final attendanceRate = attendance.today.attendanceRate;

      return DashboardSnapshot(
        schoolName: schoolName?.trim().isNotEmpty == true
            ? schoolName!.trim()
            : schoolId,
        administratorName: administratorName.trim().isEmpty
            ? 'School administrator'
            : administratorName.trim(),
        term: termName,
        academicYear: academicYear,
        lastUpdated: DateTime.now(),
        metrics: [
          DashboardMetric(
            label: 'Students enrolled',
            value: '$totalStudents',
            caption: 'Current enrolled students',
            change: '${_integer(statistics['totalActiveStudents'])} active',
            icon: Icons.groups_rounded,
            color: AppColors.green,
          ),
          DashboardMetric(
            label: 'Active classes',
            value: '$activeClasses',
            caption: '$totalClasses classes configured',
            change: '${_integer(statistics['totalGradeLevels'])} grade levels',
            icon: Icons.class_rounded,
            color: AppColors.purple,
          ),
          DashboardMetric(
            label: 'Attendance today',
            value: '${attendanceRate.toStringAsFixed(1)}%',
            caption:
                '${attendance.today.present} of ${attendance.today.totalStudents} present',
            change: '${attendance.streamsPending} streams pending',
            icon: Icons.fact_check_rounded,
            color: AppColors.blue,
          ),
          DashboardMetric(
            label: 'Fees collected',
            value: _money(feeOverview.totalCollected),
            caption: termName,
            change:
                '${feeOverview.collectionRate.toStringAsFixed(1)}% collected',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.amber,
          ),
        ],
        admissions: const [],
        alerts: attendance.alerts
            .map(
              (alert) => SchoolAlert(
                title: alert.title,
                message: alert.message,
                context: 'Attendance',
                level: _alertLevel(alert.severity),
              ),
            )
            .toList(),
        events: const [],
        activities: const [],
        attendance: AttendanceSummary(
          total: attendance.today.totalStudents,
          present: attendance.today.present,
          absent: attendance.today.absent,
          late: attendance.today.late,
        ),
        fees: FeeSummary(
          collected: feeOverview.totalCollected,
          outstanding: feeOverview.outstanding,
          waivers: 0,
        ),
      );
    } on DashboardApiException {
      rethrow;
    } on FeeApiException catch (error) {
      throw DashboardApiException(error.message);
    } on AttendanceApiException catch (error) {
      throw DashboardApiException(error.message);
    } catch (_) {
      throw const DashboardApiException(
        'Unable to load the school dashboard from the server.',
      );
    }
  }

  Future<Map<String, dynamic>> _getSchoolStatistics(String schoolId) async {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const DashboardApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      return _client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/schools/$schoolId/dashboard/statistics',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${accessToken!.trim()}',
            },
          )
          .timeout(const Duration(seconds: 20));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final refreshed = await onRefreshAccessToken!();
        if (refreshed?.trim().isNotEmpty == true) {
          accessToken = refreshed!.trim();
          response = await send();
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DashboardApiException(_responseMessage(response));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const DashboardApiException(
          'The school statistics response was invalid.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const DashboardApiException(
        'The school dashboard took too long to load. Please try again.',
      );
    } on DashboardApiException {
      rethrow;
    } catch (_) {
      throw const DashboardApiException(
        'Unable to reach the school dashboard service.',
      );
    }
  }

  String _responseMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'details']) {
          final value = '${decoded[key] ?? ''}'.trim();
          if (value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return 'Dashboard request failed (${response.statusCode}).';
  }

  int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  AlertLevel _alertLevel(String severity) {
    return switch (severity.trim().toUpperCase()) {
      'CRITICAL' || 'HIGH' || 'ERROR' => AlertLevel.critical,
      'WARNING' || 'MEDIUM' => AlertLevel.warning,
      _ => AlertLevel.info,
    };
  }

  String _money(double amount) {
    final value = amount.toStringAsFixed(0);
    return 'GH₵$value';
  }
}

class DashboardApiException implements Exception {
  const DashboardApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
