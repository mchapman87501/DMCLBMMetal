import Accelerate
import Foundation
import Metal
import MetalPerformanceShaders

public class Lattice {
    private struct CollideParams {
        let omega: Float
    }

    private struct StreamParams {
        let latticeSize: LatticeSize
    }

    private typealias TracerParams = StreamParams

    let module: MetalModule

    // To help with unit testing.
    public let width: Int
    public let height: Int
    public let numSites: Int
    public let numFields: Int

    private let collidePS: MTLComputePipelineState
    private let streamPS: MTLComputePipelineState
    private let moveTracerPS: MTLComputePipelineState

    private var collideParamsBM: MetalBuffMgr<CollideParams>
    private var streamParamsBM: MetalBuffMgr<StreamParams>

    let fields1BM: MetalBuffMgr<Float>
    let fields2BM: MetalBuffMgr<Float>
    // Which fields buffer to use for collisions?  Which one to
    // stream into?
    private var useFields1 = true

    private var siteTypeBM: MetalBuffMgr<SiteType>
    let sitePropsBM: MetalBuffMgr<SiteProps>
    let tracerBM: MetalBuffMgr<TracerCoord>

    public init(
        fields: FieldData, width: Int, height: Int, siteTypes: SiteTypeData,
        tracers: Tracers, omega: Double
    ) {
        self.width = width
        self.height = height
        self.numSites = width * height
        self.numFields = width * height * fieldsPerSite

        guard fields.count == self.numFields else {
            fatalError("Number of fields does not match lattice dimensions.")
        }
        self.module = try! MetalModule()
        collidePS = try! self.module.pipelineState(name: "collide")
        streamPS = try! self.module.pipelineState(name: "stream")
        moveTracerPS = try! self.module.pipelineState(name: "move_tracers")

        let dev = self.module.dev
        collideParamsBM = MetalBuffMgr<CollideParams>(device: dev)
        streamParamsBM = MetalBuffMgr<StreamParams>(device: dev)

        fields1BM = MetalBuffMgr<Float>(device: dev)
        fields2BM = MetalBuffMgr<Float>(device: dev)
        siteTypeBM = MetalBuffMgr<SiteType>(device: dev)
        sitePropsBM = MetalBuffMgr<SiteProps>(device: dev)
        tracerBM = MetalBuffMgr<TracerCoord>(device: dev)

        // Expect to receive one value for each site, not for each field.
        let numSites = numFields / fieldsPerSite

        collideParamsBM.prepare(value: CollideParams(omega: Float(omega)))

        let latticeSize = LatticeSize(
            width: UInt32(width), height: UInt32(height))
        streamParamsBM.prepare(value: StreamParams(latticeSize: latticeSize))

        fields1BM.prepare(values: fields)
        // Initial values for fields2 don't really matter.
        fields2BM.prepare(values: fields)
        useFields1 = true
        siteTypeBM.prepare(values: siteTypes)

        sitePropsBM.prepare(numResults: numSites)

        tracerBM.prepare(values: tracers.coords)
    }

    public func stepOneFrame(stepsPerFrame: Int, moveTracers: Bool) {
        guard let cmdBuff = module.cmdBuff() else {
            fatalError("Failed to make command buffer")
        }
        for _ in 0..<stepsPerFrame {
            encodeStepCommands(cmdBuff: cmdBuff, moveTracers: moveTracers)
            useFields1.toggle()
        }
        // Execute the command
        cmdBuff.commit()
        // Wait synchronously for the result
        cmdBuff.waitUntilCompleted()
    }

    func encodeStepCommands(cmdBuff: MTLCommandBuffer, moveTracers: Bool) {
        guard let encoder = cmdBuff.makeComputeCommandEncoder() else {
            fatalError("Failed to make compute command encoder")
        }
        encodeCollideCmd(encoder)
        encodeStreamCmd(encoder)
        if moveTracers {
            encodeMoveTracersCmd(encoder)
        }
        encoder.endEncoding()
    }

    // These should be private - made internal for unit testing
    func encodeCollideCmd(_ encoder: MTLComputeCommandEncoder) {
        let ps = collidePS
        encoder.setComputePipelineState(ps)
        encoder.setBuffer(collideParamsBM.buff(), offset: 0, index: 0)
        if useFields1 {
            encoder.setBuffer(fields1BM.buff(), offset: 0, index: 1)
        } else {
            encoder.setBuffer(fields2BM.buff(), offset: 0, index: 1)
        }
        encoder.setBuffer(siteTypeBM.buff(), offset: 0, index: 2)
        encoder.setBuffer(sitePropsBM.buff(), offset: 0, index: 3)

        // Do one item of work for each site,
        // while passing a buffer of all fields.
        let numSites = self.numFields / fieldsPerSite
        let gridSize = MTLSizeMake(numSites, 1, 1)

        let tgSize = min(numSites, ps.maxTotalThreadsPerThreadgroup)
        let threadGroupSize = MTLSizeMake(tgSize, 1, 1)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
    }

    func encodeStreamCmd(_ encoder: MTLComputeCommandEncoder) {
        let ps = streamPS
        encoder.setComputePipelineState(ps)
        encoder.setBuffer(streamParamsBM.buff(), offset: 0, index: 0)
        if useFields1 {
            encoder.setBuffer(fields1BM.buff(), offset: 0, index: 1)
            encoder.setBuffer(fields2BM.buff(), offset: 0, index: 2)
        } else {
            encoder.setBuffer(fields2BM.buff(), offset: 0, index: 1)
            encoder.setBuffer(fields1BM.buff(), offset: 0, index: 2)
        }
        encoder.setBuffer(siteTypeBM.buff(), offset: 0, index: 3)

        let gridSize = MTLSizeMake(width, height, numDirections)

        // From https://eugenebokhan.io/introduction-to-metal-compute-part-three
        // and from Xcode documentation.
        let tgWidth = ps.threadExecutionWidth
        // How to choose dimensions so the total size is as near as possible to
        // maxTotalThreadsPerThreadgroup?
        let tgHD = ps.maxTotalThreadsPerThreadgroup / tgWidth
        let tgHeight = tgHD / numDirections
        let tgDepth = numDirections

        let threadGroupSize = MTLSize(
            width: tgWidth,
            height: tgHeight,
            depth: tgDepth)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
    }

    func encodeMoveTracersCmd(_ encoder: MTLComputeCommandEncoder) {
        let ps = moveTracerPS
        encoder.setComputePipelineState(ps)
        // Tracer kernel function takes same params as stream:
        encoder.setBuffer(streamParamsBM.buff(), offset: 0, index: 0)
        encoder.setBuffer(sitePropsBM.buff(), offset: 0, index: 1)
        encoder.setBuffer(tracerBM.buff(), offset: 0, index: 2)

        // Do one item of work for each tracer.
        let numTracers = tracerBM.numValues
        let gridSize = MTLSizeMake(numTracers, 1, 1)

        let tgSize = min(numTracers, ps.maxTotalThreadsPerThreadgroup)
        let threadGroupSize = MTLSizeMake(tgSize, 1, 1)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
    }
}
