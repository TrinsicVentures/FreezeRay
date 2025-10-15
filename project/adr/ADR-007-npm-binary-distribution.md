# ADR-007: npm Binary Distribution

**Status:** Accepted
**Date:** 2025-10-14
**Deciders:** Core Team

## Context

FreezeRay CLI needs easy distribution for developers. Swift Package Manager is for the library, but the CLI tool needs a separate distribution channel.

### Requirements

1. Easy installation (`npm install -g @trinsicventures/freezeray`)
2. Don't commit large binaries (~21MB) to git
3. Keep build artifacts and release configs separate
4. Precompiled binary for Apple Silicon (most iOS developers)

## Decision

**Use npm with precompiled binary (copied at publish time):**

1. **Directory structure:**
   ```
   release/
   └── npm/
       ├── package.json
       ├── README.md
       └── bin/
           └── freezeray (copied from .build/release/ at publish time)
   ```

2. **Publishing workflow via mise:**
   ```bash
   mise run publish:npm
   ```

   This task:
   - Builds release binary (`swift build -c release --arch arm64`)
   - Copies binary to `release/npm/bin/`
   - Publishes to npm

3. **Scoped package name:** `@trinsicventures/freezeray` (unscoped `freezeray` was taken)

4. **Why copy instead of symlink?** npm does NOT follow symlinks that point outside the package directory. Symlinks must be relative within the package or they're ignored during `npm pack`/`npm publish`.

## Rationale

### Why npm?
- Familiar to web developers (many iOS devs use npm)
- Simple installation command
- Works well for precompiled binaries
- Easy to automate in CI/CD

### Why copy instead of commit binary?
- **No git bloat:** Binary never committed to git history
- **Fresh on every publish:** Copy happens during publish task
- **Automated via mise:** `mise run publish:npm` handles build + copy + publish
- **npm packaging works:** Binary is present in package directory for npm to include

### Why release/ directory?
- Clear it's about release process, not artifacts
- Keeps packaging configs separate from code
- Room for other distribution channels (release/homebrew/, etc.)
- `.gitignore` for `.build/` already handles the binary target

### Why Apple Silicon only?
- ~90% of iOS developers use Apple Silicon Macs
- Smaller package size (one binary, not universal)
- Intel users can build from source

## Consequences

### Positive
- ✅ Zero git bloat (binary never committed)
- ✅ Easy installation for most users
- ✅ Standard npm workflow
- ✅ Automated via mise task
- ✅ Clear separation of concerns
- ✅ Binary always fresh from build

### Negative
- ❌ Intel Mac users must build from source
- ❌ Requires npm installed (but most devs have it)
- ❌ macOS-only (but that's inherent to Xcode/SwiftData)
- ❌ Must copy binary before each publish (but automated via mise)

### Neutral
- Scoped package name is longer but clear ownership
- mise task handles entire workflow

## Alternatives Considered

### 1. Use symlink to binary

**Decision:** Rejected (initially attempted)

```bash
ln -s ../../../.build/release/freezeray release/npm/bin/freezeray
```

**Pros:**
- No copy step needed
- Always points to latest build

**Cons:**
- npm does NOT follow symlinks pointing outside package directory
- Results in published package without binary
- Discovered during first publish attempt (v0.4.0)

### 2. Universal binary (x86_64 + ARM64)

**Decision:** Rejected

```bash
swift build -c release --arch arm64 --arch x86_64
```

**Pros:**
- Works on Intel Macs

**Cons:**
- ~2x package size
- Intel usage declining rapidly
- Adds build complexity
- Not worth the tradeoff

### 2. Homebrew only

**Decision:** Rejected (but will add later)

**Pros:**
- Native macOS package manager
- Automatic updates

**Cons:**
- Requires Homebrew tap setup
- Less familiar to some developers
- npm is faster to set up initially

**Decision:** Use npm now, add Homebrew in Phase 3

### 3. GitHub Releases with install script

**Decision:** Rejected as primary method

```bash
curl -sSL https://freezeray.dev/install.sh | bash
```

**Pros:**
- No npm dependency
- Can do platform detection

**Cons:**
- Security concerns (curl | bash)
- More code to maintain
- Less discoverable

## Implementation Notes

### Publishing Workflow (Automated via mise)

```bash
# Use mise task (recommended)
mise run publish:npm

# Or manually:
swift build -c release --arch arm64
mkdir -p release/npm/bin
cp .build/release/freezeray release/npm/bin/
cd release/npm
npm publish --access public

# Test installation
npm install -g @trinsicventures/freezeray
freezeray --version
```

### mise Configuration

See `.mise.toml` for complete task definitions. The `publish:npm` task:
1. Depends on `build` task (ensures fresh binary)
2. Copies binary to `release/npm/bin/`
3. Publishes to npm with `--access public`

### Version Management

- Version in `release/npm/package.json` must match git tag
- Automated in CI/CD later (Phase 3)

### Future: Multi-Platform Support

If Intel support needed:
1. Build both architectures
2. Use `postinstall` script to select correct binary
3. Or publish separate packages: `@trinsicventures/freezeray-arm64`, `@trinsicventures/freezeray-x64`

## References

- npm binary distribution: https://docs.npmjs.com/cli/v9/configuring-npm/package-json#bin
- npm symlink behavior: npm does NOT follow symlinks pointing outside package directory
- Example: many Rust CLI tools use precompiled binaries via npm (ripgrep, fd, etc.)
- mise task runner: https://mise.jdx.dev/
