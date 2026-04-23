# ``Ownership_Primitives/Ownership/Mutable/Unchecked``

@Metadata {
    @DisplayName("Ownership.Mutable.Unchecked")
    @TitleHeading("Ownership Primitives")
}

An explicit `@unchecked Sendable` opt-in over ``Ownership/Mutable``.

## Overview

`Ownership.Mutable.Unchecked<Value>` is `@unsafe @unchecked Sendable` — it tells the compiler "I've established synchronization externally; trust the cell across `@Sendable` boundaries." The underlying storage is identical to `Mutable`; the difference is the `Sendable` assertion.

This type exists so every cross-isolation escape from plain `Mutable` is greppable. A code review looking for "where do we mutate shared state across actors?" searches for `Mutable.Unchecked`, and every site surfaces.

## When to Use

Use `Mutable.Unchecked` when ALL of the following hold:

- You need an ARC-shared mutable cell across `@Sendable` boundaries.
- External synchronization is in place (`Mutex`, atomic operations, an actor routing access, a read-write lock).
- You can point to the synchronization mechanism in review.

If you can push the mutation into an actor, do that instead. If you can scope the cell to one isolation domain, use plain ``Ownership/Mutable``. `Unchecked` is the last resort.

## Example

```swift
import Ownership_Primitives
import Synchronization

struct State: ~Copyable { /* ... */ }

let mutex = Mutex(State())
let cell = Ownership.Mutable.Unchecked(...)   // externally synchronized
// Crossing a Sendable boundary is sound because mutex.withLock guards access.
```

## See Also

- ``Ownership/Mutable``
- <doc:Shared-vs-Mutable-vs-Unique>
