enum Practice {
  bareback,
  barebackPrep,
  safe,
  saferOnly,
  safeOrBareback,
  letsTalk,
}

extension PracticeLabel on Practice {
  static const _pt = {
    Practice.bareback: 'Bareback',
    Practice.barebackPrep: 'Bareback + PrEP',
    Practice.safe: 'Seguro',
    Practice.saferOnly: 'Apenas mais seguro',
    Practice.safeOrBareback: 'Seguro ou bareback',
    Practice.letsTalk: 'Vamos conversar',
  };
  String get label => _pt[this]!;
}