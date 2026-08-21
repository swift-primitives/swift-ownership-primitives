extension Ownership.Transfer.Erased {

    public enum Outgoing {}
}

extension Ownership.Transfer.Erased.Outgoing {

    @unsafe
    public static func make<T>(
        _ value: T
    ) -> UnsafeMutableRawPointer {
        let headerSize = MemoryLayout<Header>.size
        let headerAlignment = MemoryLayout<Header>.alignment
        let payloadSize = MemoryLayout<T>.size
        let payloadAlignment = MemoryLayout<T>.alignment

        let payloadOffset = (headerSize + payloadAlignment - 1) & ~(payloadAlignment - 1)
        let totalSize = payloadOffset + payloadSize
        let alignment = max(headerAlignment, payloadAlignment)

        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: totalSize,
            alignment: alignment
        )

        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        unsafe headerPtr.initialize(
            to: Header(
                payloadOffset: payloadOffset,
                destroyPayload: { base, offset in
                    unsafe (base + offset).assumingMemoryBound(to: T.self)
                        .deinitialize(count: 1)
                }
            )
        )

        let payloadPtr = unsafe (ptr + payloadOffset).assumingMemoryBound(to: T.self)
        unsafe payloadPtr.initialize(to: value)

        return unsafe ptr
    }

    @unsafe
    public static func consume<T>(
        _ ptr: UnsafeMutableRawPointer
    ) -> T {
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        let header = unsafe headerPtr.move()
        let payloadPtr = unsafe (ptr + header.payloadOffset).assumingMemoryBound(to: T.self)
        let result = unsafe payloadPtr.move()
        unsafe ptr.deallocate()
        return result
    }
}

extension Ownership.Transfer.Erased.Outgoing {

    @unsafe
    public static func destroy(_ ptr: UnsafeMutableRawPointer) {
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        let header = unsafe headerPtr.move()
        unsafe header.destroyPayload(ptr, header.payloadOffset)
        unsafe ptr.deallocate()
    }
}
