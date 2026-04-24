# ``Ownership_Primitives/Ownership/Latch``

@Metadata {
    @DisplayName("Ownership.Latch")
    @TitleHeading("Ownership Primitives")
}

A one-shot atomic cell holding a single `~Copyable` value with exactly-once publication and consumption.

## Overview

`Ownership.Latch<Value>` is a `final class` holding at most one value across its lifetime, with an atomic state machine (`empty → initializing → full → taken`) that ensures a value is published exactly once and taken exactly once. Multiple ARC holders may share the latch, but only one ``Ownership/Latch/take()`` (or ``Ownership/Latch/takeIfPresent()``) call succeeds across all holders.

Unlike ``Ownership/Slot``, which cycles indefinitely between `empty` and `full`, `Latch` is *terminal* after its sole value is consumed. The vocabulary mirrors Java's `CountDownLatch` and the broader "latch" concept in concurrency literature — once triggered, the latch does not reset. This makes `Latch` the right primitive for one-shot hand-off patterns (futures, promises, single-publication channels).

## Example

```swift
import Ownership_Primitives

let latch = Ownership.Latch<Resource>()

// Producer thread
latch.store(resource)

// Consumer thread (after happens-before established)
let resource = latch.take()
```

## Thread Safety

All operations are atomic. The latch can be safely shared across threads: publication uses release-acquire semantics, so any thread that observes `.full` sees the write from the producer's `store(_:)` that preceded it. The state machine precludes the "observable mid-store" race — the intermediate `initializing` state is never observable as takeable, and the atomic CAS chain establishes the happens-before edge consumers need.

## Relationship to the Transfer Family

``Ownership/Transfer`` composes `Latch` with Sendable token types to model cross-boundary transfer. `Latch` itself is the underlying atomic hand-off primitive; use it directly when you want one-shot hand-off with maximum simplicity (no Token indirection, no separate Storage / Cell split) and direct shared-reference semantics across threads.

| Use case | Type |
|----------|------|
| One-shot hand-off, direct ARC sharing | ``Ownership/Latch`` |
| One-shot hand-off, Token-based cross-boundary | ``Ownership/Transfer/Cell`` / ``Ownership/Transfer/Storage`` |
| Reusable slot (cycles empty ↔ full) | ``Ownership/Slot`` |

## Topics

### Construction

- ``Ownership/Latch/init()``
- ``Ownership/Latch/init(_:)``

### Operations

- ``Ownership/Latch/store(_:)``
- ``Ownership/Latch/take()``
- ``Ownership/Latch/takeIfPresent()``

### Inspection

- ``Ownership/Latch/hasValue``

## See Also

- ``Ownership/Slot``
- ``Ownership/Transfer``
