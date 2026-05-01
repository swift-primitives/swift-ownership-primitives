# Borrow vs Inout

@Metadata {
    @DisplayName("Borrow vs Inout")
    @TitleHeading("Ownership Primitives")
}

Pick ``Ownership/Borrow`` for read-only scoped references and ``Ownership/Inout`` for mutable scoped references. The two types differ along three dimensions — copyability, mutability, and what `Value` they can carry — and each dimension has a single correct choice given the call site's needs.

## Decision Matrix

| Need | Type | Why |
|------|------|-----|
| Read-only reference you can duplicate within the scope | ``Ownership/Borrow`` | `Copyable, ~Escapable` — multiple copies within the borrow scope are safe |
| `Optional<Borrow<Value>>` for peek-style APIs | ``Ownership/Borrow`` | The read side can carry `Optional`; ``Ownership/Inout`` cannot (it is `~Copyable`) |
| Mutable reference with exclusive access | ``Ownership/Inout`` | `~Copyable, ~Escapable` — exclusivity is compiler-guaranteed by `~Copyable` |
| Reference to a `~Escapable` `Value` (e.g., a `Span`) | ``Ownership/Borrow`` (raw-address init) | `Borrow` admits `~Escapable` `Value` via `init(unsafeRawAddress:borrowing:)`; `Inout` is `~Escapable` only in its own shape |
| Stored as a field with `@_lifetime(...)` | Either | Both are `~Escapable` and storable as the payload of a `~Copyable, ~Escapable` wrapper |

## Copyability

``Ownership/Borrow`` is `Copyable`. You can pass the same `Borrow` through multiple functions within its lifetime scope, fork it into children, or place it inside an `Optional` for peek-style APIs where "no value" is a valid state.

``Ownership/Inout`` is `~Copyable`. You pass it once (consuming), or borrow it (`borrowing Inout<V>`). Exclusivity falls out of the `~Copyable` constraint: two mutable references cannot exist to the same storage because the `Inout` value cannot be copied.

## Escapability

Both types are `~Escapable` — they cannot outlive their source. The compiler enforces this through `@_lifetime(...)` annotations on the init sites: `init(borrowing value: borrowing Value)` yields a `Borrow` whose lifetime is `borrow value`; `init(mutating value: inout Value)` yields an `Inout` whose lifetime is `&value`. When the source's scope ends, so does the reference.

## The `Copyable` / `~Copyable` Value Axis

`Ownership.Inout.value` splits on `Value` copyability to resolve a compiler lifetime-escape interaction:

| `Value` constraint | `get` accessor | `_modify` accessor |
|--------------------|----------------|--------------------|
| `Copyable` | `get { unsafe _pointer.pointee }` | `nonmutating _modify { yield unsafe &_pointer.pointee }` |
| `~Copyable` | `_read { yield unsafe _pointer.pointee }` | `nonmutating _modify { yield unsafe &_pointer.pointee }` |

The `Copyable` `get` escapes the compound coroutine lifetime chain that `_read` introduces, letting `base.value._buffer.peek.front` return a `Copyable` `Element` without triggering a "lifetime-dependent value escapes its scope" error in chains that pass through multiple `@_lifetime(borrow self)` accessors. `_modify` is preserved on both paths so nested method-call mutations (`base.value.pop.front()`) route through the shared pointer, preserving CoW.

The `~Copyable` path uses `_read` because the `get`-style returning-by-copy shape is not available on `~Copyable` `Value` — there's no copy to return.

## Lifetime Attributes

| Init | Attribute | Lifetime binds to |
|------|-----------|-------------------|
| `Borrow(_ pointer:)` | `@_lifetime(borrow pointer)` | The pointer's lifetime scope |
| `Borrow(borrowing:)` | `@_lifetime(borrow value)` | The caller's `borrowing` scope |
| `Borrow(unsafeAddress:borrowing:)` | `@_lifetime(borrow owner)` | The owner's `borrowing` scope |
| `Inout(_ pointer:)` | (pointer scope) | The pointer's lifetime scope |
| `Inout(mutating:)` | `@_lifetime(&value)` | The caller's `&value` scope |
| `Inout(unsafeAddress:mutating:)` | `@_lifetime(&owner)` | The owner's `&owner` scope |

All four safe inits are `@safe`; the `unsafeAddress` variants are explicit escape hatches for the few call sites that need raw-address construction (e.g., element pointers into contiguous buffer storage).

## See Also

- ``Ownership/Borrow``
- ``Ownership/Inout``
- <doc:Shared-vs-Mutable-vs-Unique>
