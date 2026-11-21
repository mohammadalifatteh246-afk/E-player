# Cast Dual-Protocol Real Discovery (mDNS + SSDP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all hardcoded mock demo cast devices, fix real network device discovery via RFC 6762 QU-bit mDNS + SSDP UPnP MediaRenderer discovery across Windows network adapters, and wire live DLNA playback execution.

**Architecture:** 
1. **Core Service Cleanup:** Remove hardcoded demo devices in `CastService` (`_devices = []`), updating UI to show dynamic Wi-Fi scan state and empty state.
2. **mDNS QU-Bit RFC 6762 Alignment:** Set QCLASS to `0x8001` (QU bit enabled) in mDNS queries so responders reply directly via unicast to ephemeral socket ports.
3. **SSDP UPnP Discovery Engine:** Implement pure Dart `SsdpDiscoveryService` broadcasting M-SEARCH to `239.255.255.250:1900` across all active IPv4 network interfaces to detect Smart TVs (Samsung, LG, Sony, Roku).
4. **DLNA Remote Playback Trigger:** Send UPnP AVTransport `SetAVTransportURI` and `Play` SOAP requests on connect so Smart TVs immediately stream from `LocalStreamingDaemon`.

**Tech Stack:** Flutter 3.x, Dart 3.x (`dart:io`, `RawDatagramSocket`, `HttpClient`, `NetworkInterface`). Pure Dart with zero native plugins (FAT32 safe).

**Spec:** Approach A selected by user from forensic audit.

---

## Global Constraints
- **NO THIRD-PARTY NATIVE PLUGINS**: Must NOT modify `pubspec.yaml` with native plugins due to FAT32 filesystem symlink constraints. Use pure `dart:io`.
- Always pass `--no-pub` to `flutter test` and `flutter analyze`.
- All tests must pass with 0 errors and `flutter analyze` must return 0 issues.

---

## Tasks

### Task 1: Cleanse Hardcoded Demo Devices & Add Empty/Scanning UI States
- [x] In `app/lib/features/casting/domain/cast_service.dart`, remove all hardcoded mock devices (`chromecast_living_room`, `appletv_studio`, etc.) and initialize `_devices = [];`.
- [x] In `app/lib/features/casting/ui/cast_sheet.dart`, add empty-state card when `displayedDevices.isEmpty`:
  - When `castService.isScanning`: display animated Wi-Fi radar indicator with "Scanning local Wi-Fi for Chromecast & Smart TVs...".
  - When not scanning: display "No casting devices detected on this network. Tap 'Scan' to refresh" with a "Scan for Devices" button.
- [x] Update `app/test/unit/cast_service_test.dart` to assert initial devices list is empty.

### Task 2: Fix mDNS Query Protocol with RFC 6762 QU Bit (Unicast Response)
- [x] In `app/lib/features/cast/data/cast_discovery_service.dart`:
  - In `encodeDnsPtrQuery`, change QCLASS bytes from `[0x00, 0x01]` to `[0x80, 0x01]` (0x8000 QU bit = unicast response requested, required by RFC 6762 when querier port != 5353).
- [x] Enumerate `NetworkInterface.list(type: InternetAddressType.IPv4)` in `DefaultCastSocketTransport`:
  - Bind socket to `InternetAddress.anyIPv4`, set `broadcastEnabled = true`, `multicastHops = 255`, and join multicast group `224.0.0.251` across all valid non-loopback network interfaces.
- [x] Verify with unit test in `app/test/unit/cast_service_mdns_integration_test.dart`.

### Task 3: Implement Pure Dart SSDP Discovery for Smart TVs (Samsung, LG, Sony, Roku)
- [x] Create `app/lib/features/cast/data/ssdp_discovery_service.dart`:
  - Raw UDP socket sending M-SEARCH datagrams to `239.255.255.250:1900` for `urn:schemas-upnp-org:device:MediaRenderer:1` and `ssdp:all`.
  - Parse HTTP 200 responses for `LOCATION`, `ST`, `USN`.
  - Fetch device XML descriptor from `LOCATION` using `HttpClient` with 2.5s timeout to extract `friendlyName`, `modelName`, `AVTransport` control URL.
  - Return/emit discovered devices as `CastDevice` with `CastProtocol.dlna`.
- [x] Integrate SSDP discovery into `CastDiscoveryService` so both mDNS and SSDP streams merge into `devicesStream`.
- [x] Write unit tests in `app/test/unit/ssdp_discovery_test.dart`.

### Task 4: Implement DLNA AVTransport Action Dispatch on Connect
- [x] In `app/lib/features/casting/domain/cast_service.dart`:
  - In `connect(CastDevice device)`, if `device.protocol == CastProtocol.dlna` and device has an AVTransport control URL, send `SetAVTransportURI` and `Play` SOAP requests to the TV via `HttpClient`.
  - Include graceful error handling and fallback so local stream daemon keeps running.

### Task 5: Verification & End-to-End Validation
- [x] Run `flutter analyze --no-pub` to verify 0 errors and 0 warnings.
- [x] Run `flutter test --no-pub` across all cast tests (`cast_service_test.dart`, `cast_service_mdns_integration_test.dart`, `ssdp_discovery_test.dart`).
- [x] Commit and push to `origin/main`.
