# Ownership Types — Usage and Justification

<!--
---
version: 1.0.0
last_updated: 2026-04-23
status: RECOMMENDATION
tier: 2
scope: cross-package
---
-->

## Context

Before tagging `swift-ownership-primitives` 0.1.0, the package author asked:
*"for each ownership type, inventory usage across the ecosystem and evaluate
whether we even SHOULD provide such ownership type. The `@unchecked Sendable`
types are suspicious — we should primarily rely on region-based isolation of
`Sendable` / `unchecked Sendable`."*

This is a legitimate pre-tag question: 0.1.0 cements API surface that is
expensive to remove later. Types that duplicate stdlib primitives or that
exist only because `sending` + region-based isolation (SE-0430) wasn't in
the language at the time they were designed are prime candidates for
deprecation before they become entrenched.

Provenance context: several of these types were **moved** from
`swift-reference-primitives` to `swift-ownership-primitives` per the doc
comment at `swift-reference-primitives/Sources/Reference Primitives/Reference.swift:74–80`:

| Old name | New name |
|----------|----------|
| `Reference.Box` | `Ownership.Shared` |
| `Reference.Indirect` | `Ownership.Mutable` |
| `Reference.Slot` | `Ownership.Slot` |
| `Reference.Transfer` | `Ownership.Transfer` |

So the evaluation is partly a second chance to reconsider designs that
were accepted elsewhere and are now centralised here.

## Question

For each type currently shipped in `swift-ownership-primitives`:

1. **Inventory**: which packages (outside this one) actually use it, and how?
2. **Alternative**: could Swift 6's region-based isolation (`sending` +
   `Sendable`) + existing stdlib primitives (`Mutex`, `AsyncStream`,
   `~Copyable` parameter annotations) cover the same use cases?
3. **Verdict**: KEEP / NARROW / DEPRECATE / MOVE — with rationale.

## Analysis

### Inventory methodology

`grep -rE "Ownership\.<Type>"` across:
- `/Users/coen/Developer/swift-primitives/` (superrepo + sibling packages)
- `/Users/coen/Developer/swift-standards/`
- `/Users/coen/Developer/swift-foundations/`
- `/Users/coen/Developer/swift-institute/Experiments/`

Excluded: swift-ownership-primitives itself, `.build/`, `_index.json`,
Research/Reflections docs (doc references don't count as usage).

**Counts are call-site files, not call-site counts.** A single file using
`Ownership.Shared` in 20 places counts as 1.

---

### 1. `Ownership.Borrow` — KEEP

**Usage**: 3 direct conformers + 1 major structural consumer.

| Consumer | Shape |
|----------|-------|
| `swift-tagged-primitives` | `Tagged+Ownership.Borrow.Protocol.swift` — Tagged's transparent forwarding to the underlying type's Borrow |
| `swift-string-primitives` | `String.Borrowed.swift` — conforms to `Ownership.Borrow.`Protocol`` |
| `swift-path-primitives` | `Path.Borrowed.swift` — same |
| `swift-property-primitives` | `Property.View.Read` family stores `Tagged<Tag, Ownership.Borrow<Base>>` as its canonical read-side reference shape |

**Alternative considered**: raw `UnsafePointer<Value>` + hand-written `@_lifetime`
annotations on every call site. That was the predecessor; moving to
`Ownership.Borrow` cut every consumer's `@_lifetime` bookkeeping.

Stdlib SE-0519 `Borrow<T>` is the eventual replacement but (a) ships on
SwiftStdlib 6.4 (not yet stable) and (b) stores `Builtin.Borrow<Value>`,
which we can't use outside stdlib. The `UnsafeRawPointer`-backed
`Ownership.Borrow` is the production-toolchain bridge until SE-0507
(`BorrowAndMutateAccessors`) lands stable — at which point the `_read`
coroutine inside `Ownership.Borrow.value` becomes a `borrow` accessor and
the type survives.

**Verdict**: KEEP. Core SE-0519 bridge. Consumers cannot be written without it
on production 6.3.1. Deprecation path is structural (swap `_read` → `borrow`),
not API-breaking.

---

### 2. `Ownership.Inout` — KEEP

**Usage**: 2 direct consumers, both structural.

| Consumer | Shape |
|----------|-------|
| `swift-tagged-primitives` | `Tagged.swift` — Tagged's mutating forwarding |
| `swift-property-primitives` | `Property.View` family stores `Tagged<Tag, Ownership.Inout<Base>>` — the canonical mutable-side reference shape |

Both consumers consume 10+ call-site instances each. The Property.View family
is the ecosystem-wide fluent-accessor primitive and its shape is frozen by
property's 0.1.0 plan.

**Alternative considered**: `inout Base` parameter. Inout parameters are not
storable (cannot be a field) — the Property.View family explicitly needs a
storable field, which is why `Ownership.Inout<Base>` exists.

`sending Base` won't help here — the View keeps a reference, not a transferred
value.

**Verdict**: KEEP. Same argument as Borrow. V12 accessor split (this package's
`get` + `nonmutating _modify` for `Copyable` `Value`, `_read` + `nonmutating _modify`
for `~Copyable`) is the toolchain workaround until SE-0507 lands.

---

### 3. `Ownership.Unique` — KEEP (NARROWLY)

**Usage**: 1 call-site file outside this package (`swift-reference-primitives/Sources/Reference Primitives/Reference.swift` — the doc table mentioning the rename).

Real consumer count: **effectively zero** outside the rename documentation.

The package has no downstream consumer today that constructs an `Ownership.Unique`
directly. The type exists as the "heap-allocated exclusive owner" slot in the
taxonomy (Swift's analogue of Rust's `Box<T>`) and sits in the doc alongside
`Shared` / `Mutable`.

**Alternative considered**:

| Alternative | Fits when |
|-------------|-----------|
| Plain `~Copyable` struct with allocation inside `init` | When the type has a single use site and you control the layout |
| `ManagedBuffer` subclass | When you need manual class-backed heap allocation |
| `Ownership.Shared` (ARC-shared immutable) | When one owner is not required |
| `Ownership.Mutable` (ARC-shared mutable) | When mutation through multiple refs is required |

Direct stdlib alternative: none. Swift does not provide a `Box<T>` for `~Copyable`
`T` with exclusive ownership + deterministic deinit. `ManagedBuffer` is the nearest
but requires class subclassing.

**Region-based isolation question**: does `sending Value` + region transfer cover
"exclusive heap ownership"? No — `sending` is about crossing an isolation boundary
with a value, not about where the value lives. `Ownership.Unique` is about heap
placement.

**Verdict**: KEEP, but NARROW — the docstring should discourage use in favour
of direct `~Copyable` containers when allocation is the consumer's concern.
Unique is the right answer for "I need a heap-backed exclusive cell I can
`take()` from" — a genuinely narrow niche. Zero-usage today isn't grounds for
removal because the type is load-bearing semantically (it completes the
ownership-mode taxonomy the docstring table advertises); the question is
whether the doc needs to soft-promote alternatives for common cases.

**Recommended action**: soften the docstring to guide readers away from Unique
for the 80% case (direct `~Copyable` container > Unique-wrapping), keep the
type.

---

### 4. `Ownership.Shared` — KEEP, but QUESTION @unchecked

**Usage**: 13 files across the ecosystem (8 primitives sites, 4 foundations, 1
institute).

Real consumers include:

| Consumer | Use |
|----------|-----|
| `swift-pool-primitives` | `Pool.Acquire.swift`, `Pool.Bounded.Destructor.swift`, `Pool.Bounded.Creation.swift`, `Pool.Bounded.Policy.swift` (Pool internals) |
| `swift-async-primitives` | `Async.Mutex+Deque.swift` |
| `swift-loader-primitives` | `Loader.Error.swift` |
| `swift-tests` / `swift-institute` research | Referenced in `sink-concurrent-sharing-pattern.md` |

Real need: a heap-shared immutable cell for a `~Copyable & Sendable` value,
useful when the value is expensive to construct and multiple owners need a
stable reference without copying.

**`@unsafe @unchecked Sendable`** — Category D / SP-4 per [MEM-SAFE-024]. The
class has `let value: Value` (immutable) with `Value: Sendable`; the compiler
*should* be able to infer `Sendable`, but `~Copyable` generics in class storage
block the inference.

**Alternative considered**:

1. **Region-based `sending`**: does not apply — Shared is for multi-owner sharing,
   not one-shot transfer.
2. **Plain `Sendable` final class**: cannot; the `~Copyable` generic blocks
   inference (per existing doc comment).
3. **Drop `~Copyable` from the Value constraint**: narrower than today — consumers
   relying on storing `~Copyable` values would lose. Unclear if any do, but the
   constraint is cheap to keep.
4. **Move to `swift-reference-primitives`**: already came FROM there. Not a win.

**Region-based-isolation verdict**: the `@unchecked Sendable` on `Shared` is
**not** a region-isolation issue — it's a `Sendable`-inference issue specific
to `~Copyable` generics in class storage. When Swift resolves that, the
conformance becomes checked `Sendable` with no API change.

**Verdict**: KEEP. The `@unchecked` is a structural-workaround Category D
(SP-4), not a design smell. Docstring already documents the inference gap.
Add a revisit-when-fixed anchor.

---

### 5. `Ownership.Mutable` — KEEP, SCOPE NARROW

**Usage**: 19 files across the ecosystem (14 foundations, 3 primitives, 2
institute).

14 of those are concentrated in a single package (`swift-foundations/swift-markdown-html-render`)
for the `Markdown.Rendering.Frame` / `Render.Context+Capturing` rendering stack,
where a mutable heap-shared context is needed for frame accumulation.

Other consumers:
- `swift-cache-primitives` — `Cache.Storage.swift`
- `swift-async-primitives` — `Async.Channel.Bounded.Storage.swift`

Real need: a heap-shared **mutable** cell without synchronization, used inside
a single isolation domain.

**`Ownership.Mutable` itself is NOT `Sendable`** — by design. Only
`Ownership.Mutable.Unchecked` (the explicit opt-in wrapper) is
`@unsafe @unchecked Sendable`.

**Region-based-isolation verdict for the non-Unchecked form**: `Mutable` is
not an @unchecked-Sendable smell; it's the principled non-Sendable
counterpart to `Shared`. The design policy ("no general-purpose mutable
reference wrapper is Sendable unless it provides synchronization or
actor isolation by construction") aligns with the user's stated preference.

**Alternative considered**:

1. **`Mutex<Value>` from stdlib `Synchronization`**: provides mutable shared
   state WITH synchronization. Use when cross-isolation access is needed.
   `Mutable` is for within-isolation sharing where synchronization would be
   wasted.
2. **Actor + stored property**: provides cross-isolation mutable shared state
   via actor reentrancy. Use when the sharer naturally lives inside an actor.
3. **Reference type with `@_spi`-gated mutation**: not a real alternative.

**Region-based-isolation doesn't help here** — `sending` transfers regions;
`Mutable` is intentionally about NOT crossing regions.

**Verdict**: KEEP. Docstring could be clearer that `Mutable` is only for
**intra-isolation** shared mutable state — for cross-isolation use, point
at `Mutex` or an actor.

**Follow-up**: consider whether the concentration of 14 of 19 consumers in
a single foundation package (`markdown-html-render`) suggests the type is
being used where a local domain-specific solution would be clearer. This
is a downstream concern, not a 0.1.0 blocker.

---

### 6. `Ownership.Mutable.Unchecked` — DEFER + SHRINK USAGE

**Usage**: no direct consumers outside this package's own tests.

The type exists as an explicit `@unchecked Sendable` opt-in over
`Ownership.Mutable`, per [MEM-SAFE-024] Category C (thread-confined,
caller-asserted).

**Region-based-isolation verdict**: Category C is precisely the class the
audit skill flags for migration to `~Sendable` (SE-0518). The type's
entire purpose — "I promise external synchronization; let me cross a
`@Sendable` boundary" — is the exact thing `~Sendable` + scoped `unsafe`
transfer sites are designed for.

**Alternative when SE-0518 stabilises**:
- Consumers who today wrap their non-Sendable state in
  `Ownership.Mutable.Unchecked` would instead mark the state `~Sendable` at
  its type declaration, and each transfer site would use an explicit
  `unsafe` expression (or a helper that contains the assertion).
- The current wrapper becomes a grep-able escape-hatch that migrates to
  inline unsafe assertions when `~Sendable` ships.

**Verdict**: DEFER (as already flagged in audit finding #5). Once
`~Sendable` stabilises:
- Deprecate `Ownership.Mutable.Unchecked` with a migration note.
- Provide a migration example in DocC.

**For 0.1.0**: keep the type. The DEFERRED status is acknowledged; no
consumer use today, so deprecation later costs nothing.

---

### 7. `Ownership.Slot` — KEEP

**Usage**: 16 files (14 primitives, 2 institute).

Real consumers:
- `swift-pool-primitives` — `Pool.Bounded.Entry.swift`, `Pool.Bounded.swift`
  (core pool-cell implementation)
- `swift-async-primitives` — `Async.Channel.Bounded.Storage.swift`,
  `Async.Channel.Bounded.State.swift`, `Async.Channel.Bounded.Receiver.swift`
  (bounded channel implementation)
- `swift-institute/Experiments/inout-noncopyable-optional-closure-capture`

This is the one @unchecked Sendable type that's genuinely load-bearing: the
bounded-channel implementation uses `Ownership.Slot` directly, and Pool.Bounded.Entry
uses it for pool-entry cycling.

**`@unsafe @unchecked Sendable`** — Category A (atomic-synchronized) per
[MEM-SAFE-024]. The class owns an `Atomic<UInt8>` state machine; access is
serialized by CAS.

**Region-based-isolation verdict**: Category A is the case where `@unchecked
Sendable` is the **correct** answer — the class is its own synchronization
mechanism. Region-based isolation + `sending` cannot replace it because the
slot supports **reusable** cycling (empty ↔ full ↔ empty ↔ full), not a
one-shot transfer. An AsyncChannel is the closest functional alternative but
has heavier state (continuations, back-pressure).

**Alternative considered**:

1. **`Mutex<Optional<Value>>`**: provides a lockable slot. Cost: lock
   contention on uncontended paths (Slot's CAS is contention-free on the
   empty→full and full→empty transitions). Different performance profile.
2. **`AsyncChannel`**: handles bounded single-slot transfer but involves
   async continuations. Heavier for synchronous producer/consumer.
3. **Raw `Atomic<Int>` + `UnsafeMutablePointer<Value>`**: what Slot is, hand-rolled.

**Verdict**: KEEP. Genuinely load-bearing; `@unchecked` is correct; no
alternative offers the same sync-on-CAS profile.

---

### 8. `Ownership.Transfer.Cell` — KEEP (NARROW)

**Usage**: 3 files in `swift-foundations`:

| File | Use |
|------|-----|
| `swift-foundations/Experiments/async-let-noncopyable-transfer/Sources/main.swift` | Experimental use |
| `swift-foundations/swift-kernel/Sources/Kernel Thread/Kernel.Thread.spawn.swift` | Passing a value to a thread spawn |
| `swift-foundations/swift-io/Benchmarks/io-bench/IO Performance Tests/Channel.swift` | Benchmark fixture |

Real production consumer: `Kernel.Thread.spawn` (1 site).

Design: "pass an existing `~Copyable` value through a `@Sendable` escaping
closure, consume it exactly once on the other side via an atomic token."

**Region-based-isolation verdict**: this is exactly what `sending` in
Swift 6 covers — `func spawn<T: Sendable>(...) sending T` or the
`~Copyable sending` variant lets the value be passed across the
`@Sendable` boundary.

However — `Kernel.Thread.spawn` runs the closure on an OS thread, not a
Swift Task. `sending` works at Task / isolation boundaries; OS threads
spawned via `pthread_create` don't participate in Swift 6's region
isolation. The Transfer.Cell token-with-CAS model is the equivalent for
the pthread case.

**Alternative considered**:

1. **`sending T` parameter**: works for Swift Tasks + actor boundaries, not
   pthread spawns.
2. **`Mutex<Optional<T>>` + manual join**: works but needs external
   coordination (thread.join → read).
3. **`Ownership.Slot<T>` + `move.in` before spawn**: functionally equivalent,
   just Slot under a different name. Slot is more general (reusable).

**Verdict**: KEEP, but NARROW in docstring: position Transfer.Cell
specifically as the **pthread / OS-thread transfer** case. For Swift Task
boundaries, recommend `sending` parameters directly.

---

### 9. `Ownership.Transfer.Storage` — DEPRECATE

**Usage**: **zero** direct call sites outside this package.

Design: inverse of Transfer.Cell — the consumer pre-allocates empty storage
and ships the store-capable token to a producer, who deposits the value,
and the consumer retrieves after.

**Region-based-isolation verdict**: the `sending` return-value shape in
Swift 6 (`-> sending T`) covers most of this. A function returning
`sending T` from an actor-isolated context gives the caller a value
transferred into its region.

Actual use cases for Storage would need to involve pthread-style producers
that can't return values directly. Transfer.Cell already covers that case
by flipping the direction. Having both Cell and Storage duplicates the
transfer primitive along a direction axis that ~never matters in practice —
the grep confirms: nobody uses Storage.

**Alternative considered**:

1. **Transfer.Cell in reverse**: use a captured Cell the producer writes to
   via mutation... actually doesn't work because Cell is one-shot constructor.
2. **Transfer.Cell with inverted roles**: let the consumer hold the cell, let
   the producer ship a value into it... functionally similar, but Storage
   already exists for that.
3. **`Ownership.Slot<T>`**: reusable version; covers same pattern with
   extra capacity.
4. **`AsyncChannel` / `AsyncStream`**: structured-concurrency equivalent.

**Verdict**: DEPRECATE in 0.1.0 — document the type as "historical; use
`Transfer.Cell` + inverted roles or `Ownership.Slot` instead." Removal
proper can happen in 0.2.0 after any latent consumers surface.

Actual removal plan could be as simple as removing the type from the
public API and collapsing `_Box`'s Storage path, since Cell and Storage
share `_Box` internally.

---

### 10. `Ownership.Transfer.Retained` — KEEP (LOAD-BEARING)

**Usage**: 6 files across foundations (`swift-executors`, `swift-testing`,
`swift-io`).

All real consumers:

| File | Use |
|------|-----|
| `swift-executors/Sources/Executors/Executor.Scheduled.swift` | Scheduling executor |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.Completion.swift` | Completion-thread handoff |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.swift` | Core thread-executor |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.Stealing.Worker.swift` | Work-stealing worker |
| `swift-executors/Sources/Executors/Kernel.Thread.Executor.Polling.swift` | Polling executor |
| `swift-testing/Sources/Testing/Testing.Discovery.swift` | Test discovery |

Design: zero-allocation transfer of `AnyObject` across pthread boundaries
via `Unmanaged.passRetained(_:).toOpaque()` + balanced retain.

**Region-based-isolation verdict**: same argument as Transfer.Cell — pthread
boundaries don't participate in region isolation. `sending T: AnyObject`
would work for Task boundaries, but the Executor infrastructure runs on
pthreads by construction (those OS threads ARE the executor).

`Transfer.Retained` is the zero-allocation variant when `T: AnyObject`:
skips the Cell's heap box by using `Unmanaged` directly. This is a real
performance argument in the executor hot path.

**Alternative considered**:

1. **Transfer.Cell<T: AnyObject>**: works, but costs the box allocation. For
   executor internals this is non-trivial.
2. **Manual `Unmanaged` at call sites**: what Retained wraps. Unscoped; every
   call site re-derives safety.
3. **`nonisolated(unsafe)` + raw pointer**: same shape, no type safety.

**Verdict**: KEEP. Genuinely load-bearing for executor performance; zero-alloc
justifies the narrow AnyObject-only surface.

---

### 11. `Ownership.Transfer.Box` — DEPRECATE

**Usage**: 1 real file (`swift-io` benchmarks) + 2 in swift-institute
experiments (one is mine from the workaround revalidation).

Real production consumer: **zero**.

Design: type-erased boxing via `UnsafeMutableRawPointer` + closure-based
destroy function (per the [DOC-045] WORKAROUND note — the closure
can't be a thin function pointer due to a Swift 6.3.1 compiler limitation).

**Region-based-isolation verdict**: Box exists for opaque-pointer
boundaries (C APIs taking `void*` context). That's a very narrow use case
that doesn't come up in Swift-only code. For Swift-to-Swift transfer,
Transfer.Cell handles it with a typed token.

**Alternative considered**:

1. **Direct `Unmanaged` + `toOpaque()` / `fromOpaque()`**: what Box wraps
   internally. Unscoped but standard for C-interop.
2. **Transfer.Cell with typed token**: works when both sides are Swift.
3. **`CVaArgRepresentable` / `UnsafeMutableRawPointer.allocate`**: lower-level.

**Verdict**: DEPRECATE in 0.1.0 — no production consumer, significant
surface area (Header + Pointer + make/take/destroy statics). The
type-erased-opaque-pointer use case is narrow enough that per-consumer
`Unmanaged` is probably cleaner than a shared primitive.

If a real consumer surfaces later, Box can return — but at 0.1.0 it's
pure speculation.

---

## Summary

| Type | Usage | @unchecked status | 0.1.0 Verdict |
|------|-------|-------------------|---------------|
| `Ownership.Borrow` | 4 consumers, load-bearing | No (Copyable) | KEEP |
| `Ownership.Inout` | 2 consumers, load-bearing | No (`~Copyable`) | KEEP |
| `Ownership.Unique` | 0 real consumers today | Category B (sound) | KEEP narrowly — soften docstring |
| `Ownership.Shared` | 13 files across ecosystem | Category D / SP-4 (sound) | KEEP — revisit when `~Copyable` generics unblock `Sendable` inference |
| `Ownership.Mutable` | 19 files (14 in one package) | Not Sendable | KEEP — clarify intra-isolation scope in docstring |
| `Ownership.Mutable.Unchecked` | 0 real consumers | Category C (opt-in) | **DEFER** — migrate to `~Sendable` (SE-0518) post-stabilisation |
| `Ownership.Slot` | 16 files, pool + channel core | Category A (atomic) | KEEP — correct @unchecked use |
| `Ownership.Transfer.Cell` | 1 real consumer (Kernel.Thread.spawn) | Uses @unchecked _Box | KEEP — narrow docstring to pthread case |
| `Ownership.Transfer.Storage` | **0 real consumers** | Uses @unchecked _Box | **DEPRECATE** — remove in 0.2.0 |
| `Ownership.Transfer.Retained` | 6 files, executor infra | Category B (sound) | KEEP |
| `Ownership.Transfer.Box` | **0 real consumers** | @unchecked Pointer | **DEPRECATE** — remove in 0.2.0 |

### @unchecked Sendable breakdown

| Category | Instances | Action |
|----------|-----------|--------|
| A (synchronized) | Slot, _Box, Box.Pointer | KEEP — correct per [MEM-SAFE-024] |
| B (ownership transfer) | Unique (conditional), Retained | KEEP — sound; `~Copyable` + exclusive ownership |
| C (thread-confined, caller-asserted) | Mutable.Unchecked | DEFER → `~Sendable` post-SE-0518 |
| D (structural workaround, SP-4 non-Sendable generic) | Shared | KEEP with revisit-when-fixed anchor |

The user's concern — "we should primarily rely on region-based isolation" — is
addressed: none of the KEEP-verdict `@unchecked Sendable` instances are
Category C (the one class `~Sendable` + scoped `unsafe` would replace).
Category A (`Slot`, `_Box`, `Box.Pointer`) and Category B (`Unique`, `Retained`)
have internal synchronization or `~Copyable` exclusive-ownership contracts
that region-based isolation does not replace.

### Proposed actions for 0.1.0 tag

1. **DEPRECATE** `Ownership.Transfer.Storage` — no real consumers, covered by
   `Transfer.Cell` + `Slot`.
2. **DEPRECATE** `Ownership.Transfer.Box` — no real production consumers;
   the use case is narrow enough that per-consumer `Unmanaged` is cleaner.
3. **DOCSTRING NARROWING** on `Ownership.Unique` (soft-promote direct
   `~Copyable` containers), `Ownership.Transfer.Cell` (position as
   pthread-transfer, not Task-transfer), `Ownership.Mutable` (intra-isolation
   scope).
4. **DEFER** `Ownership.Mutable.Unchecked` → `~Sendable` migration path
   documented; no 0.1.0 change.
5. **KEEP EVERYTHING ELSE** at current shape.

### Alternative: keep Storage + Box as a no-cost hedge

The opposite choice — keep Storage and Box even with zero consumers today —
costs:
- Larger public API surface frozen at 0.1.0 (harder to evolve).
- DocC / README have to document types nobody uses.
- Consumers scanning the API inventory see more than they need.

Benefits:
- Zero risk that a pre-tag consumer we haven't found loses their type.
- No deprecation churn later.

The grep-based inventory is confident enough (0 hits across 4 superrepos)
that the risk of a hidden consumer is low. Recommend the DEPRECATE path.

### Alternative: remove without deprecation period

Would also work — no consumer → no break. But deprecation is the polite
default, and 0.1.0 can ship with `@available(*, deprecated, message: "...")`
on Storage and Box, with proper removal in 0.2.0.

## Outcome

**Status**: RECOMMENDATION.

Recommended pre-0.1.0 actions:

1. Add `@available(*, deprecated, message: "Use Ownership.Transfer.Cell with inverted roles, or Ownership.Slot for reusable single-value transfer.")` to `Ownership.Transfer.Storage` public surface.
2. Add `@available(*, deprecated, message: "No production consumers; use Unmanaged directly for C-interop opaque-pointer contexts.")` to `Ownership.Transfer.Box` public surface.
3. Soften docstrings per action #3 above.
4. Record the `~Sendable` migration plan for `Mutable.Unchecked` in the package's DocC philosophy article or README.

The principal retains the decision; this research lays out the evidence.
Deprecation is reversible (remove the `@available` if a consumer surfaces);
inclusion at 0.1.0 is less reversible (removal breaks the API).

## References

- Swift Evolution SE-0519 — Builtin Borrow and Inout (SwiftStdlib 6.4)
- Swift Evolution SE-0507 — BorrowAndMutateAccessors
- Swift Evolution SE-0430 — `sending` regions
- Swift Evolution SE-0518 — `~Sendable`
- `swift-institute/Research/ownership-borrow-protocol-unification.md`
- `swift-institute/Research/self-projection-default-pattern.md`
- `swift-institute/Research/noncopyable-ecosystem-state.md`
- `swift-institute/Research/tilde-sendable-semantic-inventory.md`
- [MEM-SAFE-024] Sendable Category classification (memory-safety skill)
- swift-reference-primitives/Sources/Reference Primitives/Reference.swift — the doc table documenting the Reference → Ownership rename.

## Provenance

Commissioned by the package author 2026-04-23 pre-0.1.0 tag. Inventory
produced by `grep -rE "Ownership\.<Type>"` across
/Users/coen/Developer/swift-primitives/, swift-standards/,
swift-foundations/, swift-institute/Experiments/. Counts are file-level
(not call-site-level); files in .build/, _index.json, Research/, and
Reflections/ excluded.
