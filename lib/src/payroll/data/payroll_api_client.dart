import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class PayrollApiClient {
  PayrollApiClient({
    required this.schoolId,
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String schoolId;
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  String get _root => '/api/schools/${Uri.encodeComponent(schoolId)}/payroll';

  Future<PayrollAccess> getAccess() async {
    final response = await _send('GET', '$_root/access');
    final value = jsonDecode(response.body);
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return PayrollAccess(
      canView: json['canView'] == true,
      canEdit: json['canEdit'] == true,
    );
  }

  Future<List<PayrollStaffRecord>> getStaff() async {
    final response = await _send('GET', '$_root/staff');
    final decoded = jsonDecode(response.body);
    final values = decoded is List ? decoded : const [];
    return values
        .whereType<Map<String, dynamic>>()
        .map(PayrollStaffRecord.fromJson)
        .toList();
  }

  Future<PayrollConfiguration> getConfiguration(String staffId) async {
    final response = await _send(
      'GET',
      '$_root/staff/${Uri.encodeComponent(staffId)}',
    );
    return PayrollConfiguration.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PayrollConfiguration> saveConfiguration({
    required String staffId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'PUT',
      '$_root/staff/${Uri.encodeComponent(staffId)}',
      body: body,
    );
    return PayrollConfiguration.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> savePaymentAccount({
    required String staffId,
    required Map<String, dynamic> body,
  }) async {
    await _send(
      'PUT',
      '$_root/staff/${Uri.encodeComponent(staffId)}/payment-account/payroll-update',
      body: body,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken?.isNotEmpty != true) {
      throw const PayrollApiException('Please sign in again to open payroll.');
    }
    Future<http.Response> send() {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      return method == 'PUT'
          ? _client
                .put(uri, headers: headers, body: jsonEncode(body ?? {}))
                .timeout(const Duration(seconds: 20))
          : _client
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 20));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final next = await onRefreshAccessToken!.call();
        if (next?.isNotEmpty == true) {
          accessToken = next;
          response = await send();
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw PayrollApiException(_message(response));
    } on TimeoutException {
      throw const PayrollApiException(
        'The payroll request took too long. Please try again.',
      );
    } on PayrollApiException {
      rethrow;
    } catch (_) {
      throw const PayrollApiException(
        'Unable to reach the payroll service right now.',
      );
    }
  }

  String _message(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) {
        for (final key in ['message', 'detail', 'error']) {
          final text = '${value[key] ?? ''}'.trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (_) {}
    return switch (response.statusCode) {
      403 => 'You do not have permission to view or change payroll.',
      404 => 'The payroll record could not be found.',
      >= 500 => 'The payroll service is having trouble. Please try again.',
      _ => 'The payroll request could not be completed.',
    };
  }
}

class PayrollStaffRecord {
  const PayrollStaffRecord({
    required this.staffId,
    required this.name,
    required this.jobTitle,
    required this.department,
    required this.employmentType,
    required this.payrollStatus,
    required this.basicPay,
    required this.grossSalary,
    required this.paymentMethod,
    required this.paymentAccountLabel,
  });

  final String staffId;
  final String name;
  final String jobTitle;
  final String department;
  final String employmentType;
  final String payrollStatus;
  final double basicPay;
  final double grossSalary;
  final String paymentMethod;
  final String paymentAccountLabel;

  factory PayrollStaffRecord.fromJson(Map<String, dynamic> json) =>
      PayrollStaffRecord(
        staffId: '${json['staffId'] ?? ''}',
        name: '${json['name'] ?? 'Staff member'}',
        jobTitle: '${json['jobTitle'] ?? 'Staff'}',
        department: '${json['department'] ?? 'Not assigned'}',
        employmentType: '${json['employmentType'] ?? 'Not specified'}',
        payrollStatus: '${json['payrollStatus'] ?? 'NOT_CONFIGURED'}',
        basicPay: _amount(json['basicPay']),
        grossSalary: _amount(json['grossSalary']),
        paymentMethod: '${json['paymentMethod'] ?? ''}',
        paymentAccountLabel: '${json['paymentAccountLabel'] ?? ''}',
      );
}

class PayrollConfiguration {
  const PayrollConfiguration({
    required this.payrollStatus,
    required this.payType,
    required this.payGrade,
    required this.tier2Provider,
    required this.effectiveDate,
    required this.ssnitStatus,
    required this.basicPay,
    required this.houseAllowance,
    required this.transportAllowance,
    required this.otherAllowances,
    required this.houseAllowanceTaxable,
    required this.transportAllowanceTaxable,
    required this.otherAllowancesTaxable,
    required this.grossSalary,
    required this.ssnitNumber,
    required this.tinNumber,
    required this.unionName,
    required this.unionDues,
    required this.tier3Percentage,
    required this.otherDeductions,
    required this.taxRelief,
    required this.ssnitEmployee,
    required this.ssnitEmployer,
    required this.chargeableIncome,
    required this.estimatedPaye,
    required this.netPay,
    required this.paymentMethod,
    required this.paymentAccountLabel,
  });

  final String payrollStatus;
  final String payType;
  final String payGrade;
  final String tier2Provider;
  final String effectiveDate;
  final String ssnitStatus;
  final double basicPay;
  final double houseAllowance;
  final double transportAllowance;
  final double otherAllowances;
  final bool houseAllowanceTaxable;
  final bool transportAllowanceTaxable;
  final bool otherAllowancesTaxable;
  final double grossSalary;
  final String ssnitNumber;
  final String tinNumber;
  final String unionName;
  final double unionDues;
  final double tier3Percentage;
  final double otherDeductions;
  final double taxRelief;
  final double ssnitEmployee;
  final double ssnitEmployer;
  final double chargeableIncome;
  final double estimatedPaye;
  final double netPay;
  final String paymentMethod;
  final String paymentAccountLabel;

  factory PayrollConfiguration.fromJson(Map<String, dynamic> json) =>
      PayrollConfiguration(
        payrollStatus: '${json['payrollStatus'] ?? 'NOT_CONFIGURED'}',
        payType: '${json['payType'] ?? 'PERMANENT'}',
        payGrade: '${json['payGrade'] ?? ''}',
        tier2Provider: '${json['tier2Provider'] ?? ''}',
        effectiveDate: '${json['effectiveDate'] ?? ''}',
        ssnitStatus: '${json['ssnitStatus'] ?? 'CONTRIBUTING'}',
        basicPay: _amount(json['basicPay']),
        houseAllowance: _amount(json['houseAllowance']),
        transportAllowance: _amount(json['transportAllowance']),
        otherAllowances: _amount(json['otherAllowances']),
        houseAllowanceTaxable: json['houseAllowanceTaxable'] != false,
        transportAllowanceTaxable: json['transportAllowanceTaxable'] == true,
        otherAllowancesTaxable: json['otherAllowancesTaxable'] != false,
        grossSalary: _amount(json['grossSalary']),
        ssnitNumber: '${json['ssnitNumber'] ?? ''}',
        tinNumber: '${json['tinNumber'] ?? ''}',
        unionName: '${json['unionName'] ?? ''}',
        unionDues: _amount(json['unionDues']),
        tier3Percentage: _amount(json['tier3Percentage']),
        otherDeductions: _amount(json['otherDeductions']),
        taxRelief: _amount(json['taxRelief']),
        ssnitEmployee: _amount(json['ssnitEmployee']),
        ssnitEmployer: _amount(json['ssnitEmployer']),
        chargeableIncome: _amount(json['chargeableIncome']),
        estimatedPaye: _amount(json['estimatedPaye']),
        netPay: _amount(json['netPay']),
        paymentMethod: '${json['paymentMethod'] ?? ''}',
        paymentAccountLabel: '${json['paymentAccountLabel'] ?? ''}',
      );
}

double _amount(dynamic value) =>
    double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;

class PayrollApiException implements Exception {
  const PayrollApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PayrollAccess {
  const PayrollAccess({required this.canView, required this.canEdit});
  final bool canView;
  final bool canEdit;
}
