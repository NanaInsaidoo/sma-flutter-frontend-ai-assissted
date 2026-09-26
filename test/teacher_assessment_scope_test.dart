import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/assessments/data/assessment_api_client.dart';
import 'package:school_management_app/src/assessments/domain/teacher_assessment_scope.dart';
import 'package:school_management_app/src/dashboard/data/teacher_workspace_api_client.dart';

void main() {
  const setup = AssessmentFormSetup(
    streams: [
      AssessmentStreamOption(
        id: 10,
        gradeLevelId: 1,
        gradeName: 'Basic 1',
        streamName: 'A',
        studentCount: 20,
      ),
      AssessmentStreamOption(
        id: 20,
        gradeLevelId: 2,
        gradeName: 'Basic 2',
        streamName: 'B',
        studentCount: 18,
      ),
    ],
    gradeLevels: [
      AssessmentGradeLevelOption(id: 1, name: 'Basic 1', status: 'ACTIVE'),
      AssessmentGradeLevelOption(id: 2, name: 'Basic 2', status: 'ACTIVE'),
    ],
    subjects: [
      AssessmentSubjectOption(
        id: 100,
        gradeLevelId: 1,
        name: 'English',
        availableStreamIds: {10},
      ),
      AssessmentSubjectOption(
        id: 200,
        gradeLevelId: 1,
        name: 'Mathematics',
        availableStreamIds: {10},
      ),
      AssessmentSubjectOption(
        id: 300,
        gradeLevelId: 2,
        name: 'Science',
        availableStreamIds: {20},
      ),
    ],
    academicYearId: 1,
    academicYearName: '2026-2027',
    termId: 1,
    termName: 'First Term',
    termSequence: 1,
    termClosed: false,
  );

  test('class label does not repeat a grade already in the stream name', () {
    const stream = AssessmentStreamOption(
      id: 30,
      gradeLevelId: 3,
      gradeName: 'Creche',
      streamName: 'Creche - Section 1',
      studentCount: 3,
    );

    expect(stream.label, 'Creche - Section 1');
  });

  test(
    'class teacher sees every configured subject in assigned class only',
    () {
      const workspace = TeacherWorkspaceSnapshot(
        role: 'CLASS_TEACHER',
        assignedStudents: 20,
        classes: [
          TeacherClassAssignment(
            gradeLevelId: 1,
            gradeName: 'Basic 1',
            streamName: 'A',
            streamId: 10,
            primary: true,
          ),
        ],
        subjects: [],
      );

      final scoped = scopeAssessmentSetupForTeacher(setup, workspace);

      expect(scoped.streams.map((item) => item.id), [10]);
      expect(scoped.gradeLevels.map((item) => item.id), [1]);
      expect(scoped.subjects.map((item) => item.name), [
        'English',
        'Mathematics',
      ]);
    },
  );

  test('subject teacher sees assigned class and subject combination only', () {
    const workspace = TeacherWorkspaceSnapshot(
      role: 'SUBJECT_TEACHER',
      assignedStudents: 20,
      classes: [],
      subjects: [
        TeacherSubjectAssignment(
          gradeLevelId: 1,
          gradeName: 'Basic 1',
          streamId: 10,
          streamName: 'A',
          subjectId: 200,
          subjectName: 'Mathematics',
        ),
      ],
    );

    final scoped = scopeAssessmentSetupForTeacher(setup, workspace);

    expect(scoped.streams.map((item) => item.id), [10]);
    expect(scoped.subjects.map((item) => item.name), ['Mathematics']);
    expect(scoped.subjects.single.availableStreamIds, {10});
  });

  test('inactive teacher assignments are not included', () {
    const workspace = TeacherWorkspaceSnapshot(
      role: 'SUBJECT_TEACHER',
      assignedStudents: 0,
      classes: [],
      subjects: [
        TeacherSubjectAssignment(
          gradeLevelId: 2,
          gradeName: 'Basic 2',
          streamId: 20,
          streamName: 'B',
          subjectId: 300,
          subjectName: 'Science',
          active: false,
        ),
      ],
    );

    final scoped = scopeAssessmentSetupForTeacher(setup, workspace);

    expect(scoped.streams, isEmpty);
    expect(scoped.subjects, isEmpty);
  });
}
