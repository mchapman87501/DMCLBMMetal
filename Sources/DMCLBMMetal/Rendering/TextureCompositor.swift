import Foundation
import Metal

struct TextureCompositor {
    typealias GPUImageSize = LatticeSize

    private struct CompositeParams {
        let overlayAlpha: Float
    }

    private struct ClearParams {
        let color: SIMD4<Float>
    }

    let module: MetalModule
    let size: GPUImageSize
    let backgroundColor: SIMD4<Float>
    let texture: MTLTexture
    let overlayTexture: MTLTexture

    private let ps: MTLComputePipelineState
    private let clearPS: MTLComputePipelineState

    private let clearParamsBM: MetalBuffMgr<ClearParams>
    private let paramsBM: MetalBuffMgr<CompositeParams>

    init(
        module: MetalModule, imageSize: NSSize,
        backgroundColor: SIMD4<Float>? = nil) throws
    {
        self.module = module
        size = GPUImageSize(
            width: UInt32(imageSize.width), height: UInt32(imageSize.height))
        self.backgroundColor = backgroundColor ?? [0.0, 0.0, 0.0, 1.0]

        clearPS = try module.pipelineState(name: "clear")
        ps = try module.pipelineState(name: "composite_textures")

        clearParamsBM = MetalBuffMgr<ClearParams>(device: module.dev)
        paramsBM = MetalBuffMgr<CompositeParams>(device: module.dev)

        texture = Self.createTexture(dev: module.dev, size: size)
        overlayTexture = Self.createTexture(dev: module.dev, size: size)
    }

    func composite(textures: [MTLTexture], alpha: Float) {
        guard textures.count > 0 else {
            fatalError("Need at least one texture to composite.")
        }

        let cmdBuff = cmdBuff()

        // Composite all of the layers into overlayTexture, with alpha 1.0
        clear(cmdBuff: cmdBuff, texture: overlayTexture, color: backgroundColor)
        paramsBM.prepare(value: CompositeParams(overlayAlpha: 1.0))
        for srcTexture in textures {
            compositeTextures(
                cmdBuff: cmdBuff, background: overlayTexture,
                overlay: srcTexture)
        }

        // Overlay the overlayTexture on the result texture, with specified alpha.
        clear(cmdBuff: cmdBuff, texture: texture, color: backgroundColor)
        paramsBM.prepare(value: CompositeParams(overlayAlpha: alpha))
        compositeTextures(
            cmdBuff: cmdBuff, background: texture, overlay: overlayTexture)

        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()
    }

    private func clear(
        cmdBuff: MTLCommandBuffer, texture destTexture: MTLTexture,
        color: SIMD4<Float>)
    {
        guard let encoder = cmdBuff.makeComputeCommandEncoder() else {
            fatalError("Could not create clear encoder")
        }

        let params = ClearParams(color: color)
        clearParamsBM.prepare(value: params)

        encoder.setComputePipelineState(clearPS)
        encoder.setBuffer(clearParamsBM.buff(), offset: 0, index: 0)
        encoder.setTexture(destTexture, index: 0)

        let gridSize = MTLSize(
            width: destTexture.width, height: destTexture.height, depth: 1)

        let tgWidth = ps.threadExecutionWidth
        let maxTotalThreads = ps.maxTotalThreadsPerThreadgroup
        let tgHeight = maxTotalThreads / tgWidth
        let tgDepth = 1
        let threadGroupSize = MTLSize(
            width: tgWidth, height: tgHeight, depth: tgDepth)

        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }

    private func compositeTextures(
        cmdBuff: MTLCommandBuffer, background: MTLTexture, overlay: MTLTexture)
    {
        guard background.width == overlay.width else {
            fatalError("Composite texture widths do not match: \(background.width) != \(overlay.width)")
        }
        guard background.height == overlay.height else {
            fatalError("Composite texture heights do not match: \(background.height) != \(overlay.height)")
        }

        guard let encoder = cmdBuff.makeComputeCommandEncoder() else {
            fatalError("Could not create compositor encoder")
        }

        encoder.setComputePipelineState(ps)
        encoder.setBuffer(paramsBM.buff(), offset: 0, index: 0)
        encoder.setTexture(background, index: 0)
        encoder.setTexture(overlay, index: 1)

        let gridSize = MTLSize(
            width: background.width, height: background.height, depth: 1)

        let tgWidth = ps.threadExecutionWidth
        let maxTotalThreads = ps.maxTotalThreadsPerThreadgroup
        let tgHeight = maxTotalThreads / tgWidth
        let tgDepth = 1
        let threadGroupSize = MTLSize(
            width: tgWidth, height: tgHeight, depth: tgDepth)

        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
    }

    private func cmdBuff() -> MTLCommandBuffer {
        guard let result = module.cmdBuff() else {
            fatalError("Could not create command buffer for composite render")
        }
        return result
    }

    private static func createTexture(dev: MTLDevice, size: GPUImageSize)
        -> MTLTexture
    {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: Int(size.width),
            height: Int(size.height),
            mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let result = dev.makeTexture(descriptor: desc) else {
            fatalError("Could not create texture for compositing")
        }
        return result
    }
}
