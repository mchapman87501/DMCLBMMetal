// Learning from
// https://avinashselvam.medium.com/hands-on-metal-image-processing-using-apples-gpu-framework-8e5306172765
// and
// https://gist.github.com/avinashselvam/9ccdd297ce28a3363518727e50f77d11

import DMC2D
import Metal
import MetalKit

class FrameRenderer {
    let title: String
    let imgWidth: Int
    let imgHeight: Int
    let imgSize: NSSize

    let lattice: Lattice
    let edgeForceCalc: EdgeForceCalc

    private let densityRenderer: DensityRenderer
    private let foilRenderer: FoilRenderer
    private let tracerRenderer: TracerRenderer
    private let edgeForceRenderer: EdgeForceRenderer
    private let netForceRenderer: NetForceRenderer
    private let legendRenderer: LegendRenderer
    private let compositor: TextureCompositor

    private let renderTexture: MTLTexture
    private let aaTexture: MTLTexture

    init(
        title: String, width: Int, height: Int,
        lattice: Lattice, edgeForceCalc: EdgeForceCalc,
        foil: AirFoil
    ) throws {
        self.title = title
        // Image size:
        self.imgWidth = width
        self.imgHeight = height
        self.imgSize = NSSize(width: width, height: height)

        self.lattice = lattice
        self.edgeForceCalc = edgeForceCalc

        self.densityRenderer = DensityRenderer(
            lattice: lattice, imgSize: imgSize)
        self.foilRenderer = FoilRenderer(
            lattice: lattice, foilShape: foil.shape)
        self.tracerRenderer = TracerRenderer(lattice: lattice)
        self.edgeForceRenderer = EdgeForceRenderer(
            lattice: lattice, shape: foil.shape,
            edgeForceBM: edgeForceCalc.edgeForceBM)
        self.netForceRenderer = NetForceRenderer(
            lattice: lattice, shape: foil.shape)
        self.legendRenderer = LegendRenderer(
            module: lattice.module, imageSize: self.imgSize, title: title)
        self.compositor = try TextureCompositor(
            module: lattice.module, imageSize: self.imgSize)

        self.renderTexture = Self.createRenderTexture(
            dev: lattice.module.dev, width: width,
            height: height)
        self.aaTexture = Self.createAntialiasedTexture(
            dev: lattice.module.dev, width: width,
            height: height)
    }

    private static let multisampleCount = 4

    private static func createRenderTexture(
        dev: MTLDevice, width: Int, height: Int
    ) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height,
            mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        desc.textureType = .type2DMultisample
        desc.sampleCount = multisampleCount
        guard let result = dev.makeTexture(descriptor: desc) else {
            fatalError("Failed to create render texture")
        }
        return result
    }

    private static func createAntialiasedTexture(
        dev: MTLDevice, width: Int, height: Int
    )
        -> MTLTexture
    {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height,
            mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let result = dev.makeTexture(descriptor: desc) else {
            fatalError("Failed to create antialiased texture")
        }
        return result
    }

    func render(alpha: Double) -> NSImage {
        densityRenderer.render()

        getTracerContext(clearTexture: true).render {
            tracerRenderer.render(context: $0)
        }
        getFoilRenderContext(clearTexture: false).render {
            foilRenderer.render(context: $0)
        }

        getEdgeForceRenderContext(clearTexture: false).render {
            edgeForceRenderer.render(context: $0)
            netForceRenderer.render(
                context: $0, netForce: edgeForceCalc.netForce)
        }

        compositor.composite(
            textures: [
                densityRenderer.texture, aaTexture, legendRenderer.texture,
            ], alpha: Float(alpha))
        let result = NSImage.fromTexture(texture: compositor.texture)
        return result
    }

    private func cmdBuff() -> MTLCommandBuffer {
        guard let result = lattice.module.cmdBuff() else {
            fatalError("Could not create command buffer for frame render")
        }
        return result
    }

    // MARK: - Building RenderContexts
    private func getTracerContext(clearTexture: Bool) -> RenderContext {
        getContext(
            vertexShader: "tracer_vertex_shader",
            fragShader: "tracer_fragment_shader",
            clearTexture: clearTexture)
    }

    private func getFoilRenderContext(clearTexture: Bool) -> RenderContext {
        getContext(
            vertexShader: "foil_vertex_shader",
            fragShader: "foil_fragment_shader",
            clearTexture: clearTexture)
    }

    private func getEdgeForceRenderContext(clearTexture: Bool) -> RenderContext
    {
        getContext(
            vertexShader: "edge_force_vertex_shader",
            fragShader: "edge_force_fragment_shader", clearTexture: clearTexture
        )
    }

    private func getContext(
        vertexShader: String, fragShader: String, clearTexture: Bool
    )
        -> RenderContext
    {
        let module = lattice.module

        let passDesc = getRenderPassDesc(
            renderTexture: renderTexture, resolveTexture: aaTexture,
            loadAction: clearTexture ? .clear : .load)
        let pipeDesc = getRenderPipeDesc(
            lib: module.lib, vertexShader: vertexShader, fragShader: fragShader)
        return RenderContext(
            module: module, tex: renderTexture, pipeDesc: pipeDesc,
            passDesc: passDesc)
    }

    private func getRenderPassDesc(
        renderTexture: MTLTexture, resolveTexture: MTLTexture,
        loadAction: MTLLoadAction
    ) -> MTLRenderPassDescriptor {
        let result = MTLRenderPassDescriptor()

        result.colorAttachments[0].texture = renderTexture
        result.colorAttachments[0].resolveTexture = resolveTexture

        result.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        result.colorAttachments[0].loadAction = loadAction
        result.colorAttachments[0].storeAction = .storeAndMultisampleResolve
        return result
    }

    private func getRenderPipeDesc(
        lib: MTLLibrary, vertexShader: String, fragShader: String
    ) -> MTLRenderPipelineDescriptor {
        let result = MTLRenderPipelineDescriptor()
        result.vertexFunction = lib.makeFunction(name: vertexShader)
        result.fragmentFunction = lib.makeFunction(name: fragShader)
        result.colorAttachments[0].pixelFormat = .bgra8Unorm
        result.sampleCount = Self.multisampleCount
        result.vertexBuffers[0].mutability = .immutable
        return result
    }
}
