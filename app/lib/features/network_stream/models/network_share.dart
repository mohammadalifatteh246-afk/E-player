/// Supported network streaming and sharing protocols.
enum NetworkProtocol {
  smb,
  upnpDlna,
  nfs,
  webdav,
  http,
}

/// Represents a local network media share or media server.
class NetworkShare {
  final String id;
  final String name;
  final String host;
  final int port;
  final NetworkProtocol protocol;
  final String sharedPath;
  final String? username;
  final String? password;
  final bool isAnonymous;
  final Map<String, dynamic> metadata;

  const NetworkShare({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.sharedPath = '',
    this.username,
    this.password,
    this.isAnonymous = true,
    this.metadata = const {},
  });

  /// Derives default port based on protocol if port is 0 or unspecified.
  static int defaultPortFor(NetworkProtocol protocol) {
    switch (protocol) {
      case NetworkProtocol.smb:
        return 445;
      case NetworkProtocol.upnpDlna:
        return 8200; // Common default for MiniDLNA / UPnP
      case NetworkProtocol.nfs:
        return 2049;
      case NetworkProtocol.webdav:
        return 80;
      case NetworkProtocol.http:
        return 80;
    }
  }

  /// Constructs the canonical URI for accessing this share.
  Uri toUri({String? subPath}) {
    final scheme = protocol == NetworkProtocol.upnpDlna ? 'http' : protocol.name;
    final cleanPath = _combinePaths(sharedPath, subPath);

    String? userInfo;
    if (!isAnonymous && username != null && username!.isNotEmpty) {
      if (password != null && password!.isNotEmpty) {
        userInfo = '$username:$password';
      } else {
        userInfo = username;
      }
    }

    final isDefaultPort = (protocol == NetworkProtocol.smb && port == 445) ||
        (protocol == NetworkProtocol.http && port == 80) ||
        (protocol == NetworkProtocol.webdav && port == 80);

    return Uri(
      scheme: scheme,
      userInfo: userInfo,
      host: host,
      port: (port > 0 && !isDefaultPort) ? port : null,
      path: cleanPath.startsWith('/') ? cleanPath : '/$cleanPath',
    );
  }

  factory NetworkShare.fromJson(Map<String, dynamic> json) {
    final protocolStr = json['protocol']?.toString() ?? 'smb';
    final protocol = NetworkProtocol.values.firstWhere(
      (p) => p.name.toLowerCase() == protocolStr.toLowerCase(),
      orElse: () => NetworkProtocol.smb,
    );

    return NetworkShare(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['host']?.toString() ?? 'Network Share',
      host: json['host']?.toString() ?? '',
      port: json['port'] is int ? json['port'] as int : int.tryParse(json['port']?.toString() ?? '0') ?? 0,
      protocol: protocol,
      sharedPath: json['sharedPath']?.toString() ?? json['shared_path']?.toString() ?? '',
      username: json['username']?.toString(),
      password: json['password']?.toString(),
      isAnonymous: json['isAnonymous'] == true || json['is_anonymous'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'protocol': protocol.name,
      'sharedPath': sharedPath,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      'isAnonymous': isAnonymous,
      'metadata': metadata,
    };
  }

  NetworkShare copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    NetworkProtocol? protocol,
    String? sharedPath,
    String? username,
    String? password,
    bool? isAnonymous,
    Map<String, dynamic>? metadata,
  }) {
    return NetworkShare(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      sharedPath: sharedPath ?? this.sharedPath,
      username: username ?? this.username,
      password: password ?? this.password,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkShare &&
        other.id == id &&
        other.host == host &&
        other.port == port &&
        other.protocol == protocol &&
        other.sharedPath == sharedPath;
  }

  @override
  int get hashCode => Object.hash(id, host, port, protocol, sharedPath);

  @override
  String toString() => 'NetworkShare($name, ${protocol.name}://$host:$port/$sharedPath)';

  static String _combinePaths(String base, String? sub) {
    if (sub == null || sub.isEmpty) return base;
    if (base.isEmpty) return sub;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanSub = sub.startsWith('/') ? sub.substring(1) : sub;
    return '$cleanBase/$cleanSub';
  }
}

/// Represents an individual directory or media stream item inside a network share.
class NetworkMediaItem {
  final String id;
  final String shareId;
  final String title;
  final String path;
  final String streamUrl;
  final bool isDirectory;
  final int? sizeBytes;
  final Duration? duration;
  final String? mimeType;
  final List<NetworkMediaItem> children;

  const NetworkMediaItem({
    required this.id,
    required this.shareId,
    required this.title,
    required this.path,
    required this.streamUrl,
    required this.isDirectory,
    this.sizeBytes,
    this.duration,
    this.mimeType,
    this.children = const [],
  });

  bool get isVideo {
    if (isDirectory) return false;
    final lower = (mimeType ?? path).toLowerCase();
    return lower.contains('video') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.wmv');
  }

  bool get isAudio {
    if (isDirectory) return false;
    final lower = (mimeType ?? path).toLowerCase();
    return lower.contains('audio') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.opus');
  }

  bool get isSubtitle {
    if (isDirectory) return false;
    final lower = path.toLowerCase();
    return lower.endsWith('.srt') ||
        lower.endsWith('.vtt') ||
        lower.endsWith('.ass') ||
        lower.endsWith('.ssa') ||
        lower.endsWith('.sub');
  }

  factory NetworkMediaItem.fromJson(Map<String, dynamic> json) {
    Duration? duration;
    final rawDuration = json['durationMs'] ?? json['duration_ms'];
    if (rawDuration is int) {
      duration = Duration(milliseconds: rawDuration);
    } else if (rawDuration is String) {
      final parsed = int.tryParse(rawDuration);
      if (parsed != null) duration = Duration(milliseconds: parsed);
    }

    final childrenList = <NetworkMediaItem>[];
    if (json['children'] is List) {
      for (final child in json['children'] as List) {
        if (child is Map<String, dynamic>) {
          childrenList.add(NetworkMediaItem.fromJson(child));
        }
      }
    }

    return NetworkMediaItem(
      id: json['id']?.toString() ?? '',
      shareId: json['shareId']?.toString() ?? json['share_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString() ?? json['stream_url']?.toString() ?? '',
      isDirectory: json['isDirectory'] == true || json['is_directory'] == true,
      sizeBytes: json['sizeBytes'] is int ? json['sizeBytes'] as int : int.tryParse(json['sizeBytes']?.toString() ?? ''),
      duration: duration,
      mimeType: json['mimeType']?.toString() ?? json['mime_type']?.toString(),
      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shareId': shareId,
      'title': title,
      'path': path,
      'streamUrl': streamUrl,
      'isDirectory': isDirectory,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (duration != null) 'durationMs': duration!.inMilliseconds,
      if (mimeType != null) 'mimeType': mimeType,
      if (children.isNotEmpty) 'children': children.map((c) => c.toJson()).toList(),
    };
  }

  NetworkMediaItem copyWith({
    String? id,
    String? shareId,
    String? title,
    String? path,
    String? streamUrl,
    bool? isDirectory,
    int? sizeBytes,
    Duration? duration,
    String? mimeType,
    List<NetworkMediaItem>? children,
  }) {
    return NetworkMediaItem(
      id: id ?? this.id,
      shareId: shareId ?? this.shareId,
      title: title ?? this.title,
      path: path ?? this.path,
      streamUrl: streamUrl ?? this.streamUrl,
      isDirectory: isDirectory ?? this.isDirectory,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      duration: duration ?? this.duration,
      mimeType: mimeType ?? this.mimeType,
      children: children ?? this.children,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkMediaItem &&
        other.id == id &&
        other.shareId == shareId &&
        other.path == path &&
        other.streamUrl == streamUrl;
  }

  @override
  int get hashCode => Object.hash(id, shareId, path, streamUrl);

  @override
  String toString() => 'NetworkMediaItem($title, dir=$isDirectory, url=$streamUrl)';
}
