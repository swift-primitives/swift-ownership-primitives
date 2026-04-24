---
package: swift-ownership-primitives
path: /Users/coen/Developer/swift-primitives/swift-ownership-primitives
simulated_date: 2026-04-24
predicted_category: related-projects
era_applied: swift6-era
base_rates_source: "stratified:related-projects (n=224) + era multipliers"
terminal_posture_detected: false
archetypes_used:
  - "c1 — The general-purpose technical reviewer"
  - "c2 — The ~Copyable / Sendable / protocol-shape reviewer"
  - "c3 — The closure/expression/syntax technical reviewer"
  - "c4 — The constructive Evolution-process reviewer"
  - "c5 — The pointed -1 reviewer"
  - "c6 — The Core-Team-aware process voice"
  - "c7 — The init/deinit/lifecycle reviewer"
  - "c8 — The SwiftPM / build-tooling / modularity reviewer"
  - "c9 — The long-form deep-analysis essay reviewer"
  - "c10 — The heavy-quoting long-form authoritative reviewer"
note: |
  Simulated forums.swift.org thread under the "related-projects" category.
  Handles use non-identifying @reviewer-<cluster-id> tags per [FREVIEW-010].
  Corpus grounding: analysis/archetypes_labeled.json, analysis/critique_angles_by_venue.json,
  analysis/critique_angles_by_era.json, analysis/openers_closers.json.
  This is a DRAFT-ONLY artifact. Do not post any portion of this thread externally.
---

# Simulated forums.swift.org thread — swift-ownership-primitives 0.1.0

### Post 1 — @op-author (OP)

I'm opening this thread to get community eyes on **swift-ownership-primitives** 0.1.0 before the release. It's a Layer 1 (primitives) Apache-2.0 package shipping fifteen types that cover what I've been calling the "ownership lattice" — scoped references, heap-owned cells, copy-on-write cells, atomic hand-off slots, and cross-boundary transfer tokens.

Two of the fifteen types (`Ownership.Borrow` and `Ownership.Inout`) mirror SE-0519's `Borrow<T>` / `Inout<T>` shape on Swift 6.3.1 via `_read` / `nonmutating _modify` coroutines. The other thirteen cover positions in the lattice that SE-0519 doesn't absorb: `Ownership.Unique` (SE-0517 UniqueBox parity), `Ownership.Indirect` (CoW), `Ownership.Shared` / `Ownership.Mutable` / `Ownership.Mutable.Unchecked` (ARC-shared variants), `Ownership.Slot` / `Ownership.Latch` (atomic), plus the six-cell direction × kind `Ownership.Transfer.*` matrix.

A minimal example:

```swift
import Ownership_Primitives

struct Editor<Base: ~Copyable>: ~Copyable, ~Escapable {
    private let ref: Ownership.Inout<Base>

    @_lifetime(&base)
    init(_ base: inout Base) {
        self.ref = Ownership.Inout(mutating: &base)
    }

    func apply(_ mutation: (inout Base) -> Void) {
        mutation(&ref.value)
    }
}
```

The package lives in the [swift-primitives](https://github.com/swift-primitives) org alongside [swift-property-primitives](https://github.com/swift-primitives/swift-property-primitives), which stores `Tagged<Tag, Ownership.Inout<Base>>` as the canonical `Property.View` storage shape.

What kind of feedback I'm looking for:

- **Naming across the 15-type surface.** Does `Ownership.{Unique, Latch, Slot, Indirect, Shared, Mutable, Transfer.{Value<V>, Retained<T>, Erased} × {Outgoing, Incoming}}` read as a coherent lattice or as ad-hoc accumulation?
- **Modularization.** 14 products backed by 15 targets — is "one product per variant" the right split, or does it atomize too much for consumers?
- **`@_lifetime(&base)` exposure** in the `Ownership.Inout` init. Acceptable because this is the primitive that exists to carry the lifetime relation, or should the public sample avoid underscored annotations?
- **Two pre-standardization shims shipped in a package that positions itself as "timeless" for the other 13 types.** Does the "compatibility spellings" framing justify it, or should `Borrow` / `Inout` live in a separate companion package that explicitly self-retires?
- **`Ownership.Mutable.Unchecked` as a named `@unchecked Sendable` wrapper.** Concentrated unchecked assertion or encouraged misuse?

Companion blog post on the SE-0519 language motivation: *[Passing references without erasing them: the gap SE-0519 closes](./../../Blog/Published/2026-04-24-se-0519-first-class-references.md)*.

<!-- archetype: OP — angles: scope-motivation, naming, layering-modularity, ownership-memory, concurrency -->

---

### Post 2 — @reviewer-1

Thanks for opening this. I'm reading through the surface now — it's coherent enough that I can form an initial read. One thing I want to push on: `Ownership.Mutable<Value>` is documented as "explicitly non-`Sendable`" and the design stance in the README argues shared-mutable-without-sync is intra-isolation only. That's defensible, but `Ownership.Mutable.Unchecked` as the named escape hatch concentrates exactly the assertion the parent type says shouldn't be common — and the 27 `Sendable` conformances I'm counting across `Sources/` suggests a lot of synchronization reasoning is being done at the type level rather than via `Mutex<T>` or actors.

The `Ownership` namespace declaration at `Sources/Ownership Namespace/Ownership.swift:60` sets up an enum-as-namespace, which is conventional. Where the shape surprises me is at `Sources/Ownership Mutable Primitives/Ownership.Mutable.swift:87` — the `var value { _read _modify }` accessor pair on a `final class`-backed wrapper whose design rationale is that it must NOT be `Sendable`. In the SE-0518 world where `~Sendable` is the language's actual stance for that class of opt-out, does `Ownership.Mutable` just become the only cell and `.Unchecked` disappears? Or do both survive, and if so, what's the discriminator between them post-SE-0518?

<!-- archetype: c1 — The general-purpose technical reviewer — angles: concurrency, type-system, evolution-process -->

---

### Post 3 — @reviewer-9

Why did you decide to keep `Ownership.Borrow` and `Ownership.Inout` in the 0.1.0 surface given where SE-0519 is in the review cycle? I ask because the post is explicit — "compatibility spellings for a shape that belongs in the stdlib" — and that framing raises an interesting question about whether a pre-standardization shim belongs in a package whose other 13 types are positioned as timeless.

Reading `Sources/Ownership Inout Primitives/Ownership.Inout.swift:36`, I see the actual init: `@_lifetime(&base) public init(mutating base: inout Base) { ... }`. The type does what SE-0519 will do — `~Copyable & ~Escapable`, single-reference bound to `&base`, coroutine-backed accessors. The delta from the stdlib's eventual shape is essentially which internals the compiler gets to bless as builtin. That's a legitimate library-level achievement; it's also the same shape I've seen in three separate ecosystem packages this year under various names (`Mutable<T>`, `MutRef<T>`, `BorrowBox`). The question isn't "is this a reasonable shape" — it is — it's "is there net value in another library spelling of this during the pre-standardization window versus letting users reach directly for what Apple ships."

The argument in favor, which the OP makes, is that `Ownership.Inout` lets `Property.View` in `swift-property-primitives` work today on Swift 6.3.1 without waiting for SE-0519 to land stable. That's real — it lets downstream ecosystem packages use the shape now. But two things nag:

First: when SE-0519 lands and downstream code migrates, do the thirteen other types still make sense as a unit? The package's narrative is "the ownership lattice, rendered." Subtract `Borrow` + `Inout` and you're left with heap-owned cells, atomic slots, CoW, and transfer — all valuable, none of which need the SE-0519 bridge. Has an alternative shape been considered where `swift-ownership-primitives` ships the thirteen, and a separate adapter package (say, `swift-ownership-compat-primitives`) holds `Borrow` / `Inout` with an explicit self-retiring mission?

Second: I see `Transfer.Erased.Outgoing` at `Sources/Ownership Transfer Erased Primitives/Ownership.Transfer.Erased.Outgoing.swift:38` — the type-erased transfer cell. The direction × payload-kind matrix argument applies to the other thirteen types: each is a distinct position in a lattice, and the lattice is the value claim. But the lattice argument is purely structural. None of the related work I've seen — Rust's `std::sync` primitives, Swift-NIO's channel machinery, Boost.Intrusive's ownership types — asserts totality over a set of axes as a library's value prop. Totality as an organizing principle is strong if it actually drives implementation decisions; it's weak if it's a post-hoc description of what the package ships. Which is it in your case — did the lattice derivation produce the type list, or did it catalogue an existing list?

<!-- archetype: c9 — The long-form deep-analysis essay reviewer — angles: evolution-process, concurrency, type-system -->

---

### Post 4 — @reviewer-8

I'm going to push back on the modularization, specifically. Fourteen products backed by sixteen targets (per `Package.swift`) plus an umbrella — that's a decomposition ratio I haven't seen outside of stdlib-scale projects, and for a 2764-LOC package it feels aggressive. The argument that narrow variants minimize compile-time surface for consumers is true in principle; in practice, adopting `swift-ownership-primitives` means a consumer's `Package.swift` grows by eight to fifteen product entries depending on which cells they actually use.

Concretely: `Ownership.Mutable<Value>` at `Sources/Ownership Mutable Primitives/Ownership.Mutable.swift:87` is one file's worth of code. Splitting it into its own product means consumers write `.product(name: "Ownership Mutable Primitives", package: "swift-ownership-primitives")` for what is effectively a thirty-line wrapper.

Recommendation: merge the heap-cell cluster (`Unique`, `Indirect`, `Shared`, `Mutable`, `Mutable.Unchecked`) into one product; keep the transfer matrix as one product; atomic slots (`Slot`, `Latch`) as one; scoped references (`Borrow`, `Inout`) as one. That's four cluster products instead of fourteen per-variant products, and it matches how I'd actually reach for these types — by cluster, not by individual cell. Consumers who genuinely want per-variant surface minimization can still get it by importing a specific module inside a product, but the default dependency line should be a small number of clusters.

<!-- archetype: c8 — The SwiftPM / build-tooling / modularity reviewer — angles: layering-modularity, build-tooling -->

---

### Post 5 — @reviewer-10

> The package is the Institute's rendering of a design space that spans SE-0517 (`UniqueBox`), SE-0519 (`Borrow<T>` and `Inout<T>`), and the manual cells that appear in libraries where stdlib primitives do not quite fit.

This framing is the post's load-bearing claim and I want to examine it directly. "Spans a design space" is a strong assertion. The Swift ownership conversation has been happening in the open since at least [SE-0390](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) accepted in 2023, and the types you're identifying as "pre-standardization shims" are either (a) library renderings of shapes the stdlib is formally standardizing or (b) ARC-wrapped cells that libraries have been writing in various spellings since Swift 3.

> Six types cover the direction × kind matrix of one-shot transfer across `@Sendable` boundaries

Looking at `Sources/Ownership Transfer Erased Primitives/Ownership.Transfer.Erased.Outgoing.swift:38`, I see the Outgoing cell wraps `AnyObject` via `Unmanaged.passRetained`. That's a concrete mechanism — zero-allocation transfer via retained pointer. The question is whether the matrix's symmetry argument actually pays off at the less-common cells. The blog post's answer to that question is:

> The less common cells are present because the matrix is part of the contract: if a boundary can send a generic value, a retained object, or an erased pointer out, the corresponding inbound shape should not require a hand-rolled result cell.

"Part of the contract" is doing a lot of load-bearing work in that sentence. In `Transfer.Retained<T>.Incoming`, the "inbound class transfer" shape matters when you're running detached threads outside Swift concurrency. Is there a downstream consumer doing that today, or is the cell reserved for a future need that the matrix's symmetry predicts but no user has asked for?

The post's specific consumer-case argument — "if you have written an ad-hoc result cell to get a return value out of a detached thread, you have written a hand-rolled `Transfer.Value<V>.Incoming`" — is a compelling motivation for `Transfer.Value.Incoming` specifically. It does not extend to the erased and retained variants in both directions with the same strength. Are the six cells load-bearing in the same way, or is the matrix completeness doing the argument on its own?

<!-- archetype: c10 — The heavy-quoting long-form authoritative reviewer — angles: evolution-process, type-system, concurrency -->

---

### Post 6 — @reviewer-3

One small thing on the accessor shape. `Ownership.Borrow<Value>` at `Sources/Ownership Borrow Primitives/Ownership.Borrow.swift:45` uses `_read` + `nonmutating _modify` coroutines for the `.value` accessor. That's pre-SE-0507 mechanics — functional on 6.3.1 but explicitly a bridge. Once SE-0507's `borrow` / `mutate` accessors ship in a stable toolchain, migrating the internals is straightforward. What I'm less clear on: does the public API surface stay exactly the same, or does `ref.value` become something different under the non-coroutine accessors? The OP says "the call sites do not change" but the coroutine story has edges the non-coroutine one doesn't — particularly around how concurrency-aware the compiler is about the yield site.

Separately: `Ownership.Latch.takeIfPresent(_:)` at `Sources/Ownership Latch Primitives/Ownership.Latch.swift:192` — the name reads as a `get if present` idiom rather than a consuming read. `Unique.consume()` uses the verb `consume`. `Slot.take()` uses `take`. `Latch.takeIfPresent` uses `take`. Is there a reason the latch isn't `consumeIfPresent` to align with the stronger destructive-read vocabulary? I'd recommend renaming for consistency — if `consume` is reserved for once-for-all destruction of `~Copyable` values and `take` is the reusable extract, then both `Latch` and `Slot` are `take`-shaped, but `Unique` is `consume`-shaped. That's two verbs for what look like overlapping operations; one of them should give.

<!-- archetype: c3 — The closure/expression/syntax technical reviewer — angles: type-system, naming -->

---

### Post 7 — @reviewer-4

Thanks for putting this together — the lattice framing is unusual for an infrastructure package and I want to engage with it constructively rather than nitpick individual types. My take as someone who has watched the Evolution process handle a lot of ownership-adjacent proposals: the "compatibility spellings" argument for `Borrow` and `Inout` is clean, but it sets up a situation where downstream consumers take a dependency on ecosystem types whose migration path depends on SE-0519's acceptance timeline, which is currently the LSG's call on the rename debate.

If SE-0519's `Ref` / `MutableRef` rename lands (the review-thread signal on 2026-04-22 leaned that way), the package's two named shims immediately have divergent names from the stdlib. That's a small migration but it's one the downstream pays on the order of weeks after SE-0519 ships stable. Is there value in anticipating the rename — shipping `Ownership.Borrow` as an internal alias and exposing `Ownership.Ref` / `Ownership.MutableRef` today — or is the argument "stay in lockstep with the proposal's current names" the stronger one?

On `Ownership.Mutable.Unchecked` at `Sources/Ownership Mutable Primitives/Ownership.Mutable.Unchecked.swift:52`: I see the design argument. The name is very current Swift-6-era convention (`Unchecked` as a suffix that telegraphs `@unchecked Sendable` opt-in). Do you anticipate the eventual SE-0518 shape forcing a rename — e.g., to `Ownership.Mutable.Sending` or a `~Sendable` variant — or is `Unchecked` the final spelling the package commits to?

<!-- archetype: c4 — The constructive Evolution-process reviewer — angles: evolution-process, naming -->

---

### Post 8 — @reviewer-2

Sorry if I'm missing something obvious, but I want to double-check the `~Copyable` story on the atomic slot. `Ownership.Slot<Value>.take() -> Value?` at `Sources/Ownership Slot Primitives/Ownership.Slot+Take.swift:42` returns an Optional of a `~Copyable` type — which composes with `Optional<Wrapped>.take()` for `~Copyable` `Wrapped`, also shipped by the package. That's elegant, assuming the Optional-of-noncopyable wrapping actually holds at the SILGen level for the slot's backing storage.

The question: in the `Slot` case, is the atomic state machine holding the `~Copyable` in a raw storage buffer (via `UnsafeMutablePointer` or similar) and reconstructing the `Optional<~Copyable>` at the return site, or does the type rely on Swift 6.3.1 actually expressing `~Copyable & Sendable` in a way the compiler's region-based isolation can verify on the class's stored property? I ask because I've hit cases on 6.3.1 where the compiler rejects `~Copyable` `Value` in a `Sendable`-conforming class stored property even when the class is structurally fine — `swift-institute/Experiments/noncopyable-generic-sendable-inference/` has writeups on some of this. Worth clarifying which path the `Slot` takes, because that determines how much of the `@unchecked` footprint is actually forced versus chosen.

<!-- archetype: c2 — The ~Copyable / Sendable / protocol-shape reviewer — angles: concurrency, type-system, ownership-memory -->

---

### Post 9 — @reviewer-7

How are `init` / `deinit` sequenced for the `Transfer.Value<V>.Incoming` case when the boundary crossing fails and the inbound slot is destroyed empty? Looking at `Sources/Ownership Primitives Core/Ownership.Transfer.swift:45`, I see the namespace declaration — `public enum Transfer {}` under `Ownership` — but the actual `Incoming` cell's teardown path lives in the variant targets. The concern is that an `Incoming` slot that is empty-on-destruction is a different lifecycle state from an `Outgoing` cell whose value was never consumed — both states involve atomic state-machine reasoning at `deinit` time, and both need to agree on what "abandon" means at the token level.

Separately: I spotted `__Ownership_Borrow_Protocol` at `Sources/Ownership Borrow Primitives/__Ownership_Borrow_Protocol.swift:30`. Double-underscored identifiers on public surface are unusual. The README references `` Ownership.Borrow.`Protocol` `` (backticked) as the canonical capability protocol — I assume the underscored form is the internal name the backtick alias hoists onto, but worth confirming. If it's genuinely SPI, wrap it behind `@_spi(Internal)` or move it into a `package`-scope target. If it's public, losing the underscores would help. Recommending the SPI wrap — the `__` prefix reads to me as "do not touch," but Swift has no enforcement on the protocol form without `@_spi`.

<!-- archetype: c7 — The init/deinit/lifecycle reviewer — angles: ownership-memory, naming -->

---

### Post 10 — @reviewer-6

Thanks for sharing the draft. I'll add a few process-level observations since the announcement's timing intersects with SE-0519's review cycle.

The SE-0519 acceptance-in-principle on 2026-04-22 flagged a rename debate (`Borrow` / `Inout` → `Ref` / `MutableRef`). If the package ships `Ownership.Borrow` and `Ownership.Inout` next Monday and the LSG lands on `Ref` / `MutableRef` two or three weeks later, the library names diverge from the stdlib the moment the stdlib stabilises. That's survivable — migration tools can alias, the package can rename in 0.2.0 — but it's also a position where the "compatibility spelling" framing starts to carry more burden than its fifteen-types-in-a-lattice mission is designed for.

I see `Ownership.Inout<Base>` at `Sources/Ownership Inout Primitives/Ownership.Inout.swift:36` uses `@_lifetime(&base)`. `@_lifetime` is still underscored. Downstream consumers inheriting that marker in their own init sites is a real ecosystem-spread concern — once the non-underscored lifetime annotation lands, every `Ownership.Inout` init site in downstream code needs an update. The blog draft's caveat sentence acknowledges this directly, which I appreciate; I would push the caveat into the README and DocC `Ownership.Inout` article too, not just the announcement blog.

At `Sources/Ownership Transfer Erased Primitives/Ownership.Transfer.Erased.Outgoing.swift:83` I see the raw `Pointer`-shaped internal storage for the erased cell. That's the correct mechanism for `void*` interop; I flag it only to confirm that the rest of the lattice does not leak raw-pointer surface in the same way — if it does elsewhere, consistency would push for a shared internal helper.

I may be reading the SE-0519 timing window wrong; the review thread has been moving quickly and my read on the rename could already be stale.

<!-- archetype: c6 — The Core-Team-aware process voice — angles: evolution-process, naming -->

---

### Post 11 — @reviewer-5

I'll be direct because I think the thread is being cooperative-to-a-fault.

The package has fifteen types, two of which are explicitly pre-standardization shims, and four of the remaining thirteen (`Shared`, `Mutable`, `Mutable.Unchecked`, `Indirect`) are `final class`-backed wrappers whose mechanics do not meaningfully differ from writing the class yourself. That's six types out of fifteen whose value-add, as library primitives, is narrow.

`Ownership.Transfer.Erased.Outgoing` at `Sources/Ownership Transfer Erased Primitives/Ownership.Transfer.Erased.Outgoing.swift:85` — I see the raw `Pointer`-shaped surface. The type-erased transfer pattern exists because C-interop requires `void*`-shaped slots, fine. But the package positions it alongside fourteen typed shapes and calls the set "total for the ownership-transfer-and-cell domain." Type-erased `void*` interop is the opposite of type-system-enforced ownership. Shipping it in the same "lattice" as `Ownership.Unique<Value>` elides a real tension that the lattice framing doesn't resolve.

`Ownership.Mutable.Unchecked` at `Sources/Ownership Mutable Primitives/Ownership.Mutable.Unchecked.swift:50` — I understand the Category-C concentration argument. I do not think a type whose whole job is "assert `Sendable` without the compiler checking" earns a place in a lattice that's claiming to be principled. You are shipping the opposite-of-safe case as a named public API with equal billing to the safe cases.

My concrete recommendation: either narrow the package to the thirteen types that make a principled claim, or stop calling the set "total for the ownership-transfer-and-cell domain." You cannot have both a totality claim and a named unchecked-opt-in in the same lattice without undermining one of them. I'd ship the thirteen.

<!-- archetype: c5 — The pointed -1 reviewer — angles: evolution-process, naming, scope-motivation -->

---

## Notes

**Opener distribution (per [FREVIEW-005])**: thanks (3) / direct-stance (3) / question (2) / apology-hedge (1) / — 4 distinct patterns, none >30%.

**Closer distribution**: question-to-author (5 = 50%) / recommendation (3) / withdraw-hedge (1) / explicit-vote-shaped prescription (1). Question-to-author exceeds the `~30%` soft ceiling; corpus reality (84%) and the archetype assignments from `prepare_simulation.py` support the imbalance, but the skill flags it here in case the synthetic-detection concern outweighs realism preservation.

**Archetype coverage**: 10 distinct clusters (c1, c2, c3, c4, c5, c6, c7, c8, c9, c10). Within [FREVIEW-003]'s 6–12 range. Includes at least one process/procedure voice (c6) and one short-form/nit voice (c3).

**Concrete-anchor audit**: every post cites at least one `Sources/…\.swift:<line>` reference per [FREVIEW-006]. Anchor counts vary; post-authoring triage (`scripts/triage_simulation.py`) will classify each reply into load-bearing / partially / archetype-shaped.
