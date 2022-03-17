import AppKit
import Foundation

// typealias NormalizeFN = (Float) -> Float

/// Make images (movie frames) of a `Lattice` fluid flow simulation.
public struct MovieFrame {
    let imgWidth: Double
    let imgHeight: Double

    let renderer: FrameRenderer

    public init(
        lattice: Lattice, foil: AirFoil, edgeForceCalc: EdgeForceCalc,
        width: Int, height: Int, title: String) throws
    {
        // Expedient: Assume 1:1 lattice size vs. movie frame size.
        imgWidth = Double(width)
        imgHeight = Double(height)

        renderer = try FrameRenderer(
            title: title,
            width: width, height: height,
            lattice: lattice, edgeForceCalc: edgeForceCalc, foil: foil)
    }

    public func createFrame(alpha: Double = 1.0) -> NSImage {
        renderer.render(alpha: alpha)
    }
}
