# FreezeRay Roadmap

**Mission:** Make SwiftData schema management safe and predictable for production iOS apps.

**Core Value:** "Freeze your schemas like you freeze your dependencies - know exactly what ships."

---

## Phase 1: Foundation ✅ COMPLETE

**Goal:** Prove the concept with macro-based schema freezing

**Outcomes:**
- ✅ Swift macros generate freeze/check/test methods
  - `@FreezeSchema` generates `__freezeray_freeze_` and `__freezeray_check_`
  - `@TestMigrations` generates `__freezeray_test_migrations()`
- ✅ SQLite-based fixture export (iOS native, no shell commands)
- ✅ SHA256-based drift detection
- ✅ Cross-platform support (macOS + iOS Simulator)

**Versions:** v0.1.0 - v0.3.0

---

## Phase 2: CLI Architecture 🚧 IN PROGRESS

**Goal:** Enable practical usage in real iOS projects

**Key Insight:** Macro-only approach can't write to source tree in iOS simulator. Solution: Hybrid CLI + Macro architecture.

**Outcomes:**
- ✅ CLI tool (`freezeray freeze <version>`)
- ✅ AST-based schema discovery (SwiftSyntax)
- ✅ Simulator orchestration
- ✅ Fixture extraction from ephemeral test containers
- ✅ Convention-over-configuration (auto-detect everything)
- ✅ Versioned fixture filenames
- 🚧 Test scaffolding (drift + migration tests)
  - ✅ Sprint 2 Phase 1: Macro generates per-version migration functions
  - 📋 Sprint 2 Phase 2: CLI scaffolds drift test files
  - 📋 Sprint 2 Phase 3: CLI scaffolds migration test files

**Versions:** v0.4.0 (current)

**Status:** Sprint 1 complete, Sprint 2 Phase 1 complete, Sprint 2 Phase 2 in progress

---

## Phase 3: Production Readiness 📋 PLANNED

**Goal:** Battle-tested tool ready for real apps

**Outcomes:**
- Pre-built binaries (Homebrew, GitHub Releases)
- Comprehensive documentation & video walkthrough
- CI/CD integration examples
- Performance optimization for large schemas
- Error handling & recovery strategies
- Xcode project conversion (TestApp as real .xcodeproj)

**Target:** v1.0.0

---

## Phase 4: Advanced Validation 🎯 FUTURE

**Goal:** Catch data integrity issues before production

**Outcomes:**
- Sample data migration testing
- Lossy migration detection (data deletion warnings)
- Performance benchmarks for migrations
- Schema diff visualization
- Custom validation hooks
- CloudKit sync validation (detect custom migration incompatibilities)

**Target:** v1.1.0 - v1.2.0

**CloudKit Challenge:** Custom `MigrationStage` implementations break CloudKit sync ([known iOS bug](https://stackoverflow.com/questions/78710730)). Need reliable detection method for CloudKit-incompatible migrations before they ship.

---

## Phase 5: Ecosystem Integration 🔮 VISION

**Goal:** Seamless integration with developer workflows

**Outcomes:**
- Xcode extension/plugin
- VS Code extension
- SwiftPM plugin (`swift package freeze-schemas`)
- GitHub Actions integration
- Multi-platform support (watchOS, tvOS, visionOS)

**Target:** v2.0.0+

---

## Success Metrics

### Adoption
- 100+ GitHub stars in first 3 months
- 10+ production apps using it
- Mentioned in SwiftData tutorials/blogs

### Quality
- Zero critical bugs in first month
- 95%+ test coverage
- Support for latest Xcode versions

### Community
- 5+ community PRs merged
- Active discussions & feedback
- Positive reception from iOS community

---

## Current Focus

**Sprint 1 (Complete):** `freezeray freeze` command with fixture extraction

**Sprint 2 Phase 1 (Complete):** Macro generates per-version migration functions (`__freezeray_test_migrate_X_to_Y`)

**Sprint 2 Phase 2 (In Progress):** CLI scaffolds drift test files

**Sprint 2 Phase 3 (Planned):** CLI scaffolds migration test files

**After v0.4.0:** Production polish, distribution, documentation

---

## Design Principles

1. **User-owned tests** - Scaffolded once, customizable forever
2. **Convention over configuration** - Zero config for standard projects
3. **iOS-first** - Designed for real-world iOS app constraints
4. **Fail fast** - Catch schema changes before production
5. **Developer experience** - Clear errors, helpful guidance

---

For detailed implementation notes, see:
- [ADRs](/project/adr/) - Technical decisions
- [Sprints](/project/sprints/) - Implementation milestones
- [README](/README.md) - User documentation
