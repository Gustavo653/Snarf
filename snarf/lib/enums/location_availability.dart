enum LocationAvailability {
  none,
  hasPlace,
  canHostGroup,
  gloryHole,
  hotelRoom,
  inCar,
  lookingLivePlay,
}

extension LocationAvailabilityLabel on LocationAvailability {
  static const _pt = {
    LocationAvailability.none: 'Nenhum',
    LocationAvailability.hasPlace: 'Tenho lugar',
    LocationAvailability.canHostGroup: 'Posso receber grupo',
    LocationAvailability.gloryHole: 'Glory hole',
    LocationAvailability.hotelRoom: 'Quarto de hotel',
    LocationAvailability.inCar: 'No carro',
    LocationAvailability.lookingLivePlay: 'Procurando jogo ao vivo',
  };
  String get label => _pt[this]!;
}