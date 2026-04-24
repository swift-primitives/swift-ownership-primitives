# ``Ownership_Primitives/Ownership/Slot/Move``

@Metadata {
    @DisplayName("Ownership.Slot.Move")
    @TitleHeading("Ownership Primitives")
}

Fluent trapping accessor for ``Ownership/Slot`` store/take operations.

## Overview

`Slot.Move` is returned by `slot.move`. It exposes `.in(_)` (store) and `.out` (take), both of which trap on failure. Use this surface when the caller has already proved — through invariant or logic — that the operation cannot fail; traps surface logic errors at the call site rather than propagating them as result values.

## Example

```swift
import Ownership_Primitives

let slot = Ownership.Slot<Resource>()

// Known-empty slot: .in(_) traps if the invariant is violated.
slot.move.in(resource)

// Known-full slot: .out traps if already taken.
let taken = slot.move.out
```

## When to Use

| Surface | Guarantee | API |
|---------|-----------|-----|
| Total | Caller handles every outcome | `slot.store(_:)` / `slot.take()` |
| Fluent trapping | Caller has proven success | `slot.move.in(_)` / `slot.move.out` |

The fluent form exists so call sites with established invariants don't need to write `__unchecked:` argument noise.

## See Also

- ``Ownership/Slot``
- <doc:Slot-Move-vs-Store>
