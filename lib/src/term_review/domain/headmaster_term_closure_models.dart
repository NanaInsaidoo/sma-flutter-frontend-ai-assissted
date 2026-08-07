class TermClosureItem {
  const TermClosureItem({
    required this.key,
    required this.label,
    required this.status,
    required this.severity,
    required this.detail,
  });
  final String key, label, status, severity, detail;
  bool get ready => status == 'READY';
  bool get warning => severity == 'WARNING' && !ready;
}

class HeadmasterTermClosure {
  const HeadmasterTermClosure({
    required this.termId,
    required this.status,
    required this.termClosed,
    required this.readyToClose,
    required this.items,
    required this.acknowledgements,
    required this.facilities,
    required this.summary,
    this.transitionPreview = const {},
    this.transition = const {},
  });
  final int termId;
  final String status;
  final bool termClosed, readyToClose;
  final List<TermClosureItem> items;
  final Map<String, String> acknowledgements;
  final Map<String, dynamic> facilities, summary;
  final Map<String, dynamic> transitionPreview, transition;
}

class HeadmasterTermClosureInput {
  const HeadmasterTermClosureInput({
    required this.actorUserId,
    required this.acknowledgements,
    required this.facilities,
    this.confirmation,
  });
  final int? actorUserId;
  final Map<String, String> acknowledgements;
  final Map<String, dynamic> facilities;
  final String? confirmation;
}

abstract class HeadmasterTermClosureRepository {
  Future<HeadmasterTermClosure> get(String schoolId);
  Future<HeadmasterTermClosure> saveDraft(
    String schoolId,
    HeadmasterTermClosureInput input,
  );
  Future<HeadmasterTermClosure> close(
    String schoolId,
    HeadmasterTermClosureInput input,
  );
  Future<List<int>> downloadReport(String schoolId);
}
