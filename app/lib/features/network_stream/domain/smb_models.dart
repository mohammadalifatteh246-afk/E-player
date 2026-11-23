library;

/// Configuration for an SMB / Windows Network Share (VLC `smb2.c` / `dsm.c` Parity).
class SmbShareConfig {
  final String host;
  final int port; // Default 445
  final String shareName;
  final String subPath;
  final String? domain; // Windows Workgroup or Active Directory Domain (e.g. WORKGROUP)
  final String? username;
  final String? password;
  final bool isAnonymous;

  const SmbShareConfig({
    required this.host,
    this.port = 445,
    required this.shareName,
    this.subPath = '',
    this.domain,
    this.username,
    this.password,
    this.isAnonymous = false,
  });

  /// Constructs the unmasked, canonical SMB MRL for libmpv / VLC streaming.
  /// Standard VLC format: `smb://[[domain;]user[:password]@]host[:port]/share/subpath`
  String toMrl() {
    final cleanHost = host.trim();
    final cleanShare = shareName.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final cleanSub = subPath.trim().replaceAll(RegExp(r'^/+|/+$'), '');

    final fullPath = cleanSub.isNotEmpty ? '$cleanShare/$cleanSub' : cleanShare;

    if (isAnonymous || (username == null || username!.trim().isEmpty)) {
      final portPart = (port > 0 && port != 445) ? ':$port' : '';
      return 'smb://$cleanHost$portPart/$fullPath';
    }

    final user = username!.trim();
    final pass = (password != null && password!.isNotEmpty)
        ? ':${Uri.encodeComponent(password!)}'
        : '';
    final dom = (domain != null && domain!.trim().isNotEmpty)
        ? '${domain!.trim()};'
        : '';
    final portPart = (port > 0 && port != 445) ? ':$port' : '';

    return 'smb://$dom$user$pass@$cleanHost$portPart/$fullPath';
  }

  /// Constructs a safe-for-display MRL where passwords are masked with '****'.
  String toSafeDisplayMrl() {
    final cleanHost = host.trim();
    final cleanShare = shareName.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final cleanSub = subPath.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final fullPath = cleanSub.isNotEmpty ? '$cleanShare/$cleanSub' : cleanShare;

    if (isAnonymous || (username == null || username!.trim().isEmpty)) {
      final portPart = (port > 0 && port != 445) ? ':$port' : '';
      return 'smb://$cleanHost$portPart/$fullPath';
    }

    final user = username!.trim();
    final passMask = (password != null && password!.isNotEmpty) ? ':****' : '';
    final dom = (domain != null && domain!.trim().isNotEmpty)
        ? '${domain!.trim()};'
        : '';
    final portPart = (port > 0 && port != 445) ? ':$port' : '';

    return 'smb://$dom$user$passMask@$cleanHost$portPart/$fullPath';
  }

  /// Displays compact label for chip or history item, e.g. "192.168.1.50/Movies"
  String get displayTitle {
    final cleanShare = shareName.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return '$host/$cleanShare';
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'shareName': shareName,
        'subPath': subPath,
        'domain': domain,
        'username': username,
        'isAnonymous': isAnonymous,
        // For safety, password is NOT saved in persistent recent history
      };

  factory SmbShareConfig.fromJson(Map<String, dynamic> json) {
    return SmbShareConfig(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 445,
      shareName: json['shareName'] as String? ?? '',
      subPath: json['subPath'] as String? ?? '',
      domain: json['domain'] as String?,
      username: json['username'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }
}

/// Represents a recently connected SMB share with last accessed timestamp.
class SmbRecentShare {
  final SmbShareConfig config;
  final DateTime lastAccessed;

  const SmbRecentShare({
    required this.config,
    required this.lastAccessed,
  });

  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'lastAccessed': lastAccessed.toIso8601String(),
      };

  factory SmbRecentShare.fromJson(Map<String, dynamic> json) {
    return SmbRecentShare(
      config: SmbShareConfig.fromJson(
          json['config'] as Map<String, dynamic>? ?? {}),
      lastAccessed:
          DateTime.tryParse(json['lastAccessed'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
