# ``Ownership_Primitives/Ownership/Box``

@Metadata {
    @DisplayName("Ownership.Box")
    @TitleHeading("Ownership Primitives")
}

A heap-allocated copy-on-write cell — the single copy-on-write box of the ownership layer.

## Overview

`Ownership.Box<Value>` wraps a value in a refcounted heap cell with copy-on-write (CoW) semantics: reads yield a borrow without allocating; writes check whether the backing is uniquely referenced and clone it before mutating if shared. It is `Copyable` exactly when `Value` is — `Copyable` payloads share the cell until the first mutation restores uniqueness, and `~Copyable` payloads are statically unique (move-only), so no copy-on-write surface exists for them and the uniqueness gate is a proven no-op.

`Box` is the copy-on-write sibling of ``Ownership/Unique`` (the exclusive `~Copyable` cell), mirroring Apple's `Swift.Box` / `Swift.UniqueBox` split — SE-0517 reserves bare `Box` for exactly this copy-on-write variant.

## Witnesses keep the cell payload-generic

Teardown (`drain`) and deep-copy (`clone`) strategies are injected at construction, so the cell learns no element, index, or collection vocabulary. The `Copyable` convenience initializer supplies whole-value defaults; payload-specific cells (e.g. buffer columns) supply their own. `clone == nil` ⟺ statically unique ⟹ the gate is a proven no-op ⟹ move-only for free. The cell's `Storage` owns payload teardown in its own `deinit` (the drain-box rule, [MEM-SAFE-028]).

## Example

```swift
import Ownership_Primitives

var a = Ownership.Box<[Int]>([1, 2, 3])
var b = a                       // no copy yet — a and b share the cell
b.value.append(4)               // copy-on-write: b's cell is cloned here
// a.value == [1, 2, 3]
// b.value == [1, 2, 3, 4]
```

## Lazy copy-on-write vs eager `clone()`

Two deep-copy shapes are offered:

- **Lazy CoW** via `value`'s `_modify`: the copy happens the first time a shared cell is mutated. Cheap reads, cheap shared copies, cost paid at the moment of mutation.
- **Eager clone** via ``Ownership/Box/clone()``: the copy happens immediately, independent of sharing. Use when subsequent mutations are certain and the CoW branch's runtime check is avoidable, or when you want to explicitly decouple a copy from its original.

## When to Use

| Need | Type |
|------|------|
| Value semantics with lazy heap sharing (copy-on-write) | ``Ownership/Box`` |
| Exclusive single-owner heap cell for a `~Copyable` value | ``Ownership/Unique`` |
| Heap-shared immutable value (reference-identity) | ``Ownership/Immutable`` |
| Heap-shared mutable value (reference-identity) | ``Ownership/Mutable`` |
| Reusable atomic slot (cycles empty ↔ full) | ``Ownership/Slot`` |
| One-shot atomic cell (terminal after take) | ``Ownership/Latch`` |

## Sendable

`Ownership.Box<Value>` is conditionally `@unchecked Sendable where Value: Sendable & ~Copyable`, mirroring the stdlib `Array` / `Dictionary` CoW pattern. The copy-on-write uniqueness check plus the copy-before-mutate discipline preserve correctness under concurrent access: two threads each racing to mutate a shared cell each observe non-unique backings, each clone their own, and each proceed against an independently-owned value. The sole unchecked lane is ``Ownership/Box/unguarded``, whose name states the caller's uniqueness obligation. Contention wastes work; correctness is preserved.

## Topics

### Construction

- ``Ownership/Box/init(_:drain:clone:)``
- ``Ownership/Box/init(_:)``

### Reading and Mutating

- ``Ownership/Box/value``
- ``Ownership/Box/clone()``

### Uniqueness

- ``Ownership/Box/isUnique``
- ``Ownership/Box/ensureUnique()``
- ``Ownership/Box/unguarded``
- ``Ownership/Box/identity``
