# ``Ownership_Primitives/Ownership/Indirect``

@Metadata {
    @DisplayName("Ownership.Indirect")
    @TitleHeading("Ownership Primitives")
}

A heap-allocated copy-on-write value cell.

## Overview

`Ownership.Indirect<Value>` wraps a `Copyable` value in heap storage with copy-on-write (CoW) semantics: reads yield a borrow without allocating; writes check whether the heap storage is uniquely referenced and clone it before mutating if shared. Independent cells observe the value-semantic behaviour expected of a `Copyable` type — mutations through one cell never leak into another — but the physical copy is deferred until the moment it becomes observable.

The name mirrors Swift's `indirect` keyword on recursive enum cases: both place a value behind one level of heap indirection so that identically-valued instances may share a physical representation. The spelling avoids the rejected `Ownership.Copyable` alternative (which would clash with the stdlib `Copyable` protocol).

## Example

```swift
import Ownership_Primitives

var a = Ownership.Indirect<[Int]>([1, 2, 3])
var b = a                       // no copy yet — a and b share storage
b.value.append(4)               // CoW: b's storage is cloned here
// a.value == [1, 2, 3]
// b.value == [1, 2, 3, 4]
```

## CoW vs `clone()`

Two deep-copy shapes are offered:

- **Lazy CoW** via `value { _read _modify }`: the copy happens the first time a shared cell is mutated. Cheap reads, cheap shared copies, cost paid at the moment of mutation.
- **Eager clone** via ``Ownership/Indirect/clone()``: the copy happens immediately, independent of sharing. Use when subsequent mutations are certain and the CoW branch's runtime check is avoidable, or when you want to explicitly decouple a copy from its original.

## When to Use

| Need | Type |
|------|------|
| Value semantics with lazy heap sharing | ``Ownership/Indirect`` |
| Exclusive single-owner heap cell for a `~Copyable` value | ``Ownership/Unique`` |
| Heap-shared immutable value (reference-identity) | ``Ownership/Shared`` |
| Heap-shared mutable value (reference-identity) | ``Ownership/Mutable`` |
| Reusable atomic slot (cycles empty ↔ full) | ``Ownership/Slot`` |
| One-shot atomic cell (terminal after take) | ``Ownership/Latch`` |

## Sendable

`Ownership.Indirect<Value>` is conditionally `@unchecked Sendable where Value: Sendable`, mirroring the stdlib `Array` / `Dictionary` CoW pattern. The CoW uniqueness check plus the copy-before-mutate discipline preserve correctness under concurrent access: two threads each racing to mutate a shared cell each observe non-unique references, each clone their own storage, and each proceed against an independently-owned value. Contention wastes work; correctness is preserved.

## Topics

### Construction

- ``Ownership/Indirect/init(_:)``

### Operations

- ``Ownership/Indirect/value``
- ``Ownership/Indirect/clone()``
