# E-PLAYER ARCHITECTURE HARDENING SPEC V3

## Target architecture
```
Flutter UI
   |
 Application Controllers
   |
 Native Bridge / FFI
   |
 +-------------------------------+
 | E-Player Native Core          |
 | playback | audio | AI | export|
 | library | vault | cast | device|
 +-------------------------------+
   |
 +-- media_kit/libmpv
 +-- platform media services
 +-- ONNX Runtime Mobile
 +-- native DSP
 +-- secure storage
 +-- database
```

## Core interfaces
- `IPlaybackBackend`
- `IDecoderCapabilityService`
- `IAudioEngine`
- `ISubtitleService`
- `ILibraryIndexer`
- `IVaultService`
- `ITrashService`
- `INetworkSource`
- `ICastService`
- `IInferenceRuntime`
- `IModelRegistry`
- `IEnhancementJob`
- `IExportEngine`
- `IDeviceCapabilityService`
- `IThermalPolicy`

## Playback contract
Input media → probe → capability decision → decode path → render → state/diagnostics.

Every decoder mode returns: `requestedMode`, `actualMode`, `backend`, `fallbackReason`.

## Frame processing contract
Never send raw 4K frames as JSON/Base64 through Flutter. Use native buffer ownership. Dart receives commands/status/metrics.

## AI contract
```
ModelManifest
 -> runtime selection
 -> session creation
 -> bounded frame queue
 -> inference
 -> cancellation
 -> release
```

Model manifest fields:
- id
- task
- version
- checksum
- license
- input shape
- precision
- provider support
- memory class
- expected latency
- fallback.

## Vault contract
Plain input → encrypt into app-controlled storage → encrypted index → decrypt only into protected memory/stream → decoder.

No plaintext vault file is kept on persistent storage after successful migration.

## Cast contract
Remote URL: receiver fetches media directly.
Local file: E-Player starts a tokenized one-media LAN server.

Security: random session token, expiry, no directory listing, one authorized object, shutdown after session.

## Database
Use a local database with migrations. Store metadata, not media payloads.

Entities:
Media, Track, Source, WatchProgress, Favorite, SubtitleCache, VaultItem, TrashItem, ModelArtifact, EnhancementJob, DeviceProfile.

## Concurrency
Separate:
- UI/control plane
- playback/data plane
- AI worker plane
- export worker plane.

Queues are bounded. Seek/cancel invalidates stale work.

## Player pooling
Only use a pool for a future vertical/preview feed. Normal E-Player uses one primary active player. Pool size must be measured.

## Failure isolation
AI fails → playback continues.
Subtitle provider fails → local subtitles continue.
Cast fails → local playback continues.
Vault operation fails → source data remains intact.
Export fails → temp file removed; source untouched.

## Observability
Local diagnostic events:
- playback state;
- decoder;
- codec;
- frame drops;
- queue depth;
- inference latency;
- memory;
- export progress;
- thermal downgrade;
- fallback.
No media payload logging.
