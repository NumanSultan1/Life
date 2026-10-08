import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';
import 'medicines_screen.dart';

const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', "Don't know"];

/// Emergency information: blood group, allergies, conditions, medicines
/// and people to call.
class MedicalIdScreen extends StatefulWidget {
  const MedicalIdScreen({super.key});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  Box get _box => Hive.box(HiveService.settingsBox);
  String get _key => '${HiveService.getCurrentUser()}_medicalId';

  Map<String, dynamic> get _data => Map<String, dynamic>.from((_box.get(_key) as Map?) ?? const {});
  List<Map> get _contacts => List<Map>.from((_data['contacts'] as List?) ?? const []);

  Future<void> _save(Map<String, dynamic> d) async {
    await _box.put(_key, d);
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final d = _data;
    var blood = d['blood'] as String?;
    final allergies = TextEditingController(text: d['allergies'] as String?);
    final conditions = TextEditingController(text: d['conditions'] as String?);
    final notes = TextEditingController(text: d['notes'] as String?);
    final ok = await showLiquidSheet<bool>(
      context: context,
      title: 'Edit medical ID',
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetLabel('Blood group'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in _bloodGroups)
                  ChoiceChip(
                    label: Text(b),
                    selected: blood == b,
                    onSelected: (_) => setSheet(() => blood = b),
                    selectedColor: AppColors.danger,
                    labelStyle: TextStyle(color: blood == b ? Colors.white : null, fontWeight: FontWeight.w800),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SheetLabel('Allergies'),
            TextField(controller: allergies, decoration: const InputDecoration(hintText: 'e.g. penicillin, peanuts (or "none")')),
            const SheetLabel('Medical conditions'),
            TextField(controller: conditions, decoration: const InputDecoration(hintText: 'e.g. asthma, diabetes')),
            const SheetLabel('Other notes'),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(hintText: 'Anything a doctor should know')),
            const SizedBox(height: 24),
            GlowButton(label: 'Save', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, true)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _save({...d, 'blood': blood, 'allergies': allergies.text.trim(), 'conditions': conditions.text.trim(), 'notes': notes.text.trim()});
  }

  Future<void> _addContact() async {
    final name = TextEditingController(), phone = TextEditingController(), relation = TextEditingController();
    final ok = await showLiquidSheet<bool>(
      context: context,
      title: 'Emergency contact',
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetLabel('Name'),
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Abu')),
          const SheetLabel('Relation'),
          TextField(controller: relation, decoration: const InputDecoration(hintText: 'e.g. father, brother, friend')),
          const SheetLabel('Phone number'),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'e.g. 0300 1234567')),
          const SizedBox(height: 24),
          GlowButton(label: 'Add contact', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      if (mounted) showInfoSnackBar(context, 'Add a name and phone number.');
      return;
    }
    await _save({..._data, 'contacts': [..._contacts, {'name': name.text.trim(), 'phone': phone.text.trim(), 'relation': relation.text.trim()}]});
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (!await launchUrl(uri) && mounted) showInfoSnackBar(context, 'Couldn\'t open the phone app.');
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final textTheme = Theme.of(context).textTheme;
    final meds = MedicineStore.all;
    Widget field(IconData icon, String label, String? value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.danger, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(value == null || value.isEmpty ? 'Not added' : value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Medical ID',
              subtitle: 'Important info for an emergency',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              actions: [GlassIconButton(icon: Icons.edit_rounded, onTap: _edit)],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    onTap: _edit,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(HiveService.getCurrentUser(), style: textTheme.titleLarge?.copyWith(fontSize: 20)),
                            const Spacer(),
                            if (d['blood'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
                                child: Text('🩸 ${d['blood']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        field(Icons.warning_amber_rounded, 'Allergies', d['allergies'] as String?),
                        field(Icons.healing_rounded, 'Medical conditions', d['conditions'] as String?),
                        field(Icons.medication_rounded, 'Medicines', meds.isEmpty ? null : meds.map((m) => m.dose.isEmpty ? m.name : '${m.name} (${m.dose})').join(', ')),
                        field(Icons.notes_rounded, 'Notes', d['notes'] as String?),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Emergency contacts', style: textTheme.titleMedium?.copyWith(fontSize: 17)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _contacts.length; i++)
                    GlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, color: AppColors.royal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_contacts[i]['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  [(_contacts[i]['relation'] ?? '') as String, _contacts[i]['phone'] as String].where((s) => s.isNotEmpty).join(' · '),
                                  style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Call ${_contacts[i]['name']}',
                            icon: const Icon(Icons.call_rounded, color: AppColors.success),
                            onPressed: () => _call(_contacts[i]['phone'] as String),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => _save({..._data, 'contacts': [..._contacts]..removeAt(i)}),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add emergency contact'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  ),
                  const SizedBox(height: 18),
                  GlassCard(
                    child: Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded, color: AppColors.danger, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Emergency services', style: TextStyle(fontWeight: FontWeight.w800)),
                              Text('Rescue 1122 (Pakistan) · 112 works on most phones worldwide', style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () async {
                            final ok = await showLiquidConfirm(context, title: 'Call 1122?', message: 'This opens your phone app to call Rescue 1122.', confirmLabel: 'Call', icon: Icons.call_rounded, destructive: true);
                            if (ok) _call('1122');
                          },
                          child: const Text('1122'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('This stays on your phone. Show it to a doctor or rescuer if needed.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
