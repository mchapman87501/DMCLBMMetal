import DMC2D
import Metal
import simd

// TODO: DRY with respect to EdgeForceRenderer
struct NetForceRenderer {
    let lattice: Lattice
    let worldSize: WorldSize
    let numEdges: Int
    let edgeMidpoints: [VertexCoord]

    let edgeMidPointBM: MetalBuffMgr<VertexCoord>
    let edgeNormalBM: MetalBuffMgr<VertexCoord>
    let edgeForceBM: MetalBuffMgr<Float>
    let arrowVerticesBM: MetalBuffMgr<VertexCoord>
    let arrowTailMaskBM: MetalBuffMgr<Float>

    init(lattice: Lattice, shape: DMC2D.Polygon) {
        self.lattice = lattice
        worldSize = WorldSize(
            x: Float(lattice.width), y: Float(lattice.height))

        numEdges = 1

        let shapeCenter = shape.center
        edgeMidpoints = [
            VertexCoord(x: Float(shapeCenter.x), y: Float(shapeCenter.y)),
        ]

        let dev = lattice.module.dev
        edgeMidPointBM = MetalBuffMgr<VertexCoord>(device: dev)
        edgeMidPointBM.prepare(values: edgeMidpoints)

        edgeForceBM = MetalBuffMgr<Float>(device: dev)
        edgeNormalBM = MetalBuffMgr<VertexCoord>(device: dev)

        arrowVerticesBM = MetalBuffMgr<VertexCoord>(device: dev)

        let tailMask = [Float](repeating: 0.0, count: numEdges)
        arrowTailMaskBM = MetalBuffMgr<Float>(device: dev)
        arrowTailMaskBM.prepare(values: tailMask)
    }

    func render(context: RenderContext, netForce: Vector) {
        let netDirection = netForce.unit()
        let netMag = 0.5 * netForce.magnitude()
        let edgeNormals = [
            VertexCoord(x: Float(netDirection.x), y: Float(netDirection.y)),
        ]
        let edgeForces = [Float(netMag)]

        let arrowMaker = ArrowShapeMaker(
            shaftWidth: 2.0, shaftLength: netMag + 1.6)
        // Hack: offset arrow coords so the tail lies at 0.0.
        let unitArrow = arrowMaker.unitArrow
        let xTail = unitArrow.reduce(0.0) { xmax, vcoord in
            vcoord.x > xmax ? vcoord.x : xmax
        }
        let arrowVertices = unitArrow.map { vcoord in
            VertexCoord(x: vcoord.x - xTail, y: vcoord.y)
        }

        let encoder = context.newEncoder()
        var params = EdgeForceRenderParams(
            worldSize: worldSize,
            color: [1.0, 1.0, 1.0, 1.0], edgeIndex: UInt32(0))

        encoder.setVertexBytes(
            &params, length: MemoryLayout<EdgeForceRenderParams>.stride,
            index: 0)
        encoder.setVertexBuffer(edgeMidPointBM.buff(), offset: 0, index: 1)

        edgeNormalBM.prepare(values: edgeNormals)
        encoder.setVertexBuffer(edgeNormalBM.buff(), offset: 0, index: 2)

        edgeForceBM.prepare(values: edgeForces)
        encoder.setVertexBuffer(edgeForceBM.buff(), offset: 0, index: 3)

        arrowVerticesBM.prepare(values: arrowVertices)
        encoder.setVertexBuffer(arrowVerticesBM.buff(), offset: 0, index: 4)
        encoder.setVertexBuffer(arrowTailMaskBM.buff(), offset: 0, index: 5)
        encoder.drawPrimitives(
            type: .triangle, vertexStart: 0, vertexCount: unitArrow.count)
        encoder.endEncoding()
    }
}
