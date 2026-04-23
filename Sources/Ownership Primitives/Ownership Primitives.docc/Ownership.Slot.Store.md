# ``Ownership_Primitives/Ownership/Slot/Store``

@Metadata {
    @DisplayName("Ownership.Slot.Store")
    @TitleHeading("Ownership Primitives")
}

Result type returned by `Ownership.Slot.store(_:)` — either the value was accepted, or the slot was already occupied and the value is returned to the caller.

## Overview

`Slot.Store` is a `~Copyable` enum with two cases:

- `.stored` — the slot was empty; the value is now stored.
- `.occupied(Value)` — the slot was already full; the value is returned (not stored).

`~Copyable` reflects the contained `Value: ~Copyable` — the result carries ownership of the unstored value back to the caller, which is an exactly-once handoff.

## Example

```swift
import Ownership_Primitives

switch slot.store(resource) {
case .stored:
    metrics.recordStored()
case .occupied(let returned):
    releaseElsewhere(returned)
}
```

## Rationale

This type exists so `store(_:)` can be **total** — no exceptions, no traps. Callers that cannot prove the slot is empty at the call site use `store(_:)` and exhaustively handle both cases. Callers that *can* prove it use the trapping fluent form `slot.move.in(_)` (see ``Ownership/Slot/Move``) instead.

## See Also

- ``Ownership/Slot``
- ``Ownership/Slot/Move``
- <doc:Slot-Move-vs-Store>
