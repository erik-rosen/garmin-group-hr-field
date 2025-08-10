# HR Mesh (Edge 1040) — Connect IQ Data Field

Peer-to-peer sharing of heart rate between nearby riders using ANT Generic Channel.
Tested target: Edge 1040 (minApi 4.1).

## Build
1. Install Connect IQ SDK Manager and device support for Edge 1040.
2. Open this folder in VS Code with the Connect IQ extension.
3. Build to produce `.prg`.

## Install
Copy the built `.prg` to `GARMIN/APPS/` on your Edge 1040 via USB.

## Use
- Add **HR Mesh** as a data field to an activity screen.
- In Garmin Connect Mobile → Devices → Apps → HR Mesh → Settings:
  - Set **Group Code** (same for all riders).
  - Toggle **Broadcast my HR** on/off.

## Notes
- Uses an 8-byte ANT broadcast at ~2 Hz from the data field (channel period ~8 Hz).
- Peers are shown with last-seen age; entries older than 10s are dropped.
- This is a prototype; collision jitter & cloud relay can be added next.
