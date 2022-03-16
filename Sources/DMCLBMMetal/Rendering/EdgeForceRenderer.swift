import DMC2D
import Metal
import simd

struct EdgeForceRenderParams {
    let worldSize: SIMD2<Float>
    let color: SIMD4<Float>
    let edgeIndex: UInt32
}

struct EdgeForceRenderer {
    let lattice: Lattice
    let worldSize: WorldSize
    let numEdges: Int
    let edgeMidpoints: [VertexCoord]
    let edgeNormals: [VertexCoord]

    let unitArrow: [VertexCoord]
    let tailMask: [Float]

    let edgeMidPointBM: MetalBuffMgr<VertexCoord>
    let edgeNormalBM: MetalBuffMgr<VertexCoord>
    let edgeForceBM: MetalBuffMgr<Float>
    let arrowVerticesBM: MetalBuffMgr<VertexCoord>
    let arrowTailMaskBM: MetalBuffMgr<Float>

    init(
        lattice: Lattice, shape: DMC2D.Polygon,
        edgeForceBM: MetalBuffMgr<Float>
    ) {
        self.lattice = lattice
        self.worldSize = WorldSize(
            x: Float(lattice.width), y: Float(lattice.height))
        numEdges = shape.edges.count

        edgeMidpoints = shape.edges.map { edge in
            VertexCoord(
                x: Float(edge.p0.x + edge.pf.x) / 2.0,
                y: Float(edge.p0.y + edge.pf.y) / 2.0)
        }
        edgeNormals = shape.edgeNormals.map { norm in
            VertexCoord(x: Float(norm.x), y: Float(norm.y))
        }

        let arrowMaker = ArrowShapeMaker()
        unitArrow = arrowMaker.unitArrow
        tailMask = arrowMaker.tailMask

        let dev = lattice.module.dev
        edgeMidPointBM = MetalBuffMgr<VertexCoord>(device: dev)
        edgeMidPointBM.prepare(values: edgeMidpoints)

        self.edgeForceBM = edgeForceBM
        edgeNormalBM = MetalBuffMgr<VertexCoord>(device: dev)
        edgeNormalBM.prepare(values: edgeNormals)

        arrowVerticesBM = MetalBuffMgr<VertexCoord>(device: dev)
        arrowVerticesBM.prepare(values: unitArrow)

        arrowTailMaskBM = MetalBuffMgr<Float>(device: dev)
        arrowTailMaskBM.prepare(values: tailMask)
    }

    func render(context: RenderContext) {
        // Depict edge forces, as supplied by an EdgeForceCalc.
        // Depict each force using an arrow shape, ortho to the
        // corresponding shape edge.

        // Surely there's a better way than this...
        // Make a separate shader call for each edge force arrow.
        let encoder = context.newEncoder()
        for index in 0..<numEdges {
            var params = EdgeForceRenderParams(
                worldSize: worldSize,
                color: [0.0, 0.0, 1.0, 1.0], edgeIndex: UInt32(index))

            // This is far from optimal.  Maybe it will work...
            encoder.setVertexBytes(
                &params, length: MemoryLayout<EdgeForceRenderParams>.stride,
                index: 0)

            if index <= 0 {
                encoder.setVertexBuffer(
                    edgeMidPointBM.buff(), offset: 0, index: 1)
                encoder.setVertexBuffer(
                    edgeNormalBM.buff(), offset: 0, index: 2)
                encoder.setVertexBuffer(edgeForceBM.buff(), offset: 0, index: 3)
                encoder.setVertexBuffer(
                    arrowVerticesBM.buff(), offset: 0, index: 4)
                encoder.setVertexBuffer(
                    arrowTailMaskBM.buff(), offset: 0, index: 5)
            }
            // Is there a way to do a single render call to cover the whole set of
            // edge-force shapes?  Is setVertexAmplificationCount relevant?
            encoder.drawPrimitives(
                type: .triangle, vertexStart: 0, vertexCount: unitArrow.count)
        }
        encoder.endEncoding()
    }
}
