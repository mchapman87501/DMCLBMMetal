import AppKit
import Metal

class LegendRenderer {
    private(set) var title: String
    let imageSize: NSSize

    private var _texture: MTLTexture?
    var texture: MTLTexture {
        if _texture == nil {
            updateTexture()
        }
        return _texture!
    }

    let module: MetalModule

    init(module: MetalModule, imageSize: NSSize, title: String) {
        self.title = title
        self.imageSize = imageSize
        self.module = module
    }

    func setTitle(_ newValue: String) {
        title = newValue
        _texture = nil
    }

    private func updateTexture() {
        let image = NSImage(
            size: imageSize, flipped: false, drawingHandler: drawLegend)
        _texture = image.toTexture(device: module.dev)
    }

    private func drawLegend(_ fullRect: NSRect) -> Bool {
        let width = fullRect.width / 4
        let height = fullRect.height / 4

        let mfSize = 10.0
        let measureFont = NSFont.systemFont(ofSize: mfSize)
        let measureAttrs = [
            NSAttributedString.Key.font: measureFont,
        ]
        let refTitleSize = (title as NSString).size(
            withAttributes: measureAttrs)

        let scale = min(
            width / refTitleSize.width, height / refTitleSize.height)
        let fontSize = scale * mfSize
        let font = NSFont.systemFont(ofSize: fontSize)
        let attrs = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: NSColor.black,
        ]
        let titleSize = (title as String).size(withAttributes: attrs)

        // Create a background rect that fits the text plus some margin.
        let marginFract = 0.05 // Margin within the background rect
        let bgWidth = titleSize.width * (1.0 + 2.0 * marginFract)
        let bgHeight = titleSize.height * (1.0 + 2.0 * marginFract)

        let bgOffset = 10.0
        let bgOrigin = CGPoint(
            x: fullRect.origin.x + bgOffset,
            y: fullRect.height - bgHeight - bgOffset)
        let bgSize = NSSize(width: bgWidth, height: bgHeight)
        let backgroundRect = NSRect(origin: bgOrigin, size: bgSize)

        NSColor(calibratedWhite: 1.0, alpha: 0.3).setFill()
        NSBezierPath.fill(backgroundRect)

        let xPos = bgOrigin.x + (bgWidth - titleSize.width) / 2.0
        let yPos = bgOrigin.y + (bgHeight - titleSize.height) / 2.0

        (title as NSString).draw(
            at: NSPoint(x: xPos, y: yPos),
            withAttributes: attrs)

        NSColor.black.setStroke()
        NSBezierPath.stroke(backgroundRect)
        return true
    }
}
