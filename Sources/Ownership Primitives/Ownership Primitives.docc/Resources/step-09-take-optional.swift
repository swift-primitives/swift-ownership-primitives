import Ownership_Primitives

struct Handle: ~Copyable {
    var descriptor: Int32
}

func acquire() -> Handle { Handle(descriptor: 3) }

var slot: Handle? = acquire()

guard let handle = slot.take() else { return }
// `slot` is now nil; `handle` owns the value.
_ = handle
