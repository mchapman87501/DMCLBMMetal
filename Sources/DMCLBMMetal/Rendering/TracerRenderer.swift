import Foundation
import Metal

struct TracerRenderer {
    let lattice: Lattice

    init(lattice: Lattice) {
        self.lattice = lattice
    }

    func render(context: RenderContext) {
        let encoder = context.newEncoder()
        var worldSize = WorldSize(
            x: Float(lattice.width), y: Float(lattice.height))
        encoder.setVertexBytes(
            &worldSize, length: MemoryLayout<WorldSize>.size, index: 0)
        var color: MetalColor = [0.2, 0.2, 1.0, 1.0]
        encoder.setVertexBytes(
            &color, length: MemoryLayout<MetalColor>.size, index: 1)

        encoder.setVertexBuffer(lattice.tracerBM.buff(), offset: 0, index: 2)
        encoder.drawPrimitives(
            type: .point, vertexStart: 0,
            vertexCount: lattice.tracerBM.numValues)
        encoder.endEncoding()
    }
}
