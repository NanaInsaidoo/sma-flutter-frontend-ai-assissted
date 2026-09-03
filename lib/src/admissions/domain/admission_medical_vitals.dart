/// Medical values that must survive edits to conditions and allergies.
class AdmissionMedicalVitals {
  AdmissionMedicalVitals({
    this.bloodGroupId,
    this.bloodGroupName = '',
    this.heightCm,
    this.weightKg,
  });

  factory AdmissionMedicalVitals.fromJson(Map<String, dynamic>? json) {
    final group = json?['bloodGroup'];
    return AdmissionMedicalVitals(
      bloodGroupId: int.tryParse(
        '${json?['bloodGroupId'] ?? (group is Map ? group['id'] : null)}',
      ),
      bloodGroupName: group is Map ? '${group['name'] ?? ''}'.trim() : '',
      heightCm: num.tryParse('${json?['heightCm']}'),
      weightKg: num.tryParse('${json?['weightKg']}'),
    );
  }

  int? bloodGroupId;
  String bloodGroupName;
  final num? heightCm;
  final num? weightKg;

  Map<String, dynamic> toUpdateJson() => {
    if (bloodGroupId != null) 'bloodGroupId': bloodGroupId,
    // The medical update also writes these fields, even when this form does
    // not edit them. Keep existing measurements rather than clearing them.
    'heightCm': heightCm,
    'weightKg': weightKg,
  };
}
