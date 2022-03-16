import DMC2D
import Foundation

public struct TracerCoord: Equatable {
    public var x = Float(0.0)
    public var y = Float(0.0)
}

public typealias TracerCoordData = [TracerCoord]

public class Tracers {
    let width: Int
    let height: Int
    let spacing: Int

    // These are lattice site coordinates for individual tracers.
    public let coords: TracerCoordData
    public var count: Int { coords.count }

    public init(
        shape: DMC2D.Polygon,
        latticeWidth width: Int, latticeHeight height: Int, spacing: Int
    ) {
        self.width = width
        self.height = height
        self.spacing = spacing

        let numTracers = (width * height) / spacing

        // Initially lay out the tracers in a grid, avoiding the foil shape.
        var points = [TracerCoord]()
        let yCoords = Array(stride(from: 0, to: height, by: spacing))
        let xCoords = Array(stride(from: 0, to: width, by: spacing))
        for ty in yCoords {
            let rowIndex = ty * xCoords.count
            for tx in xCoords {
                let index = rowIndex + tx
                guard index < numTracers else {
                    fatalError("Check your math")
                }
                if !shape.contains(x: tx, y: ty) {
                    points.append(TracerCoord(x: Float(tx), y: Float(ty)))
                }
            }
        }
        coords = points
    }

    // Alternate constructor for unit testing - no foil
    public init(
        latticeWidth width: Int, latticeHeight height: Int, spacing: Int
    ) {
        self.width = width
        self.height = height
        self.spacing = spacing

        let numTracers = (width * height) / spacing

        // Initially lay out the tracers in a grid, avoiding the foil shape.
        var points = [TracerCoord](repeating: TracerCoord(), count: numTracers)
        let yCoords = Array(stride(from: 0, to: height, by: spacing))
        let xCoords = Array(stride(from: 0, to: width, by: spacing))
        for ty in yCoords {
            let rowIndex = ty * xCoords.count
            for tx in xCoords {
                let index = rowIndex + tx
                guard index < numTracers else {
                    fatalError("Check your math")
                }
                points[index].x = Float(tx)
                points[index].y = Float(ty)
            }
        }
        coords = points
    }
}
