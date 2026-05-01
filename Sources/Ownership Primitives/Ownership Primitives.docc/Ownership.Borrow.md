# ``Ownership_Primitives/Ownership/Borrow``

@Metadata {
    @DisplayName("Ownership.Borrow")
    @TitleHeading("Ownership Primitives")
}

A safe read-only reference with a compiler-enforced lifetime; `Copyable` and `~Escapable`.

## Overview

`Ownership.Borrow<Value>` wraps an `UnsafeRawPointer` and exposes the pointee through a `_read` coroutine. `Value` admits `~Copyable & ~Escapable` — the latter via the raw-address init. Because `Borrow` itself is `Copyable`, multiple in-scope copies can coexist, and `Optional<Ownership.Borrow<Value>>` is a legitimate shape for peek-style APIs (which `Ownership.Inout`, being `~Copyable`, cannot support).

This type is the ecosystem equivalent of SE-0519's stdlib `Borrow<T>` (SwiftStdlib 6.4). Storage is `UnsafeRawPointer` rather than `Builtin.Borrow<Value>` so the type works on toolchains without SE-0507 `BorrowAndMutateAccessors` support — `_read` is the coroutine-based stand-in for the eventual `borrow` accessor.

## Example

```swift
import Ownership_Primitives

func peek<V>(_ value: borrowing V) -> Ownership.Borrow<V> {
    Ownership.Borrow(borrowing: value)
}
```

The returned `Borrow<V>` has lifetime `@_lifetime(borrow value)` — it cannot outlive the caller's `borrow value` scope.

## Rationale

Two constructions coexist because SE-0519 consumers want `.init(borrowing:)` ergonomics, while low-level implementations (pointer arithmetic, buffer indexing) want `.init(_ pointer:)`. The explicit `unsafeAddress` / `unsafeRawAddress` escape hatches cover cases where storage is pre-computed — for example, element access inside a ring buffer.

`Ownership.Borrow.`Protocol`` is the canonical borrow-capability protocol. Conforming types participate in the borrow hierarchy without authoring a bespoke accessor.

## Topics

### Constructors

- ``Ownership/Borrow/init(_:)``
- ``Ownership/Borrow/init(borrowing:)``
- ``Ownership/Borrow/init(unsafeAddress:borrowing:)``
- ``Ownership/Borrow/init(unsafeRawAddress:borrowing:)``

### Value Access

- ``Ownership/Borrow/value``

### Canonical Protocol

- ``Ownership/Borrow/Protocol``

## See Also

- ``Ownership/Inout``
- <doc:Borrow-vs-Inout>
