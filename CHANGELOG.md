# Changelog

All notable changes to FreezeRay will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Swift macro package for freezing SwiftData schemas
- `@FreezeSchema(version:fixtureDir:)` macro generates test methods to export SQL
- `@GenerateMigrationTests` macro generates migration smoke tests
- SampleApp demonstrating macro usage with 3 schema versions
- Runtime client for schema freezing and migration testing

### Changed
- Switched from script-based approach to Swift macros for better IDE integration
- Removed `.freezeray.yml` requirement - `fixtureDir` now passed as macro parameter
- Default `fixtureDir` is `"Tests/Fixtures/SwiftData"`

### Implementation Details
- Macros expand at compile time using SwiftSyntax
- Support for implicit returns in computed properties
- Proper handling of versioned schema enums
- Migration tests generated for both individual steps and full migration path
