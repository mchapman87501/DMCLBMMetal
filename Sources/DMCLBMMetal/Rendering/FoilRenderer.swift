import DMC2D
import Foundation
import Metal

struct FoilRenderer {
    let lattice: Lattice
    let hull: [VertexCoord]
    let triangles: [VertexCoord]

    init(lattice: Lattice, foilShape: DMC2D.Polygon) {
        self.lattice = lattice
        var hull = foilShape.vertices.map { vertex in
            VertexCoord(x: Float(vertex.x), y: Float(vertex.y))
        }
        triangles = VertexUtils.hullToTriangleStrip(values: hull)
        // Close the hull:
        hull.append(hull.first!)
        self.hull = hull
    }

    func render(context: RenderContext) {
        let fillColor: MetalColor = [0.3, 0.3, 0.3, 1.0]
        renderShape(
            context: context, shape: triangles, using: .triangleStrip,
            color: fillColor)

        let strokeColor: MetalColor = [0.0, 0.0, 0.0, 1.0]
        renderShape(
            context: context, shape: hull, using: .lineStrip, color: strokeColor)
    }

    private func renderShape(
        context: RenderContext,
        shape: [VertexCoord],
        using type: MTLPrimitiveType, color shapeColor: MetalColor)
    {
        let encoder = context.newEncoder()

        var worldSize = WorldSize(
            x: Float(lattice.width), y: Float(lattice.height))
        encoder.setVertexBytes(
            &worldSize, length: MemoryLayout<WorldSize>.size, index: 0)

        var color = shapeColor
        encoder.setVertexBytes(
            &color, length: MemoryLayout<MetalColor>.size, index: 1)

        let vertexSize = MemoryLayout<VertexCoord>.stride
        encoder.setVertexBytes(
            shape, length: vertexSize * shape.count, index: 2)

        encoder.drawPrimitives(
            type: type, vertexStart: 0, vertexCount: shape.count)
        encoder.endEncoding()
    }
}
