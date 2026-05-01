# ``Ownership_Primitives/Ownership/Mutable``

@Metadata {
    @DisplayName("Ownership.Mutable")
    @TitleHeading("Ownership Primitives")
}

An ARC-retained mutable reference to a heap-allocated value.

## Overview

`Ownership.Mutable<Value>` stores `Value: ~Copyable` in a `final class` backing and permits mutation through ARC-shared ownership. Because mutation on a shared reference is racy by default, `Mutable` is **not** `Sendable`. For cross-isolation scenarios where synchronization is provided externally (lock, actor, atomic), use ``Ownership/Mutable/Unchecked`` — the explicit `@unchecked Sendable` opt-in that makes the assertion site greppable.

## Example

```swift
import Ownership_Primitives

struct Counter: ~Copyable { var count: Int = 0 }

let cell = Ownership.Mutable(Counter())
// Multiple owners within one actor / synchronization context
increment(cell)
increment(cell)
```

## Rationale

`Mutable` fills the mutable-multi-owner slot in the cell family:

| Cell | Ownership | Mutation | Sendability |
|------|-----------|----------|-------------|
| ``Ownership/Unique`` | Exclusive | Yes | `Sendable` when `Value: Sendable` |
| ``Ownership/Shared`` | ARC-shared | No | `Sendable` when `Value: Sendable` |
| ``Ownership/Mutable`` | ARC-shared | Yes | **Not `Sendable`** |
| ``Ownership/Mutable/Unchecked`` | ARC-shared | Yes | `@unchecked Sendable` (opt-in) |

The deliberate non-`Sendable` shape forces callers to state their synchronization story explicitly: either keep the cell inside one isolation domain (use plain `Mutable`), or opt in at the call site (use `Mutable.Unchecked`). Implicit cross-isolation mutation is never accidental.

## Topics

### Unchecked Sendable Opt-In

- ``Ownership/Mutable/Unchecked``

## See Also

- ``Ownership/Unique``
- ``Ownership/Shared``
- <doc:Shared-vs-Mutable-vs-Unique>
