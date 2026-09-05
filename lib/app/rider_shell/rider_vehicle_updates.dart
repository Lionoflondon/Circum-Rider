import 'package:cloud_functions/cloud_functions.dart';

import '../onboarding/rider_onboarding_policy.dart';

List<Map<String, dynamic>> riderEditableVehicles(Map<String, dynamic> profile) {
  final stored = profile['vehicles'];
  final vehicles = stored is Iterable
      ? stored
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList()
      : profile['vehicle'] is Map
          ? [Map<String, dynamic>.from(profile['vehicle'] as Map)]
          : <Map<String, dynamic>>[];
  final primary = vehicles.indexWhere((v) => v['primary'] == true);
  if (primary > 0) vehicles.insert(0, vehicles.removeAt(primary));
  return [
    for (final vehicle in vehicles)
      {
        ...vehicle,
        'make': vehicle['make'] ?? vehicle['manufacturer'] ?? '',
        'manufacturer': vehicle['manufacturer'] ?? vehicle['make'] ?? '',
        'registration': vehicle['registration'] ?? vehicle['plateNumber'] ?? '',
      },
  ];
}

Future<void> saveRiderVehicles(
  FirebaseFunctions functions,
  List<Map<String, dynamic>> vehicles,
) async {
  if (vehicles.isEmpty || vehicles.length > 2) {
    throw StateError('Keep one or two vehicles on your Rider profile.');
  }
  final ordered = [...vehicles];
  final primary = ordered.indexWhere((vehicle) => vehicle['primary'] == true);
  if (primary > 0) ordered.insert(0, ordered.removeAt(primary));
  final editable = <Map<String, dynamic>>[];
  for (var i = 0; i < vehicles.length; i++) {
    final vehicle = ordered[i];
    final type = riderVehicleValue(vehicle['type']);
    if (type == null) throw StateError('Choose Motorbike, Car or Van.');
    final registration = '${vehicle['registration'] ?? ''}'.trim();
    if (registration.isEmpty) {
      throw StateError('Enter your vehicle registration.');
    }
    editable.add({
      'type': type,
      'registration': registration,
      for (final key in ['make', 'model', 'colour', 'year', 'ownershipStatus'])
        key:
            '${(key == 'make' ? vehicle['manufacturer'] ?? vehicle['make'] : vehicle[key]) ?? ''}'
                .trim(),
      'primary': i == 0,
    });
  }
  await functions.httpsCallable('updateRiderProfile').call({
    'vehicles': editable,
    'vehicleType': editable.first['type'],
    'vehicleRegistration': editable.first['registration'],
    'vehicleColour': editable.first['colour'],
    'vehicleMakeModel': [editable.first['make'], editable.first['model']]
        .where((value) => value != '')
        .join(' '),
  }).timeout(const Duration(seconds: 20));
}
