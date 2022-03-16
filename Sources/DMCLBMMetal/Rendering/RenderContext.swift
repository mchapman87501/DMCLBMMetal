import Foundation
import Metal

struct RenderContext {
    private let module: MetalModule

    let cmdBuff: MTLCommandBuffer
    let tex: MTLTexture

    let pipeDesc: MTLRenderPipelineDescriptor
    let passDesc: MTLRenderPassDescriptor

    let pipeState: MTLRenderPipelineState

    init(
        module: MetalModule, tex: MTLTexture,
        pipeDesc: MTLRenderPipelineDescriptor, passDesc: MTLRenderPassDescriptor
    ) {
        self.module = module
        self.tex = tex

        self.pipeDesc = pipeDesc
        self.passDesc = passDesc
        guard
            let pipeState = try? module.dev.makeRenderPipelineState(
                descriptor: pipeDesc)
        else {
            fatalError("Could not create render pipeline state")
        }
        self.pipeState = pipeState

        guard let cmdBuff = module.cmdBuff() else {
            fatalError("Could not create command buffer")
        }
        self.cmdBuff = cmdBuff
    }

    func newEncoder() -> MTLRenderCommandEncoder {
        guard
            let encoder = cmdBuff.makeRenderCommandEncoder(descriptor: passDesc)
        else {
            fatalError("Could not create render command encoder")
        }
        encoder.setRenderPipelineState(pipeState)
        return encoder
    }

    func render(_ code: (RenderContext) -> Void) {
        code(self)
        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()
    }
}
