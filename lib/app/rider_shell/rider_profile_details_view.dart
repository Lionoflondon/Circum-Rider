import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../authentication/bloc/auth_bloc.dart';
import '../rider_design/rider_ui.dart';
import '../rider_truth/rider_truth.dart';

class RiderPersonalDetailsView extends StatefulWidget {
  const RiderPersonalDetailsView({super.key, required this.user});

  final User user;

  @override
  State<RiderPersonalDetailsView> createState() =>
      _RiderPersonalDetailsViewState();
}

class _RiderPersonalDetailsViewState extends State<RiderPersonalDetailsView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _dob = TextEditingController();
  final _gender = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _dob,
      _gender,
      _phone,
      _email,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    final first = '${data['firstName'] ?? ''}'.trim();
    final last = '${data['lastName'] ?? ''}'.trim();
    _name.text = '${data['fullName'] ?? data['name'] ?? '$first $last'}'.trim();
    _username.text = '${data['handle'] ?? data['username'] ?? ''}'
        .trim()
        .replaceFirst('@', '');
    _dob.text = '${data['dateOfBirth'] ?? data['dob'] ?? ''}'.trim();
    _gender.text = '${data['gender'] ?? ''}'.trim();
    _phone.text =
        '${data['phoneNumber'] ?? data['phone'] ?? widget.user.phoneNumber ?? ''}'
            .trim();
    _email.text = '${data['email'] ?? widget.user.email ?? ''}'.trim();
    _address.text = '${data['homeAddress'] ?? data['address'] ?? ''}'.trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final parts = _name.text.trim().split(RegExp(r'\s+'));
      final handle = _username.text.trim().replaceFirst('@', '');
      final patch = <String, dynamic>{
        'fullName': _name.text.trim(),
        'name': _name.text.trim(),
        'firstName': parts.first,
        'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
        'handle': handle,
        'username': handle,
        'dateOfBirth': _dob.text.trim(),
        'gender': _gender.text.trim(),
        'homeAddress': _address.text.trim(),
      };
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updateRiderProfile')
          .call(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile could not be updated. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final imageSource = await _showRiderPhotoSourceSheet(context);
    XFile? image;
    if (imageSource == 'library') {
      image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1024,
      );
    }
    if (imageSource == 'camera') {
      image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1024,
      );
    }
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    context.read<AuthBloc>().add(UpdateUserProfilePhoto(
          imagePath: image.path,
          imageBytes: bytes,
          mimeType: image.mimeType,
        ));
  }

  String _firstText(List<Map<String, dynamic>> sources, List<String> keys,
      {String fallback = ''}) {
    for (final source in sources) {
      for (final key in keys) {
        final value = '${source[key] ?? ''}'.trim();
        if (value.isNotEmpty && value != 'null') return value;
      }
    }
    return fallback;
  }

  String _profilePhotoUrl(
    Map<String, dynamic> rider,
    Map<String, dynamic> profile,
  ) {
    return _firstText([
      profile,
      rider,
    ], [
      'profileThumbnailUrl',
      'profilePhotoUrl',
      'profilePhoto',
      'photoURL',
      'photoUrl',
    ], fallback: widget.user.photoURL ?? '');
  }

  String _profileText(
    Map<String, dynamic> rider,
    Map<String, dynamic> profile,
    List<String> keys, {
    String fallback = '',
  }) {
    return _firstText([profile, rider], keys, fallback: fallback);
  }

  Map<String, dynamic> _profileData(
    Map<String, dynamic> rider,
    Map<String, dynamic> profile,
  ) {
    final data = <String, dynamic>{...rider, ...profile};
    for (final key in [
      'profileThumbnailUrl',
      'profilePhotoUrl',
      'profilePhoto',
      'photoURL',
      'photoUrl',
    ]) {
      final value = _profileText(rider, profile, [key]);
      if (value.isNotEmpty) data[key] = value;
    }
    for (final key in [
      'handle',
      'username',
      'riderHandle',
    ]) {
      final value = _profileText(rider, profile, [key]);
      if (value.isNotEmpty) data[key] = value;
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        title: const Text('Personal Details'),
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('riders')
            .doc(widget.user.uid)
            .snapshots(),
        builder: (context, riderSnapshot) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('riderProfiles')
                  .doc(widget.user.uid)
                  .snapshots(),
              builder: (context, profileSnapshot) {
                if (!riderSnapshot.hasData && !profileSnapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: RiderPalette.blue));
                }
                final rider = riderSnapshot.data?.data() ?? const {};
                final profile = profileSnapshot.data?.data() ?? const {};
                final data = _profileData(rider, profile);
                _hydrate(data);
                final profilePhotoUrl = _profilePhotoUrl(rider, profile);
                return Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
                    children: [
                      RiderGlassSurface(
                        radius: 24,
                        child: Column(
                          children: [
                            _EditableProfilePhoto(
                              imageUrl: profilePhotoUrl,
                              onTap: _pickProfilePhoto,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _pickProfilePhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Change profile photo'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This is the photo senders see during deliveries.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RiderPalette.muted, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RiderGlassSurface(
                        radius: 24,
                        child: Column(
                          children: [
                            _field(_name, 'Full name', required: true),
                            _field(_username, 'Username',
                                prefix: '@', required: true),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Your Rider username is saved to your profile.',
                                style: TextStyle(
                                    color: RiderPalette.muted, height: 1.35),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _field(_dob, 'Date of birth'),
                            _field(_gender, 'Gender (optional)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RiderGlassSurface(
                        radius: 24,
                        child: Column(
                          children: [
                            _field(_phone, 'Phone',
                                keyboard: TextInputType.phone, readOnly: true),
                            _field(_email, 'Email',
                                keyboard: TextInputType.emailAddress,
                                readOnly: true),
                            _field(_address, 'Home address', lines: 2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RiderGlassSurface(
                        radius: 20,
                        child: ListTile(
                          leading: const Icon(Icons.fingerprint_rounded,
                              color: RiderPalette.muted),
                          title: const Text('Identity',
                              style: TextStyle(
                                  color: RiderPalette.paper,
                                  fontWeight: FontWeight.w800)),
                          subtitle: Text('Rider ID ${widget.user.uid}',
                              style:
                                  const TextStyle(color: RiderPalette.muted)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: RiderPalette.blue),
                        child: Text(_saving ? 'Saving…' : 'Save changes'),
                      ),
                    ],
                  ),
                );
              });
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool required = false,
      String? prefix,
      TextInputType? keyboard,
      bool readOnly = false,
      int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        readOnly: readOnly,
        maxLines: lines,
        style: const TextStyle(color: RiderPalette.paper),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          suffixIcon: readOnly ? const Icon(Icons.lock_outline_rounded) : null,
        ),
      ),
    );
  }
}

class _EditableProfilePhoto extends StatelessWidget {
  const _EditableProfilePhoto({
    required this.imageUrl,
    required this.onTap,
  });

  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageUrl.trim().isNotEmpty && imageUrl.trim() != 'null';
    return Semantics(
      button: true,
      label: 'Change Rider profile photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF111827),
                border: Border.all(
                  color: RiderPalette.blue.withValues(alpha: .42),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .24),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _NeutralProfilePhotoFallback(),
                    )
                  : const _NeutralProfilePhotoFallback(),
            ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: RiderPalette.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: RiderPalette.background, width: 3),
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    color: RiderPalette.paper, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeutralProfilePhotoFallback extends StatelessWidget {
  const _NeutralProfilePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF111827),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: RiderPalette.muted,
          size: 54,
        ),
      ),
    );
  }
}

Future<String?> _showRiderPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: RiderPalette.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: RiderPalette.muted.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Update Rider profile photo',
              style: TextStyle(
                color: RiderPalette.paper,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the photo senders and operations see during deliveries.',
              style: TextStyle(color: RiderPalette.muted, height: 1.35),
            ),
            const SizedBox(height: 18),
            _PhotoSourceTile(
              icon: Icons.photo_camera_outlined,
              title: 'Take photo',
              subtitle: 'Use your camera',
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from library',
              subtitle: 'Upload an existing photo',
              onTap: () => Navigator.pop(context, 'library'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RiderPalette.background.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RiderPalette.blue.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: RiderPalette.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: RiderPalette.paper,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: RiderPalette.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: RiderPalette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class RiderVehicleManagerView extends StatelessWidget {
  const RiderVehicleManagerView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RiderPalette.background,
        appBar: AppBar(
          title: const Text('Vehicles'),
          backgroundColor: RiderPalette.background,
          foregroundColor: RiderPalette.paper,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editVehicle(context, null),
          backgroundColor: RiderPalette.blue,
          foregroundColor: RiderPalette.paper,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add vehicle'),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('riderProfiles')
              .doc(userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: RiderPalette.blue));
            }
            final data = snapshot.data!.data() ?? const <String, dynamic>{};
            final vehicles = _vehicles(data);
            if (vehicles.isEmpty) {
              return RiderEmptyState(
                icon: Icons.two_wheeler_outlined,
                title: 'No vehicles added',
                message: 'Add the vehicle you use for deliveries.',
                actionLabel: 'Add vehicle',
                onAction: () => _editVehicle(context, null),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                final active =
                    vehicle['primary'] == true || vehicle['active'] == true;
                return RiderGlassSurface(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.directions_car_outlined,
                            color: RiderPalette.blue),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_vehicleName(vehicle),
                                style: const TextStyle(
                                    color: RiderPalette.paper,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900))),
                        if (active)
                          const _VehicleStatus(
                              label: 'Active', color: RiderPalette.green),
                      ]),
                      const SizedBox(height: 8),
                      Text(_vehicleDetails(vehicle),
                          style: const TextStyle(
                              color: RiderPalette.muted, height: 1.4)),
                      const SizedBox(height: 8),
                      _VehicleStatus(
                          label: _status(vehicle),
                          color: _statusColor(vehicle)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [
                        if (!active)
                          TextButton(
                              onPressed: () => _setActive(vehicles, index),
                              child: const Text('Set active')),
                        TextButton(
                            onPressed: () =>
                                _editVehicle(context, vehicle, index: index),
                            child: const Text('Edit')),
                        TextButton(
                            onPressed: () => _delete(context, vehicles, index),
                            child: const Text('Delete',
                                style: TextStyle(color: RiderPalette.red))),
                      ]),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );

  List<Map<String, dynamic>> _vehicles(Map<String, dynamic> data) {
    final value = data['vehicles'];
    if (value is Iterable) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data['vehicle'] is Map) {
      return [Map<String, dynamic>.from(data['vehicle'] as Map)];
    }
    return [];
  }

  Future<void> _persist(List<Map<String, dynamic>> vehicles) async {
    final active = vehicles.cast<Map<String, dynamic>?>().firstWhere(
        (v) => v?['primary'] == true,
        orElse: () => vehicles.isEmpty ? null : vehicles.first);
    final patch = <String, dynamic>{
      'vehicles': vehicles,
      if (active != null) 'vehicle': active,
      if (active != null) 'vehicleType': active['type'],
      if (active != null) 'vehicleRegistration': active['registration'],
    };
    await FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('updateRiderProfile')
        .call(patch);
  }

  Future<void> _setActive(
      List<Map<String, dynamic>> vehicles, int index) async {
    await _persist([
      for (var i = 0; i < vehicles.length; i++)
        {...vehicles[i], 'primary': i == index, 'active': i == index}
    ]);
  }

  Future<void> _delete(BuildContext context,
      List<Map<String, dynamic>> vehicles, int index) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: RiderPalette.panel,
              title: const Text('Delete vehicle?',
                  style: TextStyle(color: RiderPalette.paper)),
              content: const Text(
                  'This removes the vehicle from your Rider profile. Existing delivery records are unchanged.',
                  style: TextStyle(color: RiderPalette.muted)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirmed != true) return;
    final next = [...vehicles]..removeAt(index);
    if (next.isNotEmpty && !next.any((v) => v['primary'] == true)) {
      next[0] = {...next[0], 'primary': true, 'active': true};
    }
    await _persist(next);
  }

  Future<void> _editVehicle(BuildContext context, Map<String, dynamic>? source,
      {int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RiderPalette.panel,
      builder: (_) => _VehicleEditor(source: source),
    );
    if (result == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('riderProfiles')
        .doc(userId)
        .get();
    final vehicles = _vehicles(snap.data() ?? const {});
    if (index == null) {
      vehicles.add(
          {...result, 'primary': vehicles.isEmpty, 'active': vehicles.isEmpty});
    } else if (index < vehicles.length) {
      vehicles[index] = {...vehicles[index], ...result};
    }
    await _persist(vehicles);
  }

  String _vehicleName(Map<String, dynamic> v) => [
        v['manufacturer'] ?? v['make'],
        v['model']
      ].map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(' ').isEmpty
          ? '${v['type'] ?? 'Vehicle'}'
          : [v['manufacturer'] ?? v['make'], v['model']]
              .map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .join(' ');
  String _vehicleDetails(Map<String, dynamic> v) => [
        v['type'],
        v['colour'],
        v['registration'],
        v['capacity']
      ].map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(' · ');
  String _status(Map<String, dynamic> v) =>
      '${v['verificationStatus'] ?? 'Pending Review'}';
  Color _statusColor(Map<String, dynamic> v) {
    final s = _status(v).toLowerCase();
    if (s.contains('verified')) return RiderPalette.green;
    if (s.contains('reject') || s.contains('expired')) return RiderPalette.red;
    return RiderPalette.amber;
  }
}

class _VehicleEditor extends StatefulWidget {
  const _VehicleEditor({this.source});
  final Map<String, dynamic>? source;
  @override
  State<_VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<_VehicleEditor> {
  late final Map<String, TextEditingController> fields;
  @override
  void initState() {
    super.initState();
    final source = widget.source ?? const <String, dynamic>{};
    fields = {
      for (final key in [
        'type',
        'manufacturer',
        'model',
        'year',
        'colour',
        'registration',
        'capacity',
        'insurance',
        'mot',
      ])
        key: TextEditingController(
          text:
              '${source[key] ?? (key == 'manufacturer' ? source['make'] : '')}',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(widget.source == null ? 'Add vehicle' : 'Edit vehicle',
                  style: const TextStyle(
                      color: RiderPalette.paper,
                      fontFamily: RiderTypography.heading,
                      fontSize: 28)),
              const SizedBox(height: 14),
              for (final entry in fields.entries)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                        controller: entry.value,
                        style: const TextStyle(color: RiderPalette.paper),
                        decoration:
                            InputDecoration(labelText: _label(entry.key)))),
              FilledButton(
                  onPressed: () {
                    if (fields['type']!.text.trim().isEmpty ||
                        fields['registration']!.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Vehicle type and registration are required.')));
                      return;
                    }
                    Navigator.pop(context, {
                      for (final e in fields.entries)
                        e.key: e.value.text.trim(),
                      'verificationStatus':
                          widget.source?['verificationStatus'] ??
                              'pending_review'
                    });
                  },
                  child: const Text('Save vehicle')),
            ])),
      ));
  String _label(String key) => {
        'type': 'Vehicle type',
        'manufacturer': 'Manufacturer',
        'model': 'Model',
        'year': 'Year',
        'colour': 'Colour',
        'registration': 'Registration',
        'capacity': 'Capacity',
        'insurance': 'Insurance',
        'mot': 'MOT'
      }[key]!;
}

class _VehicleStatus extends StatelessWidget {
  const _VehicleStatus({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: .3))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)));
}

class RiderPerformanceView extends StatelessWidget {
  const RiderPerformanceView({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    final rank = RiderRankSnapshot.from(profile);
    final current = rank?.trustPoints ?? 0;
    final currentRank = rank?.rank ?? '—';
    return Scaffold(
        backgroundColor: RiderPalette.background,
        appBar: AppBar(
            title: const Text('Rank & Trust'),
            backgroundColor: RiderPalette.background,
            foregroundColor: RiderPalette.paper),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          RiderGlassSurface(
              radius: 24,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current performance',
                        style: TextStyle(color: RiderPalette.muted)),
                    const SizedBox(height: 8),
                    Text(currentRank,
                        style: const TextStyle(
                            color: RiderPalette.paper,
                            fontFamily: RiderTypography.heading,
                            fontSize: 34)),
                    const SizedBox(height: 6),
                    Text('$current trust points',
                        style: const TextStyle(
                            color: RiderPalette.blue,
                            fontFamily: RiderTypography.mono,
                            fontWeight: FontWeight.w800))
                  ])),
          const SizedBox(height: 14),
          const RiderGlassSurface(
              radius: 24,
              child: Text(
                  'Rank and trust progress update automatically from completed delivery performance.',
                  style: TextStyle(color: RiderPalette.muted, height: 1.5))),
        ]));
  }
}
