# ADR-005: Test Scaffolding (Not Generation)

**Status:** Accepted
**Date:** 2025-10-11
**Deciders:** Core Team

## Context

FreezeRay needs to generate validation tests for:
1. **Drift detection** - Verify frozen schema hasn't changed
2. **Migration testing** - Test migrations from frozen versions to current

**Key question:** Should tests be auto-generated (regenerated on every run) or scaffolded (generated once, user owns)?

## Decision

**Tests are scaffolded once and owned by the user.**

- `freezeray freeze X.Y.Z` generates drift test (if doesn't exist)
- `freezeray freeze X.Y.Z` generates migration test from previous version (if doesn't exist)
- Tests are never regenerated automatically
- User can customize tests (add assertions, data validation)
- Tests are committed to repo as part of user's codebase

## Consequences

### Positive
- ✅ Users can add custom data validation
- ✅ Tests are part of project's test suite
- ✅ Clear ownership (user's code, not tool's code)
- ✅ TODO markers guide customization
- ✅ No surprise regeneration losing user changes

### Negative
- ❌ User must manually update if scaffold template improves
- ❌ Slightly more complex than pure generation

## References
- Spec: project/sprints/v0.4.0-sprint_2-test-scaffolding.md
