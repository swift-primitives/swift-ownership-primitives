# ``Ownership_Primitives/Ownership/Transfer``

@Metadata {
    @DisplayName("Ownership.Transfer")
    @TitleHeading("Ownership Primitives")
}

Namespace for cross-boundary ownership transfer primitives with exactly-once semantics.

## Overview

`Ownership.Transfer` is a namespace (empty `enum`) that groups four one-shot transfer shapes:

- ``Ownership/Transfer/Cell`` — pass an existing `~Copyable` value through a `@Sendable` boundary.
- ``Ownership/Transfer/Storage`` — create a value inside a closure; retrieve on the originating side.
- ``Ownership/Transfer/Retained`` — zero-allocation transfer for `AnyObject` types.
- ``Ownership/Transfer/Box`` — type-erased boxing for opaque-pointer scenarios.

Tokens for each variant are `Copyable` (so they can be captured by `@Sendable` escaping closures), but only one `take` / `store` operation succeeds — subsequent calls either trap or return the value back. Thread safety comes from atomic CAS enforcement; the types are `@unchecked Sendable` where applicable.

## When to Use

Use `Transfer.*` when ownership must cross a `@Sendable` boundary exactly once. For reusable slots (cycle between empty and full), use ``Ownership/Slot`` instead. For exclusive heap-ownership within a single thread, use ``Ownership/Unique``.

See <doc:Ownership-Transfer-Recipes> for the full recipe catalog.

## Topics

### Direction: Passing Out

- ``Ownership/Transfer/Cell``
- ``Ownership/Transfer/Retained``

### Direction: Receiving In

- ``Ownership/Transfer/Storage``

### Type Erasure

- ``Ownership/Transfer/Box``

## See Also

- ``Ownership/Slot``
- ``Ownership/Unique``
- <doc:Ownership-Transfer-Recipes>
