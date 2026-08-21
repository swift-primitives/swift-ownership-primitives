extension Ownership {

    @safe
    public final class Immutable<Value: ~Copyable & Sendable>: Sendable {

        public let value: Value

        @inlinable
        public init(_ value: consuming Value) {
            self.value = value
        }
    }
}
