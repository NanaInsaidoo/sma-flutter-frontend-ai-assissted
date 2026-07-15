import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class PlatformApiClient {
  PlatformApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<SchoolCreationLookups> getSchoolCreationLookups() async {
    final results = await Future.wait([
      _lookupOptions('/api/lookup/school-categories'),
      _lookupOptions('/api/lookup/education-levels'),
      _lookupOptions('/api/lookup/ges-registration-types'),
      _lookupOptions('/api/lookup/business-registration-types'),
      _lookupOptions('/api/lookup/social-welfare-compliance-statuses'),
      _lookupOptions('/api/lookup/nationalities'),
      _lookupOptions('/api/lookup/regions'),
      _lookupOptions('/api/lookup/academic-years'),
      _lookupOptions('/api/lookup/term-types'),
      _lookupOptions('/api/lookup/social-media-platforms'),
      _lookupOptions('/api/lookup/event-types'),
    ]);

    return SchoolCreationLookups(
      schoolCategories: results[0].labels,
      schoolCategoryIds: results[0].ids,
      educationLevels: results[1].labels,
      educationLevelIds: results[1].ids,
      gesRegistrationTypes: results[2].labels,
      gesRegistrationTypeIds: results[2].ids,
      businessRegistrationTypes: results[3].labels,
      businessRegistrationTypeIds: results[3].ids,
      socialWelfareStatuses: results[4].labels,
      socialWelfareStatusIds: results[4].ids,
      countries: results[5].labels,
      countryIds: results[5].ids,
      regions: results[6].labels,
      regionIds: results[6].ids,
      academicYears: results[7].labels,
      academicYearIds: results[7].ids,
      termTypes: results[8].labels,
      termTypeIds: results[8].ids,
      socialMediaPlatforms: results[9].labels,
      socialMediaPlatformIds: results[9].ids,
      eventTypes: results[10].labels,
      eventTypeIds: results[10].ids,
      gradeLevels: const [],
      gradeLevelIds: const {},
      cities: const [],
      cityIds: const {},
      districts: const [],
      districtIds: const {},
    );
  }

  Future<({List<String> labels, Map<String, int> ids})>
  getDefaultGradeLevels() async {
    final result = await _lookupOptions('/api/grade-levels/default');
    return (labels: result.labels, ids: result.ids);
  }

  Future<SchoolCreationLookups> getDistrictLookups(int? regionId) async {
    final options = await _lookupOptions(
      '/api/lookup/districts${regionId != null && regionId > 0 ? '?regionId=$regionId' : ''}',
    );
    return SchoolCreationLookups.empty().copyWith(
      districts: options.labels,
      districtIds: options.ids,
    );
  }

  Future<SchoolCreationLookups> getCityLookups(String search) async {
    final query = Uri.encodeQueryComponent(search.trim());
    final options = await _lookupOptions('/api/lookup/cities?search=$query');
    return SchoolCreationLookups.empty().copyWith(
      cities: options.labels,
      cityIds: options.ids,
    );
  }

  Future<_LookupResult> _lookupOptions(String path) async {
    if (accessToken == null ||
        accessToken!.isEmpty ||
        accessToken == 'preview') {
      return const _LookupResult();
    }

    try {
      final response = await _sendWithRefresh(path);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _LookupResult();
      }
      final decoded = jsonDecode(response.body);
      final list = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? _lookupList(decoded)
          : null;
      if (list is! List) return const _LookupResult();

      final options = list
          .map((item) {
            if (item is String) return _LookupOption(label: item);
            if (item is Map<String, dynamic>) {
              final id = _intFrom(item, [
                'id',
                'schoolCategoryId',
                'educationLevelId',
                'registrationTypeId',
                'gesRegistrationTypeId',
                'businessRegistrationTypeId',
                'complianceStatusId',
                'countryId',
                'regionId',
                'districtId',
                'cityId',
                'academicYearId',
                'termTypeId',
                'socialMediaPlatformId',
                'platformId',
                'eventTypeId',
                'gradeLevelId',
              ]);
              for (final key in [
                'gradeName',
                'gradeLevelName',
                'cityName',
                'districtName',
                'regionName',
                'eventName',
                'eventTypeName',
                'platformName',
                'socialMediaPlatformName',
                'name',
                'level',
                'status',
                'description',
                'label',
                'year',
                'countryName',
              ]) {
                final value = item[key];
                if (value != null && value.toString().trim().isNotEmpty) {
                  return _LookupOption(label: value.toString(), id: id);
                }
              }
            }
            return const _LookupOption(label: '');
          })
          .where((option) => option.label.trim().isNotEmpty)
          .toList();
      return _LookupResult(options);
    } catch (_) {
      return const _LookupResult();
    }
  }

  dynamic _lookupList(Map<String, dynamic> decoded) {
    final container =
        decoded['data'] ??
        decoded['content'] ??
        decoded['items'] ??
        decoded['results'] ??
        decoded['options'] ??
        decoded['districts'] ??
        decoded['regions'];
    if (container is Map<String, dynamic>) {
      return container['content'] ??
          container['items'] ??
          container['results'] ??
          container['options'] ??
          container['districts'] ??
          container['regions'];
    }
    return container;
  }

  Future<http.Response> _sendWithRefresh(String path) async {
    Future<http.Response> send() => _client.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    var response = await send().timeout(const Duration(seconds: 12));
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshedToken = await onRefreshAccessToken!.call();
      if (refreshedToken != null &&
          refreshedToken.isNotEmpty &&
          refreshedToken != accessToken) {
        accessToken = refreshedToken;
        response = await send().timeout(const Duration(seconds: 12));
      }
    }
    return response;
  }

  int? _intFrom(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is int) return value;
      final parsed = int.tryParse('$value');
      if (parsed != null) return parsed;
    }
    return null;
  }
}

class _LookupOption {
  const _LookupOption({required this.label, this.id});
  final String label;
  final int? id;
}

class _LookupResult {
  const _LookupResult([this.options = const []]);
  final List<_LookupOption> options;

  List<String> get labels =>
      options.map((option) => option.label).toSet().toList();
  Map<String, int> get ids => {
    for (final option in options)
      if (option.id != null) option.label: option.id!,
  };
}

class SchoolCreationLookups {
  const SchoolCreationLookups({
    required this.schoolCategories,
    required this.schoolCategoryIds,
    required this.educationLevels,
    required this.educationLevelIds,
    required this.gesRegistrationTypes,
    required this.gesRegistrationTypeIds,
    required this.businessRegistrationTypes,
    required this.businessRegistrationTypeIds,
    required this.socialWelfareStatuses,
    required this.socialWelfareStatusIds,
    required this.countries,
    required this.countryIds,
    required this.regions,
    required this.regionIds,
    required this.academicYears,
    required this.academicYearIds,
    required this.termTypes,
    required this.termTypeIds,
    required this.socialMediaPlatforms,
    required this.socialMediaPlatformIds,
    required this.eventTypes,
    required this.eventTypeIds,
    required this.gradeLevels,
    required this.gradeLevelIds,
    required this.cities,
    required this.cityIds,
    required this.districts,
    required this.districtIds,
  });

  final List<String> schoolCategories;
  final Map<String, int> schoolCategoryIds;
  final List<String> educationLevels;
  final Map<String, int> educationLevelIds;
  final List<String> gesRegistrationTypes;
  final Map<String, int> gesRegistrationTypeIds;
  final List<String> businessRegistrationTypes;
  final Map<String, int> businessRegistrationTypeIds;
  final List<String> socialWelfareStatuses;
  final Map<String, int> socialWelfareStatusIds;
  final List<String> countries;
  final Map<String, int> countryIds;
  final List<String> regions;
  final Map<String, int> regionIds;
  final List<String> academicYears;
  final Map<String, int> academicYearIds;
  final List<String> termTypes;
  final Map<String, int> termTypeIds;
  final List<String> socialMediaPlatforms;
  final Map<String, int> socialMediaPlatformIds;
  final List<String> eventTypes;
  final Map<String, int> eventTypeIds;
  final List<String> gradeLevels;
  final Map<String, int> gradeLevelIds;
  final List<String> cities;
  final Map<String, int> cityIds;
  final List<String> districts;
  final Map<String, int> districtIds;

  SchoolCreationLookups copyWith({
    List<String>? cities,
    Map<String, int>? cityIds,
    List<String>? districts,
    Map<String, int>? districtIds,
    List<String>? gradeLevels,
    Map<String, int>? gradeLevelIds,
    List<String>? academicYears,
    Map<String, int>? academicYearIds,
  }) {
    return SchoolCreationLookups(
      schoolCategories: schoolCategories,
      schoolCategoryIds: schoolCategoryIds,
      educationLevels: educationLevels,
      educationLevelIds: educationLevelIds,
      gesRegistrationTypes: gesRegistrationTypes,
      gesRegistrationTypeIds: gesRegistrationTypeIds,
      businessRegistrationTypes: businessRegistrationTypes,
      businessRegistrationTypeIds: businessRegistrationTypeIds,
      socialWelfareStatuses: socialWelfareStatuses,
      socialWelfareStatusIds: socialWelfareStatusIds,
      countries: countries,
      countryIds: countryIds,
      regions: regions,
      regionIds: regionIds,
      academicYears: academicYears ?? this.academicYears,
      academicYearIds: academicYearIds ?? this.academicYearIds,
      termTypes: termTypes,
      termTypeIds: termTypeIds,
      socialMediaPlatforms: socialMediaPlatforms,
      socialMediaPlatformIds: socialMediaPlatformIds,
      eventTypes: eventTypes,
      eventTypeIds: eventTypeIds,
      gradeLevels: gradeLevels ?? this.gradeLevels,
      gradeLevelIds: gradeLevelIds ?? this.gradeLevelIds,
      cities: cities ?? this.cities,
      cityIds: cityIds ?? this.cityIds,
      districts: districts ?? this.districts,
      districtIds: districtIds ?? this.districtIds,
    );
  }

  factory SchoolCreationLookups.empty() => const SchoolCreationLookups(
    schoolCategories: [],
    schoolCategoryIds: {},
    educationLevels: [],
    educationLevelIds: {},
    gesRegistrationTypes: [],
    gesRegistrationTypeIds: {},
    businessRegistrationTypes: [],
    businessRegistrationTypeIds: {},
    socialWelfareStatuses: [],
    socialWelfareStatusIds: {},
    countries: [],
    countryIds: {},
    regions: [],
    regionIds: {},
    academicYears: [],
    academicYearIds: {},
    termTypes: [],
    termTypeIds: {},
    socialMediaPlatforms: [],
    socialMediaPlatformIds: {},
    eventTypes: [],
    eventTypeIds: {},
    gradeLevels: [],
    gradeLevelIds: {},
    cities: [],
    cityIds: {},
    districts: [],
    districtIds: {},
  );
}
