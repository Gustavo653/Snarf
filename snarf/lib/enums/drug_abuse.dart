enum DrugAbuse {
  alcohol,
  cannabis,
  tobacco,
  poppers,
  pnp,
  other,
  discuss,
}

extension DrugAbuseLabel on DrugAbuse {
  static const _pt = {
    DrugAbuse.alcohol: 'Álcool',
    DrugAbuse.cannabis: 'Cannabis',
    DrugAbuse.tobacco: 'Tabaco',
    DrugAbuse.poppers: 'Poppers',
    DrugAbuse.pnp: 'PnP',
    DrugAbuse.other: 'Outro',
    DrugAbuse.discuss: 'Conversar',
  };
  String get label => _pt[this]!;
}