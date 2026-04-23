# ``Ownership_Primitives/Ownership/Inout``

@Metadata {
    @DisplayName("Ownership.Inout")
    @TitleHeading("Ownership Primitives")
}

A safe mutable reference with a compiler-enforced lifetime; `~Copyable` and `~Escapable`.

## Overview

`Ownership.Inout<Value>` wraps an `UnsafeMutablePointer<Value>` and exposes the pointee through split-by-copyability accessors. For `Copyable` `Value`, the accessor is `get` + `nonmutating _modify`; for `~Copyable` `Value`, the accessor is `_read` + `nonmutating _modify`. Both routes preserve interior mutability: the stored pointer is `let` — mutation flows through the pointee per [IMPL-071].

This type is the ecosystem equivalent of SE-0519's stdlib `Inout<T>`. It works on toolchains without SE-0507 `BorrowAndMutateAccessors` — coroutines are the stand-in for eventual `mutate` accessor support.

## Example

```swift
import Ownership_Primitives

struct Counter { var value: Int }

func increment(_ counter: inout Counter) {
    let ref = Ownership.Inout(mutating: &counter)
    ref.value = Counter(value: ref.value.value + 1)
    // Both sides of the assignment route through the shared pointer —
    // nonmutating _modify fires on the mutate, get on the read.
}
```

`Ownership.Inout(mutating:)` yields a reference whose lifetime is `@_lifetime(&value)` — it expires when the caller's `&counter` scope does.

## Rationale

The accessor split on copyability resolves a lifetime-escape interaction between `_read` coroutines and nested `@_lifetime(borrow self)` chains. When `Value: Copyable` and the call site reads through multiple stacked `Ownership.*` / `Property.*` coroutines (e.g., `base.value._buffer.peek.front`), the compound lifetime tagging from `_read` conservatively blocks the pure-read `return`. `get` returns a copy without the compound lifetime dependency; reads escape.

The `~Copyable` path retains `_read` because `get` is not available — there's no copy to return. Both paths keep `nonmutating _modify`: nested method-call mutations (`base.value.pop.front()`) must route through the real storage to preserve CoW on downstream `Copyable`-value containers. A `get` + `set` split would break CoW here — `set` writebacks do not fire for nested method-call mutations, so modifications on the throwaway `get` copy would be silently discarded.

`Ownership.Inout` is itself `~Copyable, ~Escapable`: exclusivity falls out of `~Copyable` (two mutable references cannot coexist because the `Inout` value cannot be copied), and `~Escapable` bounds the reference to its source scope.

## Topics

### Constructors

- ``Ownership/Inout/init(_:)``
- ``Ownership/Inout/init(mutating:)``
- ``Ownership/Inout/init(unsafeAddress:mutating:)``

### Value Access

- ``Ownership/Inout/value``

## See Also

- ``Ownership/Borrow``
- <doc:Borrow-vs-Inout>
