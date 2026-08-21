extension Ownership.Mutable where Value: ~Copyable {

    public struct Unchecked: @unchecked Sendable {

        public let mutable: Ownership.Mutable<Value>

        @inlinable
        public init(_ value: consuming Value) {
            self.mutable = Ownership.Mutable(value)
        }
    }
}
