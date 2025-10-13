# ADR-001: CLI + Macro Hybrid Architecture

**Status:** Accepted
**Date:** 2025-10-10
**Deciders:** Core Team

## Context

The original FreezeRay v0.3.0 used a macro-only approach where `@Freeze(version: "X.Y.Z")` generated methods that wrote fixtures directly to the source tree. This had a critical limitation: **iOS simulator tests run in sandboxed directories with no write access to the project source tree**.

### Problems with Macro-Only Approach

1. `__freezeray_freeze_X_Y_Z()` tries to write to `FreezeRay/Fixtures/` (relative path)
2. iOS simulator tests run in `/Users/.../XCTestDevices/{UUID}/`
3. No way to write outside sandbox to project directory
4. Workaround: macOS test target (poor developer experience)
5. Doesn't work with standard iOS testing workflow

### Key Insight

We need to separate:
- **Freeze operations** (explicit, write-heavy, CLI-driven)
- **Validation tests** (automatic, read-only, part of test suite)

## Decision

**Adopt a hybrid CLI + macro architecture:**

1. **CLI tool (`freezeray`)** - Orchestrates freeze operation:
   - Parses source files to find `@FreezeSchema` annotations
   - Generates temporary test file
   - Runs test in iOS simulator
   - Extracts fixtures from simulator
   - Copies to project directory
   - Scaffolds validation tests

2. **Macros** - Generate helper methods and structure:
   - `@FreezeSchema(version:)` generates `__freezeray_freeze_*()` method
   - Method is called by CLI-generated temp test
   - Generates drift detection scaffolds (future)
   - `@TestMigrations` scaffolds migration test structure (future)

3. **Runtime** - Core freeze logic:
   - Creates ModelContainer with schema
   - Exports SQLite database
   - Generates schema SQL export
   - Calculates SHA256 checksums
   - Writes to appropriate location based on environment

## Consequences

### Positive

- ✅ Works perfectly in iOS simulator (the primary use case)
- ✅ Explicit freeze operation: `freezeray freeze 1.0.0` is clear and intentional
- ✅ Validation tests are read-only, load fixtures from bundle
- ✅ CLI can orchestrate complex workflows (test generation, simulator management)
- ✅ Convention over configuration (auto-detects project structure)
- ✅ Fixtures extracted reliably without timing issues

### Negative

- ❌ Requires installing CLI tool (not just Swift package)
- ❌ More complex than pure macro approach
- ❌ Requires understanding of two components (CLI + macros)

### Neutral

- CLI is optional for validation - only needed for freezing new versions
- Users can still run tests with `⌘U` after initial freeze
- Distribution via Homebrew or binary download (future)

## Alternatives Considered

### 1. Macro-Only with macOS Target

**Decision:** Rejected

Keep macro-only approach, require macOS test target for freezing.

**Pros:**
- Simpler architecture
- No CLI tool needed

**Cons:**
- Poor developer experience (separate test target just for freezing)
- Doesn't work with standard iOS workflow
- Confusing for users (why macOS target for iOS app?)

### 2. XPC Service for Filesystem Access

**Decision:** Rejected

Use XPC service to write outside simulator sandbox.

**Pros:**
- Macros could still write directly

**Cons:**
- Extremely complex
- Security implications
- Unreliable across Xcode versions
- Not worth the complexity

### 3. Environment Variable to Disable Sandbox

**Decision:** Rejected

Use environment variable tricks to disable sandbox restrictions.

**Pros:**
- Could keep macro-only approach

**Cons:**
- Fragile, breaks with Xcode updates
- Against Apple's sandboxing intent
- Security implications
- Unreliable

## Implementation Notes

- See ADR-002 for /tmp export solution (how we extract from ephemeral test sandbox)
- See ADR-003 for dynamic test generation details
- CLI implementation: `Sources/freezeray-cli/`
- Macro implementation: `Sources/FreezeRayMacros/`
- Runtime: `Sources/FreezeRay/FreezeRayRuntime.swift`

## References

- v0.3.0 limitations: Tests failed in iOS simulator sandbox
- CLI implementation: project/sprints/v0.4.0-sprint_1-freeze-command.md
- Fixture extraction solution: ADR-002
