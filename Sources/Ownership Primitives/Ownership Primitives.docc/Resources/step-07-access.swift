import Ownership_Primitives

struct Counter {
    var value: Int
}

func increment(_ counter: inout Counter) {
    let ref = Ownership.Inout(mutating: &counter)
    let current = ref.value.value                // `get` (Copyable Value path)
    ref.value = Counter(value: current + 1)      // `nonmutating _modify`
}
