# Audit: swift-ownership-primitives

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
