import Cocoa
import Foundation
import MetalKit

public extension NSImage {
    static func fromTexture(texture: MTLTexture) -> NSImage {
        let imgSize = NSSize(width: texture.width, height: texture.height)
        if let cgImage = CGImage.fromTexture(texture: texture) {
            return NSImage(cgImage: cgImage, size: imgSize)
        }
        return NSImage(size: imgSize)
    }

    func toTexture(device: MTLDevice) -> MTLTexture {
        let imageData = tiffRepresentation!
        let source = CGImageSourceCreateWithData(imageData as CFData, nil)
            .unsafelyUnwrapped
        let maskRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
        let cgImage = maskRef.unsafelyUnwrapped
        return cgImage.toTexture(device: device)
    }
}

public extension CGImage {
    // Many thanks to Avinash!
    // https://avinashselvam.medium.com
    // https://gist.github.com/avinashselvam/9ccdd297ce28a3363518727e50f77d11)
    static func fromTexture(texture tex: MTLTexture) -> CGImage? {
        let numComps = 4
        let imgWidth = tex.width
        let imgHeight = tex.height
        var data = [UInt8](
            repeatElement(0, count: tex.width * tex.height * numComps))
        let fullRegion = MTLRegionMake2D(0, 0, imgWidth, imgHeight)
        tex.getBytes(
            &data, bytesPerRow: imgWidth * numComps, from: fullRegion,
            mipmapLevel: 0)
        let rawValue =
            (CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue)

        let bitmapInfo = CGBitmapInfo(rawValue: rawValue)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &data, width: imgWidth, height: imgHeight,
            bitsPerComponent: 8, bytesPerRow: imgWidth * numComps,
            space: colorspace, bitmapInfo: bitmapInfo.rawValue)
        return context?.makeImage()
    }

    func toTexture(device: MTLDevice) -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)

        do {
            let texture = try textureLoader.newTexture(
                cgImage: self, options: nil)
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: texture.pixelFormat, width: width,
                height: height, mipmapped: false)
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            return texture
        } catch {
            let msg = "Couldn't convert CGImage to MTLtexture \(error)"
            print(msg)
            fatalError(msg)
        }
    }
}
