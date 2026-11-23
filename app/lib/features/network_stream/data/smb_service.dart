library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/smb_models.dart';

typedef SmbSocketConnector = Future<Socket> Function(dynamic host, int port, {Duration? timeout});

/// Service managing SMB share connectivity probing and recent share history.
class SmbShareService extends ChangeNotifier {
  static const String prefsKeyRecentSmb = 'e_player_recent_smb_shares';
  static const int maxRecentShares = 5;

  SharedPreferences? _prefs;
  final SmbSocketConnector _socketConnector;
  List<SmbRecentShare> _recentShares = [];

  SmbShareService({
    SharedPreferences? prefs,
    SmbSocketConnector? socketConnector,
  })  : _socketConnector = socketConnector ?? Socket.connect {
    _prefs = prefs;
    _loadRecentShares();
  }

  /// Initializes or updates the service with loaded [SharedPreferences].
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _loadRecentShares();
    notifyListeners();
  }

  List<SmbRecentShare> get recentShares => List.unmodifiable(_recentShares);

  void _loadRecentShares() {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final rawList = prefs.getStringList(prefsKeyRecentSmb);
      if (rawList != null) {
        _recentShares = rawList
            .map((item) {
              try {
                return SmbRecentShare.fromJson(
                    jsonDecode(item) as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<SmbRecentShare>()
            .toList();
      }
    } catch (_) {}
  }

  Future<void> saveRecentShare(SmbShareConfig config) async {
    // Remove if already exists with same host and shareName
    _recentShares.removeWhere(
      (r) =>
          r.config.host.toLowerCase() == config.host.toLowerCase() &&
          r.config.shareName.toLowerCase() == config.shareName.toLowerCase(),
    );

    // Add to front
    _recentShares.insert(
      0,
      SmbRecentShare(config: config, lastAccessed: DateTime.now()),
    );

    // Limit to maxRecentShares (FIFO)
    if (_recentShares.length > maxRecentShares) {
      _recentShares = _recentShares.sublist(0, maxRecentShares);
    }

    notifyListeners();

    final prefs = _prefs;
    if (prefs != null) {
      final jsonList =
          _recentShares.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(prefsKeyRecentSmb, jsonList);
    }
  }

  Future<void> clearRecentShares() async {
    _recentShares.clear();
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(prefsKeyRecentSmb);
    }
  }

  /// Probes TCP port connectivity (default port 445) on the given host.
  /// Returns `true` if port is open and reachable within [timeout].
  Future<bool> probeHost(
    String host, {
    int port = 445,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) return false;
    try {
      final socket = await _socketConnector(
        cleanHost,
        port > 0 ? port : 445,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
