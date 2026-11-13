/// Supported wireless casting protocols.
enum CastProtocol {
  chromecast,
  dlnaRenderer,
  airplay,
}

/// Operational state of a discovered cast device.
enum CastDeviceState {
  idle,
  discovering,
  connected,
  disconnected,
  error,
}

/// Represents a discovered wireless casting receiver on the local subnet.
class CastDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final CastProtocol protocol;
  final String? modelName;
  final String serviceType;
  final Map<String, String> properties;
  final CastDeviceState state;
  final DateTime lastSeen;

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.modelName,
    this.serviceType = '_googlecast._tcp',
    this.properties = const {},
    this.state = CastDeviceState.idle,
    required this.lastSeen,
  });

  bool get isChromecast => protocol == CastProtocol.chromecast;
  bool get isDlna => protocol == CastProtocol.dlnaRenderer;
  bool get isAirplay => protocol == CastProtocol.airplay;

  /// Default port for the given cast protocol.
  static int defaultPortFor(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.chromecast:
        return 8009;
      case CastProtocol.dlnaRenderer:
        return 1400;
      case CastProtocol.airplay:
        return 7000;
    }
  }

  factory CastDevice.fromJson(Map<String, dynamic> json) {
    final protocolStr = json['protocol']?.toString() ?? 'chromecast';
    final protocol = CastProtocol.values.firstWhere(
      (p) => p.name.toLowerCase() == protocolStr.toLowerCase(),
      orElse: () => CastProtocol.chromecast,
    );

    final stateStr = json['state']?.toString() ?? 'idle';
    final state = CastDeviceState.values.firstWhere(
      (s) => s.name.toLowerCase() == stateStr.toLowerCase(),
      orElse: () => CastDeviceState.idle,
    );

    final rawLastSeen = json['lastSeen'] ?? json['last_seen'];
    DateTime lastSeen = DateTime.now();
    if (rawLastSeen is String) {
      lastSeen = DateTime.tryParse(rawLastSeen) ?? DateTime.now();
    } else if (rawLastSeen is int) {
      lastSeen = DateTime.fromMillisecondsSinceEpoch(rawLastSeen);
    }

    final properties = <String, String>{};
    if (json['properties'] is Map) {
      (json['properties'] as Map).forEach((key, value) {
        if (key != null && value != null) {
          properties[key.toString()] = value.toString();
        }
      });
    }

    return CastDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Cast Device',
      host: json['host']?.toString() ?? '127.0.0.1',
      port: json['port'] is int ? json['port'] as int : int.tryParse(json['port']?.toString() ?? '') ?? defaultPortFor(protocol),
      protocol: protocol,
      modelName: json['modelName']?.toString() ?? json['model_name']?.toString(),
      serviceType: json['serviceType']?.toString() ?? json['service_type']?.toString() ?? '_googlecast._tcp',
      properties: properties,
      state: state,
      lastSeen: lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'protocol': protocol.name,
      if (modelName != null) 'modelName': modelName,
      'serviceType': serviceType,
      'properties': properties,
      'state': state.name,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  CastDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    CastProtocol? protocol,
    String? modelName,
    String? serviceType,
    Map<String, String>? properties,
    CastDeviceState? state,
    DateTime? lastSeen,
  }) {
    return CastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      modelName: modelName ?? this.modelName,
      serviceType: serviceType ?? this.serviceType,
      properties: properties ?? this.properties,
      state: state ?? this.state,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CastDevice &&
        other.id == id &&
        other.host == host &&
        other.port == port &&
        other.protocol == protocol;
  }

  @override
  int get hashCode => Object.hash(id, host, port, protocol);

  @override
  String toString() => 'CastDevice($name, protocol: ${protocol.name}, endpoint: $host:$port, state: ${state.name})';
}
