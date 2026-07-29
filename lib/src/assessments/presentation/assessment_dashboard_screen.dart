import 'package:flutter/material.dart';

import 'assessment_workflow_screen.dart';

class AssessmentDashboardScreen extends StatelessWidget {
  const AssessmentDashboardScreen({
    super.key,
    required this.schoolName,
    required this.term,
    required this.academicYear,
    required this.customSchoolId,
    required this.accessToken,
    this.onRefreshAccessToken,
  });

  final String schoolName;
  final String term;
  final String academicYear;
  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  @override
  Widget build(BuildContext context) {
    return CompleteAssessmentWorkflow(
      schoolName: schoolName,
      term: term,
      academicYear: academicYear,
      customSchoolId: customSchoolId,
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
    );
  }
}
