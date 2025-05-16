enum HivStatus {
  negative,
  prep,
  positive,
  undetectable,
  unknown,
  private_,
}

extension HivStatusLabel on HivStatus {
  static const _pt = {
    HivStatus.negative: 'Negativo',
    HivStatus.prep: 'PrEP',
    HivStatus.positive: 'Positivo',
    HivStatus.undetectable: 'Indetectável',
    HivStatus.unknown: 'Desconhecido',
    HivStatus.private_: 'Privado',
  };
  String get label => _pt[this]!;
}