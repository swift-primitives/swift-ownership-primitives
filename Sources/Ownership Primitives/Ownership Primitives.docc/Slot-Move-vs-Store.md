# Slot: Move vs Store

@Metadata {
    @DisplayName("Slot: Move vs Store")
    @TitleHeading("Ownership Primitives")
}

``Ownership/Slot`` is a reusable atomic one-value slot with two API surfaces: a **total** surface returning `Value?`, and a **fluent** surface that traps on failure.

## Decision Matrix

| Call site | API surface | When |
|-----------|-------------|------|
| Can observe and handle failure | `slot.store(_:)` / `slot.take()` (total) | Both return `Value?` — for `take()`, `.some(v)` is the value, `nil` means empty; for `store(_:)`, `nil` is success and `.some(v)` is the caller's value bounced back (shape mirrors stdlib `Dictionary.updateValue(_:forKey:)`) |
| Pre-proved success (invariant, logic-gated) | `slot.move.in(_)` / `slot.move.out` (trapping) | Trapping surfaces a logic error inside the call site rather than propagating it as a value |

Both surfaces operate on the same underlying state machine. The choice is about *how failure is expressed*, not *what is being done*.

## The State Machine

`Slot<Value>` transitions between two observable states:

```
  empty ─── store(x) ───▶ full
   ▲                        │
   │                        │
   └───── take() ───────────┘
```

An internal `initializing` state exists briefly between the CAS that reserves the slot and the release-store that publishes the value. Observers never see `initializing`; the happens-before relationship between `initialize(to:)` and the release-store guarantees visibility of the stored value on the take side.

## Total API: `store(_:)` / `take()`

Use when failure is an expected outcome. Both return `Value?` — for `store(_:)`, `nil` means success and `.some(v)` is the caller's value bounced back unconsumed; for `take()`, `.some(v)` is the stored value and `nil` means the slot was empty.

```swift
import Ownership_Primitives

let slot = Ownership.Slot<Resource>()

if let returned = slot.store(resource) {
    // Slot was already full; `returned` is the value we tried to store
    releaseElsewhere(returned)
}
// else: resource is now stored

if let taken = slot.take() {
    use(taken)
} else {
    // Slot was empty
}
```

## Fluent API: `slot.move.in(_)` / `slot.move.out`

Use when the caller has already proved (via invariant or logic) that the operation cannot fail. The fluent accessors trap on violation, surfacing the logic error at the call site rather than silently propagating it.

```swift
import Ownership_Primitives

let slot = Ownership.Slot<Resource>()

// Known-empty slot: .in(_) traps if someone else raced us
slot.move.in(resource)

// Known-full slot: .out traps if already taken
let taken = slot.move.out
```

`slot.move.in(_)` mirrors `slot.store(__unchecked:)`; `slot.move.out` mirrors `slot.take(__unchecked: ())`. The fluent accessor exists so call sites with known invariants don't have to write `__unchecked:` argument noise.

## Slot vs Transfer

| Property | ``Ownership/Slot`` | `Ownership.Transfer` variants |
|----------|--------------------|--------------------------|
| Reusable | Yes — `empty ↔ full` cycles indefinitely | No — `empty → full → empty` (done) |
| Thread-safety | `@unchecked Sendable` via atomic state machine | Tokens `Copyable`; CAS enforces exactly-once |
| Multiple observers | Yes — multiple threads can race on `store`/`take` | Token can be copied, but only one `take()` succeeds |
| Typical use | Pools, long-lived channels | Exactly-once transfer across a `@Sendable` boundary |

Use `Slot` for reusable patterns. See <doc:Ownership-Transfer-Recipes> for the one-shot transfer alternatives.

## See Also

- ``Ownership/Slot``
- ``Ownership/Slot/Move``
- <doc:Ownership-Transfer-Recipes>
