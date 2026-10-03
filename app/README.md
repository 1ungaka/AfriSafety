# AfriSafety app (Flutter)

See the [root README](../README.md) for setup, and [CLAUDE.md](../CLAUDE.md)
for conventions.

```
lib/
  bootstrap.dart   config validation, libsodium init, error handlers
  app.dart         MaterialApp.router, theme, localisation
  core/            config, crypto, logging, theme, routing, shared widgets
  features/        one folder per feature: data/ domain/ presentation/
  l10n/            ARB strings (generated Dart files are committed)
test/
  architecture/    guards for CLAUDE.md security rules
  core/            unit + widget tests mirroring lib/core
```
