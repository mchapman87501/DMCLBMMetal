import Foundation
import MetalPerformanceShaders

/// Manages a buffer for a metal buffer containing elements of type T.
class MetalBuffMgr<T> {
    private let device: MTLDevice
    private var buffer: MTLBuffer?
    private var buffLen: Int = 0
    public private(set) var numValues: Int = 0

    init(device devIn: MTLDevice) {
        device = devIn
    }

    func prepare(value: T) {
        prepare(values: [value])
    }

    func prepare(values: [T]) {
        prepare(values: values, count: values.count)
    }

    private func prepare(values: UnsafePointer<T>, count: Int) {
        numValues = count
        if (buffer == nil) || (buffLen < numValues) {
            buffLen = numValues
            let dataSize = buffLen * MemoryLayout<T>.stride
            buffer = device.makeBuffer(
                length: dataSize, options: .storageModeShared)
        }

        guard buffer != nil else {
            fatalError("Failed to create float buffer")
        }

        // Copy the new data into the buffer.
        // XXX FIX THIS do this only once for in/out buffers.
        let unsafeBuff = buffer!.contents()
        // https://stackoverflow.com/a/41574862
        let unsafePtr = unsafeBuff.bindMemory(to: T.self, capacity: numValues)
        unsafePtr.assign(from: values, count: numValues)
    }

    func prepare(numResults: Int) {
        // Result buffer will have one float for each result.
        // Re-use the old result buffer if the results are expected to fit.
        if (buffer == nil) || (buffLen < numResults) {
            buffLen = numResults
            let resultDataSize = buffLen * MemoryLayout<T>.stride
            buffer = device.makeBuffer(
                length: resultDataSize, options: .storageModeShared)
            guard buffer != nil else {
                fatalError("Failed to make result buffer")
            }
        }
        buffLen = numResults
    }

    func buff() -> MTLBuffer {
        buffer!
    }

    func values() -> [T] {
        if let buff = buffer {
            let resultLen = buff.length
            if resultLen < buffLen {
                fatalError(
                    "Result length is too small: \(resultLen) vs. \(buffLen)")
            }
            // https://stackoverflow.com/a/41574862
            // https://stackoverflow.com/a/41574862/2826337
            let unsafePtr: UnsafeMutableRawPointer = buff.contents()
            let resultPtr: UnsafeMutablePointer<T> = unsafePtr.bindMemory(
                to: T.self, capacity: buffLen)
            return Array(UnsafeBufferPointer(start: resultPtr, count: buffLen))
        }
        return [T]()
    }
}
