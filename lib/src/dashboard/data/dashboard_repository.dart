import '../domain/dashboard_models.dart';

abstract interface class DashboardRepository {
  /// Future backend route:
  /// GET /api/v1/schools/{schoolId}/admin/dashboard
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId);

  Future<List<CalendarEventType>> getCalendarEventTypes();

  Future<SchoolEvent> createCalendarEvent({
    required String schoolId,
    required CalendarEventPayload event,
  });

  Future<SchoolEvent> updateCalendarEvent({
    required String schoolId,
    required String eventId,
    required CalendarEventPayload event,
  });

  Future<void> deleteCalendarEvent({
    required String schoolId,
    required String eventId,
  });
}
