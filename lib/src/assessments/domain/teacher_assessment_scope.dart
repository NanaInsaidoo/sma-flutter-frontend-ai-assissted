import '../../dashboard/data/teacher_workspace_api_client.dart';
import '../data/assessment_api_client.dart';

/// Narrows the school assessment setup to the classes and subjects that the
/// signed-in teacher is currently assigned to teach.
AssessmentFormSetup scopeAssessmentSetupForTeacher(
  AssessmentFormSetup setup,
  TeacherWorkspaceSnapshot workspace,
) {
  final classTeacherStreamIds = workspace.classes
      .where((assignment) => assignment.active)
      .map((assignment) => assignment.streamId)
      .toSet();
  final subjectAssignments = workspace.subjects
      .where((assignment) => assignment.active)
      .toList();
  final assignedStreamIds = <int>{
    ...classTeacherStreamIds,
    ...subjectAssignments.map((assignment) => assignment.streamId),
  };

  final streams = setup.streams
      .where((stream) => assignedStreamIds.contains(stream.id))
      .toList();
  final visibleStreamIds = streams.map((stream) => stream.id).toSet();
  final visibleGradeIds = streams.map((stream) => stream.gradeLevelId).toSet();

  final assignedSubjectStreams = <int, Set<int>>{};
  for (final assignment in subjectAssignments) {
    assignedSubjectStreams
        .putIfAbsent(assignment.subjectId, () => <int>{})
        .add(assignment.streamId);
  }

  final subjects = setup.subjects
      .map((subject) {
        final permittedStreams = <int>{};
        for (final streamId in subject.availableStreamIds) {
          if (!visibleStreamIds.contains(streamId)) continue;
          if (classTeacherStreamIds.contains(streamId) ||
              (assignedSubjectStreams[subject.id]?.contains(streamId) ??
                  false)) {
            permittedStreams.add(streamId);
          }
        }
        return AssessmentSubjectOption(
          id: subject.id,
          gradeLevelId: subject.gradeLevelId,
          name: subject.name,
          availableStreamIds: permittedStreams,
        );
      })
      .where((subject) => subject.availableStreamIds.isNotEmpty)
      .toList();

  return AssessmentFormSetup(
    streams: streams,
    gradeLevels: setup.gradeLevels
        .where((grade) => visibleGradeIds.contains(grade.id))
        .toList(),
    subjects: subjects,
    academicYearId: setup.academicYearId,
    academicYearName: setup.academicYearName,
    termId: setup.termId,
    termName: setup.termName,
    termSequence: setup.termSequence,
    termClosed: setup.termClosed,
  );
}
