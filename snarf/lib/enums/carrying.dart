enum Carrying {
  condoms,
  lube,
  naloxone,
  drugTestStrips,
  discuss,
}

extension CarryingLabel on Carrying {
  static const _pt = {
    Carrying.condoms: 'Camisinhas',
    Carrying.lube: 'Lubrificante',
    Carrying.naloxone: 'Naloxona',
    Carrying.drugTestStrips: 'Fitas de teste de drogas',
    Carrying.discuss: 'Conversar',
  };
  String get label => _pt[this]!;
}