enum BodyType {
  slim,
  fit,
  muscular,
  average,
  stocky,
  chubby,
  large,
}

extension BodyTypeLabel on BodyType {
  static const _pt = {
    BodyType.slim: 'Magro',
    BodyType.fit: 'Em Forma',
    BodyType.muscular: 'Musculoso',
    BodyType.average: 'Médio',
    BodyType.stocky: 'Robusto',
    BodyType.chubby: 'Gordinho',
    BodyType.large: 'Grande',
  };
  String get label => _pt[this]!;
}