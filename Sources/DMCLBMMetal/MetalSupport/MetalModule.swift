import Accelerate
import Foundation
import Metal
import MetalPerformanceShaders

public class MetalModule {
    let dev: MTLDevice
    let lib: MTLLibrary
    let cmdQ: MTLCommandQueue

    public init() throws {
        // How to tell Swift package manager to link to CoreGraphics?
        let device = MTLCreateSystemDefaultDevice()

        guard let dev = device else {
            throw MetalError.noDevice
        }

        guard let queue = dev.makeCommandQueue() else {
            throw MetalError.cannotMakeCommandQueue
        }

        self.dev = dev
        cmdQ = queue
        lib = try Self.loadMetal(device: dev)
    }

    private static func loadMetal(device: MTLDevice) throws -> MTLLibrary {
        if let defaultLib = device.makeDefaultLibrary() {
            return defaultLib
        }

        let bundles = [Bundle.module, Bundle(for: Self.self)]
        for bundle in bundles {
            if let defaultLib = try? device.makeDefaultLibrary(bundle: bundle) {
                return defaultLib
            }
        }
        throw MetalError.defaultLibraryNotFound
    }

    public func pipelineState(name: String) throws -> MTLComputePipelineState {
        guard let fn = lib.makeFunction(name: name) else {
            throw MetalError.cannotFindFunction(name: name)
        }

        return try dev.makeComputePipelineState(function: fn)
    }

    public func cmdBuff() -> MTLCommandBuffer? {
        let desc = MTLCommandBufferDescriptor()
        desc.errorOptions = .encoderExecutionStatus
        return cmdQ.makeCommandBuffer(descriptor: desc)
    }
}
