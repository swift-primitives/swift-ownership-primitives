extension Ownership {

    @safe
    public final class Mutable<Value: ~Copyable> {

        @usableFromInline
        var _value: Value

        @inlinable
        public init(_ value: consuming Value) {
            self._value = value
        }
    }
}

extension Ownership.Mutable where Value: ~Copyable {

    @inlinable
    public var value: Value {
        _read { yield _value }
        _modify { yield &_value }
    }
}
