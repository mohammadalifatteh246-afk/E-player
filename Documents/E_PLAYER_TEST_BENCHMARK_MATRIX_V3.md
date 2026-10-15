# E-PLAYER V3 — TEST & BENCHMARK MATRIX

## Playback
- 360p/480p/720p/1080p/1440p/2160p
- H.264/HEVC/VP9/AV1 where available
- 8-bit/10-bit where available
- MKV/MP4/AVI/MOV/TS/VOB/WebM/WMV and other shipped-container claims
- multiple audio/subtitle tracks

## Decoder
For every test record requested mode, actual mode, backend, FPS, dropped frames, CPU, thermal behavior.

## Lifecycle
- initial open
- first seek
- pause/resume
- orientation
- surface recreation
- background/foreground
- track switch
- app restart.

## Gestures
- each gesture alone
- simultaneous touches
- system-edge conflict
- accessibility mode
- accidental-tap resistance

## Audio
- EQ gain sweep
- Bass Boost
- limiter
- preamp
- virtualizer on/off
- pitch correction at 0.25x/1x/2x/4x/8x
- clipping test

## Subtitles
- SRT/VTT/ASS/SSA
- embedded/external
- delay -30s/0/+30s
- style
- encoding
- missing font
- long line
- rapid dialogue

## Library
- empty
- 1k/5k media items where feasible
- incremental rescan
- exclusions
- duplicate detection
- missing/deleted media

## Vault
- wrong PIN
- biometric fail
- app restart
- device reboot
- corrupted encrypted chunk
- trash restore
- TTL expiry

## Network
- slow Wi-Fi
- disconnect/reconnect
- HLS quality switching
- auth failure
- malformed URL
- large NAS file

## Cast
- discovery
- connect/disconnect
- play/pause/seek/volume
- local file server
- token expiry
- network loss

## AI
- model missing
- wrong checksum
- runtime unavailable
- CPU fallback
- tile boundaries
- cancellation
- low memory
- long export
- output synchronization

## Performance targets
Targets must be defined per device class instead of universal numbers.
Record median/p95 startup, inference latency, playback FPS, dropped frames, RAM, battery/thermal state.

## Release blockers
Any P0 crash, data loss, security failure, persistent A/V drift, corrupt export, unbounded memory growth, or false AI status blocks release.
