# ADR-002: /tmp Export for Fixture Extraction

**Status:** Accepted
**Date:** 2025-10-11
**Deciders:** Core Team
**Related:** ADR-001 (CLI Architecture)

## Context

After implementing the CLI architecture (ADR-001), we discovered that iOS XCTest runs in **ephemeral directories** that are deleted immediately after test completion:

- Tests run in: `/Users/{user}/Library/Developer/XCTestDevices/{UUID}/`
- These directories are cleaned up when test process ends
- Cannot extract fixtures after test completes
- Test container is NOT the same as app container

### Failed Approaches

1. **Extract from CoreSimulator/Devices** - Tests don't run there
2. **Use `xcrun simctl get_app_container`** - Test bundles aren't persistent apps
3. **Find container by simulator UUID** - Already deleted by the time we look
4. **Timing-based extraction** - Unreliable, race conditions

### Key Discovery

XCTest runs in ephemeral `XCTestDevices/` but iOS simulator tests **CAN write to `/tmp`** which:
- Persists after test completes
- Is accessible from host machine
- Requires no special permissions
- Reliable across Xcode versions

## Decision

**FreezeRayRuntime automatically exports fixtures to `/tmp` during iOS simulator test execution using conditional compilation:**

```swift
#if targetEnvironment(simulator) && os(iOS)
// Copy all fixtures to /tmp for CLI extraction
let tmpExportDir = URL(fileURLWithPath: "/tmp/FreezeRay/Fixtures/\(version)")
try? FileManager.default.createDirectory(at: tmpExportDir, withIntermediateDirectories: true)

for file in files {
    let sourceURL = fixtureDir.appendingPathComponent(file)
    let destURL = tmpExportDir.appendingPathComponent(file)
    try? FileManager.default.removeItem(at: destURL)
    try? FileManager.default.copyItem(at: sourceURL, to: destURL)
}

// Write metadata file
let metadata = """
Original path: \(fixtureDir.path)
Exported at: \(Date())
Version: \(version)
"""
try? metadata.write(to: tmpExportDir.appendingPathComponent("export_metadata.txt"),
                    atomically: true, encoding: .utf8)
#endif
```

**CLI extracts fixtures from `/tmp` after test completes:**

```swift
// SimulatorManager.swift
let fixturesURL = URL(fileURLWithPath: "/tmp/FreezeRay/Fixtures/\(version)")
// Copy to project: FreezeRay/Fixtures/{version}/
```

## Consequences

### Positive

- ✅ Reliably extracts fixtures every time
- ✅ No timing issues or race conditions
- ✅ Works across all Xcode and iOS versions
- ✅ Simple, no special permissions needed
- ✅ Conditional compilation - only exports on iOS simulator
- ✅ No impact on production apps (not included in release builds)

### Negative

- ❌ Leaves artifacts in `/tmp` (can be cleaned up easily)
- ❌ Platform-specific solution (iOS simulator only)

### Neutral

- Could add environment variable for configurability (e.g., `FREEZERAY_EXPORT_DIR`)
- `/tmp` is standard on macOS/Unix, reliable location
- Metadata file helps with debugging

## Alternatives Considered

### 1. Keep XCTestDevices Alive

**Decision:** Rejected

Try to prevent cleanup of XCTestDevices directories.

**Pros:**
- Could extract directly from test sandbox

**Cons:**
- No API to prevent cleanup
- Would interfere with Xcode's disk management
- Fragile, could break with Xcode updates

### 2. Write Directly to Project

**Decision:** Rejected

Have runtime write directly to project directory.

**Pros:**
- No extraction step needed

**Cons:**
- Requires absolute path to project (how to determine?)
- Breaks when running from different directories
- Doesn't work in CI/CD environments
- Hard-coded paths are fragile

### 3. Network Transfer (HTTP Server)

**Decision:** Rejected

Run HTTP server in CLI, have test POST fixtures.

**Pros:**
- Could work from any environment

**Cons:**
- Massive complexity
- Firewall/security issues
- Requires coordination between processes
- Overkill for simple file transfer

### 4. Shared Container

**Decision:** Rejected

Use shared container between test and CLI.

**Pros:**
- Clean iOS mechanism

**Cons:**
- Requires app group configuration
- CLI is separate process, not part of app
- Doesn't apply to test bundles

## Implementation

**File:** `Sources/FreezeRay/FreezeRayRuntime.swift` (lines 193-217)

Export logic runs after fixtures are created in Documents directory. Only active when:
- Running in simulator: `targetEnvironment(simulator)`
- iOS platform: `os(iOS)`
- Not included in macOS or production builds

**Cleanup:**
CLI could optionally clean up `/tmp/FreezeRay` after extraction, but leaving it is useful for debugging.

## Verification

Verified working in v0.4.0:
```bash
$ freezeray freeze 3.0.0
# ... test runs ...
# Fixtures found in /tmp/FreezeRay/Fixtures/3.0.0/
# Extracted 6 files successfully
```

Check contents:
```bash
$ ls -lh /tmp/FreezeRay/Fixtures/3.0.0/
App-3_0_0.sqlite
App-3_0_0.sqlite-shm
schema-3_0_0.json
schema-3_0_0.sql
schema-3_0_0.sha256
export_metadata.txt
```

## References

- Implementation: `Sources/FreezeRay/FreezeRayRuntime.swift:193-217`
- CLI extraction: `Sources/freezeray-cli/Simulator/SimulatorManager.swift`
- Sprint: project/sprints/v0.4.0-sprint_1-freeze-command.md
- Discovery process: Codex consultation on 2025-10-11
