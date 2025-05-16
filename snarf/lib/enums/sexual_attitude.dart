enum SexualAttitude {
  noPenetration,
  submissiveBottom,
  bottom,
  greedyBottom,
  versatileBottom,
  versatile,
  versatileTop,
  topBottom,
  top,
  dominantTop,
}

extension SexualAttitudeLabel on SexualAttitude {
  static const _pt = {
    SexualAttitude.noPenetration: 'Sem penetração',
    SexualAttitude.submissiveBottom: 'Passivo submisso',
    SexualAttitude.bottom: 'Passivo',
    SexualAttitude.greedyBottom: 'Passivo guloso',
    SexualAttitude.versatileBottom: 'Versátil + passivo',
    SexualAttitude.versatile: 'Versátil',
    SexualAttitude.versatileTop: 'Versátil + ativo',
    SexualAttitude.topBottom: 'Top sub',
    SexualAttitude.top: 'Ativo',
    SexualAttitude.dominantTop: 'Ativo dominante',
  };
  String get label => _pt[this]!;
}