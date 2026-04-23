# ``Ownership_Primitives/Ownership/Transfer/Box``

@Metadata {
    @DisplayName("Ownership.Transfer.Box")
    @TitleHeading("Ownership Primitives")
}

Type-erased boxing for opaque-pointer transfer scenarios.

## Overview

`Transfer.Box` provides the ownership-transfer contract through a type-erased slot. Use it when the boundary is opaque (e.g., a C API taking `void*`) and the typed wrappers (``Ownership/Transfer/Cell``, ``Ownership/Transfer/Storage``, ``Ownership/Transfer/Retained``) cannot express the crossing.

On the receiving side, the typed value is recovered by re-associating with the expected `T`.

## When to Use

- You are interoperating with a C API or opaque-pointer protocol that cannot accept a typed Swift generic.
- You need to carry an arbitrary value through an opaque slot (e.g., a `UnsafeMutableRawPointer`-typed context parameter) with ownership semantics.

For typed boundaries, prefer ``Ownership/Transfer/Cell`` — it keeps the value type in the type system.

## See Also

- ``Ownership/Transfer``
- ``Ownership/Transfer/Cell``
- <doc:Ownership-Transfer-Recipes>
