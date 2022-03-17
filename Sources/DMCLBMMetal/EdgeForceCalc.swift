import DMC2D
import Foundation
import Metal

public class EdgeForceCalc {
    // Edge force calculation entails analyzing lattice sites that
    // are adjacent to each edge of a shape/polygon.
    // An index of lattice site indices identifies all of the lattice sites
    // that are adjacent to a polygon.
    // EdgeSitesInfo identifies the contiguous entries in that index that
    // are adjacent to a single edge of the polygon.
    private struct EdgeSitesInfo {
        let edgeLength: Float // The length of this edge in lattice units
        let startIndex: UInt32 // Index of the first entry for this edge
        let numEntries: UInt32 // Number of consecutive entries belonging to this edge
    }

    let lattice: Lattice
    let shape: DMC2D.Polygon
    let ps: MTLComputePipelineState

    let allEdgeIndicesBM: MetalBuffMgr<UInt32>
    private let edgeSitesInfoBM: MetalBuffMgr<EdgeSitesInfo>
    let edgeForceBM: MetalBuffMgr<Float>

    let numEdges: Int

    // Poor separation of concerns: also maintain the net force on the shape.
    public private(set) var netForce: Vector

    public init(lattice: Lattice, shape: DMC2D.Polygon) {
        // Assumption: shape is already scaled and positioned wrt lattice -- both
        // share the same coordinate system.
        self.lattice = lattice
        self.shape = shape
        let latticeBounds = NSRect(
            x: 0, y: 0, width: lattice.width, height: lattice.height)
        let adjCoords = ShapeAdjacentCoords(
            shape: shape, latticeBounds: latticeBounds)
        numEdges = adjCoords.adjacents.count

        var edgeInfos = [EdgeSitesInfo]()

        // Flatten the coordinates into a single array, with a corresponding
        // index (and counts, to simplify the Metal shader).
        var allEdgeIndices = [UInt32]()
        var nextEdgeStartIndex = UInt32(0)
        for (i, edgeSites) in adjCoords.adjacents.enumerated() {
            let edgeLength = Float(shape.edges[i].asVector().magnitude())

            let offsets = edgeSites.map { siteX, siteY in
                UInt32(siteY * lattice.width + siteX)
            }

            allEdgeIndices.append(contentsOf: offsets)

            let numIndices = UInt32(offsets.count)
            let info = EdgeSitesInfo(edgeLength: edgeLength, startIndex: nextEdgeStartIndex, numEntries: numIndices)
            edgeInfos.append(info)

            nextEdgeStartIndex += numIndices
        }

        netForce = Vector()

        // Assertions: edgeStartIndices.count == adjCoords.adjacents.count
        //             edgeStartIndices.count == numEdgeIndices.count

        let dev = lattice.module.dev
        allEdgeIndicesBM = MetalBuffMgr<UInt32>(device: dev)
        allEdgeIndicesBM.prepare(values: allEdgeIndices)

        edgeSitesInfoBM = MetalBuffMgr<EdgeSitesInfo>(device: dev)
        edgeSitesInfoBM.prepare(values: edgeInfos)
        edgeForceBM = MetalBuffMgr<Float>(device: dev)
        edgeForceBM.prepare(numResults: adjCoords.adjacents.count)

        ps = try! lattice.module.pipelineState(name: "calc_edge_force")
    }

    public func calculate() {
        guard let cmdBuff = lattice.module.cmdBuff() else {
            fatalError("Could not create command buffer for edge force calc.")
        }
        guard let encoder = cmdBuff.makeComputeCommandEncoder() else {
            fatalError("Could not create encoder for edge force calc.")
        }

        encoder.setComputePipelineState(ps)

        encoder.setBuffer(lattice.sitePropsBM.buff(), offset: 0, index: 0)
        encoder.setBuffer(allEdgeIndicesBM.buff(), offset: 0, index: 1)
        encoder.setBuffer(edgeSitesInfoBM.buff(), offset: 0, index: 2)
        encoder.setBuffer(edgeForceBM.buff(), offset: 0, index: 3)

        // TODO: Abstract out this work item sizing logic.
        let gridSize = MTLSizeMake(numEdges, 1, 1)
        let tgSize = min(ps.maxTotalThreadsPerThreadgroup, numEdges)
        let threadGroupSize = MTLSizeMake(tgSize, 1, 1)
        encoder.dispatchThreads(
            gridSize, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        // Needed: unit tests.
        // I keep seeing average rho == 1.0.

        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()

        updateNetForce()
    }

    private func updateNetForce() {
        var sum = Vector()
        let normals = shape.edgeNormals
        let edgeForces = edgeForceBM.values()
        for i in 0..<numEdges {
            sum += normals[i] * Double(edgeForces[i])
        }
        netForce = sum
    }
}
