import XCTest

@testable import DMCLBMMetal

final class TextureCompositorTests: XCTestCase {
    private func testWithAlpha(alpha: Double) throws {
        let module = try MetalModule()
        let width = 8
        let height = 8
        let imgSize = NSSize(width: width, height: height)
        let srcImage = NSImage(size: imgSize, flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            return true
        }

        let texture = srcImage.toTexture(device: module.dev)

        let compositor = try TextureCompositor(module: module, imageSize: imgSize)
        compositor.composite(textures: [texture], alpha: Float(alpha))

        let resultImage = NSImage.fromTexture(texture: compositor.texture)
        let resultCGImage = resultImage.cgImage(
            forProposedRect: nil, context: nil, hints: nil)!
        let dp = resultCGImage.dataProvider!
        let resultData = dp.data! as Data

        // Some test: the compositor always renders over
        // a full-opacity black background, so expected alpha is always 255.
        let expectedAlpha = UInt8(255)  // UInt8(255 * alpha + 0.5)
        // How to know the component order?  It looks like BGRA...
        let alphaComp = 3

        resultData.withUnsafeBytes { ubytes in
            var errorsToGo = 4
            var index = 0
            for _ in 0..<resultCGImage.height {
                for _ in 0..<resultCGImage.width {
                    // How to know the component order?  It looks like BGRA...
                    for component in 0..<4 {
                        let value = ubytes[index]

                        if component == alphaComp {
                            if value != expectedAlpha {
                                XCTAssertEqual(value, expectedAlpha)
                                errorsToGo -= 1
                                if errorsToGo <= 0 {
                                    return
                                }
                            }
                        }
                        print("    Comp \(component): \(value)")
                        index += 1
                    }
                    print("")
                }
            }
        }
    }

    func testTransparent() throws {
        try testWithAlpha(alpha: 0.0)
    }

    func testOpaque() throws {
        try testWithAlpha(alpha: 1.0)
    }

    func testSemi() throws {
        try testWithAlpha(alpha: 0.5)
    }
}
