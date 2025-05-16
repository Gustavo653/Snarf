import 'package:flutter/material.dart';
import 'package:snarf/enums/actions.dart' as action;
import 'package:snarf/enums/body_type.dart';
import 'package:snarf/enums/interaction.dart';
import 'package:snarf/enums/kink.dart';
import 'package:snarf/enums/fetish.dart';
import 'package:snarf/enums/expression_style.dart';
import 'package:snarf/enums/location_availability.dart';
import 'package:snarf/enums/hosting_status.dart';
import 'package:snarf/enums/public_place.dart';
import 'package:snarf/enums/practice.dart';
import 'package:snarf/enums/hiv_status.dart';
import 'package:snarf/enums/immunization_status.dart';
import 'package:snarf/enums/drug_abuse.dart';
import 'package:snarf/enums/carrying.dart';
import 'package:snarf/enums/sexual_spectrum.dart';
import 'package:snarf/enums/sexual_attitude.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _circumferenceCtrl = TextEditingController();

  LocationAvailability? _locationAvailability;
  BodyType? _bodyType;
  SexualSpectrum? _spectrum;
  SexualAttitude? _attitude;
  HostingStatus? _hostingStatus;
  PublicPlace? _publicPlace;
  Practice? _practice;
  HivStatus? _hivStatus;

  final Set<ExpressionStyle> _expressions = {};
  final Set<Kink> _kinks = {};
  final Set<Fetish> _fetishes = {};
  final Set<action.Actions> _actions = {};
  final Set<Interaction> _interactions = {};
  final Set<ImmunizationStatus> _immunizations = {};
  final Set<DrugAbuse> _drugAbuses = {};
  final Set<Carrying> _carryings = {};

  bool showAge = true,
      showHeight = true,
      showWeight = true,
      showBodyType = true,
      showIsCircumcised = true,
      showCircumference = true,
      showSpectrum = true,
      showAttitude = true,
      showExpressions = true,
      showHostingStatus = true,
      showPublicPlace = true,
      showKinks = true,
      showFetishes = true,
      showActions = true,
      showInteractions = true,
      showPractice = true,
      showHivStatus = true,
      showHivDate = true,
      showStiDate = true,
      showImmunizations = true,
      showDrugAbuse = true,
      showCarrying = true;

  DateTime? _hivTestedDate;
  DateTime? _stiTestedDate;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _descriptionCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _circumferenceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Conta'),
              _buildTextField(_emailCtrl, 'E‑mail'),
              _buildTextField(_nameCtrl, 'Nome'),
              _buildTextField(_passwordCtrl, 'Senha', obscure: true),
              const Divider(),
              _buildSectionTitle('Localização de nascimento'),
              Row(
                children: [
                  Expanded(child: _buildTextField(_latCtrl, 'Latitude')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField(_lngCtrl, 'Longitude')),
                ],
              ),
              _buildDropdown<LocationAvailability>(
                'Disponibilidade de local',
                LocationAvailability.values,
                _locationAvailability,
                    (val) => setState(() => _locationAvailability = val),
              ),
              const Divider(),
              _buildSectionTitle('Estatísticas'),
              _buildSwitch('Mostrar idade', showAge, (v) => setState(() => showAge = v)),
              _buildTextField(_ageCtrl, 'Idade', keyboard: TextInputType.number),
              _buildSwitch('Mostrar altura', showHeight, (v) => setState(() => showHeight = v)),
              _buildTextField(_heightCtrl, 'Altura (cm)', keyboard: TextInputType.number),
              _buildSwitch('Mostrar peso', showWeight, (v) => setState(() => showWeight = v)),
              _buildTextField(_weightCtrl, 'Peso (kg)', keyboard: TextInputType.number),
              _buildDropdown<BodyType>(
                'Tipo de corpo',
                BodyType.values,
                _bodyType,
                    (val) => setState(() => _bodyType = val),
              ),
              _buildSwitch('Mostrar tipo de corpo', showBodyType, (v) => setState(() => showBodyType = v)),
              _buildSwitch('Circuncidado', showIsCircumcised, (v) => setState(() => showIsCircumcised = v)),
              _buildTextField(_circumferenceCtrl, 'Circunferência (cm)', keyboard: TextInputType.number),
              _buildSwitch('Mostrar circunferência', showCircumference, (v) => setState(() => showCircumference = v)),
              const Divider(),
              _buildSectionTitle('Sexualidade'),
              _buildDropdown<SexualSpectrum>(
                'Espectro',
                SexualSpectrum.values,
                _spectrum,
                    (val) => setState(() => _spectrum = val),
              ),
              _buildSwitch('Mostrar espectro', showSpectrum, (v) => setState(() => showSpectrum = v)),
              _buildDropdown<SexualAttitude>(
                'Atitude',
                SexualAttitude.values,
                _attitude,
                    (val) => setState(() => _attitude = val),
              ),
              _buildSwitch('Mostrar atitude', showAttitude, (v) => setState(() => showAttitude = v)),
              _buildMultiSelect<ExpressionStyle>('Expressões', ExpressionStyle.values, _expressions),
              _buildSwitch('Mostrar expressões', showExpressions, (v) => setState(() => showExpressions = v)),
              const Divider(),
              _buildSectionTitle('Cena'),
              _buildDropdown<HostingStatus>('Status de hospedagem', HostingStatus.values, _hostingStatus, (v) => setState(() => _hostingStatus = v)),
              _buildSwitch('Mostrar hospedagem', showHostingStatus, (v) => setState(() => showHostingStatus = v)),
              _buildDropdown<PublicPlace>('Lugar público preferido', PublicPlace.values, _publicPlace, (v) => setState(() => _publicPlace = v)),
              _buildSwitch('Mostrar lugar público', showPublicPlace, (v) => setState(() => showPublicPlace = v)),
              _buildMultiSelect<Kink>('Kinks', Kink.values, _kinks),
              _buildSwitch('Mostrar kinks', showKinks, (v) => setState(() => showKinks = v)),
              _buildMultiSelect<Fetish>('Fetiches', Fetish.values, _fetishes),
              _buildSwitch('Mostrar fetiches', showFetishes, (v) => setState(() => showFetishes = v)),
              _buildMultiSelect<action.Actions>('Ações que gosta', action.Actions.values, _actions),
              _buildSwitch('Mostrar ações', showActions, (v) => setState(() => showActions = v)),
              _buildMultiSelect<Interaction>('Interações', Interaction.values, _interactions),
              _buildSwitch('Mostrar interações', showInteractions, (v) => setState(() => showInteractions = v)),
              const Divider(),
              _buildSectionTitle('Saúde'),
              _buildDropdown<Practice>('Práticas', Practice.values, _practice, (v) => setState(() => _practice = v)),
              _buildSwitch('Mostrar prática', showPractice, (v) => setState(() => showPractice = v)),
              _buildDropdown<HivStatus>('Status HIV', HivStatus.values, _hivStatus, (v) => setState(() => _hivStatus = v)),
              _buildSwitch('Mostrar status HIV', showHivStatus, (v) => setState(() => showHivStatus = v)),
              _buildDatePicker('Data teste HIV', _hivTestedDate, (d) => setState(() => _hivTestedDate = d)),
              _buildSwitch('Mostrar data HIV', showHivDate, (v) => setState(() => showHivDate = v)),
              _buildDatePicker('Data teste IST', _stiTestedDate, (d) => setState(() => _stiTestedDate = d)),
              _buildSwitch('Mostrar data IST', showStiDate, (v) => setState(() => showStiDate = v)),
              _buildMultiSelect<ImmunizationStatus>('Imunizações', ImmunizationStatus.values, _immunizations),
              _buildSwitch('Mostrar imunizações', showImmunizations, (v) => setState(() => showImmunizations = v)),
              _buildMultiSelect<DrugAbuse>('Uso de substâncias', DrugAbuse.values, _drugAbuses),
              _buildSwitch('Mostrar substâncias', showDrugAbuse, (v) => setState(() => showDrugAbuse = v)),
              _buildMultiSelect<Carrying>('Levando', Carrying.values, _carryings),
              _buildSwitch('Mostrar levando', showCarrying, (v) => setState(() => showCarrying = v)),

              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _buildTextField(TextEditingController ctrl, String label, {bool obscure = false, TextInputType keyboard = TextInputType.text}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ),
  );

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(title: Text(label), value: value, onChanged: onChanged);

  Widget _buildDropdown<T>(String label, List<T> values, T? current, ValueChanged<T?> onChanged) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: DropdownButtonFormField<T>(
      value: current,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values
          .map((e) => DropdownMenuItem(value: e, child: Text(_enumLabel(e as Object))))
          .toList(),
      onChanged: onChanged,
    ),
  );

  Widget _buildMultiSelect<T>(String label, List<T> values, Set<T> selected) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Wrap(
        spacing: 4,
        children: values
            .map((e) => FilterChip(
          label: Text(_enumLabel(e as Object)),
          selected: selected.contains(e),
          onSelected: (v) {
            setState(() {
              v ? selected.add(e) : selected.remove(e);
            });
          },
        ))
            .toList(),
      ),
    ],
  );

  Widget _buildDatePicker(String label, DateTime? date, ValueChanged<DateTime> onPicked) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      title: Text(label),
      subtitle: Text(date != null ? '${date.day}/${date.month}/${date.year}' : 'Não definido'),
      trailing: const Icon(Icons.calendar_month),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: date ?? now, firstDate: DateTime(1900), lastDate: now);
        if (picked != null) onPicked(picked);
      },
    ),
  );

  String _enumLabel(Object e) {
    if (e is action.Actions) return e.label;
    if (e is Interaction) return e.label;
    if (e is Kink) return e.label;
    if (e is Fetish) return e.label;
    if (e is ExpressionStyle) return e.label;
    if (e is BodyType) return e.label;
    if (e is LocationAvailability) return e.label;
    if (e is HostingStatus) return e.label;
    if (e is PublicPlace) return e.label;
    if (e is Practice) return e.label;
    if (e is HivStatus) return e.label;
    if (e is ImmunizationStatus) return e.label;
    if (e is DrugAbuse) return e.label;
    if (e is Carrying) return e.label;
    if (e is SexualSpectrum) return e.label;
    if (e is SexualAttitude) return e.label;
    return e.toString().split('.').last;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil salvo (mock).')));
  }
}