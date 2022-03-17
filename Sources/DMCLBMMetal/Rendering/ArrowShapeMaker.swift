import AppKit
import DMC2D
import Foundation

struct ArrowShapeMaker {
    let unitArrow: [VertexCoord]
    let tailMask: [Float]

    init(shaftWidth: Double = 1.0, shaftLength: Double = 0.0) {
        let arrowTailX = 6.0 * shaftWidth
        let xTail = arrowTailX + shaftLength
        let halfShaft = shaftWidth / 2.0
        unitArrow = Self.unitArrow(xTail: xTail, yHalfShaft: halfShaft)
        tailMask = Self.unitArrowTailMask(
            fromTriangles: unitArrow, xTail: xTail)
    }

    private static func unitArrow(xTail: Double, yHalfShaft: Double)
        -> [VertexCoord]
    {
        // Assume zero rotation corresponds to the
        // positive x axis.  Each arrow, when rendered, will be
        // rotated to the edge normal direction.  To make it appear
        // to point in instead of out, make the untransformed arrow
        // point along negative x axis.

        // Concave hulls do not convert well to triangle strips,
        // So instead represent as a sequence of connected triangles.

        let sizeFactor = 5.0 * yHalfShaft
        let xTip = 0.0
        let yTip = 0.0
        let xBarb = 2.0 * sizeFactor
        let yBarb = sizeFactor
        let xJunct = 1.5 * sizeFactor
        let yShaft = yHalfShaft

        let triangles = [
            // Top half of arrowhead, starting at tip.
            (xTip, yTip),
            (xBarb, yBarb),
            (xJunct, yShaft),

            // Center of arrowhead, starting at tip:
            (xTip, yTip),
            (xJunct, yShaft),
            (xJunct, -yShaft),

            // Bottom half of arrowhead, starting at tip.
            (xTip, yTip),
            (xBarb, -yBarb),
            (xJunct, -yShaft),

            // Top half of shaft, starting at junction.
            (xJunct, yShaft),
            (xTail, yShaft),
            (xTail, -yShaft),

            // Bottom half of shaft, starting at bottom junction.
            (xJunct, -yShaft),
            (xJunct, yShaft),
            (xTail, -yShaft),
        ]
        let result: [VertexCoord] = triangles.map { x, y in
            VertexCoord(x: Float(x), y: Float(y))
        }

        return result
    }

    // Get a parallel array for unitArrow indicating which
    // vertices are tail endpoints.
    private static func unitArrowTailMask(
        fromTriangles: [VertexCoord], xTail: Double) -> [Float]
    {
        let result: [Float] = fromTriangles.map { vc in
            (vc.x >= Float(xTail)) ? Float(1.0) : Float(0.0)
        }
        return result
    }
}
