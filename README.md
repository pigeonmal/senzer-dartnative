# Senzer DartNative community plugins

Public, app-agnostic DartNative plugins with a focus on native performance and
small, stable C ABIs. This repository is intentionally independent of Senzer
products, services, credentials, and private model assets.

## Packages

| Package | Purpose |
| --- | --- |
| [`senzer_mmkv`](packages/senzer_mmkv) | Synchronous, Tencent MMKV Core-backed storage with AES encryption for DartNative |

Packages are designed for `dn pub get` and generated
`DartNativePluginRegistrant` registration. Native code is shared between iOS
and Android where possible; platform adapters only provide lifecycle and
sandbox paths.

```bash
cd packages/senzer_mmkv
dn pub get
dn analyze
dn test
```

## Scope and compatibility

The repository is community-maintained and uses no Senzer application data.
Each package documents its compatibility and known limitations in its own
README. New packages should use an MIT, BSD-3-Clause, or Apache-2.0 license and
must not bundle secrets or private service endpoints.
