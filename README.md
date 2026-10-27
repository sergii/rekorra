# Rekorra

Rails-native, modular administration and back-office engine.

Rekorra is an early technical prototype. Nothing is production-ready or security-audited yet.

See [incremental development steps](docs/steps/README.md) and [architecture decisions](docs/adr/README.md).

## Monorepo

- `lib/rekorra` and `app/`: installable Rails Engine gem
- `test/dummy`: real Rails host application for integration and demo data
- `test`: automated tests for each vertical slice
- `docs/steps`: one verifiable record per increment

The host app does not need npm, yarn, React, or a JavaScript build pipeline.
