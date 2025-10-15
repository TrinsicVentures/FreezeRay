# FreezeRay Roadmap

**Mission:** Make SwiftData schema management safe and predictable for production iOS apps.

**Core Value:** "Freeze your schemas like you freeze your dependencies - know exactly what ships."

---

## Phase 1: Foundation ✅ COMPLETE

**Goal:** Prove the concept with macro-based schema freezing

**Outcomes:**
- ✅ Swift macro generates freeze/check methods
  - `@FreezeSchema` generates `__freezeray_freeze_` and `__freezeray_check_`
- ✅ SQLite-based fixture export (iOS native, no shell commands)
- ✅ SHA256-based drift detection
- ✅ Cross-platform support (macOS + iOS Simulator)

**Versions:** v0.1.0 - v0.3.0

---

## Phase 2: CLI Architecture ✅ COMPLETE

**Goal:** Enable practical usage in real iOS projects

**Key Insight:** Macro-only approach can't write to source tree in iOS simulator. Solution: Hybrid CLI + Macro architecture.

**Outcomes:**
- ✅ CLI tool (`freezeray freeze <version>`)
- ✅ CLI initialization (`freezeray init`)
- ✅ AST-based schema discovery (SwiftSyntax)
- ✅ Migration plan auto-discovery (no annotation needed)
- ✅ Simulator orchestration
- ✅ Fixture extraction from ephemeral test containers
- ✅ Convention-over-configuration (auto-detect everything)
- ✅ Versioned fixture filenames
- ✅ Test scaffolding (drift + migration tests)
  - ✅ Sprint 2: Removed @TestMigrations macro, scaffolds tests calling runtime directly
  - ✅ Sprint 2: CLI scaffolds drift test files
  - ✅ Sprint 2: CLI scaffolds migration test files
- ✅ E2E validation passed (2025-10-13)
  - ✅ All 3 versions frozen successfully
  - ✅ 3 critical bugs discovered and fixed
  - ✅ FreezeRayTestApp is a real Xcode project
- ✅ npm distribution (Sprint 4)
  - ✅ Published as `@trinsicventures/freezeray`
  - ✅ Easy installation: `npm install -g @trinsicventures/freezeray`
  - ✅ Apple Silicon binary (21MB)
- ✅ Documentation site (Sprint 4)
  - ✅ Live at docs.freezeray.dev
  - ✅ Custom domain configured
  - ✅ Mintlify platform with auto-deploy
  - ✅ Documented 3 real SwiftData problems with layered defense
- ✅ Task automation (Sprint 4)
  - ✅ mise tasks for build, test, publish
  - ✅ Centralized workflow management

**Versions:** v0.4.0 - v0.4.1

**Status:** ✅ Complete and validated (Sprints 1-4)

---

## Phase 3: Production Readiness 🚧 IN PROGRESS

**Goal:** Battle-tested tool ready for real apps

**Completed:**
- ✅ Documentation site (docs.freezeray.dev) - Live with basic content
- ✅ npm distribution (@trinsicventures/freezeray)

**Remaining:**
- Documentation content (fill placeholder pages)
  - Concepts pages (schema-freezing.mdx, migration-testing.mdx, drift-detection.mdx)
  - CLI reference (init.mdx, freeze.mdx)
  - Guides (first-freeze.mdx, testing-migrations.mdx, ci-integration.mdx)
  - Macro reference (freeze-schema.mdx)
- Custom branding for docs site
  - Replace Mintlify logo with FreezeRay logo
  - Custom theme colors beyond defaults
- Pre-built binaries (Homebrew formula, GitHub Releases)
- Video walkthrough
- CI/CD integration examples
- Performance optimization for large schemas
- Error handling & recovery strategies

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

## Phase 6: GUI Application 💎 COMMERCIAL VISION

**Goal:** Professional SwiftData schema management without CLI friction

**Business Model:**
- **Free tier:** CLI tool (open source, always free)
- **Paid tier:** GUI application with advanced features

**GUI Application Features:**
- **Real-time monitoring:** Background daemon watches for schema changes
- **Visual schema diff:** Side-by-side comparison of frozen vs. current schema
- **One-click schema locking:** Freeze schemas with a single button click
- **Schema timeline:** Visual history of all frozen versions
- **Migration path visualization:** Interactive graph of migration dependencies
- **CloudKit integration:** Detect CloudKit-incompatible migrations before deploy
- **Team collaboration:** Share frozen schemas across team members
- **Continuous validation:** Automatic drift detection in background
- **Smart notifications:** Alert when schema changes detected
- **Xcode integration:** Deep links to open relevant files

**CloudKit Features:**
- Schema compatibility checking for CloudKit sync
- Detection of custom migrations that break CloudKit ([known bug](https://stackoverflow.com/questions/78710730))
- Visual warnings for CloudKit-incompatible changes
- CloudKit schema sync status dashboard

**Why GUI vs. CLI:**
- **Lower friction:** No terminal commands to remember
- **Better visualization:** Schema changes are visual, not textual
- **Proactive monitoring:** Catch issues immediately, not during build
- **Team-friendly:** Non-technical stakeholders can review schema changes
- **Professional workflow:** Matches expectations for paid developer tools

**Monetization:**
- Individual developer: $29/year
- Team license (5 seats): $99/year
- Enterprise: Custom pricing
- All proceeds support continued CLI development

**Distribution:**
- Mac App Store (for discoverability)
- Direct download (for power users)
- Both include CLI tool bundled

**Development Strategy:**
1. Build CLI to maturity first (v1.0.0+)
2. Validate market demand and CLI adoption
3. GUI as separate SwiftUI app (reuses CLI backend)
4. Launch as paid companion to free CLI

**Target:** v3.0.0+ (post-v1.0 success validation)

**Success Criteria Before Starting GUI:**
- 1,000+ GitHub stars on CLI repo
- 50+ production apps using CLI
- Proven demand for better SwiftData tooling
- Strong community engagement

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

**Phase 2 (v0.4.0 - v0.4.1): ✅ COMPLETE**
- ✅ Sprint 1: `freezeray freeze` command with fixture extraction
- ✅ Sprint 2: Test scaffolding (drift + migration tests)
- ✅ Sprint 3: `freezeray init` command with auto-detection polish
- ✅ Sprint 4: Documentation site + npm distribution
- ✅ E2E validation passed with 3 critical bugs fixed

**Phase 3 (Production Readiness): 🚧 IN PROGRESS**
- ✅ Documentation site live (docs.freezeray.dev)
- ✅ npm distribution (@trinsicventures/freezeray)
- Next: Fill documentation content (placeholder pages)
- Next: Custom branding (logo, theme)
- Next: Homebrew formula
- Next: CI/CD integration examples

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
- [CLAUDE.md](../CLAUDE.md) - Development guide
