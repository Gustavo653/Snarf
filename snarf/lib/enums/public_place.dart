enum PublicPlace {
  arcade,
  bar,
  bathhouse,
  beach,
  car,
  event,
  gym,
  outdoor,
  park,
  restroom,
  sauna,
  truckstop,
}

extension PublicPlaceLabel on PublicPlace {
  static const _pt = {
    PublicPlace.arcade: 'Fliperama',
    PublicPlace.bar: 'Bar',
    PublicPlace.bathhouse: 'Casa de banho',
    PublicPlace.beach: 'Praia',
    PublicPlace.car: 'Carro',
    PublicPlace.event: 'Evento',
    PublicPlace.gym: 'Academia',
    PublicPlace.outdoor: 'Ao ar livre',
    PublicPlace.park: 'Parque',
    PublicPlace.restroom: 'Banheiro',
    PublicPlace.sauna: 'Sauna',
    PublicPlace.truckstop: 'Parada de caminhões',
  };
  String get label => _pt[this]!;
}