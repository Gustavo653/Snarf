enum Actions {
  ballPlay,
  cuddle,
  fingering,
  fisting,
  fucking,
  frotting,
  jerkOff,
  rimming,
  massage,
  makeout,
  oral,
  oralReceiving,
  oralGiving,
  oralSwallow,
}

extension ActionsLabel on Actions {
  static const _pt = {
    Actions.ballPlay: 'Brincar com Bolas',
    Actions.cuddle: 'Abraçar',
    Actions.fingering: 'Dedilhando',
    Actions.fisting: 'Punho / Fisting',
    Actions.fucking: 'Foda',
    Actions.frotting: 'Pau com Pau',
    Actions.jerkOff: 'Bater',
    Actions.rimming: 'Rimming',
    Actions.massage: 'Massagem',
    Actions.makeout: 'Beijos',
    Actions.oral: 'Boquete',
    Actions.oralReceiving: 'Boquete (Somente recebimento)',
    Actions.oralGiving: 'Boquete (Dê somente)',
    Actions.oralSwallow: 'Boquete (Engolir)',
  };

  String get label => _pt[this]!;
}