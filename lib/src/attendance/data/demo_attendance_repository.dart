import '../domain/attendance_models.dart';

class DemoAttendanceRepository implements AttendanceRepository {
  final Map<String, List<AttendanceRecord>> _savedRecords = {};

  static const grades = [
    AttendanceGradeLevel(id: 1, name: 'KG 1'),
    AttendanceGradeLevel(id: 2, name: 'KG 2'),
    AttendanceGradeLevel(id: 3, name: 'Basic 1'),
    AttendanceGradeLevel(id: 4, name: 'Basic 2'),
    AttendanceGradeLevel(id: 5, name: 'Basic 3'),
    AttendanceGradeLevel(id: 6, name: 'Basic 4'),
    AttendanceGradeLevel(id: 7, name: 'Basic 5'),
    AttendanceGradeLevel(id: 8, name: 'Basic 6'),
    AttendanceGradeLevel(id: 9, name: 'JHS 1'),
    AttendanceGradeLevel(id: 10, name: 'JHS 2'),
    AttendanceGradeLevel(id: 11, name: 'JHS 3'),
  ];

  static final streams = [
    for (final grade in grades)
      for (var index = 0; index < 2; index++)
        AttendanceStream(
          id: grade.id * 10 + index + 1,
          name: 'Stream ${index == 0 ? 'A' : 'B'}',
          gradeLevelId: grade.id,
        ),
  ];

  static const _names = [
    ('Kofi', 'Agyemang'),
    ('David', 'Akoto'),
    ('Kwaku', 'Boakye'),
    ('Afia', 'Frimpong'),
    ('Deborah', 'Gyasi'),
    ('Ama', 'Boateng'),
    ('Yaw', 'Asante'),
    ('Adwoa', 'Mensah'),
    ('Kojo', 'Owusu'),
    ('Esi', 'Darko'),
    ('Nana', 'Adu'),
    ('Akua', 'Bonsu'),
    ('Kwame', 'Adjei'),
    ('Abena', 'Amoah'),
    ('Fiifi', 'Antwi'),
  ];

  @override
  Future<List<AttendanceGradeLevel>> getGradeLevels(
    String customSchoolId,
  ) async {
    await _pause();
    return grades;
  }

  @override
  Future<List<AttendanceStream>> getStreams({
    required String customSchoolId,
    required int gradeLevelId,
  }) async {
    await _pause();
    return streams
        .where((stream) => stream.gradeLevelId == gradeLevelId)
        .toList();
  }

  @override
  Future<AttendanceRoster> getRoster({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async {
    await _pause();
    final grade = grades.firstWhere((grade) => grade.id == gradeLevelId);
    final stream = streams.firstWhere((stream) => stream.id == streamId);
    final students = List.generate(15, (index) {
      final name = _names[(index + streamId) % _names.length];
      return AttendanceStudent(
        customStudentId:
            'STU-${grade.name.replaceAll(' ', '').toUpperCase()}-${stream.name.substring(stream.name.length - 1)}-${(index + 1).toString().padLeft(3, '0')}',
        firstName: name.$1,
        lastName: name.$2,
        gradeLevelId: gradeLevelId,
        streamId: streamId,
        streamName: stream.name,
      );
    });
    return AttendanceRoster(
      students: students,
      records: _savedRecords[_key(streamId, date)] ?? const [],
    );
  }

  @override
  Future<void> saveAttendance({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
    required List<AttendanceEntry> entries,
    required bool updateExisting,
  }) async {
    await _pause();
    _savedRecords[_key(streamId, date)] = entries
        .map(
          (entry) => AttendanceRecord(
            attendanceId:
                entry.attendanceId ??
                'ATT-$streamId-${entry.student.customStudentId}',
            customStudentId: entry.student.customStudentId,
            mark: entry.mark,
            minutesLate: entry.minutesLate,
            remarks: entry.remarks,
          ),
        )
        .toList();
  }

  static String _key(int streamId, DateTime date) =>
      '$streamId-${date.year}-${date.month}-${date.day}';

  static Future<void> _pause() =>
      Future<void>.delayed(const Duration(milliseconds: 40));
}
