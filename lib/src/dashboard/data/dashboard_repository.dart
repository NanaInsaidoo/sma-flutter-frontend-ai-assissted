import '../domain/dashboard_models.dart';

abstract interface class DashboardRepository {
  /// Future backend route:
  /// GET /api/v1/schools/{schoolId}/admin/dashboard
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId);
}
