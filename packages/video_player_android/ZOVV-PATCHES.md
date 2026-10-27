# ZOVV Android adaptation

Based on Flutter `video_player_android` 2.12.2. Original BSD license, AUTHORS,
generated API sources and upstream history remain in this directory.

Local changes are isolated to Android Java code:

- Optional media caching only when `X-Zovv-Cache-Key` supplies a gateway-verified
  identity. HLS/DASH manifests bypass the cache; media uses a shared 150 MiB LRU
  cache under Android's private cache directory, excluded from normal backups.
- Cache identities separate source versions, episodes, quality and asset names.
  Cache failures fall back to the upstream data source.
- Load control targets 8–20 seconds and 16 MiB of encoded buffers per player,
  with a 750ms startup threshold and 1500ms rebuffer threshold. These are targets,
  not guarantees or a total-process memory cap. Native decoder memory is separate.
- A `zovv/video-cache` method channel reports usage and supports clearing only
  when no active media read is in progress. App settings exposes this after exit.

No iOS implementation is modified. Future upgrades must rebase these small
patches onto a new upstream version and repeat Android simulator/native checks.
