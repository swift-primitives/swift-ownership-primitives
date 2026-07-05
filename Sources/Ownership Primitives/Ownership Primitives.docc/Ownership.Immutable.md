# ``Ownership_Primitives/Ownership/Immutable``

@Metadata {
    @DisplayName("Ownership.Immutable")
    @TitleHeading("Ownership Primitives")
}

An ARC-retained immutable reference to a heap-allocated value.

## Overview

`Ownership.Immutable<Value>` stores a `Value: ~Copyable & Sendable` on the heap in a `final class` backing and provides multiple-owner semantics through ARC. The payload is immutable after construction — every reader sees the same value for the lifetime of any owner. Because the value cannot change, `Immutable<Value>` is safely `Sendable`.

## Example

```swift
import Ownership_Primitives

let config = Configuration.loadDefaults()
let shared = Ownership.Immutable(config)

// Multiple owners — all see the same immutable value.
hand(shared, to: threadA)
hand(shared, to: threadB)
```

## Rationale

`Immutable` fills the immutable-multi-owner slot in the cell family:

| Cell | Ownership | Mutation |
|------|-----------|----------|
| ``Ownership/Unique`` | Exclusive | Yes |
| ``Ownership/Immutable`` | ARC-shared | **No** |
| ``Ownership/Mutable`` | ARC-shared | Yes (not `Sendable`) |

Use `Immutable` when passing a large `~Copyable` value across owners — configuration records, parsed documents, static catalogues — where the construction cost is non-trivial and the value is conceptually immutable. The `Sendable` property falls out of immutability; no synchronization is required.

## See Also

- ``Ownership/Unique``
- ``Ownership/Mutable``
- <doc:Immutable-vs-Mutable-vs-Unique>
