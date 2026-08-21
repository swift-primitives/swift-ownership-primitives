extension Ownership.Transfer.Retained {

    @safe
    @frozen

    public struct Outgoing: ~Copyable, @unchecked Sendable {

        internal let raw: UnsafeMutableRawPointer

        @unsafe
        public init(_ instance: T) {
            unsafe (self.raw = UnsafeMutableRawPointer(Unmanaged.passRetained(instance).toOpaque()))
        }

        @unsafe
        public init(_ ptr: UnsafeRawPointer) {
            unsafe (self.raw = UnsafeMutableRawPointer(mutating: ptr))
        }

        deinit {
            unsafe Unmanaged<T>.fromOpaque(UnsafeRawPointer(raw)).release()
        }
    }
}

extension Ownership.Transfer.Retained.Outgoing where T: Copyable {

    public consuming func consume() -> T {
        let retained = unsafe Unmanaged<T>.fromOpaque(UnsafeRawPointer(raw)).takeRetainedValue()
        discard self
        return retained
    }
}
