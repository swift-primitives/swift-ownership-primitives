extension Ownership.Transfer.Erased.Outgoing {

    @safe
    package struct Header {

        package let destroyPayload: (UnsafeMutableRawPointer, Int) -> Void

        package let payloadOffset: Int

        package init(
            payloadOffset: Int,
            destroyPayload: @escaping (UnsafeMutableRawPointer, Int) -> Void
        ) {
            self.payloadOffset = payloadOffset
            unsafe (self.destroyPayload = destroyPayload)
        }
    }
}
