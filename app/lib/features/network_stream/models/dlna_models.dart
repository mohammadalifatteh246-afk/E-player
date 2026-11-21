import 'network_share.dart';

/// Represents a discovered or configured UPnP / DLNA Media Server (e.g. Plex, Synology, MiniDLNA, Jellyfin, Kodi).
class DlnaMediaServer {
  final String id; // USN or unique identifier
  final String friendlyName;
  final String host;
  final int port;
  final String locationUrl; // rootDesc.xml URL
  final String contentDirectoryControlUrl; // SOAP Browse endpoint
  final String? manufacturer;
  final String? modelName;
  final String? iconUrl;
  final bool isOnline;

  const DlnaMediaServer({
    required this.id,
    required this.friendlyName,
    required this.host,
    required this.port,
    required this.locationUrl,
    required this.contentDirectoryControlUrl,
    this.manufacturer,
    this.modelName,
    this.iconUrl,
    this.isOnline = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'friendlyName': friendlyName,
        'host': host,
        'port': port,
        'locationUrl': locationUrl,
        'contentDirectoryControlUrl': contentDirectoryControlUrl,
        'manufacturer': manufacturer,
        'modelName': modelName,
        'iconUrl': iconUrl,
        'isOnline': isOnline,
      };

  factory DlnaMediaServer.fromJson(Map<String, dynamic> json) {
    return DlnaMediaServer(
      id: json['id'] as String? ?? '',
      friendlyName: json['friendlyName'] as String? ?? 'DLNA Media Server',
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 8200,
      locationUrl: json['locationUrl'] as String? ?? '',
      contentDirectoryControlUrl: json['contentDirectoryControlUrl'] as String? ?? '',
      manufacturer: json['manufacturer'] as String?,
      modelName: json['modelName'] as String?,
      iconUrl: json['iconUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? true,
    );
  }

  DlnaMediaServer copyWith({
    String? id,
    String? friendlyName,
    String? host,
    int? port,
    String? locationUrl,
    String? contentDirectoryControlUrl,
    String? manufacturer,
    String? modelName,
    String? iconUrl,
    bool? isOnline,
  }) {
    return DlnaMediaServer(
      id: id ?? this.id,
      friendlyName: friendlyName ?? this.friendlyName,
      host: host ?? this.host,
      port: port ?? this.port,
      locationUrl: locationUrl ?? this.locationUrl,
      contentDirectoryControlUrl: contentDirectoryControlUrl ?? this.contentDirectoryControlUrl,
      manufacturer: manufacturer ?? this.manufacturer,
      modelName: modelName ?? this.modelName,
      iconUrl: iconUrl ?? this.iconUrl,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

/// Result returned from a UPnP ContentDirectory SOAP Browse operation.
class DlnaBrowseResult {
  final String containerId;
  final List<NetworkMediaItem> items;
  final int totalMatches;
  final int numberReturned;

  const DlnaBrowseResult({
    required this.containerId,
    required this.items,
    this.totalMatches = 0,
    this.numberReturned = 0,
  });
}
