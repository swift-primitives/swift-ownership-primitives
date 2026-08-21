extension Ownership.Transfer.Erased.Outgoing {

    @safe
    public struct Pointer: @unchecked Sendable {

        @unsafe
        public let raw: UnsafeMutableRawPointer

        @unsafe
        public init(_ raw: UnsafeMutableRawPointer) { unsafe (self.raw = raw) }
    }
}
