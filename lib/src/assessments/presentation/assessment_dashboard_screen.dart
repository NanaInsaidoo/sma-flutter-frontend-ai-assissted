import 'package:flutter/material.dart';

import 'assessment_workflow_screen.dart';

class AssessmentDashboardScreen extends StatelessWidget {
  const AssessmentDashboardScreen({
    super.key,
    required this.schoolName,
    required this.term,
    required this.academicYear,
  });

  final String schoolName;
  final String term;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    return CompleteAssessmentWorkflow(
      schoolName: schoolName,
      term: term,
      academicYear: academicYear,
    );
  }
}
