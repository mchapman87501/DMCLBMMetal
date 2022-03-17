import AppKit
import DMCMovieWriter
import Foundation

/// Creates movies showing the evolving state of a fluid flow simulation.
public struct WorldWriter {
    let lattice: Lattice
    let edgeForceCalc: EdgeForceCalc
    let foil: AirFoil
    let movieWriter: DMCMovieWriter
    let frameMaker: MovieFrame
    var title: String
    let width: Int
    let height: Int

    public init(
        lattice: Lattice,
        edgeForceCalc: EdgeForceCalc,
        width: Int, height: Int,
        foil: AirFoil,
        writingTo: DMCMovieWriter,
        title: String = "") throws
    {
        self.lattice = lattice
        self.edgeForceCalc = edgeForceCalc
        self.foil = foil
        movieWriter = writingTo
        frameMaker = try MovieFrame(
            lattice: lattice, foil: foil, edgeForceCalc: edgeForceCalc,
            width: width, height: height,
            title: title)
        self.title = title
        self.width = width
        self.height = height
    }

    /// Add a title frame.
    ///
    /// Caveat: Multline titles *should* be supported, but this has not been tested.
    /// - Parameters:
    ///   - title: Text to show in the title frame
    ///   - duration: How long to display the title frame, excluding any fade-in/out time
    public func showTitle(_ title: String, duration seconds: Int = 3) throws {
        // Assume 1:1 lattice extent vs. movie frame size.
        let size = NSSize(width: width, height: height)

        let numRampFrames = 30
        let rampFrameDuration = 1.0 / 30.0

        let deferredImage = titleFrameImage(
            title: title, size: size, alpha: 1.0)
        let cgImage = deferredImage.cgImage(
            forProposedRect: nil, context: nil, hints: nil)
        let image = NSImage(cgImage: cgImage!, size: size)

        var alpha = 0.0
        let dAlpha = 1.0 / Double(numRampFrames)
        for _ in 0..<numRampFrames {
            try addTitleFrame(
                frameImage: image, alpha: alpha,
                duration: rampFrameDuration)
            alpha += dAlpha
        }

        try addTitleFrame(
            frameImage: image, alpha: 1.0, duration: Double(seconds))

        for _ in 0..<numRampFrames {
            try addTitleFrame(
                frameImage: image, alpha: alpha,
                duration: rampFrameDuration)
            alpha -= dAlpha
        }
        //        try movieWriter.drain()
    }

    private func addTitleFrame(
        frameImage: NSImage, alpha: Double, duration: Double) throws
    {
        try autoreleasepool {
            let faded = fadedImage(srcImage: frameImage, alpha: 1.0 - alpha)
            try movieWriter.addFrame(faded, duration: duration)
        }
    }

    private func fadedImage(srcImage: NSImage, alpha: Double) -> NSImage {
        NSImage(size: srcImage.size, flipped: false) {
            rect in

            srcImage.draw(in: rect)
            NSColor.black.withAlphaComponent(alpha).setFill()
            rect.fill()
            return true
        }
    }

    private func titleFrameImage(title: String, size: NSSize, alpha: Double)
        -> NSImage
    {
        NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath.fill(rect)

            // Solution from https://izziswift.com/how-to-use-nsstring-drawinrect-to-center-text/ inter alia
            let numLines = title.components(separatedBy: "\n").count

            // Try to use, e.g.,  1/3 of the height.
            let fontSize = (rect.height / 3.0) / Double(numLines)
            // https://stackoverflow.com/a/21940339/2826337
            let font = NSFont.systemFont(ofSize: fontSize)
            let attrs = [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.foregroundColor: NSColor.white
                    .withAlphaComponent(alpha),
            ]
            let size = (title as NSString).size(withAttributes: attrs)
            let xPos = max(0.0, (rect.size.width - size.width) / 2.0)
            let yPos = max(0.0, (rect.size.height - size.height) / 2.0)

            (title as NSString).draw(
                at: NSPoint(x: rect.origin.x + xPos, y: rect.origin.y + yPos),
                withAttributes: attrs)
            return true
        }
    }

    /// Record the current state of the simulation as a new movie frame.
    public func writeNextFrame(
        alpha: Double = 1.0
    ) throws {
        try autoreleasepool {
            let frameImage = frameMaker.createFrame(alpha: alpha)
            try movieWriter.addFrame(frameImage)
        }
    }

    /// Get an image showing the current state of the simulation.
    ///
    /// This method is for creating images to be displayed in user interfaces, e.g., to show the
    /// progress of a movie recording.
    public func getCurrFrame(
        width desiredWidth: Double
    ) -> NSImage {
        autoreleasepool {
            let scaleFactor = desiredWidth / Double(width)
            let desiredHeight = Double(height) * scaleFactor
            let w = Int(desiredWidth)
            let h = Int(desiredHeight)
            let maybeFrame = try? MovieFrame(
                lattice: lattice, foil: foil, edgeForceCalc: edgeForceCalc,
                width: w, height: h,
                title: title)
            if let frame = maybeFrame {
                return frame.createFrame()
            }
            // Fail grace-ish-ly
            return NSImage(size: NSSize(width: desiredWidth, height: desiredHeight))
        }
    }
}
