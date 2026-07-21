import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/app_theme.dart';
import '../data/platform_api_client.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';
import 'document_opener.dart';

const _schoolDocumentLabels = [
  'Business registration certificate',
  'GES registration document',
  'Social welfare approval',
  'School crest or logo',
  'School front photo',
];

const _requiredSchoolDocumentLabels = {
  'Business registration certificate',
  'GES registration document',
  'Social welfare approval',
};

enum _SubmissionAction { schools, viewSchool }

class _SubmissionDetail extends StatelessWidget {
  const _SubmissionDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          value.isEmpty ? 'Not provided' : value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

String _ghanaCountryValue(List<String> countries) {
  for (final country in countries) {
    if (country.trim().toLowerCase() == 'ghana') return country;
  }
  return 'Ghana';
}

class SchoolCreationScreen extends StatefulWidget {
  const SchoolCreationScreen({
    super.key,
    required this.accessToken,
    required this.onRefreshAccessToken,
    required this.repository,
    required this.onBack,
    required this.onCreated,
    this.onViewCreated,
    this.onStepSaved,
    this.initialLookups,
    this.lookupLoader,
    this.existingSchool,
    this.initialStep,
    this.singleStepEdit = false,
    this.onStepUpdated,
    this.initialRecord,
    this.initialDocuments,
    this.initialGradeLevels,
  });

  final String? accessToken;
  final Future<String?> Function() onRefreshAccessToken;
  final PlatformRepository repository;
  final VoidCallback onBack;
  final VoidCallback onCreated;
  final ValueChanged<String>? onViewCreated;
  final VoidCallback? onStepSaved;
  final SchoolCreationLookups? initialLookups;
  final Future<SchoolCreationLookups> Function()? lookupLoader;
  final ManagedSchool? existingSchool;
  final int? initialStep;
  final bool singleStepEdit;
  final Future<void> Function()? onStepUpdated;
  final SchoolOnboardingRecord? initialRecord;
  final List<SchoolDocumentInfo>? initialDocuments;
  final List<SchoolGradeLevelInfo>? initialGradeLevels;

  @override
  State<SchoolCreationScreen> createState() => _SchoolCreationScreenState();
}

class _SchoolCreationScreenState extends State<SchoolCreationScreen> {
  final _schoolName = TextEditingController();
  final _motto = TextEditingController();
  final _yearFounded = TextEditingController();
  final _gesCode = TextEditingController();
  final _gesRegistrationDate = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _businessRegistrationDate = TextEditingController();
  final _gemisCode = TextEditingController();
  final _taxIdNumber = TextEditingController();
  final _socialWelfareNumber = TextEditingController();
  final _socialWelfareOfficer = TextEditingController();
  final _socialWelfareDate = TextEditingController();
  final _houseNumber = TextEditingController();
  final _streetName = TextEditingController();
  final _address = TextEditingController();
  final _ghanaPostAddress = TextEditingController();
  final _district = TextEditingController();
  final _gpsLatitude = TextEditingController();
  final _gpsLongitude = TextEditingController();
  final _town = TextEditingController();
  final _phone = TextEditingController();
  final _phoneNetwork = TextEditingController();
  final _secondaryPhone = TextEditingController();
  final _secondaryPhoneNetwork = TextEditingController();
  final _officePhone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _socialMedia = TextEditingController();
  final _administratorName = TextEditingController();
  final _administratorPhone = TextEditingController();
  final _administratorEmail = TextEditingController();

  int _completedSteps = 0;
  String _schoolCategory = '';
  String _educationLevel = '';
  String _gesRegistrationType = '';
  String _businessRegistrationType = '';
  String _socialWelfareStatus = '';
  String _region = '';
  int? _savedRegionId;
  int? _savedDistrictId;
  String _country = 'Ghana';
  String _socialMediaPlatform = '';
  final List<SocialMediaContact> _socialMediaLinks = [];
  final Set<String> _levels = {'Kindergarten', 'Primary'};
  final Map<String, int> _gradeStreams = {};
  final Map<String, int> _savedGradeLevelIds = {};
  String _academicYear = '';
  String _academicTerm = '';
  String _termDescription = '';
  DateTime? _termStartDate;
  DateTime? _termEndDate;
  final List<_CalendarEvent> _events = [];
  final Map<String, PlatformFile> _documents = {};
  String? _customSchoolId;
  late SchoolCreationLookups _lookups =
      (widget.initialLookups ?? SchoolCreationLookups.empty()).copyWith(
        gradeLevels: const [],
        gradeLevelIds: const {},
      );
  bool _loadingLookups = false;
  bool _loadingGradeLevels = false;
  String? _gradeLevelsError;
  bool _loadingDistricts = false;
  bool _loadingCities = false;
  bool _loadingExistingRecord = false;
  String? _existingRecordError;
  int? _wizardStep = 0;

  static const _steps = [
    _SetupStep(
      'School Information',
      'School name, category, year founded, and motto.',
      Icons.school_outlined,
    ),
    _SetupStep(
      'Registration Details',
      'GES, business registration, and tax identification.',
      Icons.badge_outlined,
    ),
    _SetupStep(
      'Social Welfare',
      'Social welfare approval number and compliance status.',
      Icons.verified_user_outlined,
    ),
    _SetupStep(
      'Address & Location',
      'Physical address, region, town, GPS, and directions.',
      Icons.location_on_outlined,
    ),
    _SetupStep(
      'Contact Information',
      'Phone numbers, email addresses, and school administrator.',
      Icons.contact_phone_outlined,
    ),
    _SetupStep(
      'Required Documents',
      'Upload supporting registration and compliance documents.',
      Icons.upload_file_outlined,
    ),
    _SetupStep(
      'Create Class Structure',
      'Define levels, classes, streams, and sections.',
      Icons.account_tree_outlined,
    ),
    _SetupStep(
      'Set School Calendar',
      'Configure the academic year, terms, and important dates.',
      Icons.calendar_month_outlined,
    ),
    _SetupStep(
      'Review & Submit',
      'Review all information and submit the school for approval.',
      Icons.task_alt_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _hydrateExistingSchool();
    final initialRecord = widget.initialRecord;
    if (initialRecord != null) {
      _hydrateFromRecord(initialRecord);
      final documents = widget.initialDocuments;
      if (documents != null) _hydrateDocuments(documents);
      final grades = widget.initialGradeLevels;
      if (grades != null) _hydrateGradeLevels(grades);
      _wizardStep = widget.initialStep ?? _wizardStep;
    } else {
      _loadExistingSchoolRecord();
    }
    if (widget.initialLookups == null) _loadLookups();
    if (_customSchoolId == null) {
      _loadDefaultGradeLevels();
    }
  }

  void _hydrateExistingSchool() {
    final school = widget.existingSchool;
    if (school == null) return;
    _customSchoolId = school.code == 'PENDING' ? null : school.code;
    _schoolName.text = school.name;
    _town.text = school.town == 'Not provided' ? '' : school.town;
    _administratorName.text = school.administratorName == 'Not provided'
        ? ''
        : school.administratorName;
    _administratorPhone.text = school.administratorPhone == 'Not provided'
        ? ''
        : school.administratorPhone;
    _administratorEmail.text = school.administratorEmail == 'Not provided'
        ? ''
        : school.administratorEmail;
    _completedSteps = _stepFromProgress(school.progress);
    _wizardStep = widget.initialStep ?? _completedSteps;
  }

  int _stepFromProgress(double progress) {
    final normalized = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    final step = (normalized * _steps.length).floor();
    return step.clamp(0, _steps.length - 1);
  }

  Future<void> _loadExistingSchoolRecord() async {
    final customSchoolId = _customSchoolId;
    if (customSchoolId == null || customSchoolId.isEmpty) return;
    setState(() {
      _loadingExistingRecord = true;
      _existingRecordError = null;
    });
    try {
      final record = await widget.repository.getSchoolOnboardingRecord(
        customSchoolId,
      );
      List<SchoolDocumentInfo>? savedDocuments;
      List<SchoolGradeLevelInfo>? savedGradeLevels;
      var gradeLevelsRequestFailed = false;
      try {
        savedDocuments = await widget.repository.getSchoolDocuments(
          customSchoolId,
        );
      } catch (_) {
        // The school record can still hydrate when document listing is
        // temporarily unavailable.
      }
      try {
        savedGradeLevels = await widget.repository.getSchoolGradeLevels(
          customSchoolId,
        );
      } catch (_) {
        gradeLevelsRequestFailed = true;
      }
      if (!mounted) return;
      final loadedDocuments = savedDocuments;
      final loadedGradeLevels = savedGradeLevels;
      final gradeLevelsCompleted = record.progress.completedSteps.any(
        (step) => step.toUpperCase() == 'GRADE_LEVELS',
      );
      final shouldLoadDefaults =
          !gradeLevelsRequestFailed &&
          !gradeLevelsCompleted &&
          (loadedGradeLevels == null || loadedGradeLevels.isEmpty);
      setState(() {
        _hydrateFromRecord(record);
        if (widget.initialStep != null) {
          _wizardStep = widget.initialStep!.clamp(0, _steps.length - 1);
        }
        if (loadedGradeLevels != null && loadedGradeLevels.isNotEmpty) {
          _hydrateGradeLevels(loadedGradeLevels);
          _gradeLevelsError = null;
        } else if (gradeLevelsRequestFailed) {
          _gradeLevelsError =
              'The saved class structure could not be loaded. Try again.';
        } else if (gradeLevelsCompleted) {
          _gradeLevelsError =
              'This school has completed class setup, but no saved grade levels were returned.';
        }
        if (loadedDocuments != null) {
          _hydrateDocuments(loadedDocuments);
        }
        _loadingExistingRecord = false;
        _existingRecordError = null;
      });
      if (shouldLoadDefaults) {
        await _loadDefaultGradeLevels();
      }
      if (_region.trim().isNotEmpty) {
        await _loadDistrictsForRegion(_region);
      }
      if (_wizardStep == 8) {
        await _loadReviewRecord();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingExistingRecord = false;
        _existingRecordError =
            'The saved school information could not be loaded. Please try again.';
      });
    }
  }

  Future<void> _loadDefaultGradeLevels() async {
    if (!mounted) return;
    setState(() {
      _loadingGradeLevels = true;
      _gradeLevelsError = null;
    });
    try {
      final result = await PlatformApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getDefaultGradeLevels();
      if (!mounted) return;
      setState(() {
        _lookups = _lookups.copyWith(
          gradeLevels: result.labels,
          gradeLevelIds: result.ids,
        );
        _loadingGradeLevels = false;
        _gradeLevelsError = result.labels.isEmpty
            ? 'No default grade levels were returned by the platform.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingGradeLevels = false;
        _gradeLevelsError =
            'Default grade levels could not be loaded. Try again.';
      });
    }
  }

  Future<void> _retryGradeLevels() async {
    if (_customSchoolId == null) {
      await _loadDefaultGradeLevels();
    } else {
      await _loadExistingSchoolRecord();
    }
  }

  Future<void> _loadReviewRecord() async {
    final customSchoolId = _customSchoolId;
    if (customSchoolId == null || customSchoolId.isEmpty) return;
    if (mounted) setState(() => _loadingExistingRecord = true);
    try {
      final record = await widget.repository.getSchoolReviewRecord(
        customSchoolId,
      );
      if (!mounted) return;
      setState(() {
        _hydrateFromRecord(record);
        _wizardStep = 8;
        _loadingExistingRecord = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingExistingRecord = false);
      final detail = error.toString().replaceFirst('ClientException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load school review. $detail')),
      );
    }
  }

  Future<void> _loadLookups({bool forceLive = false}) async {
    if (widget.initialLookups == null) {
      setState(() => _loadingLookups = true);
    }
    final lookups = widget.lookupLoader == null || forceLive
        ? await PlatformApiClient(
            accessToken: widget.accessToken,
            onRefreshAccessToken: widget.onRefreshAccessToken,
          ).getSchoolCreationLookups()
        : await widget.lookupLoader!.call();
    if (!mounted) return;
    setState(() {
      _lookups = lookups.copyWith(
        gradeLevels: _lookups.gradeLevels,
        gradeLevelIds: _lookups.gradeLevelIds,
      );
      // Keep values returned by the school record even when labels differ
      // slightly from the current lookup list.
      if (_gesRegistrationType.isNotEmpty) {
        _gesRegistrationType = _ensureValue(
          _gesRegistrationType,
          lookups.gesRegistrationTypes,
        );
      }
      if (_businessRegistrationType.isNotEmpty) {
        _businessRegistrationType = _ensureValue(
          _businessRegistrationType,
          lookups.businessRegistrationTypes,
        );
      }
      if (_socialWelfareStatus.isNotEmpty) {
        _socialWelfareStatus = _ensureValue(
          _socialWelfareStatus,
          lookups.socialWelfareStatuses,
        );
      }
      if (_academicYear.isNotEmpty) {
        _academicYear = _ensureValue(_academicYear, lookups.academicYears);
      }
      if (_academicTerm.isNotEmpty) {
        _academicTerm = _ensureValue(_academicTerm, lookups.termTypes);
      }
      _country = _ghanaCountryValue(lookups.countries);
      if (_socialMediaPlatform.isNotEmpty) {
        _socialMediaPlatform = _ensureValue(
          _socialMediaPlatform,
          lookups.socialMediaPlatforms,
        );
      }
      _loadingLookups = false;
      if (_region.trim().isEmpty && _savedRegionId != null) {
        _region = _labelForId(lookups.regionIds, _savedRegionId!) ?? _region;
      }
    });
    if (_region.trim().isNotEmpty) {
      await _loadDistrictsForRegion(_region);
    }
  }

  Future<void> _loadDistrictsForRegion(String region) async {
    final regionId = _lookups.regionIds[region];
    if (regionId == null) {
      if (!mounted) return;
      setState(() {
        _loadingDistricts = false;
        _district.clear();
      });
      return;
    }
    setState(() => _loadingDistricts = true);
    try {
      final districtLookups = await PlatformApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getDistrictLookups(regionId);
      if (!mounted || _region != region) return;
      setState(() {
        _lookups = _lookups.copyWith(
          districts: districtLookups.districts,
          districtIds: districtLookups.districtIds,
        );
        if (_district.text.trim().isEmpty && _savedDistrictId != null) {
          _district.text =
              _labelForId(districtLookups.districtIds, _savedDistrictId!) ?? '';
        } else if (_district.text.trim().isNotEmpty) {
          _district.text = _ensureValue(
            _district.text,
            districtLookups.districts,
          );
        }
        _loadingDistricts = false;
      });
    } catch (_) {
      if (!mounted || _region != region) return;
      setState(() {
        _loadingDistricts = false;
        _district.clear();
      });
    }
  }

  Future<void> _loadCitiesForSearch(String search) async {
    final query = search.trim();
    if (query.length < 2) return;
    setState(() => _loadingCities = true);
    final cityLookups = await PlatformApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    ).getCityLookups(query);
    if (!mounted) return;
    setState(() {
      _lookups = _lookups.copyWith(
        cities: cityLookups.cities,
        cityIds: cityLookups.cityIds,
      );
      _loadingCities = false;
    });
  }

  String _ensureValue(String current, List<String> values) {
    if (values.contains(current)) return current;
    return values.isEmpty ? current : values.first;
  }

  String? _labelForId(Map<String, int> ids, int id) {
    for (final entry in ids.entries) {
      if (entry.value == id) return entry.key;
    }
    return null;
  }

  @override
  void dispose() {
    for (final controller in [
      _schoolName,
      _motto,
      _yearFounded,
      _gesCode,
      _gesRegistrationDate,
      _registrationNumber,
      _businessRegistrationDate,
      _gemisCode,
      _taxIdNumber,
      _socialWelfareNumber,
      _socialWelfareOfficer,
      _socialWelfareDate,
      _houseNumber,
      _streetName,
      _address,
      _ghanaPostAddress,
      _district,
      _gpsLatitude,
      _gpsLongitude,
      _town,
      _phone,
      _phoneNetwork,
      _secondaryPhone,
      _secondaryPhoneNetwork,
      _officePhone,
      _email,
      _website,
      _socialMedia,
      _administratorName,
      _administratorPhone,
      _administratorEmail,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _openStep(int index) async {
    if (index > _completedSteps) return;
    if (index == 8) {
      await _loadReviewRecord();
      return;
    }
    setState(() => _wizardStep = index);
  }

  Widget _buildWizard() {
    if (_existingRecordError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.red,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not open this school',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _existingRecordError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loadExistingSchoolRecord,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final index = _wizardStep!;
    final gradeRevision = index == 6
        ? _gradeStreams.entries
              .map((entry) => '${entry.key}:${entry.value}')
              .join('|')
        : '';
    return _StepFormDialog(
      key: ValueKey(
        '$index:${_loadingExistingRecord ? 'loading' : 'ready'}:$gradeRevision',
      ),
      embedded: true,
      loadingExistingRecord: _loadingExistingRecord,
      singleStepEdit: widget.singleStepEdit,
      completedSteps: _completedSteps,
      index: index,
      step: _steps[index],
      schoolName: _schoolName,
      motto: _motto,
      yearFounded: _yearFounded,
      gesCode: _gesCode,
      gesRegistrationDate: _gesRegistrationDate,
      registrationNumber: _registrationNumber,
      businessRegistrationDate: _businessRegistrationDate,
      gemisCode: _gemisCode,
      taxIdNumber: _taxIdNumber,
      socialWelfareNumber: _socialWelfareNumber,
      socialWelfareOfficer: _socialWelfareOfficer,
      socialWelfareDate: _socialWelfareDate,
      houseNumber: _houseNumber,
      streetName: _streetName,
      address: _address,
      ghanaPostAddress: _ghanaPostAddress,
      district: _district,
      gpsLatitude: _gpsLatitude,
      gpsLongitude: _gpsLongitude,
      town: _town,
      phone: _phone,
      phoneNetwork: _phoneNetwork,
      secondaryPhone: _secondaryPhone,
      secondaryPhoneNetwork: _secondaryPhoneNetwork,
      officePhone: _officePhone,
      email: _email,
      website: _website,
      socialMedia: _socialMedia,
      administratorName: _administratorName,
      administratorPhone: _administratorPhone,
      administratorEmail: _administratorEmail,
      category: _schoolCategory,
      educationLevel: _educationLevel,
      gesRegistrationType: _gesRegistrationType,
      businessRegistrationType: _businessRegistrationType,
      socialWelfareStatus: _socialWelfareStatus,
      region: _region,
      country: _country,
      lookups: _lookups,
      loadingLookups: _loadingLookups,
      loadingGradeLevels: _loadingGradeLevels,
      gradeLevelsError: _gradeLevelsError,
      onReloadLookups: _retryGradeLevels,
      loadingDistricts: _loadingDistricts,
      loadingCities: _loadingCities,
      levels: _levels,
      onCategoryChanged: (value) => _schoolCategory = value,
      onEducationLevelChanged: (value) => _educationLevel = value,
      onGesRegistrationTypeChanged: (value) => _gesRegistrationType = value,
      onBusinessRegistrationTypeChanged: (value) =>
          _businessRegistrationType = value,
      onSocialWelfareStatusChanged: (value) => _socialWelfareStatus = value,
      onRegionChanged: (value) {
        _region = value;
        _savedRegionId = _lookups.regionIds[value];
        _savedDistrictId = null;
      },
      onRegionSelected: _loadDistrictsForRegion,
      onCountryChanged: (value) => _country = value,
      onCitySearch: _loadCitiesForSearch,
      socialMediaPlatform: _socialMediaPlatform,
      onSocialMediaPlatformChanged: (value) => _socialMediaPlatform = value,
      socialMediaLinks: _socialMediaLinks,
      onSocialMediaLinksChanged: (value) {
        _socialMediaLinks
          ..clear()
          ..addAll(value);
        for (final link in _socialMediaLinks) {
          if (link.handle.trim().isNotEmpty) {
            _socialMediaPlatform = link.platform;
            _socialMedia.text = link.handle;
            break;
          }
        }
      },
      onLevelsChanged: (value) {
        _levels
          ..clear()
          ..addAll(value);
      },
      gradeStreams: _gradeStreams,
      onGradeStreamsChanged: (value) {
        _gradeStreams
          ..clear()
          ..addAll(value);
      },
      academicYear: _academicYear,
      academicTerm: _academicTerm,
      termDescription: _termDescription,
      termStartDate: _termStartDate,
      termEndDate: _termEndDate,
      events: _events,
      documents: _documents,
      onCalendarChanged:
          ({
            required academicYear,
            required academicTerm,
            required description,
            required startDate,
            required endDate,
            required events,
          }) {
            _academicYear = academicYear;
            _academicTerm = academicTerm;
            _termDescription = description;
            _termStartDate = startDate;
            _termEndDate = endDate;
            _events
              ..clear()
              ..addAll(events);
          },
      onDocumentsChanged: (value) {
        _documents
          ..clear()
          ..addAll(value);
      },
      onViewDocument: _viewDocument,
      onEditRequested: (targetStep) {
        setState(() => _wizardStep = targetStep);
      },
      onStepSelected: _openStep,
      onCancel: widget.onBack,
      onPrevious: widget.singleStepEdit || index == 0
          ? null
          : () => setState(() => _wizardStep = index - 1),
      onSaved: () async {
        try {
          if (index == 8) {
            await _submitSchool();
            return;
          }
          final progress = await _saveCurrentStep(index);
          widget.onStepSaved?.call();
          if (widget.singleStepEdit) {
            await widget.onStepUpdated?.call();
            return;
          }
          setState(() {
            _applyOnboardingProgress(progress, fallbackNextStep: index + 1);
          });
          if (index == 7) await _loadReviewRecord();
          if (index == 5) await _loadExistingSchoolRecord();
        } catch (error) {
          if (!mounted) return;
          final detail = error.toString().replaceFirst('ClientException: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not save ${_steps[index].title}. $detail'),
            ),
          );
        }
      },
      onUnchanged: () async {
        if (widget.singleStepEdit) {
          widget.onBack();
          return;
        }
        if (index == 7) {
          await _loadReviewRecord();
        } else if (mounted) {
          setState(() => _wizardStep = (index + 1).clamp(0, 8));
        }
      },
    );
  }

  Future<SchoolOnboardingProgress> _saveCurrentStep(int index) {
    return widget.repository.saveSchoolOnboardingStep(
      stepIndex: index,
      draft: _onboardingDraft(),
    );
  }

  Future<void> _viewDocument(PlatformFile file) async {
    try {
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        await openDocumentBytes(
          bytes,
          _documentContentType(file.name),
          file.name,
        );
        return;
      }
      final documentId = file.identifier?.trim() ?? '';
      final schoolId = _customSchoolId?.trim() ?? '';
      if (documentId.isEmpty || schoolId.isEmpty) {
        throw StateError('The saved document reference is unavailable.');
      }
      prepareDocumentWindow();
      final url = await widget.repository.getSchoolDocumentDownloadUrl(
        customSchoolId: schoolId,
        documentId: documentId,
      );
      await openDocumentUrl(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document.')),
      );
    }
  }

  String _documentContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  Future<void> _submitSchool() async {
    if (_customSchoolId == null || _customSchoolId!.isEmpty) {
      final progress = await _saveCurrentStep(0);
      widget.onStepSaved?.call();
      _applyOnboardingProgress(progress, fallbackNextStep: 1);
    }
    if (_customSchoolId != null && _customSchoolId!.isNotEmpty) {
      final progress = await _saveCurrentStep(8);
      widget.onStepSaved?.call();
      _applyOnboardingProgress(progress, fallbackNextStep: 8);
      final submitted = await widget.repository.finishSchoolSetup(
        _customSchoolId!,
      );
      widget.onStepSaved?.call();
      _applyOnboardingProgress(submitted.progress, fallbackNextStep: 8);
      if (!mounted) return;
      setState(() => _completedSteps = 9);
      await _showSubmissionSuccess(submitted);
    }
  }

  Future<void> _showSubmissionSuccess(SchoolOnboardingRecord submitted) async {
    final schoolId =
        _text(submitted.data, ['customSchoolId', 'schoolCode', 'code']) ??
        submitted.progress.customSchoolId ??
        _customSchoolId ??
        '';
    final schoolName =
        _text(submitted.data, ['schoolName', 'name']) ??
        _schoolName.text.trim();
    final status =
        _text(submitted.data, ['registrationStatus', 'status']) ??
        submitted.progress.registrationStatus;
    final action = await showDialog<_SubmissionAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.green,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'School submitted successfully',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '$schoolName has been submitted for approval.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _SubmissionDetail(label: 'School ID', value: schoolId),
                    const SizedBox(height: 9),
                    _SubmissionDetail(
                      label: 'Status',
                      value: _submissionStatusLabel(status),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, _SubmissionAction.schools),
                      child: const Text('Back to Schools'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, _SubmissionAction.viewSchool),
                      child: const Text('View School'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == _SubmissionAction.viewSchool && schoolId.isNotEmpty) {
      widget.onViewCreated?.call(schoolId);
    } else {
      widget.onCreated();
    }
  }

  String _submissionStatusLabel(String status) => status
      .trim()
      .toLowerCase()
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  void _applyOnboardingProgress(
    SchoolOnboardingProgress progress, {
    required int fallbackNextStep,
  }) {
    _customSchoolId = progress.customSchoolId ?? _customSchoolId;
    _completedSteps = progress.completedStepCount.clamp(0, _steps.length);
    final backendStep = _wizardIndexForBackendStep(progress.currentStep);
    _wizardStep = backendStep ?? fallbackNextStep.clamp(0, _steps.length - 1);
  }

  int? _wizardIndexForBackendStep(String currentStep) {
    const stepIndexes = {
      'BASIC_INFO': 0,
      'REGISTRATION_DETAILS': 1,
      'SOCIAL_WELFARE_COMPLIANCE': 2,
      'ADDRESS': 3,
      'CONTACT_INFO': 4,
      'DOCUMENTS': 5,
      'GRADE_LEVELS': 6,
      'TERM_CALENDAR': 7,
      'REVIEW': 8,
    };
    final normalized = currentStep.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    return stepIndexes[normalized];
  }

  void _hydrateFromRecord(SchoolOnboardingRecord record) {
    final data = record.data;
    _customSchoolId =
        _text(data, ['customSchoolId', 'schoolCode', 'code']) ??
        _customSchoolId;
    _schoolName.text = _text(data, ['schoolName', 'name']) ?? _schoolName.text;
    _yearFounded.text = _text(data, ['yearFounded']) ?? _yearFounded.text;
    _motto.text = _text(data, ['motto']) ?? _motto.text;
    _schoolCategory = _nameOf(data['category']) ?? _schoolCategory;
    _educationLevel =
        _nameOf(data['educationLevel']) ??
        _text(data, ['educationLevelName']) ??
        _educationLevel;

    final registration = _mapOf(
      data['registrationDetails'] ?? data['registrationDetail'],
    );
    _gesCode.text =
        _text(registration, [
          'gesRegistrationNumber',
          'registrationNumberGes',
          'registrationNumber',
          'gesNumber',
        ]) ??
        _text(data, [
          'gesRegistrationNumber',
          'registrationNumberGes',
          'registrationNumber',
        ]) ??
        _gesCode.text;
    _gesRegistrationType =
        _nameOf(
          registration['gesRegistrationType'] ??
              registration['registrationType'],
        ) ??
        _gesRegistrationType;
    _registrationNumber.text =
        _text(registration, ['businessRegistrationNumber']) ??
        _registrationNumber.text;
    _businessRegistrationType =
        _nameOf(registration['businessRegistrationType']) ??
        _businessRegistrationType;
    _gesRegistrationDate.text = _dateText(
      registration['gesRegistrationDate'],
      fallback: _gesRegistrationDate.text,
    );
    _businessRegistrationDate.text = _dateText(
      registration['businessRegistrationDate'],
      fallback: _businessRegistrationDate.text,
    );
    _gemisCode.text =
        _text(registration, ['gemisCode', 'gemisNumber', 'gemis']) ??
        _text(data, ['gemisCode', 'gemisNumber', 'gemis']) ??
        _gemisCode.text;
    _taxIdNumber.text =
        _text(registration, ['taxIdNumber', 'taxId', 'tinNumber', 'tin']) ??
        _text(data, ['taxIdNumber', 'taxId', 'tinNumber', 'tin']) ??
        _taxIdNumber.text;

    final welfare = _mapOf(data['socialWelfareCompliance']);
    _socialWelfareNumber.text =
        _text(welfare, ['approvalNumber']) ?? _socialWelfareNumber.text;
    _socialWelfareDate.text = _dateText(
      welfare['approvalDate'],
      fallback: _socialWelfareDate.text,
    );
    _socialWelfareOfficer.text =
        _text(welfare, ['approvalOfficerName', 'approvalOfficer']) ??
        _socialWelfareOfficer.text;
    _socialWelfareStatus =
        _nameOf(welfare['complianceStatus']) ?? _socialWelfareStatus;

    final address = _mapOf(data['address']);
    _houseNumber.text = _text(address, ['houseNumber']) ?? _houseNumber.text;
    _streetName.text = _text(address, ['streetName']) ?? _streetName.text;
    _address.text =
        _text(address, ['additionalDirection', 'additionalDirections']) ??
        _address.text;
    final streetAddress = _text(address, ['streetAddress']);
    if (streetAddress != null && streetAddress.isNotEmpty) {
      final parts = streetAddress
          .split(',')
          .map((part) => part.trim())
          .toList();
      if (parts.isNotEmpty && _houseNumber.text.trim().isEmpty) {
        _houseNumber.text = parts.first;
      }
      if (parts.length > 1 && _streetName.text.trim().isEmpty) {
        _streetName.text = parts[1];
      }
      if (parts.length > 2 && _address.text.trim().isEmpty) {
        _address.text = parts.skip(2).join(', ');
      }
      if (parts.length == 1 && _streetName.text.trim().isEmpty) {
        _streetName.text = parts.first;
      }
    }
    _ghanaPostAddress.text =
        _text(address, ['digitalAddress', 'ghanaPostAddress']) ??
        _ghanaPostAddress.text;
    _town.text =
        _nameOf(address['city']) ?? _text(address, ['cityName']) ?? _town.text;
    final district = _mapOf(address['district']);
    final region = _mapOf(address['region']);
    _savedDistrictId =
        _intValue(district['id']) ?? _intValue(address['districtId']);
    _savedRegionId = _intValue(region['id']) ?? _intValue(address['regionId']);
    _district.text =
        _nameOf(address['district']) ??
        _text(address, ['districtName']) ??
        (_savedDistrictId == null
            ? _district.text
            : _labelForId(_lookups.districtIds, _savedDistrictId!) ?? '');
    _region =
        _nameOf(address['region']) ??
        _text(address, ['regionName']) ??
        (_savedRegionId == null
            ? _region
            : _labelForId(_lookups.regionIds, _savedRegionId!) ?? '');
    _country = _nameOf(address['country']) ?? _country;
    final gps = _mapOf(address['gpsLocation']);
    final latitude = address['latitude'] ?? gps['latitude'];
    final longitude = address['longitude'] ?? gps['longitude'];
    if (latitude != null) _gpsLatitude.text = latitude.toString();
    if (longitude != null) _gpsLongitude.text = longitude.toString();

    final contact = _mapOf(data['contactInfo']);
    final personalPhones = _listOf(contact['personalPhoneNumbers']);
    for (final phoneValue in personalPhones) {
      final phone = _mapOf(phoneValue);
      final number = _text(phone, ['phoneNumber', 'number']);
      if (number == null || number.isEmpty) continue;
      final type = _text(phone, ['type']);
      final isPrimary = phone['isPrimary'] == true;
      if (isPrimary || _phone.text.trim().isEmpty) {
        _phone.text = number;
        if (type != null) _phoneNetwork.text = type;
      } else if (_secondaryPhone.text.trim().isEmpty) {
        _secondaryPhone.text = number;
        if (type != null) _secondaryPhoneNetwork.text = type;
      }
    }
    final workPhones = _listOf(contact['workPhoneNumbers']);
    if (workPhones.isNotEmpty) {
      _officePhone.text =
          _text(_mapOf(workPhones.first), ['phoneNumber', 'number']) ??
          _officePhone.text;
    }
    final emails = _listOf(contact['emails'])
        .map((email) => email.toString())
        .where((email) => email.trim().isNotEmpty)
        .toList();
    if (emails.isNotEmpty) _email.text = emails.join(', ');
    _website.text = _text(contact, ['website']) ?? _website.text;
    final socialMedia = _listOf(contact['socialMedia']);
    _socialMediaLinks
      ..clear()
      ..addAll(
        socialMedia
            .map((item) {
              final media = _mapOf(item);
              final platform = _mapOf(media['platform']);
              return SocialMediaContact(
                platform: _text(platform, ['name']) ?? _socialMediaPlatform,
                platformId: _intValue(platform['id']),
                handle: _text(media, ['handle', 'url']) ?? '',
              );
            })
            .where((link) => link.handle.trim().isNotEmpty),
      );
    if (_socialMediaLinks.isNotEmpty) {
      _socialMediaPlatform = _socialMediaLinks.first.platform;
      _socialMedia.text = _socialMediaLinks.first.handle;
    }

    final termCandidate = _firstMapOf(data, const [
      'currentAcademicTerm',
      'academicTerm',
      'termCalendar',
      'termDetails',
      'currentTerm',
    ]);
    final term =
        termCandidate.isNotEmpty ||
            (data['academicYear'] == null &&
                data['termType'] == null &&
                data['events'] == null)
        ? termCandidate
        : data;
    _academicYear =
        _nameOf(term['academicYear']) ??
        _text(term, ['academicYearName', 'academicYearLabel', 'yearName']) ??
        _text(_mapOf(term['academicYear']), ['year']) ??
        _academicYear;
    _academicTerm =
        _nameOf(term['termType']) ??
        _text(term, ['termTypeName', 'academicTermName', 'termName']) ??
        _academicTerm;
    _termDescription = _text(term, ['description']) ?? _termDescription;
    _termStartDate = _parseDateValue(term['startDate']) ?? _termStartDate;
    _termEndDate = _parseDateValue(term['endDate']) ?? _termEndDate;
    final eventItems = _listOf(term['events']).isNotEmpty
        ? _listOf(term['events'])
        : _listOf(data['events']);
    _events
      ..clear()
      ..addAll(
        eventItems.map((item) {
          final event = _mapOf(item);
          final eventName = _text(event, ['name', 'eventName', 'title']) ?? '';
          final eventTypeMap = _mapOf(event['eventType']);
          final eventTypeId =
              _intValue(eventTypeMap['id']) ?? _intValue(event['eventTypeId']);
          final rawType =
              (eventTypeId == null
                  ? null
                  : _labelForId(_lookups.eventTypeIds, eventTypeId)) ??
              _eventTypeLabel(event['eventType']) ??
              _text(event, ['eventTypeName', 'type']);
          final matchedType = _matchingLookupLabel(
            rawType,
            _lookups.eventTypes,
          );
          final matchedName = _matchingLookupLabel(
            eventName,
            _lookups.eventTypes,
          );
          final type = matchedType ?? matchedName ?? 'Other';
          final otherName = type == 'Other' ? eventName : '';
          final eventDate = event['eventDate'] ?? event['date'];
          return _CalendarEvent(
            type: type,
            otherName: otherName,
            description: _text(event, ['description']) ?? '',
            startDate: _parseDateValue(event['startDate'] ?? eventDate),
            endDate: _parseDateValue(event['endDate'] ?? eventDate),
            startTime: _parseTimeValue(
              event['startTime'],
              fallback: '00:00:00',
            ),
            endTime: _parseTimeValue(event['endTime'], fallback: '23:59:59'),
            isSchoolDay: event['isSchoolDay'] == true,
          );
        }),
      );

    _documents
      ..clear()
      ..addEntries(
        _listOf(data['documents']).map((item) {
          final document = _mapOf(item);
          final type = _text(document, ['documentType']) ?? 'Document';
          final label = _documentLabel(type);
          return MapEntry(
            label,
            PlatformFile(
              name: _text(document, ['fileName']) ?? '$label uploaded',
              size: _intValue(document['fileSize']) ?? 0,
              identifier: _text(document, ['documentId', 'id']),
            ),
          );
        }),
      );
    _applyOnboardingProgress(
      record.progress,
      fallbackNextStep: _wizardStep ?? _completedSteps,
    );
  }

  void _hydrateGradeLevels(List<SchoolGradeLevelInfo> gradeLevels) {
    _gradeStreams
      ..clear()
      ..addEntries(
        gradeLevels
            .where((grade) => grade.status.toUpperCase() == 'ACTIVE')
            .map(
              (grade) => MapEntry(
                grade.gradeLevelName,
                grade.numberOfStreams.clamp(1, 10),
              ),
            ),
      );
    _savedGradeLevelIds
      ..clear()
      ..addEntries(
        gradeLevels.map(
          (grade) => MapEntry(grade.gradeLevelName, grade.gradeLevelId),
        ),
      );
    _lookups = _lookups.copyWith(
      gradeLevels: _savedGradeLevelIds.keys.toList(),
      gradeLevelIds: Map.unmodifiable(_savedGradeLevelIds),
    );
    _levels
      ..clear()
      ..addAll(_gradeStreams.keys);
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _firstMapOf(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final map = _mapOf(source[key]);
      if (map.isNotEmpty) return map;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _listOf(dynamic value) => value is List ? value : const [];

  String? _text(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  String? _nameOf(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    final map = _mapOf(value);
    return _text(map, ['name', 'level', 'year', 'status']);
  }

  String? _eventTypeLabel(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    final map = _mapOf(value);
    return _text(map, [
      'name',
      'eventTypeName',
      'type',
      'label',
      'description',
    ]);
  }

  String? _matchingLookupLabel(String? rawValue, List<String> options) {
    final normalized = _normalizeLookupValue(rawValue);
    if (normalized.isEmpty) return null;
    for (final option in options) {
      if (_normalizeLookupValue(option) == normalized) return option;
    }
    return null;
  }

  String _normalizeLookupValue(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _parseDate(String value) {
    final clean = value.split('T').first.trim();
    final parts = clean.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  DateTime? _parseDateValue(dynamic value) {
    if (value is List && value.length >= 3) {
      final year = _intValue(value[0]);
      final month = _intValue(value[1]);
      final day = _intValue(value[2]);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    if (value is Map) {
      final map = _mapOf(value);
      final year = _intValue(map['year']);
      final month = _intValue(map['month']);
      final day = _intValue(map['day']);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return _parseDate(value?.toString() ?? '');
  }

  String _parseTimeValue(dynamic value, {required String fallback}) {
    int? hour;
    int? minute;
    int? second;
    if (value is List && value.length >= 2) {
      hour = _intValue(value[0]);
      minute = _intValue(value[1]);
      second = value.length > 2 ? _intValue(value[2]) : 0;
    } else if (value is Map) {
      final map = _mapOf(value);
      hour = _intValue(map['hour']);
      minute = _intValue(map['minute']);
      second = _intValue(map['second']) ?? 0;
    } else if (value != null) {
      final raw = value.toString().trim();
      final arrayMatch = RegExp(
        r'^\[\s*(\d{1,2})\s*,\s*(\d{1,2})(?:\s*,\s*(\d{1,2}))?\s*\]$',
      ).firstMatch(raw);
      if (arrayMatch != null) {
        hour = int.tryParse(arrayMatch.group(1)!);
        minute = int.tryParse(arrayMatch.group(2)!);
        second = int.tryParse(arrayMatch.group(3) ?? '0');
      } else {
        final parts = raw.split(':');
        if (parts.length >= 2) {
          hour = int.tryParse(parts[0]);
          minute = int.tryParse(parts[1]);
          second = parts.length > 2 ? int.tryParse(parts[2]) : 0;
        }
      }
    }
    if (hour == null || minute == null) return fallback;
    return '${hour.clamp(0, 23).toString().padLeft(2, '0')}:'
        '${minute.clamp(0, 59).toString().padLeft(2, '0')}:'
        '${(second ?? 0).clamp(0, 59).toString().padLeft(2, '0')}';
  }

  String _dateText(dynamic value, {required String fallback}) {
    final date = _parseDateValue(value);
    if (date == null) return fallback;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _documentLabel(String type) {
    final normalized = type.toUpperCase();
    if (normalized.contains('BUSINESS')) {
      return 'Business registration certificate';
    }
    if (normalized.contains('GES') || normalized.contains('REGISTRATION')) {
      return 'GES registration document';
    }
    if (normalized.contains('SOCIAL')) return 'Social welfare approval';
    if (normalized.contains('CREST') || normalized.contains('LOGO')) {
      return 'School crest or logo';
    }
    if (normalized.contains('PHOTO')) return 'School front photo';
    return type;
  }

  void _hydrateDocuments(List<SchoolDocumentInfo> documents) {
    _documents
      ..clear()
      ..addEntries(
        documents.map((document) {
          final label = _documentLabel(document.documentType);
          return MapEntry(
            label,
            PlatformFile(
              name: document.fileName.isEmpty
                  ? '$label uploaded'
                  : document.fileName,
              size: document.fileSize,
              identifier: document.documentId,
            ),
          );
        }),
      );
  }

  SchoolOnboardingDraft _onboardingDraft() {
    return SchoolOnboardingDraft(
      customSchoolId: _customSchoolId,
      schoolName: _schoolName.text.trim().isEmpty
          ? 'New School'
          : _schoolName.text.trim(),
      schoolType: _schoolCategory,
      schoolTypeId: _lookups.schoolCategoryIds[_schoolCategory],
      educationLevel: _educationLevel,
      educationLevelId: _lookups.educationLevelIds[_educationLevel],
      yearFounded: int.tryParse(_yearFounded.text.trim()) ?? 0,
      motto: _motto.text.trim(),
      gesRegistrationNumber: _gesCode.text.trim(),
      gesRegistrationType: _gesRegistrationType,
      gesRegistrationTypeId:
          _lookups.gesRegistrationTypeIds[_gesRegistrationType],
      gesRegistrationDate: _gesRegistrationDate.text.trim(),
      businessRegistrationNumber: _registrationNumber.text.trim(),
      businessRegistrationType: _businessRegistrationType,
      businessRegistrationTypeId:
          _lookups.businessRegistrationTypeIds[_businessRegistrationType],
      businessRegistrationDate: _businessRegistrationDate.text.trim(),
      gemisCode: _gemisCode.text.trim(),
      taxIdNumber: _taxIdNumber.text.trim(),
      socialWelfareNumber: _socialWelfareNumber.text.trim(),
      socialWelfareOfficer: _socialWelfareOfficer.text.trim(),
      socialWelfareDate: _socialWelfareDate.text.trim(),
      socialWelfareStatus: _socialWelfareStatus,
      socialWelfareStatusId:
          _lookups.socialWelfareStatusIds[_socialWelfareStatus],
      houseNumber: _houseNumber.text.trim(),
      streetName: _streetName.text.trim(),
      additionalDirection: _address.text.trim(),
      ghanaPostAddress: _ghanaPostAddress.text.trim(),
      town: _town.text.trim(),
      cityId: _lookups.cityIds[_town.text.trim()],
      district: _district.text.trim(),
      districtId: _lookups.districtIds[_district.text.trim()],
      region: _region,
      regionId: _lookups.regionIds[_region],
      country: _country,
      countryId: _lookups.countryIds[_country],
      gpsLatitude: double.tryParse(_gpsLatitude.text.trim()),
      gpsLongitude: double.tryParse(_gpsLongitude.text.trim()),
      phone: _phone.text.trim(),
      phoneNetwork: _phoneNetwork.text.trim(),
      secondaryPhone: _secondaryPhone.text.trim(),
      secondaryPhoneNetwork: _secondaryPhoneNetwork.text.trim(),
      officePhone: _officePhone.text.trim(),
      email: _email.text.trim(),
      website: _website.text.trim(),
      socialMedia: _socialMedia.text.trim(),
      socialMediaPlatformId:
          _lookups.socialMediaPlatformIds[_socialMediaPlatform],
      socialMediaLinks: _socialMediaLinks
          .where((link) => link.handle.trim().isNotEmpty)
          .map(
            (link) => SocialMediaContact(
              platform: link.platform,
              platformId: _lookups.socialMediaPlatformIds[link.platform],
              handle: link.handle.trim(),
            ),
          )
          .toList(),
      administratorName: _administratorName.text.trim(),
      administratorPhone: _administratorPhone.text.trim(),
      administratorEmail: _administratorEmail.text.trim(),
      levels: _levels.toList(),
      gradeStreams: Map.unmodifiable(_gradeStreams),
      gradeLevelIds: _lookups.gradeLevelIds,
      academicYear: _academicYear,
      academicYearId: _lookups.academicYearIds[_academicYear],
      academicTerm: _academicTerm,
      academicTermId: _lookups.termTypeIds[_academicTerm],
      termDescription: _termDescription,
      termStartDate: _termStartDate,
      termEndDate: _termEndDate,
      events: _events
          .map(
            (event) => SchoolCalendarEventDraft(
              type: event.type,
              otherName: event.otherName,
              description: event.description,
              startDate: event.startDate,
              endDate: event.endDate,
              startTime: event.startTime,
              endTime: event.endTime,
              isSchoolDay: event.isSchoolDay,
            ),
          )
          .toList(),
      eventTypeIds: _lookups.eventTypeIds,
      documents: _documents.map(
        (label, file) => MapEntry(
          label,
          SchoolDocumentDraft(
            name: file.name,
            size: file.size,
            bytes: file.bytes,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildWizard();
  }
}

class _WizardRail extends StatelessWidget {
  const _WizardRail({
    required this.steps,
    required this.current,
    required this.completed,
    required this.onSelected,
  });

  final List<_SetupStep> steps;
  final int current;
  final int completed;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New School',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '9 steps to complete',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final done = index < completed;
                final active = index == current;
                final enabled = index <= completed;
                return InkWell(
                  onTap: enabled ? () => onSelected(index) : null,
                  child: Container(
                    color: active
                        ? AppColors.green.withValues(alpha: .10)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? AppColors.green : Colors.white,
                            border: Border.all(
                              width: 2,
                              color: done || active
                                  ? AppColors.green
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            done ? '✓' : '${index + 1}',
                            style: TextStyle(
                              color: done
                                  ? Colors.white
                                  : active
                                  ? AppColors.green
                                  : AppColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                steps[index].title,
                                style: TextStyle(
                                  color: active
                                      ? AppColors.green
                                      : done
                                      ? const Color(0xFF111827)
                                      : AppColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                done
                                    ? 'Complete'
                                    : active
                                    ? 'In progress'
                                    : 'Not started',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardMobileProgress extends StatelessWidget {
  const _WizardMobileProgress({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${current + 1} of $total',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: (current + 1) / total,
          minHeight: 5,
          borderRadius: BorderRadius.circular(8),
          color: AppColors.green,
          backgroundColor: AppColors.border,
        ),
      ],
    ),
  );
}

class _WizardSection extends StatelessWidget {
  const _WizardSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.index,
    required this.total,
    required this.canSubmit,
    required this.onBack,
    required this.onCancel,
    required this.onContinue,
    this.primaryLabel,
    this.saving = false,
  });

  final int index;
  final int total;
  final bool canSubmit;
  final VoidCallback? onBack;
  final VoidCallback? onCancel;
  final Future<void> Function() onContinue;
  final String? primaryLabel;
  final bool saving;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _wizardContentWidth),
        child: Row(
          children: [
            if (primaryLabel == null)
              Text(
                'Step ${index + 1} of $total',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (onBack != null) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back'),
              ),
            ],
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSubmit && !saving ? onContinue : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (saving) ...[
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    saving
                        ? 'Saving...'
                        : primaryLabel ??
                              (index == total - 1 ? 'Submit' : 'Continue  →'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const double _wizardContentWidth = 820;

class _StepFormDialog extends StatefulWidget {
  const _StepFormDialog({
    super.key,
    this.embedded = false,
    this.loadingExistingRecord = false,
    this.singleStepEdit = false,
    this.completedSteps = 0,
    required this.index,
    required this.step,
    required this.schoolName,
    required this.motto,
    required this.yearFounded,
    required this.gesCode,
    required this.gesRegistrationDate,
    required this.registrationNumber,
    required this.businessRegistrationDate,
    required this.gemisCode,
    required this.taxIdNumber,
    required this.socialWelfareNumber,
    required this.socialWelfareOfficer,
    required this.socialWelfareDate,
    required this.houseNumber,
    required this.streetName,
    required this.address,
    required this.ghanaPostAddress,
    required this.district,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.town,
    required this.phone,
    required this.phoneNetwork,
    required this.secondaryPhone,
    required this.secondaryPhoneNetwork,
    required this.officePhone,
    required this.email,
    required this.website,
    required this.socialMedia,
    required this.administratorName,
    required this.administratorPhone,
    required this.administratorEmail,
    required this.category,
    required this.educationLevel,
    required this.gesRegistrationType,
    required this.businessRegistrationType,
    required this.socialWelfareStatus,
    required this.region,
    required this.country,
    required this.lookups,
    required this.loadingLookups,
    required this.loadingGradeLevels,
    required this.gradeLevelsError,
    required this.onReloadLookups,
    required this.loadingDistricts,
    required this.loadingCities,
    required this.levels,
    required this.onCategoryChanged,
    required this.onEducationLevelChanged,
    required this.onGesRegistrationTypeChanged,
    required this.onBusinessRegistrationTypeChanged,
    required this.onSocialWelfareStatusChanged,
    required this.onRegionChanged,
    required this.onRegionSelected,
    required this.onCountryChanged,
    required this.onCitySearch,
    required this.socialMediaPlatform,
    required this.onSocialMediaPlatformChanged,
    required this.socialMediaLinks,
    required this.onSocialMediaLinksChanged,
    required this.onLevelsChanged,
    required this.gradeStreams,
    required this.onGradeStreamsChanged,
    required this.academicYear,
    required this.academicTerm,
    required this.termDescription,
    required this.termStartDate,
    required this.termEndDate,
    required this.events,
    required this.documents,
    required this.onCalendarChanged,
    required this.onDocumentsChanged,
    required this.onViewDocument,
    required this.onEditRequested,
    this.onStepSelected,
    this.onSaved,
    this.onUnchanged,
    this.onCancel,
    this.onPrevious,
  });

  final bool embedded;
  final bool loadingExistingRecord;
  final bool singleStepEdit;
  final int completedSteps;
  final int index;
  final _SetupStep step;
  final TextEditingController schoolName;
  final TextEditingController motto;
  final TextEditingController yearFounded;
  final TextEditingController gesCode;
  final TextEditingController gesRegistrationDate;
  final TextEditingController registrationNumber;
  final TextEditingController businessRegistrationDate;
  final TextEditingController gemisCode;
  final TextEditingController taxIdNumber;
  final TextEditingController socialWelfareNumber;
  final TextEditingController socialWelfareOfficer;
  final TextEditingController socialWelfareDate;
  final TextEditingController houseNumber;
  final TextEditingController streetName;
  final TextEditingController address;
  final TextEditingController ghanaPostAddress;
  final TextEditingController district;
  final TextEditingController gpsLatitude;
  final TextEditingController gpsLongitude;
  final TextEditingController town;
  final TextEditingController phone;
  final TextEditingController phoneNetwork;
  final TextEditingController secondaryPhone;
  final TextEditingController secondaryPhoneNetwork;
  final TextEditingController officePhone;
  final TextEditingController email;
  final TextEditingController website;
  final TextEditingController socialMedia;
  final TextEditingController administratorName;
  final TextEditingController administratorPhone;
  final TextEditingController administratorEmail;
  final String category;
  final String educationLevel;
  final String gesRegistrationType;
  final String businessRegistrationType;
  final String socialWelfareStatus;
  final String region;
  final String country;
  final SchoolCreationLookups lookups;
  final bool loadingLookups;
  final bool loadingGradeLevels;
  final String? gradeLevelsError;
  final Future<void> Function() onReloadLookups;
  final bool loadingDistricts;
  final bool loadingCities;
  final Set<String> levels;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onEducationLevelChanged;
  final ValueChanged<String> onGesRegistrationTypeChanged;
  final ValueChanged<String> onBusinessRegistrationTypeChanged;
  final ValueChanged<String> onSocialWelfareStatusChanged;
  final ValueChanged<String> onRegionChanged;
  final Future<void> Function(String) onRegionSelected;
  final ValueChanged<String> onCountryChanged;
  final Future<void> Function(String) onCitySearch;
  final String socialMediaPlatform;
  final ValueChanged<String> onSocialMediaPlatformChanged;
  final List<SocialMediaContact> socialMediaLinks;
  final ValueChanged<List<SocialMediaContact>> onSocialMediaLinksChanged;
  final ValueChanged<Set<String>> onLevelsChanged;
  final Map<String, int> gradeStreams;
  final ValueChanged<Map<String, int>> onGradeStreamsChanged;
  final String academicYear;
  final String academicTerm;
  final String termDescription;
  final DateTime? termStartDate;
  final DateTime? termEndDate;
  final List<_CalendarEvent> events;
  final Map<String, PlatformFile> documents;
  final _CalendarChanged onCalendarChanged;
  final ValueChanged<Map<String, PlatformFile>> onDocumentsChanged;
  final Future<void> Function(PlatformFile) onViewDocument;
  final ValueChanged<int> onEditRequested;
  final ValueChanged<int>? onStepSelected;
  final Future<void> Function()? onSaved;
  final Future<void> Function()? onUnchanged;
  final VoidCallback? onCancel;
  final VoidCallback? onPrevious;

  @override
  State<_StepFormDialog> createState() => _StepFormDialogState();
}

class _StepFormDialogState extends State<_StepFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.category;
  late String _educationLevel = widget.educationLevel;
  late String _gesRegistrationType = widget.gesRegistrationType;
  late String _businessRegistrationType = widget.businessRegistrationType;
  late String _socialWelfareStatus = widget.socialWelfareStatus;
  late String _region = widget.region;
  late String _country = _ghanaCountryValue(widget.lookups.countries);
  late String _socialMediaPlatform = widget.socialMediaPlatform;
  late final Set<String> _levels = {...widget.levels};
  late final Map<String, int> _gradeStreams = {...widget.gradeStreams};
  late String _academicYear = widget.academicYear;
  late String _academicTerm = widget.academicTerm;
  late final TextEditingController _termDescription = TextEditingController(
    text: widget.termDescription,
  );
  late DateTime? _termStartDate = widget.termStartDate;
  late DateTime? _termEndDate = widget.termEndDate;
  late final List<_CalendarEvent> _events = widget.events
      .map((event) => event.copy())
      .toList();
  late final Map<String, PlatformFile> _documents = {...widget.documents};
  late final List<_SocialMediaFormRow> _socialMediaRows;
  bool _reviewConfirmed = false;
  bool _saving = false;
  String? _validationMessage;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    _socialMediaRows = widget.socialMediaLinks.isNotEmpty
        ? widget.socialMediaLinks
              .map(
                (link) => _SocialMediaFormRow(
                  platform: link.platform,
                  handle: link.handle,
                ),
              )
              .toList()
        : [
            _SocialMediaFormRow(
              platform: _defaultSocialMediaPlatform(),
              handle: widget.socialMedia.text,
            ),
          ];
    _initialSignature = _stepSignature();
  }

  @override
  void dispose() {
    _termDescription.dispose();
    for (final row in _socialMediaRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.index < widget.completedSteps &&
        widget.index < 8 &&
        _stepSignature() == _initialSignature) {
      await widget.onUnchanged?.call();
      return;
    }
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _validationMessage =
            'Check the highlighted required fields before continuing.';
      });
      return;
    }
    if (widget.index == 6 && widget.lookups.gradeLevels.isEmpty) {
      setState(() {
        _validationMessage =
            'Grade levels could not be loaded from the school platform. Retry before continuing.';
      });
      return;
    }
    if (widget.index == 6 && _gradeStreams.isEmpty) {
      setState(() {
        _validationMessage = 'Select at least one grade level.';
      });
      return;
    }
    if (widget.index == 6 &&
        _gradeStreams.keys.any(
          (grade) => widget.lookups.gradeLevelIds[grade] == null,
        )) {
      setState(() {
        _validationMessage =
            'One or more selected grades no longer match the platform records. Reload the grade levels and try again.';
      });
      return;
    }
    if (widget.index == 7) {
      if (widget.lookups.academicYearIds[_academicYear] == null ||
          widget.lookups.termTypeIds[_academicTerm] == null) {
        setState(() {
          _validationMessage =
              'Select an academic year and term supplied by the school platform.';
        });
        return;
      }
      if (_events.any(
        (event) => widget.lookups.eventTypeIds[event.type] == null,
      )) {
        setState(() {
          _validationMessage =
              'Every event must use an event type supplied by the school platform.';
        });
        return;
      }
      if (_termStartDate == null || _termEndDate == null) {
        setState(() {
          _validationMessage = 'Select both the term start and end dates.';
        });
        return;
      }
      if (_termEndDate!.isBefore(_termStartDate!)) {
        setState(() {
          _validationMessage =
              'The term end date must be after the start date.';
        });
        return;
      }
      for (var index = 0; index < _events.length; index++) {
        final event = _events[index];
        final missing = <String>[
          if (event.type.trim().isEmpty) 'event type',
          if (event.type == 'Other' && event.otherName.trim().isEmpty)
            'event name',
          if (event.startDate == null) 'start date',
          if (event.endDate == null) 'end date',
        ];
        if (missing.isEmpty) continue;
        setState(() {
          _validationMessage =
              'Event ${index + 1} needs: ${missing.join(', ')}.';
        });
        return;
      }
    }
    if (widget.index == 5) {
      final missingDocuments = _requiredSchoolDocumentLabels
          .where((label) => !_documents.containsKey(label))
          .toList();
      if (missingDocuments.isNotEmpty) {
        setState(() {
          _validationMessage =
              'Upload the required documents before continuing: ${missingDocuments.join(', ')}.';
        });
        return;
      }
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      widget.onCategoryChanged(_category);
      widget.onEducationLevelChanged(_educationLevel);
      widget.onGesRegistrationTypeChanged(_gesRegistrationType);
      widget.onBusinessRegistrationTypeChanged(_businessRegistrationType);
      widget.onSocialWelfareStatusChanged(_socialWelfareStatus);
      widget.onRegionChanged(_region);
      _country = _ghanaCountryValue(widget.lookups.countries);
      widget.onCountryChanged(_country);
      final socialLinks = _socialMediaRows
          .where((row) => row.handle.text.trim().isNotEmpty)
          .map(
            (row) => SocialMediaContact(
              platform: row.platform,
              platformId: widget.lookups.socialMediaPlatformIds[row.platform],
              handle: row.handle.text.trim(),
            ),
          )
          .toList();
      if (socialLinks.isNotEmpty) {
        _socialMediaPlatform = socialLinks.first.platform;
        widget.socialMedia.text = socialLinks.first.handle;
      }
      widget.onSocialMediaPlatformChanged(_socialMediaPlatform);
      widget.onSocialMediaLinksChanged(socialLinks);
      widget.onLevelsChanged(_levels);
      widget.onGradeStreamsChanged(_gradeStreams);
      widget.onCalendarChanged(
        academicYear: _academicYear,
        academicTerm: _academicTerm,
        description: _termDescription.text,
        startDate: _termStartDate,
        endDate: _termEndDate,
        events: _events
            .map((event) => event.copy(isDraft: false))
            .toList(growable: false),
      );
      widget.onDocumentsChanged(_documents);
      if (widget.embedded) {
        await widget.onSaved?.call();
      } else if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _stepSignature() {
    String date(DateTime? value) => value?.toIso8601String() ?? '';
    final gradeEntries = _gradeStreams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final documentEntries = _documents.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final value = switch (widget.index) {
      0 => [
        widget.schoolName.text.trim(),
        _category,
        _educationLevel,
        widget.yearFounded.text.trim(),
        widget.motto.text.trim(),
      ],
      1 => [
        widget.gesCode.text.trim(),
        _gesRegistrationType,
        widget.gesRegistrationDate.text.trim(),
        widget.registrationNumber.text.trim(),
        _businessRegistrationType,
        widget.businessRegistrationDate.text.trim(),
        widget.gemisCode.text.trim(),
        widget.taxIdNumber.text.trim(),
      ],
      2 => [
        widget.socialWelfareNumber.text.trim(),
        widget.socialWelfareOfficer.text.trim(),
        widget.socialWelfareDate.text.trim(),
        _socialWelfareStatus,
      ],
      3 => [
        widget.houseNumber.text.trim(),
        widget.streetName.text.trim(),
        widget.address.text.trim(),
        widget.ghanaPostAddress.text.trim(),
        widget.town.text.trim(),
        widget.district.text.trim(),
        _region,
        _country,
        widget.gpsLatitude.text.trim(),
        widget.gpsLongitude.text.trim(),
      ],
      4 => [
        widget.phone.text.trim(),
        widget.phoneNetwork.text.trim(),
        widget.secondaryPhone.text.trim(),
        widget.secondaryPhoneNetwork.text.trim(),
        widget.officePhone.text.trim(),
        widget.email.text.trim(),
        widget.website.text.trim(),
        for (final row in _socialMediaRows)
          [row.platform, row.handle.text.trim()],
      ],
      5 => [
        for (final entry in documentEntries)
          [
            entry.key,
            entry.value.name,
            entry.value.size,
            entry.value.identifier ?? '',
          ],
      ],
      6 => [
        for (final entry in gradeEntries) [entry.key, entry.value],
      ],
      7 => [
        _academicYear,
        _academicTerm,
        _termDescription.text.trim(),
        date(_termStartDate),
        date(_termEndDate),
        for (final event in _events)
          [
            event.type,
            event.otherName.trim(),
            event.description.trim(),
            date(event.startDate),
            date(event.endDate),
            event.startTime,
            event.endTime,
            event.isSchoolDay,
          ],
      ],
      _ => const [],
    };
    return jsonEncode(value);
  }

  bool get _hasUnsavedChanges => _stepSignature() != _initialSignature;

  Future<bool> _confirmLeavingUnsavedStep() async {
    if (!_hasUnsavedChanges || _saving) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Leave without saving?'),
        content: const Text(
          'You have unsaved changes on this step. If you leave now, those changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave without saving'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _handleCancel() async {
    if (await _confirmLeavingUnsavedStep()) {
      widget.onCancel?.call();
    }
  }

  Future<void> _handlePrevious() async {
    if (await _confirmLeavingUnsavedStep()) {
      widget.onPrevious?.call();
    }
  }

  Future<void> _handleStepSelected(int step) async {
    if (step == widget.index) return;
    if (await _confirmLeavingUnsavedStep()) {
      widget.onStepSelected?.call(step);
    }
  }

  Future<void> _handleDialogCancel() async {
    if (await _confirmLeavingUnsavedStep() && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildEmbeddedWizard(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleDialogCancel();
      },
      child: AlertDialog(
        title: Text(widget.step.title),
        content: SizedBox(
          width: 620,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_validationMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _validationMessage!,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _content(),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleDialogCancel,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: widget.index == 8 && !_reviewConfirmed ? null : _save,
            child: Text(
              widget.index == 8 ? 'Submit school' : 'Save & continue',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedWizard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = !widget.singleStepEdit && constraints.maxWidth >= 820;
        final form = Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _wizardContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.loadingExistingRecord) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: .18),
                          ),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.green,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Loading saved school details...',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_validationMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _validationMessage!,
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.index <= 5)
                      _WizardSection(
                        title: widget.step.title,
                        child: _content(),
                      )
                    else
                      _content(),
                  ],
                ),
              ),
            ),
          ),
        );

        final pane = Column(
          children: [
            if (!showRail && !widget.singleStepEdit)
              _WizardMobileProgress(
                current: widget.index,
                total: _SchoolCreationScreenState._steps.length,
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _wizardContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TextButton(
                            onPressed: _handleCancel,
                            child: const Text('Onboarding'),
                          ),
                          const Text(
                            '›',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Add New School',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.singleStepEdit
                            ? 'Edit ${widget.step.title}'
                            : widget.step.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.step.description,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: form),
            _WizardFooter(
              index: widget.index,
              total: _SchoolCreationScreenState._steps.length,
              canSubmit: widget.index != 8 || _reviewConfirmed,
              onBack: widget.onPrevious == null ? null : _handlePrevious,
              onCancel: _handleCancel,
              onContinue: _save,
              primaryLabel: widget.singleStepEdit ? 'Save Changes' : null,
              saving: _saving,
            ),
          ],
        );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleCancel();
          },
          child: ColoredBox(
            color: AppColors.background,
            child: Row(
              children: [
                if (showRail)
                  _WizardRail(
                    steps: _SchoolCreationScreenState._steps,
                    current: widget.index,
                    completed: widget.completedSteps,
                    onSelected: _handleStepSelected,
                  ),
                Expanded(child: pane),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content() {
    return switch (widget.index) {
      0 => _fields([
        _requiredField(
          'School name',
          widget.schoolName,
          'Enter the registered school name',
        ),
        _dropdown(
          label: 'School category',
          value: _category,
          values: widget.lookups.schoolCategories,
          onChanged: (value) => setState(() => _category = value),
        ),
        _dropdown(
          label: 'Education level',
          value: _educationLevel,
          values: widget.lookups.educationLevels,
          onChanged: (value) => setState(() => _educationLevel = value),
        ),
        _pair(
          _requiredField(
            'Year founded',
            widget.yearFounded,
            'e.g. 2012',
            keyboardType: TextInputType.number,
          ),
          _optionalField(
            'School motto',
            widget.motto,
            'Knowledge and character',
          ),
        ),
      ]),
      1 => _fields([
        _pair(
          _requiredField(
            'GES registration number',
            widget.gesCode,
            'e.g. GES-PRV-123456',
          ),
          _dropdown(
            label: 'GES registration type',
            value: _gesRegistrationType,
            values: widget.lookups.gesRegistrationTypes,
            onChanged: (value) => setState(() => _gesRegistrationType = value),
          ),
        ),
        _requiredDateField('GES registration date', widget.gesRegistrationDate),
        _pair(
          _requiredField(
            'Business registration number',
            widget.registrationNumber,
            'e.g. BRN-2024-001234',
          ),
          _dropdown(
            label: 'Business registration type',
            value: _businessRegistrationType,
            values: widget.lookups.businessRegistrationTypes,
            onChanged: (value) =>
                setState(() => _businessRegistrationType = value),
          ),
        ),
        _requiredDateField(
          'Business registration date',
          widget.businessRegistrationDate,
        ),
        _pair(
          _requiredField('GEMIS code', widget.gemisCode, 'e.g. GMS-0042318'),
          _requiredField(
            'Tax ID number / TIN',
            widget.taxIdNumber,
            'e.g. C0012345678',
          ),
        ),
      ]),
      2 => _fields([
        _requiredField(
          'Social welfare approval number',
          widget.socialWelfareNumber,
          'e.g. SWA-2024-0023',
        ),
        _pair(
          _requiredField(
            'Approval officer name',
            widget.socialWelfareOfficer,
            'Full name of approving officer',
          ),
          _requiredDateField('Approval date', widget.socialWelfareDate),
        ),
        _dropdown(
          label: 'Compliance status',
          value: _socialWelfareStatus,
          values: widget.lookups.socialWelfareStatuses,
          onChanged: (value) => setState(() => _socialWelfareStatus = value),
        ),
      ]),
      3 => _fields([
        _pair(
          _requiredField('House number', widget.houseNumber, 'e.g. No. 14'),
          _requiredField(
            'Street name',
            widget.streetName,
            'e.g. Banana Inn Road',
          ),
        ),
        _pair(
          _lockedCountryField(),
          _dropdown(
            label: 'Region',
            value: _region,
            values: widget.lookups.regions,
            onChanged: (value) {
              setState(() {
                _region = value;
                widget.district.clear();
              });
              widget.onRegionChanged(value);
              widget.onRegionSelected(value);
            },
          ),
        ),
        _pair(
          _districtField(),
          _requiredField('City', widget.town, 'e.g. Kumasi'),
        ),
        _requiredField(
          'Additional directions',
          widget.address,
          'Describe how to find the school',
          maxLines: 3,
        ),
        _requiredField(
          'Ghana Post address',
          widget.ghanaPostAddress,
          'e.g. GA-123-4567',
        ),
        _pair(
          _requiredField(
            'GPS latitude',
            widget.gpsLatitude,
            'e.g. 5.5571',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
          _requiredField(
            'GPS longitude',
            widget.gpsLongitude,
            'e.g. -0.1969',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
        ),
      ]),
      4 => _fields([
        _contactSection(
          'Primary contact',
          _pair(
            _requiredField(
              'Phone Number',
              widget.phone,
              '+233 24 000 0000',
              keyboardType: TextInputType.phone,
            ),
            _phoneNetworkDropdown(
              label: 'Type',
              controller: widget.phoneNetwork,
            ),
          ),
        ),
        _contactSection(
          'Secondary contact',
          _pair(
            _optionalField(
              'Phone Number',
              widget.secondaryPhone,
              '+233 20 000 0000',
              keyboardType: TextInputType.phone,
              optional: true,
            ),
            _phoneNetworkDropdown(
              label: 'Type',
              controller: widget.secondaryPhoneNetwork,
              optional: true,
            ),
          ),
        ),
        _contactSection(
          'Work & email',
          _pair(
            _optionalField(
              'Office Phone',
              widget.officePhone,
              '+233 30 000 0000',
              keyboardType: TextInputType.phone,
              optional: true,
            ),
            _optionalField(
              'Email Address(es)',
              widget.email,
              'admin@school.edu.gh',
              keyboardType: TextInputType.emailAddress,
              optional: true,
              helperText: 'Comma-separated for multiple',
            ),
          ),
        ),
        _contactSection(
          'Social media',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._socialMediaRows.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == _socialMediaRows.length - 1 ? 0 : 10,
                  ),
                  child: _socialMediaRow(entry.key, entry.value),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => _socialMediaRows.add(
                    _SocialMediaFormRow(
                      platform: _defaultSocialMediaPlatform(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add platform'),
              ),
            ],
          ),
        ),
      ]),
      5 => _fields([
        ..._schoolDocumentLabels.map(
          (label) => _UploadTile(
            label: label,
            requiredDocument: _requiredSchoolDocumentLabels.contains(label),
            file: _documents[label],
            onView: widget.onViewDocument,
            onChanged: (file) => setState(() {
              if (file == null) {
                _documents.remove(label);
              } else {
                _documents[label] = file;
              }
              _validationMessage = null;
            }),
          ),
        ),
      ]),
      6 => _GradeLevelSetup(
        streams: _gradeStreams,
        gradeLevels: widget.lookups.gradeLevels,
        loading: widget.loadingGradeLevels,
        error: widget.gradeLevelsError,
        onRetry: widget.onReloadLookups,
        onChanged: (value) => setState(() {
          _gradeStreams
            ..clear()
            ..addAll(value);
          _levels
            ..clear()
            ..addAll(value.keys);
        }),
      ),
      7 => _CalendarSetup(
        academicYear: _academicYear,
        academicTerm: _academicTerm,
        academicYears: widget.lookups.academicYears,
        termTypes: widget.lookups.termTypes,
        eventTypes: widget.lookups.eventTypes,
        description: _termDescription,
        startDate: _termStartDate,
        endDate: _termEndDate,
        events: _events,
        onChanged:
            ({
              required academicYear,
              required academicTerm,
              required description,
              required startDate,
              required endDate,
              required events,
            }) => setState(() {
              _validationMessage = null;
              _academicYear = academicYear;
              _academicTerm = academicTerm;
              _termDescription.text = description;
              _termStartDate = startDate;
              _termEndDate = endDate;
              _events
                ..clear()
                ..addAll(events);
            }),
      ),
      _ => _ReviewSetup(
        schoolName: widget.schoolName.text,
        category: _category,
        educationLevel: _educationLevel,
        yearFounded: widget.yearFounded.text,
        motto: widget.motto.text,
        phone: widget.phone.text,
        phoneNetwork: widget.phoneNetwork.text,
        secondaryPhone: widget.secondaryPhone.text,
        secondaryPhoneNetwork: widget.secondaryPhoneNetwork.text,
        officePhone: widget.officePhone.text,
        email: widget.email.text,
        website: widget.website.text,
        socialMedia: widget.socialMedia.text,
        houseNumber: widget.houseNumber.text,
        streetName: widget.streetName.text,
        address: widget.address.text,
        ghanaPostAddress: widget.ghanaPostAddress.text,
        town: widget.town.text,
        district: widget.district.text,
        region: _region,
        country: _country,
        gesCode: widget.gesCode.text,
        gesRegistrationType: _gesRegistrationType,
        gesRegistrationDate: widget.gesRegistrationDate.text,
        registrationNumber: widget.registrationNumber.text,
        businessRegistrationType: _businessRegistrationType,
        businessRegistrationDate: widget.businessRegistrationDate.text,
        gemisCode: widget.gemisCode.text,
        taxIdNumber: widget.taxIdNumber.text,
        socialWelfareNumber: widget.socialWelfareNumber.text,
        socialWelfareOfficer: widget.socialWelfareOfficer.text,
        socialWelfareDate: widget.socialWelfareDate.text,
        socialWelfareStatus: _socialWelfareStatus,
        gradeStreams: _gradeStreams,
        academicYear: _academicYear,
        academicTerm: _academicTerm,
        description: _termDescription.text,
        startDate: _termStartDate,
        endDate: _termEndDate,
        events: _events,
        documents: _documents,
        onViewDocument: widget.onViewDocument,
        confirmed: _reviewConfirmed,
        onConfirmed: (value) => setState(() => _reviewConfirmed = value),
        onEdit: widget.onEditRequested,
      ),
    };
  }

  Widget _fields(List<Widget> fields) => Column(
    children: [
      for (var i = 0; i < fields.length; i++) ...[
        fields[i],
        if (i < fields.length - 1) const SizedBox(height: 14),
      ],
    ],
  );

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(children: [first, const SizedBox(height: 14), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _contactSection(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _defaultSocialMediaPlatform() {
    final options = widget.lookups.socialMediaPlatforms;
    return options.contains(_socialMediaPlatform) ? _socialMediaPlatform : '';
  }

  Widget _socialMediaRow(int index, _SocialMediaFormRow row) {
    final options = widget.lookups.socialMediaPlatforms;
    final platform = options.contains(row.platform) ? row.platform : '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final platformField = DropdownButtonFormField<String>(
          value: platform,
          validator: (selected) =>
              row.handle.text.trim().isNotEmpty &&
                  (selected == null || selected.trim().isEmpty)
              ? 'Select a platform'
              : null,
          decoration: const InputDecoration(
            labelText: 'Platform',
            border: OutlineInputBorder(),
          ),
          items: {'', ...options}
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.isEmpty ? 'Select platform' : item),
                ),
              )
              .toList(),
          onChanged: (selected) {
            if (selected != null) {
              setState(() {
                row.platform = selected;
                _socialMediaPlatform = selected;
              });
            }
          },
        );
        final handleField = _optionalField(
          'URL or handle',
          row.handle,
          'URL or handle',
          optional: true,
        );
        final removeButton = IconButton.filledTonal(
          tooltip: 'Remove platform',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFFE8E8),
            foregroundColor: AppColors.red,
          ),
          onPressed: _socialMediaRows.length == 1
              ? () => setState(() => row.handle.clear())
              : () => setState(() {
                  final removed = _socialMediaRows.removeAt(index);
                  removed.dispose();
                }),
          icon: const Icon(Icons.close_rounded, size: 18),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              platformField,
              const SizedBox(height: 12),
              handleField,
              Align(alignment: Alignment.centerRight, child: removeButton),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 220, child: platformField),
            const SizedBox(width: 12),
            Expanded(child: handleField),
            const SizedBox(width: 8),
            removeButton,
          ],
        );
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    final options = values.contains(value) ? values : [value, ...values];
    return DropdownButtonFormField<String>(
      value: value,
      validator: (selected) =>
          selected == null || selected.trim().isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item.trim().isEmpty ? 'Select $label' : item),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  Widget _districtField() {
    if (_region.trim().isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'District',
          border: OutlineInputBorder(),
        ),
        child: Text(
          'Select a region first',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    if (widget.loadingDistricts) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'District',
          border: OutlineInputBorder(),
        ),
        child: Text('Loading districts...'),
      );
    }
    if (widget.lookups.districts.isEmpty) {
      if (widget.district.text.trim().isNotEmpty) {
        return TextFormField(
          controller: widget.district,
          enabled: false,
          decoration: const InputDecoration(
            labelText: 'District',
            border: OutlineInputBorder(),
            helperText: 'Saved district',
          ),
        );
      }
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'District',
          border: OutlineInputBorder(),
        ),
        child: Text(
          'No districts available. Select the region again.',
          style: TextStyle(color: AppColors.red),
        ),
      );
    }
    return _dropdown(
      label: 'District',
      value: widget.district.text,
      values: widget.lookups.districts,
      onChanged: (value) => setState(() => widget.district.text = value),
    );
  }

  Widget _lockedCountryField() {
    final country = _ghanaCountryValue(widget.lookups.countries);
    return TextFormField(
      initialValue: country,
      enabled: false,
      decoration: const InputDecoration(
        labelText: 'Country',
        border: OutlineInputBorder(),
        helperText: 'Fixed for Ghanaian schools',
        suffixIcon: Icon(Icons.lock_outline_rounded),
      ),
    );
  }

  Widget _requiredField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    onChanged: onChanged,
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'Required' : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _requiredDateField(String label, TextEditingController controller) =>
      InkWell(
        onTap: () async {
          final current = _parseDate(controller.text);
          final picked = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
          );
          if (picked != null) {
            setState(() => controller.text = _formatDate(picked));
          }
        },
        borderRadius: BorderRadius.circular(9),
        child: IgnorePointer(
          child: TextFormField(
            controller: controller,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Select date',
              suffixIcon: const Icon(Icons.calendar_month_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      );

  Widget _phoneNetworkDropdown({
    required String label,
    required TextEditingController controller,
    bool optional = false,
  }) {
    const values = ['mobile', 'home', 'office', 'whatsapp', 'other'];
    final value = values.contains(controller.text) ? controller.text : null;
    return DropdownButtonFormField<String>(
      value: value,
      validator: optional
          ? null
          : (selected) =>
                selected == null || selected.trim().isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: optional ? '$label (optional)' : label,
        hintText: 'Select ${label.toLowerCase()}',
        border: const OutlineInputBorder(),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (selected) {
        if (selected != null) setState(() => controller.text = selected);
      },
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  Widget _optionalField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    bool optional = false,
    String? helperText,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: optional ? '$label (optional)' : label,
      hintText: hint,
      helperText: helperText,
      border: const OutlineInputBorder(),
    ),
  );
}

class _SocialMediaFormRow {
  _SocialMediaFormRow({required this.platform, String handle = ''})
    : handle = TextEditingController(text: handle);

  String platform;
  final TextEditingController handle;

  void dispose() => handle.dispose();
}

class _GradeLevelSetup extends StatefulWidget {
  const _GradeLevelSetup({
    required this.streams,
    required this.gradeLevels,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onChanged,
  });
  final Map<String, int> streams;
  final List<String> gradeLevels;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final ValueChanged<Map<String, int>> onChanged;

  @override
  State<_GradeLevelSetup> createState() => _GradeLevelSetupState();
}

class _GradeLevelSetupState extends State<_GradeLevelSetup> {
  final List<int> _draftRows = [];
  int _nextDraftId = 0;

  static const groups = {
    'Early Childhood': ['Creche', 'Nursery 1', 'Nursery 2', 'KG1', 'KG2'],
    'Primary School': [
      'Basic 1',
      'Basic 2',
      'Basic 3',
      'Basic 4',
      'Basic 5',
      'Basic 6',
    ],
    'Junior High School': ['JHS 1', 'JHS 2', 'JHS 3'],
    'Senior High School': ['SHS 1', 'SHS 2', 'SHS 3'],
  };

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.green),
              SizedBox(height: 14),
              Text(
                'Loading grade levels from the school platform...',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.gradeLevels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.muted,
                size: 34,
              ),
              const SizedBox(height: 12),
              const Text(
                'Grade levels could not be loaded',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                widget.error ??
                    'No placeholder grades are being used. Try the live platform again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final groupedLevels = _groupedLevels;
    final totalStreams = widget.streams.values.fold(
      0,
      (total, value) => total + value,
    );
    final selectedPreview = widget.streams.entries
        .take(6)
        .map(
          (entry) =>
              '${entry.key} (${entry.value} ${entry.value == 1 ? 'stream' : 'streams'})',
        )
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.green.withValues(alpha: .16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.streams.length} grades selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$totalStreams total streams',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.streams.isEmpty
                    ? 'Select the grade levels this school currently runs. Streams can be changed later in school settings.'
                    : selectedPreview +
                          (widget.streams.length > 6
                              ? ' · +${widget.streams.length - 6} more'
                              : ''),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AddGradeLevelControl(
          canAdd: _availableGradeLevels.isNotEmpty,
          onAdd: _addDraftRow,
        ),
        if (_draftRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._draftRows.map(
            (id) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DraftGradeLevelRow(
                availableGrades: _availableGradeLevels,
                onSelected: (grade) {
                  if (grade == null || grade.trim().isEmpty) return;
                  final next = {...widget.streams, grade: 1};
                  widget.onChanged(next);
                  setState(() => _draftRows.remove(id));
                },
                onCancel: () => setState(() => _draftRows.remove(id)),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        ...groupedLevels.entries.map(
          (group) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _categoryIcon(group.key),
                          color: AppColors.green,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.key,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${_selectedInGroup(group.value)} of ${group.value.length} selected',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final next = {...widget.streams};
                          final allSelected = group.value.every(
                            next.containsKey,
                          );
                          for (final grade in group.value) {
                            if (allSelected) {
                              next.remove(grade);
                            } else {
                              next.putIfAbsent(grade, () => 1);
                            }
                          }
                          widget.onChanged(next);
                        },
                        child: Text(
                          group.value.every(widget.streams.containsKey)
                              ? 'Clear'
                              : 'Select all',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...group.value.map((grade) {
                    final active = widget.streams.containsKey(grade);
                    final count = widget.streams[grade] ?? 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.green.withValues(alpha: .045)
                            : AppColors.background,
                        border: Border.all(
                          color: active ? AppColors.green : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: active,
                            onChanged: (selected) {
                              final next = {...widget.streams};
                              selected == true
                                  ? next[grade] = 1
                                  : next.remove(grade);
                              widget.onChanged(next);
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  grade,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  active
                                      ? '$count ${count == 1 ? 'stream' : 'streams'} selected'
                                      : 'Not included',
                                  style: TextStyle(
                                    color: active
                                        ? AppColors.green
                                        : AppColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (active) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: count > 1
                                        ? () {
                                            final next = {...widget.streams};
                                            next[grade] = count - 1;
                                            widget.onChanged(next);
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$count',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: count < 10
                                        ? () {
                                            final next = {...widget.streams};
                                            next[grade] = count + 1;
                                            widget.onChanged(next);
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'max 10',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.muted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A stream represents a separate class for the same grade level. Example: Basic 1 with three classes should be set to 3 streams.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _selectedInGroup(List<String> grades) =>
      grades.where(widget.streams.containsKey).length;

  List<String> get _availableGradeLevels => widget.gradeLevels
      .where((grade) => !widget.streams.containsKey(grade))
      .toList();

  void _addDraftRow() {
    if (_availableGradeLevels.isEmpty) return;
    setState(() => _draftRows.insert(0, _nextDraftId++));
  }

  Map<String, List<String>> get _groupedLevels {
    final grouped = {for (final entry in groups.entries) entry.key: <String>[]};
    final extras = <String>[];
    for (final grade in widget.gradeLevels) {
      final normalized = grade.toLowerCase().replaceAll(' ', '');
      if (normalized.contains('nursery') ||
          normalized.contains('creche') ||
          normalized.contains('crèche') ||
          normalized.startsWith('kg')) {
        grouped['Early Childhood']!.add(grade);
      } else if (normalized.startsWith('basic')) {
        grouped['Primary School']!.add(grade);
      } else if (normalized.startsWith('jhs')) {
        grouped['Junior High School']!.add(grade);
      } else if (normalized.startsWith('shs')) {
        grouped['Senior High School']!.add(grade);
      } else {
        extras.add(grade);
      }
    }
    if (extras.isNotEmpty) grouped['Other'] = extras;
    return {
      for (final entry in grouped.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
  }

  IconData _categoryIcon(String category) => switch (category) {
    'Early Childhood' => Icons.child_care_rounded,
    'Primary School' => Icons.menu_book_rounded,
    'Junior High School' => Icons.school_rounded,
    'Senior High School' => Icons.workspace_premium_rounded,
    _ => Icons.school_outlined,
  };
}

class _AddGradeLevelControl extends StatelessWidget {
  const _AddGradeLevelControl({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: canAdd ? onAdd : null,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add New'),
      ),
    );
  }
}

class _DraftGradeLevelRow extends StatelessWidget {
  const _DraftGradeLevelRow({
    required this.availableGrades,
    required this.onSelected,
    required this.onCancel,
  });

  final List<String> availableGrades;
  final ValueChanged<String?> onSelected;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: null,
              items: availableGrades
                  .map(
                    (grade) =>
                        DropdownMenuItem(value: grade, child: Text(grade)),
                  )
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'New grade level',
                hintText: 'Select grade level',
              ),
              onChanged: onSelected,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Remove row',
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _CalendarSetup extends StatelessWidget {
  const _CalendarSetup({
    required this.academicYear,
    required this.academicTerm,
    required this.academicYears,
    required this.termTypes,
    required this.eventTypes,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.events,
    required this.onChanged,
  });

  final String academicYear;
  final String academicTerm;
  final List<String> academicYears;
  final List<String> termTypes;
  final List<String> eventTypes;
  final TextEditingController description;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<_CalendarEvent> events;
  final _CalendarChanged onChanged;

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) =>
      showDatePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: DateTime(2035),
        initialDate: initial ?? DateTime.now(),
      );
  String _date(DateTime? value) => value == null
      ? 'Select date'
      : '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';

  @override
  Widget build(BuildContext context) {
    final academicYearOptions = academicYears.contains(academicYear)
        ? academicYears
        : [academicYear, ...academicYears];
    final termOptions = termTypes.contains(academicTerm)
        ? termTypes
        : [academicTerm, ...termTypes];
    final duration = startDate != null && endDate != null
        ? endDate!.difference(startDate!).inDays + 1
        : null;
    final hasIncompleteEvent = events.any((event) => !event.isComplete);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CalendarSummary(
          academicYear: academicYear,
          academicTerm: academicTerm,
          duration: duration,
          eventCount: events.length,
        ),
        const SizedBox(height: 16),
        _CalendarCard(
          title: 'Academic Term',
          child: Column(
            children: [
              _ResponsivePair(
                first: DropdownButtonFormField<String>(
                  value: academicYear,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: academicYearOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value.isEmpty ? 'Select academic year' : value,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => onChanged(
                    academicYear: value!,
                    academicTerm: academicTerm,
                    description: description.text,
                    startDate: startDate,
                    endDate: endDate,
                    events: events,
                  ),
                ),
                second: DropdownButtonFormField<String>(
                  value: academicTerm,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                  decoration: const InputDecoration(labelText: 'Term'),
                  items: termOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value.isEmpty ? 'Select academic term' : value,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => onChanged(
                    academicYear: academicYear,
                    academicTerm: value!,
                    description: description.text,
                    startDate: startDate,
                    endDate: endDate,
                    events: events,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: description,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'e.g. First term calendar for 2026/27 academic year',
                ),
              ),
              const SizedBox(height: 14),
              _ResponsivePair(
                first: _DateControl(
                  label: 'Start Date',
                  value: _date(startDate),
                  onTap: () async {
                    final value = await _pickDate(context, startDate);
                    if (value != null) {
                      onChanged(
                        academicYear: academicYear,
                        academicTerm: academicTerm,
                        description: description.text,
                        startDate: value,
                        endDate: endDate,
                        events: events,
                      );
                    }
                  },
                ),
                second: _DateControl(
                  label: 'End Date',
                  value: _date(endDate),
                  onTap: () async {
                    final value = await _pickDate(context, endDate);
                    if (value != null) {
                      onChanged(
                        academicYear: academicYear,
                        academicTerm: academicTerm,
                        description: description.text,
                        startDate: startDate,
                        endDate: value,
                        events: events,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CalendarCard(
          title: 'Events (optional)',
          action: OutlinedButton.icon(
            onPressed: hasIncompleteEvent
                ? null
                : () {
                    final next = [
                      _CalendarEvent(type: '', isDraft: true),
                      ...events,
                    ];
                    onChanged(
                      academicYear: academicYear,
                      academicTerm: academicTerm,
                      description: description.text,
                      startDate: startDate,
                      endDate: endDate,
                      events: next,
                    );
                  },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              hasIncompleteEvent ? 'Complete open event first' : 'Add event',
            ),
          ),
          child: events.isEmpty
              ? const _EmptyCalendarEvents()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasIncompleteEvent) ...[
                      const Text(
                        'Complete or delete the open event before adding another.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    ...events.asMap().entries.map(
                      (entry) => _EventEditor(
                        index: entry.key,
                        event: entry.value,
                        eventTypes: eventTypes,
                        onChanged: (event) {
                          final next = [...events];
                          next[entry.key] = event.copy(
                            isDraft: !event.isComplete,
                          );
                          onChanged(
                            academicYear: academicYear,
                            academicTerm: academicTerm,
                            description: description.text,
                            startDate: startDate,
                            endDate: endDate,
                            events: next,
                          );
                        },
                        onDelete: () {
                          final next = [...events]..removeAt(entry.key);
                          onChanged(
                            academicYear: academicYear,
                            academicTerm: academicTerm,
                            description: description.text,
                            startDate: startDate,
                            endDate: endDate,
                            events: next,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _CalendarSummary extends StatelessWidget {
  const _CalendarSummary({
    required this.academicYear,
    required this.academicTerm,
    required this.duration,
    required this.eventCount,
  });
  final String academicYear;
  final String academicTerm;
  final int? duration;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Academic Year', academicYear, Icons.date_range_rounded),
      ('Term', academicTerm, Icons.school_rounded),
      (
        'Duration',
        duration == null ? 'Select dates' : '$duration days',
        Icons.timelapse_rounded,
      ),
      ('Events', '$eventCount added', Icons.event_available_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            item.$3,
                            color: AppColors.green,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _EmptyCalendarEvents extends StatelessWidget {
  const _EmptyCalendarEvents();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: const Row(
      children: [
        Icon(Icons.event_note_outlined, color: AppColors.muted),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'No events added yet. Add mid-term holidays, Christmas breaks, sports days, or school-specific events.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _DateControl extends StatelessWidget {
  const _DateControl({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(value),
    ),
  );
}

class _EventEditor extends StatelessWidget {
  const _EventEditor({
    required this.index,
    required this.event,
    required this.eventTypes,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final _CalendarEvent event;
  final List<String> eventTypes;
  final ValueChanged<_CalendarEvent> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final options = {'', ...eventTypes}.toList();
    final value = options.contains(event.type) ? event.type : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: value,
                  validator: (selected) =>
                      selected == null || selected.trim().isEmpty
                      ? 'Required'
                      : null,
                  decoration: const InputDecoration(labelText: 'Event Type'),
                  items: options
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value.isEmpty ? 'Select event type' : value,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => onChanged(event.copy(type: value)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete event',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          if (event.type == 'Other') ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue: event.otherName,
              decoration: const InputDecoration(labelText: 'Specify event'),
              onChanged: (value) => onChanged(event.copy(otherName: value)),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            initialValue: event.description,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Event Description',
              hintText: 'Describe this event',
            ),
            onChanged: (value) => onChanged(event.copy(description: value)),
          ),
          const SizedBox(height: 10),
          _ResponsivePair(
            first: _DateControl(
              label: 'Event Start Date',
              value: event.startDate == null ? 'Select date' : event.shortStart,
              onTap: () async {
                final value = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2035),
                  initialDate: event.startDate ?? DateTime.now(),
                );
                if (value != null) onChanged(event.copy(startDate: value));
              },
            ),
            second: _DateControl(
              label: 'Event End Date',
              value: event.endDate == null ? 'Select date' : event.shortEnd,
              onTap: () async {
                final value = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2035),
                  initialDate: event.endDate ?? DateTime.now(),
                );
                if (value != null) onChanged(event.copy(endDate: value));
              },
            ),
          ),
          const SizedBox(height: 10),
          _ResponsivePair(
            first: _DateControl(
              label: 'Start Time',
              value: _displayTime(event.startTime),
              onTap: () async {
                final value = await showTimePicker(
                  context: context,
                  initialTime: _parseTime(event.startTime),
                );
                if (value != null) {
                  onChanged(event.copy(startTime: _apiTime(value)));
                }
              },
            ),
            second: _DateControl(
              label: 'End Time',
              value: _displayTime(event.endTime),
              onTap: () async {
                final value = await showTimePicker(
                  context: context,
                  initialTime: _parseTime(event.endTime),
                );
                if (value != null) {
                  onChanged(event.copy(endTime: _apiTime(value)));
                }
              },
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            value: event.isSchoolDay,
            onChanged: (value) => onChanged(event.copy(isSchoolDay: value)),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'School day',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Students are expected to attend school on this event date.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _apiTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  String _displayTime(String value) {
    final time = _parseTime(value);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}

class _ReviewSetup extends StatelessWidget {
  const _ReviewSetup({
    required this.schoolName,
    required this.category,
    required this.educationLevel,
    required this.yearFounded,
    required this.motto,
    required this.phone,
    required this.phoneNetwork,
    required this.secondaryPhone,
    required this.secondaryPhoneNetwork,
    required this.officePhone,
    required this.email,
    required this.website,
    required this.socialMedia,
    required this.houseNumber,
    required this.streetName,
    required this.address,
    required this.ghanaPostAddress,
    required this.town,
    required this.district,
    required this.region,
    required this.country,
    required this.gesCode,
    required this.gesRegistrationType,
    required this.gesRegistrationDate,
    required this.registrationNumber,
    required this.businessRegistrationType,
    required this.businessRegistrationDate,
    required this.gemisCode,
    required this.taxIdNumber,
    required this.socialWelfareNumber,
    required this.socialWelfareOfficer,
    required this.socialWelfareDate,
    required this.socialWelfareStatus,
    required this.gradeStreams,
    required this.academicYear,
    required this.academicTerm,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.events,
    required this.documents,
    required this.onViewDocument,
    required this.confirmed,
    required this.onConfirmed,
    required this.onEdit,
  });
  final String schoolName,
      category,
      educationLevel,
      yearFounded,
      motto,
      phone,
      phoneNetwork,
      secondaryPhone,
      secondaryPhoneNetwork,
      officePhone,
      email,
      website,
      socialMedia,
      houseNumber,
      streetName,
      address,
      ghanaPostAddress,
      town,
      district,
      region,
      country,
      gesCode,
      gesRegistrationType,
      gesRegistrationDate,
      registrationNumber,
      businessRegistrationType,
      businessRegistrationDate,
      gemisCode,
      taxIdNumber,
      socialWelfareNumber,
      socialWelfareOfficer,
      socialWelfareDate,
      socialWelfareStatus,
      academicYear,
      academicTerm,
      description;
  final Map<String, int> gradeStreams;
  final DateTime? startDate, endDate;
  final List<_CalendarEvent> events;
  final Map<String, PlatformFile> documents;
  final Future<void> Function(PlatformFile) onViewDocument;
  final bool confirmed;
  final ValueChanged<bool> onConfirmed;
  final ValueChanged<int> onEdit;

  String _date(DateTime? value) =>
      value == null ? 'Not provided' : _previewDate(value);

  List<(String, String)> get _gradeRows {
    if (gradeStreams.isEmpty) {
      return const [('Grade Levels', 'No grade levels configured')];
    }
    final rows = gradeStreams.entries
        .take(13)
        .map(
          (entry) => (
            entry.key,
            '${entry.value} stream${entry.value == 1 ? '' : 's'}',
          ),
        )
        .toList();
    if (gradeStreams.length > 13) {
      rows.add(('Total Grades', '${gradeStreams.length} grades configured'));
    }
    return rows;
  }

  List<(String, String)> get _academicTermRows {
    return <(String, String)>[
      ('Academic Year', academicYear),
      ('Academic Term', academicTerm),
      ('Start Date', _date(startDate)),
      ('End Date', _date(endDate)),
      ('Description', description),
      ('Events', '${events.length} ${events.length == 1 ? 'event' : 'events'}'),
    ];
  }

  List<(String, String)> get _documentRows {
    return _schoolDocumentLabels.map((label) {
      final file = documents[label];
      final required = _requiredSchoolDocumentLabels.contains(label);
      final title = _titleCase(label);
      if (file == null) {
        return (title, required ? 'Required - not uploaded' : 'Not uploaded');
      }
      return (title, '${file.name} · ${_formatSize(file.size)}');
    }).toList();
  }

  String _titleCase(String value) => value
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ReviewSection(
        title: 'School Information',
        step: 0,
        onEdit: onEdit,
        rows: [
          ('School Name', schoolName),
          ('Custom School ID', 'Generated on submission'),
          ('Category', category),
          ('Education Level', educationLevel),
          ('Year Founded', yearFounded),
          ('School Motto', motto),
          ('Registration Status', 'In progress'),
        ],
      ),
      _ReviewSection(
        title: 'Contact Information',
        step: 4,
        onEdit: onEdit,
        rows: [
          ('Primary Phone', '$phone · $phoneNetwork'),
          ('Secondary Phone', '$secondaryPhone · $secondaryPhoneNetwork'),
          ('Work Phone Numbers', officePhone),
          ('Email Addresses', email),
          ('Website', website),
          ('Social Media', socialMedia),
        ],
      ),
      _ReviewSection(
        title: 'Address',
        step: 3,
        onEdit: onEdit,
        rows: [
          ('House Number', houseNumber),
          ('Street Name', streetName),
          ('Additional Direction', address),
          ('Ghana Post Address', ghanaPostAddress),
          ('City', town),
          ('District', district),
          ('Region', region),
          ('Country', country),
        ],
      ),
      _ReviewSection(
        title: 'Registration Details',
        step: 1,
        onEdit: onEdit,
        rows: [
          ('GES Registration Number', gesCode),
          ('GES Registration Type', gesRegistrationType),
          ('GES Registration Date', gesRegistrationDate),
          ('Business Registration Number', registrationNumber),
          ('Business Registration Type', businessRegistrationType),
          ('Business Registration Date', businessRegistrationDate),
          ('GEMIS Code', gemisCode),
          ('Tax ID Number', taxIdNumber),
          ('Registration Number', registrationNumber),
        ],
      ),
      _ReviewSection(
        title: 'Social Welfare Compliance',
        step: 2,
        onEdit: onEdit,
        rows: [
          ('Approval Number', socialWelfareNumber),
          ('Approval Officer Name', socialWelfareOfficer),
          ('Approval Date', socialWelfareDate),
          ('Compliance Status', socialWelfareStatus),
        ],
      ),
      _ReviewSection(
        title: 'Grade Levels',
        step: 6,
        onEdit: onEdit,
        rows: _gradeRows,
      ),
      _ReviewSection(
        title: 'Academic Term Details',
        step: 7,
        onEdit: onEdit,
        rows: _academicTermRows,
        footer: _ReviewEventList(events: events),
      ),
      _ReviewSection(
        title: 'Documents',
        step: 5,
        onEdit: onEdit,
        rows: _documentRows,
        onRowTap: (index) async {
          final file = documents[_schoolDocumentLabels[index]];
          if (file != null) await onViewDocument(file);
        },
      ),
      CheckboxListTile(
        value: confirmed,
        onChanged: (value) => onConfirmed(value ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'I confirm that all the information provided above is accurate and complete.',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Submitting will send this school onboarding record for approval.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ),
    ],
  );
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.step,
    required this.onEdit,
    required this.rows,
    this.onRowTap,
    this.footer,
  });
  final String title;
  final int step;
  final ValueChanged<int> onEdit;
  final List<(String, String)> rows;
  final Future<void> Function(int)? onRowTap;
  final Widget? footer;

  IconData get _icon => switch (step) {
    0 => Icons.school_outlined,
    1 => Icons.badge_outlined,
    2 => Icons.verified_user_outlined,
    3 => Icons.location_on_outlined,
    4 => Icons.contact_phone_outlined,
    5 => Icons.upload_file_outlined,
    6 => Icons.account_tree_outlined,
    7 => Icons.calendar_month_outlined,
    _ => Icons.fact_check_outlined,
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: AppColors.green, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => onEdit(step),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        ...rows.asMap().entries.map((entry) {
          final row = entry.value;
          return _ReviewRow(
            label: row.$1,
            value: row.$2,
            onTap: onRowTap == null ? null : () => onRowTap!(entry.key),
          );
        }),
        if (footer != null) ...[const SizedBox(height: 4), footer!],
      ],
    ),
  );
}

class _ReviewEventList extends StatelessWidget {
  const _ReviewEventList({required this.events});

  final List<_CalendarEvent> events;

  String _date(DateTime? value) =>
      value == null ? 'Date not provided' : _previewDate(value);

  String _name(_CalendarEvent event) =>
      event.type == 'Other' && event.otherName.trim().isNotEmpty
      ? event.otherName.trim()
      : event.type;

  String _time(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No events added for this term.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TERM EVENTS',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 8),
        ...events.map(
          (event) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.event_outlined,
                    color: AppColors.green,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _name(event),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          _EventReviewBadge(
                            label: event.type,
                            color: AppColors.green,
                          ),
                          _EventReviewBadge(
                            label: event.isSchoolDay
                                ? 'School day'
                                : 'No school',
                            color: event.isSchoolDay
                                ? AppColors.green
                                : AppColors.amber,
                          ),
                        ],
                      ),
                      if (event.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          event.description.trim(),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 5,
                        children: [
                          _EventReviewMeta(
                            icon: Icons.date_range_outlined,
                            text:
                                '${_date(event.startDate)} to ${_date(event.endDate)}',
                          ),
                          _EventReviewMeta(
                            icon: Icons.schedule_outlined,
                            text:
                                '${_time(event.startTime)} to ${_time(event.endTime)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EventReviewBadge extends StatelessWidget {
  const _EventReviewBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _EventReviewMeta extends StatelessWidget {
  const _EventReviewMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

String _previewDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final day = value.day;
  final suffix = day >= 11 && day <= 13
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$day$suffix ${months[value.month - 1]} ${value.year}';
}

class _ReviewRow extends StatefulWidget {
  const _ReviewRow({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final Future<void> Function()? onTap;

  @override
  State<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends State<_ReviewRow> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening || widget.onTap == null) return;
    setState(() => _opening = true);
    try {
      await widget.onTap!();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanValue = widget.value.trim().isEmpty
        ? 'Not provided'
        : widget.value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final labelWidget = Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .1,
            ),
          );
          final valueText = Text(
            cleanValue,
            style: TextStyle(
              color: widget.onTap != null
                  ? AppColors.green
                  : cleanValue == 'Not provided'
                  ? AppColors.muted
                  : AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          );
          final Widget valueWidget = widget.onTap == null
              ? valueText
              : InkWell(
                  onTap: _opening ? null : _open,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: valueText),
                      const SizedBox(width: 5),
                      if (_opening)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: AppColors.green,
                          ),
                        )
                      else
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: AppColors.green,
                        ),
                    ],
                  ),
                );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 2), valueWidget],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 210, child: labelWidget),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

typedef _CalendarChanged =
    void Function({
      required String academicYear,
      required String academicTerm,
      required String description,
      required DateTime? startDate,
      required DateTime? endDate,
      required List<_CalendarEvent> events,
    });

class _CalendarEvent {
  _CalendarEvent({
    required this.type,
    this.otherName = '',
    this.description = '',
    this.startDate,
    this.endDate,
    this.startTime = '00:00:00',
    this.endTime = '23:59:59',
    this.isSchoolDay = false,
    this.isDraft = false,
  });
  final String type;
  final String otherName;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String startTime;
  final String endTime;
  final bool isSchoolDay;
  final bool isDraft;
  String get shortStart =>
      '${startDate!.day}-${startDate!.month}-${startDate!.year}';
  String get shortEnd => '${endDate!.day}-${endDate!.month}-${endDate!.year}';
  bool get isComplete {
    if (type.trim().isEmpty) return false;
    if (type == 'Other' && otherName.trim().isEmpty) return false;
    return startDate != null && endDate != null;
  }

  _CalendarEvent copy({
    String? type,
    String? otherName,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    bool? isSchoolDay,
    bool? isDraft,
  }) => _CalendarEvent(
    type: type ?? this.type,
    otherName: otherName ?? this.otherName,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    isSchoolDay: isSchoolDay ?? this.isSchoolDay,
    isDraft: isDraft ?? this.isDraft,
  );
}

class _UploadTile extends StatefulWidget {
  const _UploadTile({
    required this.label,
    required this.requiredDocument,
    required this.file,
    required this.onView,
    required this.onChanged,
  });
  final String label;
  final bool requiredDocument;
  final PlatformFile? file;
  final Future<void> Function(PlatformFile) onView;
  final ValueChanged<PlatformFile?> onChanged;

  @override
  State<_UploadTile> createState() => _UploadTileState();
}

class _UploadTileState extends State<_UploadTile> {
  String? _error;
  bool _viewing = false;

  Future<void> _viewFile() async {
    final file = widget.file;
    if (file == null || _viewing) return;
    setState(() => _viewing = true);
    try {
      await widget.onView(file);
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final sizeMb = file.size / (1024 * 1024);
    if (sizeMb > 10) {
      setState(() => _error = 'File must be 10MB or smaller.');
      return;
    }
    widget.onChanged(file);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(Icons.upload_file_outlined, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (widget.requiredDocument)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                if (widget.file == null)
                  Text(
                    'PDF, image, Word document · max 10MB',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _error == null ? AppColors.muted : AppColors.red,
                      fontSize: 11,
                    ),
                  )
                else
                  InkWell(
                    onTap: _viewing ? null : _viewFile,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${widget.file!.name} · ${_formatSize(widget.file!.size)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (_viewing)
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.7,
                              color: AppColors.green,
                            ),
                          )
                        else
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: AppColors.green,
                          ),
                      ],
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (widget.file != null)
            IconButton(
              tooltip: 'Remove file',
              onPressed: _viewing
                  ? null
                  : () {
                      setState(() => _error = null);
                      widget.onChanged(null);
                    },
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
            ),
          OutlinedButton(
            onPressed: _viewing ? null : _pickFile,
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
  }
}

class _SetupStep {
  const _SetupStep(this.title, this.description, this.icon);
  final String title;
  final String description;
  final IconData icon;
}
