# ``Ownership_Primitives/Ownership/Slot``

@Metadata {
    @DisplayName("Ownership.Slot")
    @TitleHeading("Ownership Primitives")
}

A reusable atomic heap slot for a single `~Copyable` value.

## Overview

`Ownership.Slot<Value>` is a `final class` holding one value at a time, with an atomic state machine (`empty` ↔ `full`) protecting all observable state. The slot can be safely shared across threads: publication of a stored value uses release-acquire semantics, so any thread that observes `.full` sees the write from `initialize(to:)` that preceded it.

Unlike ``Ownership/Transfer``, which is one-shot, `Slot` is reusable — it cycles between empty and full indefinitely. Use it for resource pools, long-lived channels, or any pattern where the same storage is reused across many `store`/`take` pairs.

## Example

```swift
import Ownership_Primitives

let slot = Ownership.Slot<Resource>()

switch slot.store(resource) {
case .stored:
    // Resource stored — slot is now full
    break
case .occupied(let returned):
    // Slot was full; the value we tried to store is returned
    release(returned)
}

if let taken = slot.take() {
    use(taken)
}
```

## Rationale

`Slot` exposes two API surfaces:

- **Total**: `store(_:)` → `Store` result enum; `take()` → `Value?`. Use when failure is an expected outcome (e.g., a pool where "slot full" is routine).
- **Fluent trapping**: `slot.move.in(_)` and `slot.move.out` (see ``Ownership/Slot/Move``). Use when the caller has pre-proved success; traps surface logic errors at the call site rather than propagating them as values.

The atomic state machine uses three states internally: `empty` (0), `initializing` (1, transient), `full` (2). Observers never see `initializing` — the CAS reserves the slot, `initialize(to:)` writes the value, and the release-store publishes. On the take side, the acquire-CAS establishes happens-before with the initialization write before calling `move()`.

## Topics

### Construction

- ``Ownership/Slot/init()``
- ``Ownership/Slot/init(_:)``

### Total API

- ``Ownership/Slot/store(_:)``
- ``Ownership/Slot/take()``

### Fluent API

- ``Ownership/Slot/move``
- ``Ownership/Slot/Move``
- ``Ownership/Slot/Store``

## See Also

- ``Ownership/Transfer``
- <doc:Slot-Move-vs-Store>
