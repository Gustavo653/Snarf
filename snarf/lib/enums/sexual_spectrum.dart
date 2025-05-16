enum SexualSpectrum {
  straight,
  straightCurious,
  biCurious,
  bisexual,
  gay,
}

extension SexualSpectrumLabel on SexualSpectrum {
  static const _pt = {
    SexualSpectrum.straight: 'Hétero',
    SexualSpectrum.straightCurious: 'Hétero-curioso',
    SexualSpectrum.biCurious: 'Bicurioso',
    SexualSpectrum.bisexual: 'Bissexual',
    SexualSpectrum.gay: 'Gay',
  };

  String get label => _pt[this]!;
}