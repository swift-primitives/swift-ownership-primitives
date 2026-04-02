# Audit: Ownership.Borrow / Ownership.Inout — stdlib parity

> **Date**: 2026-03-31
> **Scope**: `Ownership.Borrow` and `Ownership.Inout` vs stdlib `Borrow<T>` and `Inout<T>` (SE-0519, SwiftStdlib 6.4)
> **Source**: `/Users/coen/Developer/swiftlang/swift/stdlib/public/core/Borrow.swift`, `Inout.swift`
> **Target**: `/Users/coen/Developer/swift-primitives/swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Borrow.swift`, `Ownership.Inout.swift`
> **Result**: **PASS** — no parity gaps. All divergences are intentional ecosystem adaptations or toolchain constraints.

---

## Ownership.Borrow vs stdlib Borrow\<T\>

| # | Feature | stdlib | Ours | Verdict |
|---|---------|--------|------|---------|
| 1 | Type constraints | `Copyable, ~Escapable` | `~Escapable` | PASS — Copyable is the implicit default |
| 2 | `@frozen` | Yes | No | PASS — ABI stability, stdlib-only concern |
| 3 | `@safe` | No | Yes | NOTED — stdlib stores `Builtin.Borrow` (not a pointer); we store `UnsafePointer`, so `@safe` is correct for us |
| 4 | Storage | `Builtin.Borrow<Value>` | `UnsafePointer<Value>` | PASS — Builtin unavailable outside stdlib |
| 5 | `init(_ value: borrowing Value)` | Unlabeled `init(_:)` | Labeled `init(borrowing:)` | NOTED — our unlabeled slot is taken by `init(_ pointer:)`. Matches `Property.View.Read.init(borrowing:)` ecosystem pattern |
| 6 | `init(_ pointer:)` | N/A | Yes | PASS — ecosystem addition for buffer access |
| 7 | `init(unsafeAddress:borrowing:)` | `@unsafe @_lifetime(borrow owner)` | Same | PASS — exact parity |
| 8 | `var value` accessor | `borrow { }` | `_read { yield }` | PASS — `BorrowAndMutateAccessors` not in production compiler |
| 9 | `@_alwaysEmitIntoClient` / `@_transparent` | Yes | `@inlinable` | PASS — stdlib-internal optimization attrs |
| 10 | `@_unsafeSelfDependentResult` | Not on Borrow | Not used | PASS |

## Ownership.Inout vs stdlib Inout\<T\>

| # | Feature | stdlib | Ours | Verdict |
|---|---------|--------|------|---------|
| 1 | Type constraints | `~Copyable, ~Escapable` | Same | PASS |
| 2 | `@frozen` | Yes | No | PASS — stdlib-only |
| 3 | `@safe` | Yes | Yes | PASS |
| 4 | Storage | `let pointer: UnsafeMutablePointer<Value>` | `let _pointer: ...` | PASS — underscore prefix is package convention |
| 5 | `init(_ value: inout Value)` | Unlabeled `init(_:)` with `@_lifetime(&value)` | Labeled `init(mutating:)` with `@_lifetime(&value)` | NOTED — same reasoning as Borrow |
| 6 | `init(_ pointer:)` | N/A | Yes | PASS — ecosystem addition |
| 7 | `init(unsafeAddress:mutating:)` | `@unsafe @_lifetime(&owner)` | Same | PASS — exact parity |
| 8 | `var value` borrow | `borrow { }` | `_read { yield }` | PASS |
| 9 | `var value` mutate | `mutate { }` | `nonmutating _modify { yield }` | FINDING-1 |
| 10 | `@_unsafeSelfDependentResult` | Yes (on both borrow + mutate) | No | FINDING-2 |

---

## Findings

### FINDING-1: `nonmutating _modify` vs stdlib `mutate`

**Severity**: Informational (intentional extension)

The stdlib's `mutate` accessor has no ownership modifier. Our `nonmutating _modify` adds the ability to mutate through a `let`-bound `Inout`, which is an intentional extension per [IMPL-071] (interior mutability through raw pointer). Since `Inout` is `~Copyable`, exclusivity is guaranteed regardless of the ownership modifier on the accessor.

**Action**: None. This is strictly more capable than stdlib.

### FINDING-2: `@_unsafeSelfDependentResult` absent

**Severity**: Track for migration

The stdlib uses `@_unsafeSelfDependentResult` on both accessors of `Inout.value`. It tells the compiler the result's lifetime depends on `self`. Our `_read`/`_modify` coroutines scope the yield implicitly — the value is only valid during the coroutine's suspension, so the lifetime dependency is enforced structurally.

This attribute would become relevant when migrating to `borrow`/`mutate` accessors (SE-0507, `BorrowAndMutateAccessors`). The `borrow`/`mutate` accessors may not have the same implicit scoping as `_read`/`_modify` coroutines.

**Action**: No action now. Re-evaluate when `BorrowAndMutateAccessors` ships in a production compiler.

---

## Intentional Divergences Summary

| Divergence | Reason | Applies to |
|------------|--------|------------|
| `@inlinable` instead of `@_alwaysEmitIntoClient` / `@_transparent` | stdlib-internal optimization attributes | Both |
| No `@frozen` | ABI stability concern, stdlib-only | Both |
| Labeled value inits (`borrowing:` / `mutating:`) instead of unlabeled | Unlabeled slot taken by pointer init; matches `Property.View.Read.init(borrowing:)` ecosystem pattern | Both |
| Extra `init(_ pointer:)` | Ecosystem addition for direct buffer access (ring buffer, storage types) | Both |
| `_read` / `_modify` instead of `borrow` / `mutate` | `BorrowAndMutateAccessors` not available in production compiler | Both |
| `@safe` on Borrow (stdlib doesn't have it) | stdlib stores `Builtin.Borrow` (compiler-managed); we store `UnsafePointer` (needs `@safe` annotation) | Borrow only |
| `nonmutating _modify` on Inout | [IMPL-071] interior mutability through raw pointer; stdlib's `mutate` doesn't have ownership modifier | Inout only |
