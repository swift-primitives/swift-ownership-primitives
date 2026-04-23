# ``Ownership_Primitives/Ownership/Shared``

@Metadata {
    @DisplayName("Ownership.Shared")
    @TitleHeading("Ownership Primitives")
}

An ARC-retained immutable reference to a heap-allocated value.

## Overview

`Ownership.Shared<Value>` stores a `Value: ~Copyable & Sendable` on the heap in a `final class` backing and provides multiple-owner semantics through ARC. The payload is immutable after construction — every reader sees the same value for the lifetime of any owner. Because the value cannot change, `Shared<Value>` is safely `Sendable`.

## Example

```swift
import Ownership_Primitives

let config = Configuration.loadDefaults()
let shared = Ownership.Shared(config)

// Multiple owners — all see the same immutable value.
hand(shared, to: threadA)
hand(shared, to: threadB)
```

## Rationale

`Shared` fills the immutable-multi-owner slot in the cell family:

| Cell | Ownership | Mutation |
|------|-----------|----------|
| ``Ownership/Unique`` | Exclusive | Yes |
| ``Ownership/Shared`` | ARC-shared | **No** |
| ``Ownership/Mutable`` | ARC-shared | Yes (not `Sendable`) |

Use `Shared` when passing a large `~Copyable` value across owners — configuration records, parsed documents, static catalogues — where the construction cost is non-trivial and the value is conceptually immutable. The `Sendable` property falls out of immutability; no synchronization is required.

## See Also

- ``Ownership/Unique``
- ``Ownership/Mutable``
- <doc:Shared-vs-Mutable-vs-Unique>
