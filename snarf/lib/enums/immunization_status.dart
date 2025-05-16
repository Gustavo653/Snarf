enum ImmunizationStatus {
  covid1,
  monkeypox1,
  doxyPep,
  condoms,
}

extension ImmunizationStatusLabel on ImmunizationStatus {
  static const _pt = {
    ImmunizationStatus.covid1: 'COVID-19 (1 dose)',
    ImmunizationStatus.monkeypox1: 'Varíola dos macacos (1 dose)',
    ImmunizationStatus.doxyPep: 'DoxyPEP',
    ImmunizationStatus.condoms: 'Camisinhas',
  };
  String get label => _pt[this]!;
}