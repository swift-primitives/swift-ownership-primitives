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
| 3 | HIGH | [API-IMPL-008] | Ownership.Mutable.swift:74–107 | `value` computed property, `withValue(_:)`, `update(_:)` are declared inside the `final class Mutable<Value: ~Copyable>` body. Per [API-IMPL-008] "Type declarations MUST contain only stored properties and the canonical initializer. Everything else MUST be in extensions." For consistency with Ownership.Unique (body: storage + init + deinit; methods in extensions), Ownership.Mutable should move `value`, `withValue`, `update` to extensions. The [API-IMPL-008] exception for `~Copyable` types permits nested storage types and types referencing the `~Copyable` parameter in the body — it does not cover computed properties or methods. | OPEN |
| 4 | HIGH | [API-IMPL-007] | Ownership.Unique Copyable.swift (filename) | File contains only `extension Ownership.Unique where Value: Copyable { duplicated() }` — an extension file, not a type declaration file. [API-IMPL-007] "Extension files MUST use `+` suffix pattern." Current filename uses a space, suggesting a nested type `Ownership.Unique.Copyable`. Rename to `Ownership.Unique+Copyable.swift` clarifies intent. | OPEN |
| 5 | MEDIUM | [MEM-SAFE-024] Category C | Ownership.Mutable.Unchecked.swift:61 | `Ownership.Mutable.Unchecked: @unsafe @unchecked Sendable` is Category C (thread-confined via caller-asserted external synchronization) per [MEM-SAFE-024]. The skill prescribes `~Sendable` (SE-0518) instead of `@unchecked Sendable` for Category C; thread-confined types should express confinement at the type level and use explicit `unsafe` at transfer sites. SE-0518 is gated behind `.enableExperimentalFeature("TildeSendable")` in Swift 6.3. | DEFERRED — re-evaluate when `~Sendable` (SE-0518) stabilizes. The wrapper's current docstring correctly warns about data-race hazard; migration is deferred because consumers (`@Sendable` closure capture of non-Sendable async iterators) would need parallel migration. |
| 6 | MEDIUM | [MEM-SAFE-023] | Ownership.Transfer.Box.swift:102 | `Ownership.Transfer.Box.Pointer.raw: UnsafeMutableRawPointer` is `public let`. [MEM-SAFE-023] "Public properties returning unsafe pointer types MUST be annotated `@unsafe`." `Pointer` is an `Escapable` struct (no `~Escapable`), so the pointer is not structurally lifetime-bounded — severity is MEDIUM per [MEM-SAFE-023]. Docstring calls it "an ownership-transfer token that must be round-tripped back via `take()`," but the public property surface allows external reads that bypass the token contract. | OPEN |
| 7 | MEDIUM | [API-NAME-002] | Ownership.Transfer.Storage.swift:118 | `takeIfStored()` is a compound identifier. The idiomatic nested-accessor form would be `take.ifStored` or `take.ifPresent()`. The `_Box` internal parallel is `takeIfPresent` (same compound shape). Renaming requires a coordinated nested-accessor pattern (`Take` fluent struct similar to `Slot.Move`). | OPEN |
| 8 | LOW | [DOC-045] | Ownership.Transfer.Box.swift:59–67 (Header doc) | The header block's "Why Closure (Future: Replace with Thin Function Pointer)" explanation is a WORKAROUND but doesn't follow the [DOC-045] four-part template (WORKAROUND / WHY / WHEN TO REMOVE / TRACKING). It mentions "Swift 6.2.3 crashes when `unsafeBitCast`ing generic thin function pointers" without a tracking URL. Should be reformatted with a compiler issue reference or `swift-institute/Experiments/` entry. | OPEN |
| 9 | LOW | [TEST-009] | Tests/Ownership Primitives Tests/OwnershipTests.swift (filename) | [TEST-009] mandates `{TypePath} Tests.swift` file naming. `OwnershipTests.swift` uses a compound name. Rename to `Ownership Tests.swift` (or delete — the namespace-level smoke tests are redundant now that per-type test files exist). | OPEN |

### Summary

**9 findings: 2 CRITICAL/HIGH resolved (source fixes + regression tests), 3 HIGH open, 2 MEDIUM open, 1 MEDIUM deferred, 2 LOW open.**

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
