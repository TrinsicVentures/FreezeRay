# Changelog

All notable changes to FreezeRay will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-09

### Added
- `@FreezeRay.Freeze(version:)` macro to freeze SwiftData schema versions
- `@FreezeRay.AutoTests` macro to generate migration smoke tests
- Automatic fixture generation (App.sqlite, schema.json, schema.sql, schema.sha256)
- SHA256-based drift detection that fails builds on schema changes
- Migration testing from all frozen versions to HEAD
- Complete integration test suite with SampleApp
- Swift Testing support (no XCTest dependencies)
- Comprehensive README with examples and best practices

### Technical Details
- Built with Swift 6.2 and strict concurrency
- Uses SwiftSyntax for macro implementation
- Generates DEBUG-only test methods with `#if DEBUG` guards
- Compatible with macOS 14+ and iOS 17+

[0.1.0]: https://github.com/didgeoridoo/FreezeRay/releases/tag/0.1.0
