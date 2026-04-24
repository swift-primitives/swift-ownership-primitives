# Audit: swift-ownership-primitives

## Timeless 0.1.0 Completion — 2026-04-24

### Scope

Final session before the `0.1.0` tag. Applies the five-phase plan from
`HANDOFF.md` to close every design-review finding that blocks the
timeless-0.1.0 criterion: the ownership lattice is totally covered, every
principled position is occupied by a shipped type, no planned breaking
renames remain.

### Phases

| Phase | Action | Outcome |
|-------|--------|---------|
| 1 | Promote internal `Transfer._Box<T>` → public `Ownership.Latch<V: ~Copyable>` (new variant target `Ownership Latch Primitives`; `Value.*` / `Retained.*` rewired to use it through `internal import`) | LANDED |
| 2 | Add `Ownership.Indirect<Value>` heap copy-on-write cell (new variant target `Ownership Indirect Primitives`) | LANDED |
| 3 | Transfer reorganization: kind × direction matrix. `Transfer.Value<V>.{Outgoing, Incoming}` (was `Cell<V>` / `Storage<V>`); `Transfer.Retained<T>.{Outgoing, Incoming}` (was `Retained<T>`; `Incoming` new); `Transfer.Erased.{Outgoing, Incoming}` (was `Transfer.Box`; `Incoming` new). Target `Ownership Transfer Box Primitives` → `Ownership Transfer Erased Primitives`. D7 `consumeIfStored()` kept as single-concept Optional-returning consume variant per principal direction. | LANDED |
| 4 | DocC decision-matrix article `Choosing an Ownership Primitive.md` at the `Ownership Primitives.docc` root — 15-row lattice across lifetime × mutability × ownership-multiplicity × sync × copyability. | LANDED |
| 5 | Final sweep — this section; grep for residual planning-language; final build + test verification. | IN FLIGHT |

### Final type-set (frozen)

`Ownership.{Borrow, Inout, Unique, Shared, Mutable, Mutable.Unchecked, Slot, Latch, Indirect, Transfer.{Value<V>.Outgoing, Value<V>.Incoming, Retained<T>.Outgoing, Retained<T>.Incoming, Erased.Outgoing, Erased.Incoming}}` — 15 types, each holding a unique contract in the lattice. The Design Review section below records the path from pre-session state to this set.

### Tests

`swift test` green — 113 tests passing in 47 suites on Swift 6.3.1.

---

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

---

## 0.1.0 Release Readiness — 2026-04-23

### Scope

Pre-tag checklist per the `AUDIT-0.1.0-release-readiness.md` brief, Phase 3. Verifies the package is ready to cut `0.1.0` subject to the CI / make-public gate.

### Checks

| # | Item | Status | Detail |
|---|------|--------|--------|
| 1 | `Package.swift` metadata: tools-version `6.3.1`, platforms `v26`, `swiftLanguageModes: [.v6]` | ✓ | |
| 1a | No `// TODO` / `// FIXME` in `Sources/` | ✓ | `grep -rnE 'TODO\|FIXME' Sources/` returns empty |
| 1b | No `@_spi` / `@_implementationOnly` / `@_unsafeSelfDependentResult` in `Sources/` | ✓ | `grep -rnE '@_spi\|@_implementationOnly\|@_unsafeSelfDependentResult' Sources/` returns empty |
| 2 | `LICENSE.md` present, Apache 2.0 | ✓ | |
| 3 | README install snippet matches the about-to-cut tag (`.package(url: ..., from: "0.1.0")`) | ✓ | Narrow-variant products listed per [MOD-015] |
| 3a | No CI badge on README (workflows currently disabled; per [README-004] failing badges are forbidden) | ✓ | README ships with `Development Status` badge only |
| 4 | CI green across the 4 matrix jobs + docs job | **DEFERRED** | Gated by repo visibility — the three workflows (CI / Swift Format / SwiftLint) are `state: disabled_manually` on GitHub since 2026-03-04, and GHA billing on the account needs attention. Post-public: enable workflows → watch CI → approve tag. |
| 5 | `Research/_index.json` + `Experiments/_index.json` internally consistent | ✓ | Research index carries pointers to 12 ecosystem-wide cross-refs (10 in `swift-institute/Research/`, 2 in `swift-primitives/Research/`). Experiments index lists 3 in-package experiments (inout-value-accessor-copyability-split, borrow-inout-stdlib-parity, nested-in-generic-extension-target-boundary) + 3 cross-ref pointers to superrepo-level experiments. |
| 6 | `Audits/_index.json` | ✓ | Created 2026-04-23; points at `audit.md` with status `ACTIVE` (1 OPEN, 2 DEFERRED). |
| 7 | No `.DS_Store` in tree | ✓ | Removed; `.gitignore` covers it. |
| 8 | `.gitignore` covers `.build/`, `DerivedData/`, `.DS_Store`, docs intermediates | ✓ | |
| 9 | Tag plan: `0.1.0` as first tag on `main` | **STAGED — DO NOT EXECUTE WITHOUT AUTHORIZATION** | See below. |

### Staged tag command

Do not run until the principal explicitly authorizes (per `feedback_no_public_or_tag_without_explicit_yes`). The command below is for reference:

```bash
# Run from swift-ownership-primitives/ working tree
git tag -a 0.1.0 -m "$(cat <<'EOF'
swift-ownership-primitives 0.1.0

First public release. Ships safe ownership references and cells for
~Copyable / ~Escapable / Copyable values on production Swift 6.3.1.
Parallels SE-0519 stdlib Borrow / Inout, SE-0517 UniqueBox, and
SE-0507 BorrowAndMutateAccessors on toolchains where the stdlib has
not yet landed the final shapes.

14 library products per [MOD-015] primary decomposition:

  - Ownership Namespace — bare `public enum Ownership {}`
  - Ownership Primitives Core — internal — namespace enums for Transfer family
  - Ownership Borrow Primitives — Ownership.Borrow + Protocol typealias
  - Ownership Inout Primitives — Ownership.Inout (V12 accessor split)
  - Ownership Unique Primitives — Ownership.Unique (SE-0517 parity)
  - Ownership Shared Primitives — Ownership.Shared
  - Ownership Mutable Primitives — Ownership.Mutable + Mutable.Unchecked
  - Ownership Slot Primitives — Ownership.Slot + Slot.Move
  - Ownership Latch Primitives — Ownership.Latch (one-shot atomic cell)
  - Ownership Indirect Primitives — Ownership.Indirect (CoW value cell)
  - Ownership Transfer Primitives — Transfer.Value<V>.{Outgoing, Incoming},
        Transfer.Retained<T>.{Outgoing, Incoming}
  - Ownership Transfer Erased Primitives — Transfer.Erased.{Outgoing, Incoming}
  - Ownership Primitives Standard Library Integration — Optional<~Copyable>.take()
  - Ownership Primitives — umbrella (re-exports every variant)

Fifteen ownership types complete the direction x kind matrix of the
transfer family and the heap-owned / scoped reference lattice.

Tests: 113 pass in 47 suites. Design Review closes A1 + A2 + A3 + A5 +
B1 + B2 + D7 + F1 (all RESOLVED 2026-04-24). Remaining audit items are
downstream coordination (G1) and validations/visual DocC (D*, F2).
EOF
)"
# Verify:
git tag -l
git show 0.1.0
# Push (only after CI is green and principal authorizes):
# git push origin 0.1.0
```

### Remaining gates (outside this session)

1. Make the repo public (user action).
2. Re-enable the three workflows on GitHub (CI / Swift Format / SwiftLint).
3. Resolve GHA billing so the matrix jobs can run.
4. Watch CI complete green across all 4 matrix jobs + docs job.
5. Principal authorization: reply with explicit "YES DO NOW TAG 0.1.0" (or equivalent) — then run the staged command above and optionally `git push origin 0.1.0`.

### Summary

**Release-readiness status: READY subject to CI gate.** All source-, test-, docs-, and metadata-level checks pass; the only outstanding work is external to this session (visibility flip + CI + principal tag approval).

---

## Design Review — 2026-04-23

Parked per [AUDIT-017] — deferred investigations, naming decisions, and claims to validate. Findings in this section are NOT violations against a current rule; they are design-space items that need a decision or further investigation before they can be resolved.

### Scope

- **Target**: swift-ownership-primitives — pre-0.1.0 design surface
- **Input**: Research/ownership-types-usage-and-justification.md v2.1.0
- **Companion experiments**: `swift-institute/Experiments/{static-stored-property-in-generic-type, unsafe-bitcast-generic-thin-function-pointer, noncopyable-generic-sendable-inference}`; `swift-ownership-primitives/Experiments/nested-in-generic-extension-target-boundary`
- **Goal**: enumerate what remains to decide / investigate / explore before or after 0.1.0

### Findings

#### A — Naming decisions pending principal choice

| # | Cluster | Severity | Rule | Location | Finding | Status |
|---|---------|----------|------|----------|---------|--------|
| A1 | Cluster A — `Transfer.Box` rename | MEDIUM | [API-NAME-001] | was Ownership.Transfer.Box.swift:41 | `Transfer.Box` collided diametrically with Rust's `Box<T>` (= our `Ownership.Unique`). **RESOLVED 2026-04-24 (Phase 3)** — target `Ownership Transfer Box Primitives` renamed to `Ownership Transfer Erased Primitives`; type renamed to `Transfer.Erased.Outgoing` under the kind-namespace structure. | RESOLVED 2026-04-24 |
| A2 | Cluster B — Transfer direction rename | MEDIUM | [API-NAME-002] | was Transfer.Cell / Transfer.Storage / Transfer.Retained | **RESOLVED 2026-04-24 (Phase 3)** — landed as a kind × direction matrix with the generic at the kind layer to sidestep the Swift 6.3.1 nested-generic access limit (ref. `Experiments/nested-type-generic-escape/`). `Cell<V>` → `Value<V>.Outgoing`; `Storage<V>` → `Value<V>.Incoming`; `Retained<T>` → `Retained<T>.Outgoing`. | RESOLVED 2026-04-24 |
| A3 | Cluster C — `Unique` API → SE-0517 parity | MEDIUM | [API-NAME-001] | Ownership.Unique.swift | **RESOLVED 2026-04-24.** Original proposal (rename type to `Box`) SUPERSEDED by `Research/naming-box-ecosystem-survey.md` (v1.2.0): Apple explicitly rejected bare `Box` in SE-0517 and reserves it for a future CoW sibling. Experiments `unified-vs-two-type-box-design` + `nested-type-generic-escape` proved unified/nested approaches not viable. Final action: keep `Ownership.Unique` name (Institute rendering of SE-0517 `UniqueBox`); rewrite API to SE-0517 parity — `.take()` (mutating, leaves empty) → `.consume()` (consuming, destroys self); `.duplicated()` → `.clone()`; drop `.hasValue`, `.leak()`, `description`, `debugDescription`; add `var value { _read _modify }`; storage `UnsafeMutablePointer<Value>?` → non-optional `UnsafeMutablePointer<Value>`. 85 tests in 35 suites pass. | RESOLVED 2026-04-24 |
| A4 | Cluster D — Shared/Mutable symmetry | LOW | [API-NAME-001] | Ownership.Shared / Ownership.Mutable / Mutable.Unchecked | Asymmetric names: both types are ARC-shared; only mutability differs. Pair-rename to `Shared.Immutable` / `Shared.Mutable` / `Shared.Mutable.Unchecked` would read symmetrically. 32+ external call sites — highest blast radius. | DEFERRED — likely not pre-0.1.0 |
| A5 | Cluster E — `Slot.Store` result enum removal | LOW | [API-NAME-002] | was Ownership.Slot.Store.swift:22 | Result enum `Slot.Store` collided verb/noun with the method `slot.store(_:)`. **RESOLVED 2026-04-24 — removed entirely.** `store(_)` now returns `Value?` directly (Apple-idiomatic — mirrors stdlib `Dictionary.updateValue(_:forKey:)`). Zero external consumers of the enum cases per ecosystem sweep. 84/33 tests pass; swift-async + swift-pool build clean. Research: `Research/naming-slot-store-result-enum.md` v2.0.0 IMPLEMENTED. | RESOLVED 2026-04-24 |

#### B — Completeness gaps (the "total package" principle)

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| B1 | MEDIUM | — (totality design goal) | Ownership.Transfer.Retained.Incoming | Missing: inbound zero-alloc `AnyObject` transfer. **RESOLVED 2026-04-24 (Phase 3)** — shipped as `Transfer.Retained<T>.Incoming`, a consumer-side `AnyObject` slot backed by `Ownership.Latch<T>` with a Sendable `Token` for producer hand-off. | RESOLVED 2026-04-24 |
| B2 | MEDIUM | — (totality design goal) | Ownership.Transfer.Erased.Incoming | Missing: inbound type-erased transfer. **RESOLVED 2026-04-24 (Phase 3)** — shipped as `Transfer.Erased.Incoming`, a consumer-side slot holding the opaque pointer produced by `Erased.Outgoing.make(_:)`; `consume<T>(_:)` unboxes with the consumer-known type. | RESOLVED 2026-04-24 |

#### C — Claims validated this session (informational)

| # | Claim | Experiment | Verdict |
|---|-------|------------|---------|
| C1 | Static stored properties in generic types forbidden → justifies hoisted `__OwnershipSlotState` / `__OwnershipTransferBoxState` | `swift-institute/Experiments/static-stored-property-in-generic-type/` | STILL PRESENT on 6.3.1 — hoist stays |
| C2 | Nested protocol in generic (SE-0404) forbidden → justifies hoisted `__Ownership_Borrow_Protocol` | `swift-institute/Experiments/protocol-inside-generic-namespace/` (pre-existing; revalidated 2026-04-17) | STILL PRESENT on 6.3.1 — hoist stays |
| C3 | Generic-capturing thin function pointer crashes → justifies closure-based `Box.Header.destroyPayload` | `swift-institute/Experiments/unsafe-bitcast-generic-thin-function-pointer/` | STILL PRESENT on 6.3.1 (INTERNAL ERROR) — closure stays |
| C4 | Nested-in-generic extension + cross-target mangling blocks `Token.take()` in extension | `swift-ownership-primitives/Experiments/nested-in-generic-extension-target-boundary/` | **FIXED** on 6.3.1 — Token methods moved to extensions this session |
| C5 | `~Copyable` generic blocks Sendable inference on `final class` with immutable payload | `swift-institute/Experiments/noncopyable-generic-sendable-inference/` | **REFUTED** on 6.3.1 — `Ownership.Shared` is now plain `Sendable` |

#### D — Claims / behaviors NOT yet validated (candidates for future experiments)

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| D1 | LOW | — | Ownership.Slot.swift (atomic state machine) | Release/acquire memory ordering is asserted in doc comments but not verified. TSAN harness + multi-thread stress test would anchor the claim. | OPEN — investigate |
| D2 | LOW | — | Ownership.Transfer.{Cell,Storage,_Box}.take / store | Atomic CAS on `State.full ↔ State.empty` is claimed exactly-once; behavioral test under concurrent double-take / double-store would document the invariant. | OPEN — investigate |
| D3 | LOW | [MEM-LIFE-006] | Ownership.Inout V12 accessor | V12 `get` + `nonmutating _modify` split was validated for the lifetime-escape fix but not for deep CoW chains (5+ levels of coroutine yields). Existing tests cover one level. | OPEN — investigate |
| D4 | LOW | — | Package.swift | "Swift Embedded compatible" is claimed in the DocC landing but not verified — no embedded build job runs. | OPEN — investigate |
| D5 | LOW | — | All types | Behavior on Swift 6.4-dev nightly is untested (only 6.3.1 verified). Resolves when CI matrix runs. | OPEN — resolves with CI |
| D6 | LOW | — | Ownership.Borrow | `Value: ~Copyable & ~Escapable` is admitted; the `~Escapable` path is exercised only through the raw-address init. No end-to-end test covers the `Span`-like shape. | OPEN — investigate |
| D7 | LOW | [API-NAME-002] | Transfer.Value.Incoming.consumeIfStored, Ownership.Latch.takeIfPresent | Compound-looking identifiers considered for fluent-accessor reshape. **RESOLVED 2026-04-24 (Phase 3)** — kept as single-concept Optional-returning consume/take variants (analogous to stdlib `hasPrefix` / `first(where:)`). Per principal: the reshape to a fluent nested-accessor struct would collide with the `consuming self` destruction semantic these methods must express. The existing names read as one conditional operation each. | RESOLVED 2026-04-24 |
| D8 | LOW | — | Ownership.Mutable.Unchecked | SE-0518 `~Sendable` migration path not drafted. When `~Sendable` stabilises: migration doc + `@available(*, deprecated, message: "...")`. | DEFERRED — pending SE-0518 stable |
| D9 | LOW | — | Ownership.Borrow, Ownership.Inout | SE-0519 stable `Borrow<T>` / `Inout<T>` (SwiftStdlib 6.4) migration path not drafted. Typealias bridge vs. hard rename vs. coexist? | DEFERRED — pending SE-0519 stable |
| D10 | LOW | — | Ownership.Borrow.value, Ownership.Inout.value | SE-0507 `BorrowAndMutateAccessors` — `_read` / `_modify` coroutines replaced by `borrow` / `mutate`. Structure survives; body syntax changes. | DEFERRED — pending SE-0507 stable |

#### E — Explorations (no current action)

| # | Topic | Scope | Status |
|---|-------|-------|--------|
| E1 | `Ownership.Once` — set-once cell (Rust `OnceCell`) | Does set-once belong here or in a separate primitive? | EXPLORATORY |
| E2 | `Ownership.Lease` — time-bounded ownership | Pool-adjacent. Useful? | EXPLORATORY |
| E3 | Zero-alloc Transfer for known-size structs | `Transfer.Retained` is AnyObject-only; `Transfer.Inline<T>` for small structs? | EXPLORATORY |
| E4 | Swift Evolution pitch — `_Ownership` stdlib module | The taxonomy could feed a SE proposal | EXPLORATORY |
| E5 | Formal verification of `Slot` CAS correctness | TLA+ / CAT model for release-acquire publication + exactly-once CAS | EXPLORATORY (academic) |
| E6 | "Scoped multi-owner mutable" — the one empty cell in the 5-axis lattice | Intentionally empty (incoherent without sync)? If so, document the principled absence. | EXPLORATORY |

#### F — DocC + documentation polish

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| F1 | LOW | [DOC-060] | `Ownership Primitives.docc/Choosing an Ownership Primitive.md` | Top-level decision-matrix article. **RESOLVED 2026-04-24 (Phase 4)** — 15-row lattice across lifetime × mutability × ownership-multiplicity × sync × copyability; decision flowchart; cross-axis pairs naming the single-bit flip that moves between them. Linked from the umbrella landing page. | RESOLVED 2026-04-24 |
| F2 | LOW | — | `Ownership Primitives.docc` | DocC rendering not visually verified end-to-end (`swift build --emit-symbol-graph` + `xcrun docc convert` pipeline not run locally). | OPEN — verify |
| F3 | LOW | — | `Ownership Primitives.md` landing | The "Narrow-Import Decomposition" section was added in the earlier commit; could expand with a decision matrix linking to per-variant articles. | PARTIALLY RESOLVED |
| F4 | LOW | [DOC-019a] | Tutorial step files under `Ownership Primitives.docc/Resources/` | Tutorial references `Ownership.Unique`; if Cluster C lands, tutorial must update. | DEFERRED — depends on Cluster C |

#### G — Downstream / ecosystem items

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| G1 | MEDIUM | — | swift-reference-primitives/Sources/Reference Primitives/Reference.swift | Doc table in Reference.swift characterises Ownership types as-of-relocation. With Phase 3 Transfer rename landed, the downstream table references `Transfer.Cell` / `Transfer.Storage` / `Transfer.Box` which no longer exist. Needs coordinated update. | OPEN — coordinate |
| G2 | LOW | — | swift-property-primitives (commit `b4ae443`) | Narrow-import migration bundled with pre-existing V12-parent WIP. Clean separation would require interactive rebase; cost/benefit low. | ACCEPTED — documented in commit message |
| G3 | LOW | — | swift-tagged-primitives | `Tagged+Ownership.Borrow.Protocol.swift` imports `Ownership.Borrow`. When SE-0519 stable lands, parallel migration needed. | DEFERRED — pending SE-0519 |
| G4 | LOW | — | swift-async-primitives, swift-pool-primitives, swift-cache-primitives, swift-foundations/swift-markdown-html-render | All use `Ownership.Shared` / `.Mutable`. If Cluster D lands (`Shared.Immutable` / `Shared.Mutable`), 32+ call sites need parallel migration. Argument for NOT doing Cluster D. | DEFERRED — pending Cluster D decision |

### Summary

**36 findings total: 5 VALIDATED (experiment revalidations), 8 RESOLVED (A1 + A2 + A3 + A5 + B1 + B2 + D7 + F1, all 2026-04-24), 8 OPEN (investigations / visual DocC / downstream coordination), 7 DEFERRED (pending language evolution — A4 Cluster D, D8/SE-0518, D9/SE-0519 stable, D10/SE-0507 stable, F4/Tutorial update conditional on Unique API work, G3/G4 downstream cascades), 6 EXPLORATORY (E1–E6), 1 ACCEPTED (G2), 1 PARTIALLY RESOLVED (F3).**

Timeless-0.1.0 gate (direction × kind matrix totality + ownership-lattice completeness): satisfied. The remaining OPEN items are validations and downstream cascades; no type-level gap blocks the tag.

### Side-effect improvements from A3 landing (2026-04-24)

After the A3 SE-0517 alignment on `Ownership.Unique`, an audit of the other heap-cell-adjacent types applied the same learnings:

- **`Ownership.Mutable`**: dropped `withValue(_:)` and `update(_:)` closure shims — redundant with `var value { _read _modify }` accessor.
- **`Ownership.Transfer.Storage`**: renamed `consuming func take()` → `consuming func consume()` and `consuming func takeIfStored()` → `consuming func consumeIfStored()` — SE-0517 vocabulary for "consuming self, yield value".
- **`Ownership.Transfer.Retained`**: renamed `consuming func take()` → `consuming func consume()`. Initially kept as `take()` for Apple `Unmanaged.takeRetainedValue()` parallel, but the second review pass applied the principal's "perfect in isolation — don't accommodate downstream" guidance: internal consistency wins. All `consuming` extractors across the package now use `consume()`; non-consuming atomic extractors (`Slot.take`, `Cell.Token.take`, `Optional.take`) keep `take()`.
- **`Ownership.Borrow`**, **`Ownership.Inout`**, **`Ownership.Shared`**, **`Ownership.Mutable.Unchecked`**, **`Ownership.Slot`**: audited, no changes — already aligned with the relevant subset of SE-0517 learnings.

Final convention across the package:
- `consume()` — `consuming func` that destroys `self` and yields its owned value (SE-0517 pattern)
- `take()` — non-consuming atomic extractor on a Copyable container that stays usable (reusable or tokenized)

### Recommended next step

Taken. The totality-now path (A1 + A2 + A3 + B1 + B2 + F1) + the Unique
SE-0517 parity (A3) + the Slot.Store removal (A5) all landed in a single
five-phase session on 2026-04-24, plus two additional type additions not
in the original plan — `Ownership.Latch` (Phase 1 — promoted from the
internal `Transfer._Box`) and `Ownership.Indirect` (Phase 2 — CoW heap
cell). The lattice is complete at fifteen types.

Companion research:
- `Research/ownership-types-usage-and-justification.md` — cross-type merit + naming
- `Research/naming-transfer-box-to-erased.md` (A1 decision basis) — LANDED
- `Research/naming-slot-store-result-enum.md` (A5 — LANDED 2026-04-24)
- `Research/naming-unique-to-box.md` — SUPERSEDED by naming-box-ecosystem-survey
- `Research/naming-box-ecosystem-survey.md` (A3 decision basis) — LANDED
- `Research/naming-transfer-direction-pair.md` (A2 decision basis) — LANDED with semantic refinement (generic at kind layer)
- `Research/naming-shared-mutable-symmetry.md` (A4 — recommend DEFER)
