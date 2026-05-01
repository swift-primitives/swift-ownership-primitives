# Choosing among handoff primitives

@Metadata {
    @PageKind(article)
}

When you need to hand a `~Copyable` value across a boundary — a
function call, a closure capture, a thread, an async task — the
package offers four primitives with overlapping but distinct
semantics. This article picks one for you.

## Decision tree

Start at the top; take the first match.

1. **Does the consumer need to receive the value before the producer
   has it ready?** (paired-channel handoff with deferred fulfilment)
   → **Use `Ownership.Transfer`**. The `Outgoing` / `Incoming` /
   `Token` triad threads the producer-side allocation through to the
   consumer-side reader; the producer can fulfil the channel after
   the consumer is already reading.
   - `Transfer.Value` — non-class `~Copyable` payload.
   - `Transfer.Retained` — class instance handed across a `@Sendable`
     boundary with zero box allocation; the channel rides the existing
     class retain.
   - `Transfer.Erased` — type-erased payload for cross-module / dynamic
     dispatch where the concrete type is agreed out of band.

2. **Does the cell need to be reusable** (multiple stores and takes
   over its lifetime)?
   → **Use `Ownership.Slot`**. `store(_:)` returns the previous
   occupant (if any); `take()` empties the cell. The cell can be
   refilled.

3. **Is the cell strictly one-shot** (one store, then one take, both
   atomic, traps on misuse)?
   → **Use `Ownership.Latch`**. `store(_:)` traps if a value is
   already present; `take()` traps after take. Atomic CAS state
   machine; suitable for cross-thread fulfilment.

4. **Are you not yet sure?** Reach for `Ownership.Slot` — it's the
   most flexible cell. Migrate to `Latch` if you confirm one-shot
   semantics are sufficient (and the trap-on-misuse contract is
   acceptable). Migrate to `Transfer.*` if the consumer side needs
   the paired-channel `Outgoing → Incoming` shape.

## Side-by-side

| Primitive | Shape | Reusable | Atomic | Trap on misuse | Heap allocation |
|-----------|-------|---------:|:------:|:--------------:|:---------------:|
| ``Ownership/Slot`` | single cell | Yes — re-store, re-take | No (uses atomic state but operations are not lock-free across all paths) | No (returns nil on empty `take()`; `store(_:)` returns previous) | Yes — one heap cell |
| ``Ownership/Latch`` | single cell | No (one-shot) | Yes — atomic CAS state machine | Yes — traps on `store` after `store`, `take` after `take` | Yes — one heap cell + atomic state |
| ``Ownership/Transfer/Value/Outgoing`` paired with ``Ownership/Transfer/Value/Incoming`` | paired channel via Token | No (one-shot per Outgoing) | Internally backed by `Latch` | Yes (per Latch) | Yes — one Latch |
| ``Ownership/Transfer/Retained/Outgoing`` paired with ``Ownership/Transfer/Retained/Incoming`` | paired channel via Token | No (one-shot) | Yes — uses `Unmanaged` pass-retained | Yes — `consume()` traps after consume | **No box allocation** — rides existing class retain |
| ``Ownership/Transfer/Erased/Outgoing`` (paired with ``Ownership/Transfer/Erased/Incoming``) | paired channel, type erased | No (one-shot) | No | Caller responsibility — `consume(_:)` and `destroy(_:)` are exclusive | Yes — one block: header + padding + payload |

## Why three (or four) different shapes

`Slot`, `Latch`, and the `Transfer` family are not three solutions
to the same problem — they are three different problems that share a
heap-cell-backed shape:

- **`Slot`** answers: *"I need a heap-allocated cell I can reuse for a
  `~Copyable` value over time."* Reuse is the load-bearing property.
  Examples: resource pools, lifetime-management caches, any
  state-machine cell whose contents change but whose identity stays
  stable.
- **`Latch`** answers: *"I need a cross-thread one-shot delivery of a
  `~Copyable` value, atomic enough that misuse traps deterministically
  rather than corrupting state."* The trap contract is the load-bearing
  property. Examples: signal-handler-style handoff, deferred-init
  patterns, any scenario where double-store or store-after-take is a
  programmer error worth surfacing immediately.
- **`Transfer.*`** answers: *"I need to give the consumer a handle
  *before* the producer is ready to fulfil it, and the consumer reads
  through that handle after fulfilment."* The paired-channel shape is
  the load-bearing property. The producer holds an `Outgoing`, the
  consumer holds an `Incoming` connected by a `Token`; the consumer
  can capture the Incoming in an escaping closure and read the value
  whenever the producer fulfils the channel.

Consolidating these into one type with a mode parameter would conflate
the three properties and force every consumer to learn all three
contracts at the cost of using any one. Keeping them separate
preserves precise semantics at each call site.

## When NOT to use any of these

If your handoff is **synchronous and structured** — the value flows
from producer to consumer within a single function or a single
`borrowing` / `consuming` parameter pass — none of these primitives
are needed. Use the language's ownership annotations directly:

```swift
func produce() -> consuming MyValue { … }
func consume(_ value: consuming MyValue) { … }

let value = produce()
consume(value)  // no Slot, no Latch, no Transfer needed
```

The handoff primitives are for cases where the language's stack-based
ownership flow is not enough — typically because the handoff crosses
a closure capture, a thread boundary, or an async-task boundary.

## See Also

- ``Ownership/Slot``
- ``Ownership/Latch``
- ``Ownership/Transfer/Value/Outgoing``
- ``Ownership/Transfer/Retained/Outgoing``
- ``Ownership/Transfer/Erased/Outgoing``
- <doc:Slot-Move-vs-Store>
- <doc:Ownership-Transfer-Recipes>
