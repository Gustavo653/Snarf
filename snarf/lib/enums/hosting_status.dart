enum HostingStatus { host, travel }

extension HostingStatusLabel on HostingStatus {
  String get label => this == HostingStatus.host ? 'Hospedo' : 'Viajo';
}