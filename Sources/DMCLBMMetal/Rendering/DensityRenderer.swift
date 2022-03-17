import Foundation
import Metal

struct DensityRenderParams {
    let latticeSize: LatticeSize
    let imageSize: LatticeSize
    let numColors: UInt32
}

struct DensityRenderer {
    let lattice: Lattice
    let imgSize: NSSize

    private let ps: MTLComputePipelineState
    private let paramsBM: MetalBuffMgr<DensityRenderParams>
    private let paletteBM: MetalBuffMgr<Float>

    let texture: MTLTexture

    init(lattice: Lattice, imgSize: NSSize) {
        self.lattice = lattice
        self.imgSize = imgSize

        let module = lattice.module
        let dev = module.dev

        ps = try! module.pipelineState(name: "render_density")
        paramsBM = MetalBuffMgr<DensityRenderParams>(device: dev)

        let components = Self.getPaletteData()
        let numColors = components.count / 4 // b, g, r, a

        let width = UInt32(imgSize.width)
        let height = UInt32(imgSize.height)
        let renderParams = DensityRenderParams(
            latticeSize: LatticeSize(
                width: UInt32(width), height: UInt32(height)),
            imageSize: LatticeSize(
                width: UInt32(imgSize.width),
                height: UInt32(imgSize.height)),
            numColors: UInt32(numColors))
        paramsBM.prepare(value: renderParams)

        paletteBM = MetalBuffMgr<Float>(device: lattice.module.dev)
        paletteBM.prepare(values: components)

        texture = Self.createTexture(
            dev: lattice.module.dev, width: Int(imgSize.width),
            height: Int(imgSize.height))
    }

    private static func createTexture(dev: MTLDevice, width: Int, height: Int)
        -> MTLTexture
    {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height,
            mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let result = dev.makeTexture(descriptor: desc) else {
            fatalError("Could not create density render texture")
        }
        return result
    }

    // Get an array of b,g,r,a,b,g,r,a,...
    private static func getPaletteData() -> [Float] {
        let numColors = 512

        var compArray = [Float]()
        for fract in stride(from: 0.0, to: 1.0, by: 1.0 / Double(numColors)) {
            let color = BluescalePalette.color(fraction: fract)
            compArray.append(Float(color.blueComponent))
            compArray.append(Float(color.greenComponent))
            compArray.append(Float(color.redComponent))
            compArray.append(1.0)
        }
        return compArray
    }

    func render() {
        let cmdBuff = cmdBuff()
        guard let encoder = cmdBuff.makeComputeCommandEncoder() else {
            fatalError("Could not create renderer encoder")
        }
        encoder.setComputePipelineState(ps)
        encoder.setBuffer(paramsBM.buff(), offset: 0, index: 0)
        encoder.setBuffer(paletteBM.buff(), offset: 0, index: 1)
        encoder.setBuffer(lattice.sitePropsBM.buff(), offset: 0, index: 2)
        encoder.setTexture(texture, index: 0)

        let gridSize = MTLSize(
            width: Int(imgSize.width), height: Int(imgSize.height), depth: 1)

        let tgWidth = ps.threadExecutionWidth
        let maxTotalThreads = ps.maxTotalThreadsPerThreadgroup
        let tgHeight = maxTotalThreads / tgWidth
        let tgDepth = 1
        let threadGroupSize = MTLSize(
            width: tgWidth, height: tgHeight, depth: tgDepth)

        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()
    }

    private func cmdBuff() -> MTLCommandBuffer {
        guard let result = lattice.module.cmdBuff() else {
            fatalError("Could not create command buffer for density render")
        }
        return result
    }
}
