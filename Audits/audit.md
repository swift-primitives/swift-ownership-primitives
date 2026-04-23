# Audit: swift-ownership-primitives

## Memory Safety — 2026-04-23

### Scope

- **Target**: swift-ownership-primitives (all source files)
- **Skill**: memory-safety — [MEM-COPY-*], [MEM-SAFE-*], [MEM-SEND-*], [MEM-LIFE-*]
- **Files**: 20 source files under `Sources/Ownership Primitives/`
- **Trigger**: Source-level audit pass before 0.1.0 tag; ecosystem research check against `swift-institute/Research/` and `swift-institute/Experiments/` for timeless-infrastructure quality.

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | **CRITICAL** | [MEM-COPY-004] / [COPY-FIX-003] | Ownership.Unique.swift:79, :83, :160 | `extension Ownership.Unique` (Core Operations, Description) and `extension Ownership.Unique: @unsafe @unchecked Sendable where Value: Sendable` are missing `where Value: ~Copyable`. Swift implicitly adds `where Value: Copyable`, making `take()`, `withValue(_:)`, `withMutableValue(_:)`, `leak()`, `hasValue`, `description`, `debugDescription`, and the `Sendable` conformance unavailable for `~Copyable Value`. Empirical proof: `let taken = cell.take()` where `cell: Ownership.Unique<~CopyableType>` produced `error: referencing instance method 'take()' on 'Ownership.Unique' requires that '<Type>' conform to 'Copyable'` with note `'where Value: Copyable' is implicit here`. This defeats `Ownership.Unique`'s mission as a heap cell for ~Copyable values. | RESOLVED 2026-04-23 — added `where Value: ~Copyable` on all three sites; regression tests added to `Ownership.Unique Tests.swift` EdgeCase suite (`take() works with ~Copyable Value`, `withValue works with ~Copyable Value`, `withMutableValue works with ~Copyable Value`). 73/73 tests pass. |
| 2 | **HIGH** | [MEM-COPY-004] / [COPY-FIX-003] | Ownership.Slot.swift:159 | `extension Ownership.Slot { ... isEmpty / isFull ... }` (State Inspection) missing `where Value: ~Copyable`. Identical implicit-Copyable mechanism. `Ownership.Slot<~CopyableType>().isFull` produced `error: property 'isFull' requires that '<Type>' conform to 'Copyable'`. `store` / `take` extensions (Slot.Store.swift, Slot.Move.swift) correctly carry `where Value: ~Copyable`; only the state-inspection extension was unconstrained. | RESOLVED 2026-04-23 — added `where Value: ~Copyable`; regression test added to `Ownership.Slot Tests.swift` Integration suite (`isEmpty / isFull work with ~Copyable Value`). 73/73 tests pass. |
| 3 | HIGH | [API-IMPL-008] | Ownership.Mutable.swift:74–107 | `value` computed property, `withValue(_:)`, `update(_:)` declared inside the `final class Mutable<Value: ~Copyable>` body. Per [API-IMPL-008] "Type declarations MUST contain only stored properties and the canonical initializer. Everything else MUST be in extensions." | RESOLVED 2026-04-23 — moved `value`, `withValue`, `update` to `extension Ownership.Mutable where Value: ~Copyable`. Body now holds `_value` + canonical `init`. |
| 4 | HIGH | [API-IMPL-007] | Ownership.Unique Copyable.swift (filename) | Extension file named with space instead of `+` suffix. | RESOLVED 2026-04-23 — renamed to `Ownership.Unique+Copyable.swift` via `git mv` (history preserved) during the Phase-2 modularization restructure. |
| 5 | MEDIUM | [MEM-SAFE-024] Category C | Ownership.Mutable.Unchecked.swift:61 | `Ownership.Mutable.Unchecked: @unsafe @unchecked Sendable` is Category C (thread-confined via caller-asserted external synchronization) per [MEM-SAFE-024]. The skill prescribes `~Sendable` (SE-0518) instead of `@unchecked Sendable` for Category C. | DEFERRED — re-evaluate when `~Sendable` (SE-0518) stabilizes; wrapper's docstring correctly warns about data-race hazard today. |
| 6 | MEDIUM | [MEM-SAFE-023] | Ownership.Transfer.Box.swift:102 | `Ownership.Transfer.Box.Pointer.raw: UnsafeMutableRawPointer` was `public let` without `@unsafe`. Public pointer property on an Escapable struct. | RESOLVED 2026-04-23 — annotated `@unsafe public let raw`. |
| 7 | MEDIUM | [API-NAME-002] | Ownership.Transfer.Storage.swift:118 | `takeIfStored()` is a compound identifier. Idiomatic form would be `take.ifStored` via a nested `Take` fluent accessor struct similar to `Slot.Move`. | OPEN — deferred; requires authoring a `Take` fluent accessor struct (sizable), and the current method is internal-facing enough that the cost/benefit favors deferring to a follow-up after 0.1.0. |
| 8 | LOW | [DOC-045] | Ownership.Transfer.Box.swift (Header doc) | Workaround note didn't follow the four-part [DOC-045] template. | RESOLVED 2026-04-23 — reformatted as `// WORKAROUND: … // WHY: … // WHEN TO REMOVE: … // TRACKING: …`. |
| 9 | LOW | [TEST-009] | Tests/Ownership Primitives Tests/OwnershipTests.swift (filename) | Compound-name test file; basic smoke tests for Unique/Shared/Mutable/Slot that are redundant once per-type test files exist. | RESOLVED 2026-04-23 — deleted `OwnershipTests.swift`; added `Ownership.Shared Tests.swift` and `Ownership.Mutable Tests.swift` with parallel-namespace suites per [SWIFT-TEST-003]. Test count: 84 tests / 33 suites (was 73/26). |

### Summary

**9 findings: 6 RESOLVED, 1 OPEN, 2 DEFERRED.**

As of 2026-04-23 (post Phase-2 remediation pass): findings #1, #2 (CRITICAL/HIGH ~Copyable extension constraints), #3 (API-IMPL-008 Mutable body methods), #4 (API-IMPL-007 Unique+Copyable rename), #6 (MEM-SAFE-023 Pointer.raw @unsafe), #8 (DOC-045 workaround doc), #9 (TEST-009 OwnershipTests.swift) all resolved. Finding #7 (takeIfStored compound name) deferred to a post-0.1.0 follow-up requiring a nested Take fluent accessor struct. Finding #5 (Category C → ~Sendable migration) deferred until SE-0518 stabilizes.

Systemic pattern: the two CRITICAL/HIGH findings (#1, #2) share a single root cause — extensions on `~Copyable`-generic types without explicit `where Value: ~Copyable`. Swift implicitly adds `where Value: Copyable` to otherwise-unconstrained extensions, defeating the `~Copyable` generic constraint on the base type. [MEM-COPY-004] flags this as a propagation gotcha; [COPY-FIX-003] is the canonical fix. The fix is mechanical and both instances are now closed with regression tests. Future additions of extensions on `Ownership.*<~Copyable Value>` types MUST explicitly restate the constraint.

**Verified clean** (no findings):
- [MEM-SAFE-001] Strict memory safety enabled in Package.swift.
- [MEM-SAFE-002] Unsafe expressions correctly marked with `unsafe` (expression-level).
- [MEM-SAFE-021] No `@unsafe` on encapsulating types; `Ownership.Borrow`, `Ownership.Inout`, `Ownership.Unique`, `Ownership.Shared`, `Ownership.Mutable`, `Ownership.Slot`, `Ownership.Transfer.Retained` all use `@safe`.
- [MEM-SAFE-024] Sendable category classification: Ownership.Slot + Ownership.Transfer._Box + Pointer = Category A (synchronized); Ownership.Unique + Ownership.Transfer.Retained = Category B (ownership transfer); Ownership.Shared = Category D / SP-4 (non-Sendable generic); Ownership.Transfer.Cell.Token + Storage.Token = plain Sendable (structural).
- [MEM-LIFE-*] `@_lifetime` annotations correctly scope `Ownership.Borrow.init(_:)` to `borrow pointer` and `Ownership.Inout.init(mutating:)` to `&value`.
- [API-ERR-001] Typed throws used consistently — `withValue<Result, E: Error>(...) throws(E) -> Result`.
- [COPY-FIX-003] extensions on `Ownership.Borrow`, `Ownership.Inout`, `Ownership.Transfer.Cell`, `Ownership.Transfer.Storage`, `Ownership.Mutable.Unchecked`, `Ownership.Slot.Store`, `Ownership.Slot.Move` all carry explicit `where Value: ~Copyable` (or the equivalent `T: ~Copyable`).

Ecosystem context: the `swift-institute/Research/ownership-borrow-protocol-unification.md` decision (v1.4.0, IMPLEMENTED 2026-04-23) is already reflected in this package's source (`Ownership.Borrow.`Protocol`` typealias + hoisted `__Ownership_Borrow_Protocol` conform path landed in commit `b3eb11b`). The Path.View → Path.Borrowed cascade applies to `swift-iso-9945` / `swift-posix` / `swift-kernel` / etc., not to `Ownership.*` types. No rename-cascade action required here.

---

## Legacy — Consolidated 2026-04-08

### From: audit-borrow-inout-stdlib-parity.md (2026-03-31)

**Scope**: Parity audit of `Ownership.Borrow` and `Ownership.Inout` against stdlib `Borrow<T>` and `Inout<T>` (SE-0519, SwiftStdlib 6.4).

**Auditor**: Claude | **Status**: PASS — no parity gaps; all divergences are intentional ecosystem adaptations or toolchain constraints.

**Ownership.Borrow vs stdlib Borrow<T>** (10 items):

| Severity | Count |
|----------|-------|
| PASS | 8 |
| NOTED (intentional divergence) | 2 |
| Findings | 0 |

**Ownership.Inout vs stdlib Inout<T>** (10 items):

| Severity | Count |
|----------|-------|
| PASS | 8 |
| Findings | 2 |

**Findings**:

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| FINDING-1 | Informational | `nonmutating _modify` vs stdlib `mutate` — our version is strictly more capable (interior mutability through raw pointer per [IMPL-071]); exclusivity guaranteed because Inout is ~Copyable | RESOLVED — intentional extension, no action |
| FINDING-2 | Track for migration | `@_unsafeSelfDependentResult` absent — stdlib uses it on both Inout.value accessors; our `_read`/`_modify` coroutines enforce lifetime structurally via coroutine suspension scoping | DEFERRED — re-evaluate when `BorrowAndMutateAccessors` (SE-0507) ships in production compiler |

**Intentional divergences** (7 total):
- `@inlinable` instead of `@_alwaysEmitIntoClient`/`@_transparent` (stdlib-internal attrs)
- No `@frozen` (stdlib-only ABI concern)
- Labeled value inits (`borrowing:`/`mutating:`) — unlabeled slot taken by pointer init
- Extra `init(_ pointer:)` — ecosystem addition for buffer access
- `_read`/`_modify` instead of `borrow`/`mutate` — BorrowAndMutateAccessors not available
- `@safe` on Borrow (stdlib stores Builtin.Borrow; we store UnsafePointer)
- `nonmutating _modify` on Inout (interior mutability per [IMPL-071])

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-small-packages-batch.md (2026-03-20)

**Implementation + naming audit**

CLEAN - no findings
