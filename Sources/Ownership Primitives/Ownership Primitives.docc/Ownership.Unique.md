# ``Ownership_Primitives/Ownership/Unique``

@Metadata {
    @DisplayName("Ownership.Unique")
    @TitleHeading("Ownership Primitives")
}

A unique-ownership heap cell with deterministic deinitialization.

## Overview

`Ownership.Unique<Value>` heap-allocates a single `~Copyable` value and owns it exclusively. The type is always `~Copyable` to prevent accidental duplication and double-free; for `Copyable` `Value`, a `duplicated()` extension provides explicit deep-copy semantics.

Memory is deallocated at `deinit` unless explicitly released via `leak()`. Access is through `withValue` (borrowing) or `withMutableValue` (inout); `take()` moves the value out and empties the cell.

`Unique` is `Sendable` when `Value: Sendable` — the exclusive ownership model means there is no sharing to synchronize.

## Example

```swift
import Ownership_Primitives

struct Request: ~Copyable {
    var url: String
    var timeout: Duration
}

var cell = Ownership.Unique(
    Request(url: "https://example.com", timeout: .seconds(5))
)

cell.withMutableValue { $0.timeout = .seconds(30) }
let owned = cell.take()      // cell.hasValue == false after this
```

## Rationale

`Unique` is the Swift equivalent of Rust's `Box<T>`: one owner, heap storage, deterministic cleanup. It replaces the common manual pattern:

```swift
let storage = UnsafeMutablePointer<T>.allocate(capacity: 1)
storage.initialize(to: value)
// ... every exit path: storage.deinitialize(count: 1); storage.deallocate()
```

with a single `@safe`, `~Copyable` struct. The storage is `nil` only after `take()` / `leak()`; all other operations are precondition-checked against the "empty" state.

`leak()` is the explicit escape hatch for interop cases where ownership transfers out of Swift (e.g., passing to a C API that takes raw ownership). The caller becomes responsible for deinitialization and deallocation.

## Topics

### Construction

- ``Ownership/Unique/init(_:)``

### Scoped Access

- ``Ownership/Unique/withValue(_:)``
- ``Ownership/Unique/withMutableValue(_:)``

### Move Out

- ``Ownership/Unique/take()``
- ``Ownership/Unique/leak()``

### State

- ``Ownership/Unique/hasValue``

## See Also

- ``Ownership/Shared``
- ``Ownership/Mutable``
- <doc:Shared-vs-Mutable-vs-Unique>
