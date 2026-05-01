import Ownership_Primitives

struct Handle: ~Copyable {
    var descriptor: Int32
}

func acquire() -> Handle { Handle(descriptor: 3) }

var slot: Handle? = acquire()
// `slot` holds a ~Copyable Handle; copying out is not possible.
