# ``Ownership_Primitives/Ownership/Unique``

@Metadata {
    @DisplayName("Ownership.Unique")
    @TitleHeading("Ownership Primitives")
}

A heap-owned, exclusively-owned single-value cell.

## Overview

`Ownership.Unique<Value>` heap-allocates a single value and owns it
exclusively. The type is always `~Copyable` — copies are forbidden —
so the owner is guaranteed to be unique at every point in the value's
lifetime. On destruction (either via ``Ownership/Unique/consume()`` or
scope-exit `deinit`), the value is deinitialised and the heap storage
is deallocated.

This is the Institute's Nest.Name rendering of Apple stdlib's
`Swift.UniqueBox<Value: ~Copyable>` (SE-0517, accepted March 2026). The
compound-form `UniqueBox` name is expressed here as `Ownership.Unique`
per `[API-NAME-001]`; semantics and API surface mirror SE-0517.

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

cell.value.timeout = .seconds(30)         // _modify coroutine
let owned = cell.consume()                 // cell no longer exists
```

## No Empty State

An `Ownership.Unique` instance always holds a value while it exists.
There is no observable "empty" state. Callers who need optional
ownership should use `Ownership.Unique<Value>?`:

```swift
var maybe: Ownership.Unique<Resource>? = Ownership.Unique(resource)
if let cell = maybe.take() {                // consume the Optional's payload
    let value = cell.consume()
    use(value)
}
// maybe is now nil; there is no "empty Unique" to re-observe.
```

This matches SE-0517's design choice and eliminates the class of bugs
from re-observing a taken cell.

## Rationale

`Ownership.Unique` is the named primitive for "own this value on the
heap with deterministic cleanup". It replaces the common manual pattern:

```swift
let storage = UnsafeMutablePointer<T>.allocate(capacity: 1)
storage.initialize(to: value)
// ... every exit path: storage.deinitialize(count: 1); storage.deallocate()
```

with a single `@safe`, `~Copyable` struct whose `init` allocates and
whose `deinit` / `consume()` reliably deallocates.

## Sendable

`Ownership.Unique` is `@unsafe @unchecked Sendable` when
`Value: ~Copyable & Sendable`. The `@unchecked` is required because
the stored `UnsafeMutablePointer<Value>` is non-Sendable by stdlib
`@unsafe` conformance. The exclusive-ownership contract enforced by
the `~Copyable` wrapper plus `Value`'s own Sendable guarantee make the
concrete type safe to transfer — only one thread can hold an
`Ownership.Unique<Value>` at a time — so the conformance is sound.

## Topics

### Construction

- ``Ownership/Unique/init(_:)``

### Direct Access

- ``Ownership/Unique/value``

### Span Access

- ``Ownership/Unique/span``
- ``Ownership/Unique/mutableSpan``

### Consume

- ``Ownership/Unique/consume()``

### Deep Copy (Copyable Value)

- ``Ownership/Unique/clone()``

## See Also

- ``Ownership/Shared``
- ``Ownership/Mutable``
- <doc:Shared-vs-Mutable-vs-Unique>
