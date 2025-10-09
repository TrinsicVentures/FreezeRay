# FreezeRay Public Release Plan

**Status:** Pre-release (internal use only)
**Target:** v1.0.0 public release
**License:** MIT
**Repository:** https://github.com/trinsic/FreezeRay (to be created)

---

## Mission

Make SwiftData schema management safe and predictable for production iOS/macOS apps by providing Swift macros that freeze schemas and generate migration tests.

**Core Value Prop:** "Freeze your schemas like you freeze your dependencies - know exactly what ships."

## Architecture: Swift Macros

FreezeRay uses **Swift macros** instead of external scripts for tight integration with your codebase:

**Benefits:**
- ✅ **Compile-time generation** - Test methods generated during build
- ✅ **Type-safe** - Compiler validates everything
- ✅ **IDE integration** - Xcode understands it natively
- ✅ **Zero orchestration** - Just run tests normally
- ✅ **No external config** - Minimal `.freezeray.yml` for shared paths

**Usage:**
```swift
// Minimal config file
// .freezeray.yml
fixture_dir: app/ClearlyTests/Fixtures/SwiftData

// In your schema files
@FreezeSchema(version: 1)
enum SchemaV1: VersionedSchema { ... }

@FreezeSchema(version: 2)
enum SchemaV2: VersionedSchema { ... }

// In your migration plan
@GenerateMigrationTests
enum MigrationPlan: SchemaMigrationPlan {
    static var stages: [MigrationStage] { ... }
}
```

**What the macros generate:**
- `@FreezeSchema` → Test method that exports SQL to `{fixture_dir}/v{N}-schema.sql`
- `@GenerateMigrationTests` → Smoke tests validating full migration path works

**Package Structure:**
```
FreezeRay/
  Sources/
    FreezeRay/           # Public API (macro declarations)
    FreezeRayMacros/     # Macro implementation (SwiftSyntax)
    FreezeRayClient/     # Runtime helpers (SQL export, etc.)
  Tests/
    FreezeRayTests/      # Macro expansion tests
  Examples/
    SampleApp/           # Demo SwiftData app
```

---

## Pre-Release Checklist (v0.1.0 → v1.0.0)

### Phase 1: Core Functionality

- [ ] Macro package structure (FreezeRay, FreezeRayMacros, FreezeRayClient)
- [ ] `@FreezeSchema` macro declaration and implementation
- [ ] `@GenerateMigrationTests` macro declaration and implementation
- [ ] `.freezeray.yml` parser (minimal: just `fixture_dir`)
- [ ] SQL export runtime helper
- [ ] Compile-time validation (config exists, fixture_dir defined)

### Phase 2: Testing & Validation

- [ ] Unit tests for schema detection logic
- [ ] Integration tests with sample SwiftData project
- [ ] Test across multiple Xcode versions (15.0, 16.0, 17.0)
- [ ] Test with various project structures (CocoaPods, SPM, standalone)
- [ ] Verify works with CloudKit-enabled schemas

### Phase 3: Configuration & Customization

- [ ] Minimal `.freezeray.yml` (just `fixture_dir`)
- [ ] Macro compile-time validation of config
- [ ] Support for optional `data_namespace_prefix` in config
- [ ] Custom test class name generation
- [ ] Error messages with file/line info

### Phase 4: Developer Experience

- [ ] Helpful error messages (not just "failed to generate SQL")
- [ ] Progress indicators for long-running operations
- [ ] Diff preview before freezing
- [ ] Interactive mode for conflict resolution
- [ ] Verbose/debug logging mode (`--verbose`)

### Phase 5: CI/CD Integration

- [ ] GitHub Actions example workflow
- [ ] GitLab CI example
- [ ] Fastlane integration guide
- [ ] Xcode Cloud integration guide
- [ ] Exit codes for scripting (0 = all frozen, 1 = unfrozen, 2 = error)

### Phase 6: Documentation

- [ ] Complete README with examples
- [ ] Troubleshooting guide
- [ ] Migration guide from manual schema management
- [ ] Best practices document
- [ ] Architecture decision record (how it works internally)
- [ ] Video walkthrough/demo

### Phase 7: Distribution

- [ ] Swift Package Manager (primary)
- [ ] Homebrew tap (`brew install trinsic/tap/freezeray`)
- [ ] Pre-built binaries for releases (GitHub Releases)
- [ ] Optional: Mint support

### Phase 8: Polish

- [ ] Version check (warn if using old version)
- [ ] Self-update command (`freezeray update`)
- [ ] Telemetry opt-in (anonymized usage stats)
- [ ] Man page generation
- [ ] Shell completion (bash/zsh/fish)

---

## Known Limitations (Pre-v1.0)

### Current Issues

1. **Not yet implemented** - switching from script to macro approach
2. **No example project** - need sample SwiftData app
3. **Macro testing** - need comprehensive macro expansion tests

### Blockers for Public Release

1. ❌ **Core macro implementation** not complete
2. ❌ **Macro expansion tests** not written
3. ❌ **Example project** to demonstrate usage
4. ❌ **Documentation** for macro-based approach

---

## Post-v1.0 Roadmap

### v1.1: Schema Migration Validation

- Validate that migrations actually work (not just freeze schemas)
- Test migrations with sample data
- Detect lossy migrations (data deletion)

### v1.2: Multi-Platform Support

- Support for Linux (non-Xcode environments)
- Support for other platforms (watchOS, tvOS, visionOS schemas)

### v1.3: Advanced Features

- Schema diff visualization (graphical)
- Integration with SwiftData schema versioning
- Auto-generate migration code templates
- Emergency schema update workflow (when frozen schema has bugs)

### v2.0: Ecosystem Integration

- Xcode extension/plugin
- VS Code extension
- SwiftPM plugin (run as `swift package freeze-schemas`)
- Integration with popular schema migration tools

---

## Success Metrics (Post-Launch)

### Adoption
- 100+ GitHub stars in first 3 months
- 10+ production apps using it
- Mentioned in SwiftData blogs/tutorials

### Quality
- Zero critical bugs reported in first month
- 95%+ test coverage
- All major Xcode versions supported

### Community
- 5+ community PRs merged
- Active discussions in issues/discussions
- Positive feedback from iOS community

---

## Go-to-Market Strategy

### Announcement Channels
1. **Blog post** on Trinsic Ventures blog
2. **Tweet** from @TrinsicVentures
3. **Post on Hacker News** ("Show HN: FreezeRay - Freeze SwiftData schemas for safe releases")
4. **Swift Forums** announcement
5. **Reddit** r/swift, r/iOSProgramming
6. **iOS Dev Weekly** submission

### Content
- "Why We Built FreezeRay" blog post
- Video demo (< 2 minutes)
- Before/after comparison (manual vs. FreezeRay)
- Case study from Clearly app

### Timing
- Launch alongside Clearly 1.2.0 release
- Highlight real-world usage in production app
- Show schema freeze automation in action

---

## Open Questions

1. **Name:** Is "FreezeRay" good? Alternatives: SchemaLock, SwiftFreeze, SchemaSnap
2. **Scope:** Should it handle migrations too, or just freezing?
3. **Pricing:** Free/OSS only, or paid enterprise features later?
4. **Support:** Who maintains this long-term?
5. **Alternatives:** What do others use? Can we learn from them?

---

## Dependencies

### Required
- **SwiftSyntax** (Apache 2.0) - AST parsing
- **Swift Argument Parser** (Apache 2.0) - CLI args

### Optional (Future)
- **Rainbow** - Colored terminal output
- **Progress.swift** - Progress bars
- **Files** - File system utilities

---

## Repository Setup

### Pre-Launch
```bash
cd /Users/gk/Projects/Trinsic/FreezeRay
git init
git add .
git commit -m "Initial commit - FreezeRay v0.1.0"
```

### Public Launch
```bash
# Create GitHub repo: github.com/trinsic/FreezeRay
git remote add origin git@github.com:trinsic/FreezeRay.git
git push -u origin main
git tag v1.0.0
git push --tags
```

### Repository Structure
```
FreezeRay/
  Sources/
    main.swift
    SchemaDetector.swift
    SchemaFreezer.swift
    GitCommitter.swift
  Tests/
    FreezeRayTests/
      SchemaDetectorTests.swift
      ...
  Examples/
    SampleSwiftDataApp/
  Package.swift
  README.md
  LICENSE (MIT)
  PLAN.md (this file)
  CHANGELOG.md
  .gitignore
  .github/
    workflows/
      ci.yml
```

---

## Implementation Plan

### Step 1: Package Structure
1. Create Swift macro package with three targets:
   - `FreezeRay` - Public API (macro declarations)
   - `FreezeRayMacros` - Macro implementation (SwiftSyntax)
   - `FreezeRayClient` - Runtime helpers (SQL export)
2. Set up test target with macro expansion tests
3. Add example app demonstrating usage

### Step 2: Core Macros
1. Implement `@FreezeSchema(version:)`:
   - Read `.freezeray.yml` to get `fixture_dir`
   - Generate test method that creates schema and exports SQL
   - Validate version number is positive integer
2. Implement `@GenerateMigrationTests`:
   - Read `.freezeray.yml` to get `fixture_dir`
   - Scan for all `@FreezeSchema` versions
   - Generate smoke tests for each migration path

### Step 3: Runtime Helpers
1. SQL export helper - creates ModelContainer, exports schema via sqlite3
2. YAML parser - minimal, just reads `fixture_dir`
3. Migration test helpers - setup/teardown for migration tests

### Step 4: Testing & Documentation
1. Write macro expansion tests
2. Create example SwiftData app with 2-3 schemas
3. Update README for macro-based usage
4. Test on Clearly app

Once these are done, we can do a soft launch to iOS community for feedback.

---

## Timeline

- **Week 1 (Now):** Core functionality working internally
- **Week 2-3:** Testing, polish, documentation
- **Week 4:** Create example project, write tests
- **Week 5:** Soft launch to small iOS dev community (Twitter, friends)
- **Week 6:** Incorporate feedback, fix bugs
- **Week 7:** Public v1.0.0 release
- **Week 8+:** Community support, feature additions

---

## Contact & Ownership

**Maintainers:** Geordie Kaytes (@geordiekaytes)
**Organization:** Trinsic Ventures
**Support:** GitHub Issues
**License:** MIT (free forever, commercial use OK)

---

*Last Updated: 2025-10-09*
