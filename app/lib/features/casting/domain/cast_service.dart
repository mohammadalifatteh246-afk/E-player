import 'dart:async';
import 'package:flutter/foundation.dart';

/// Supported Wireless Cast Protocols
enum CastProtocol {
  chromecast('Chromecast V2', 'Google Cast', 0xFF19BFFF),
  airplay('AirPlay 2', 'Apple AirPlay', 0xFFE741FF),
  dlna('DLNA / UPnP', 'Universal Media', 0xFF00E676),
  miracast('Miracast Direct', 'Wi-Fi Display', 0xFFFFB300);

  final String label;
  final String description;
  final int colorHex;

  const CastProtocol(this.label, this.description, this.colorHex);
}

/// Represents a discovered wireless network display target
class CastDevice {
  final String id;
  final String name;
  final CastProtocol protocol;
  final String model;
  final String ipAddress;
  final int signalPercentage;
  final String resolutionCapability;
  bool isConnected;
  bool isConnecting;

  CastDevice({
    required this.id,
    required this.name,
    required this.protocol,
    required this.model,
    required this.ipAddress,
    required this.signalPercentage,
    required this.resolutionCapability,
    this.isConnected = false,
    this.isConnecting = false,
  });

  CastDevice copyWith({
    bool? isConnected,
    bool? isConnecting,
  }) {
    return CastDevice(
      id: id,
      name: name,
      protocol: protocol,
      model: model,
      ipAddress: ipAddress,
      signalPercentage: signalPercentage,
      resolutionCapability: resolutionCapability,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
    );
  }
}

/// Service managing network device discovery radar and remote casting session
class CastService extends ChangeNotifier {
  bool _isScanning = false;
  Timer? _scanTimer;
  Timer? _simulatedDiscoveryTimer;

  final List<CastDevice> _devices = [
    CastDevice(
      id: 'chromecast_living_room',
      name: 'Living Room Chromecast Ultra',
      protocol: CastProtocol.chromecast,
      model: 'Google Chromecast Ultra 4K',
      ipAddress: '192.168.1.104',
      signalPercentage: 98,
      resolutionCapability: '4K UHD · 60 FPS',
    ),
    CastDevice(
      id: 'appletv_studio',
      name: 'Studio Apple TV 4K',
      protocol: CastProtocol.airplay,
      model: 'Apple TV 4K (3rd Gen)',
      ipAddress: '192.168.1.118',
      signalPercentage: 92,
      resolutionCapability: '4K Dolby Vision',
    ),
    CastDevice(
      id: 'sony_bravia_theater',
      name: 'Home Theater Sony Bravia',
      protocol: CastProtocol.dlna,
      model: 'Sony XR-65A80J OLED',
      ipAddress: '192.168.1.150',
      signalPercentage: 100,
      resolutionCapability: '4K HDR10 · eARC',
    ),
    CastDevice(
      id: 'samsung_bedroom',
      name: 'Bedroom Samsung Neo QLED',
      protocol: CastProtocol.dlna,
      model: 'Samsung QN90B 55"',
      ipAddress: '192.168.1.162',
      signalPercentage: 76,
      resolutionCapability: '4K UHD · HDR',
    ),
    CastDevice(
      id: 'shield_guest',
      name: 'Guest Room Android TV',
      protocol: CastProtocol.chromecast,
      model: 'NVIDIA Shield TV Pro',
      ipAddress: '192.168.1.175',
      signalPercentage: 68,
      resolutionCapability: '4K 60FPS · AI Upscale',
    ),
  ];

  CastDevice? _connectedDevice;
  double _remoteVolume = 0.75;
  bool _isMuted = false;
  bool _isRemotePlaying = true;
  String _audioRoute = 'tv'; // 'tv', 'device', 'bluetooth'

  List<CastDevice> get devices => List.unmodifiable(_devices);
  CastDevice? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  double get remoteVolume => _remoteVolume;
  bool get isMuted => _isMuted;
  bool get isRemotePlaying => _isRemotePlaying;
  String get audioRoute => _audioRoute;

  CastService() {
    startScan();
  }

  /// Start mDNS / SSDP discovery radar simulation
  Future<void> startScan() async {
    _isScanning = true;
    notifyListeners();

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 12), () {
      _isScanning = false;
      notifyListeners();
    });
  }

  void stopScan() {
    _scanTimer?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  /// Connect to selected target device
  Future<bool> connect(CastDevice device) async {
    // If another device is connected, disconnect first
    if (_connectedDevice != null && _connectedDevice!.id != device.id) {
      _connectedDevice!.isConnected = false;
      _connectedDevice = null;
    }

    device.isConnecting = true;
    notifyListeners();

    // Handshake delay simulation
    await Future.delayed(const Duration(milliseconds: 700));

    device.isConnecting = false;
    device.isConnected = true;
    _connectedDevice = device;
    _isRemotePlaying = true;
    notifyListeners();
    return true;
  }

  /// Disconnect current casting session
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      _connectedDevice!.isConnected = false;
      _connectedDevice!.isConnecting = false;
      _connectedDevice = null;
      notifyListeners();
    }
  }

  void setRemoteVolume(double volume) {
    _remoteVolume = volume.clamp(0.0, 1.0);
    if (_remoteVolume > 0 && _isMuted) {
      _isMuted = false;
    }
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleRemotePlayPause() {
    _isRemotePlaying = !_isRemotePlaying;
    notifyListeners();
  }

  void setAudioRoute(String route) {
    _audioRoute = route;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _simulatedDiscoveryTimer?.cancel();
    super.dispose();
  }
}
