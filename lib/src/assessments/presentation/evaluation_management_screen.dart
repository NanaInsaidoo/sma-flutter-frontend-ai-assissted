import 'package:flutter/material.dart';

import '../data/assessment_api_client.dart';
import 'term_evaluation_workflow_screen.dart';

class EvaluationManagementScreen extends StatefulWidget {
  const EvaluationManagementScreen({
    super.key,
    required this.schoolId,
    required this.viewerName,
    required this.viewerRole,
    required this.accessToken,
    this.onRefreshAccessToken,
  });

  final String schoolId;
  final String viewerName;
  final String viewerRole;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  @override
  State<EvaluationManagementScreen> createState() =>
      _EvaluationManagementScreenState();
}

class _EvaluationManagementScreenState
    extends State<EvaluationManagementScreen> {
  late final AssessmentApiClient _api;
  late Future<AssessmentFormSetup> _setup;

  @override
  void initState() {
    super.initState();
    _api = AssessmentApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    _setup = _loadSetup();
  }

  Future<AssessmentFormSetup> _loadSetup() {
    if (widget.schoolId.trim().isEmpty) {
      return Future.error(
        const AssessmentApiException(
          'A school must be selected before loading evaluation management.',
        ),
      );
    }
    return _api.getFormSetup(widget.schoolId);
  }

  void _retry() => setState(() => _setup = _loadSetup());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssessmentFormSetup>(
      future: _setup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is AssessmentApiException
              ? error.message
              : 'Evaluation management could not be loaded.';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFB45309),
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return TermEvaluationWorkflowScreen(
          api: _api,
          schoolId: widget.schoolId,
          viewerName: widget.viewerName,
          viewerRole: widget.viewerRole,
          setup: snapshot.requireData,
          managementProgressOnly: true,
        );
      },
    );
  }
}
