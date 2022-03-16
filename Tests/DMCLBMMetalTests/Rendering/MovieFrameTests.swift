import XCTest

@testable import DMCLBMMetal

class MovieFrameTests: XCTestCase {
    func testSingleFrame() throws {
        let width = 32
        let height = 32
        let numSites = width * height
        let numFields = numSites * fieldsPerSite
        
        let fields0 = (0..<numFields).map {
            Float($0)
        }
        let foil = AirFoil(
            x: Double(width) / 4.0, y: Double(height) / 2.0, width: Double(width) / 3.0,
            alphaRad: 4.0 * .pi / 180.0)
        
        var siteTypes = SiteTypeData()
        for y in 0..<height {
            for x in 0..<width {
                let siteType: SiteType = foil.shape.contains(x: x, y: y) ? .obstacle : .fluid
                siteTypes.append(siteType)
            }
        }

        let tracers = Tracers(latticeWidth: width, latticeHeight: height, spacing: 1)

        let lattice = Lattice(
            fields: fields0, width: width, height: height, siteTypes: siteTypes,
            tracers: tracers, omega: 9.1)

        let efc = EdgeForceCalc(lattice: lattice, shape: foil.shape)
        let frameMaker = try MovieFrame(lattice: lattice, foil: foil, edgeForceCalc: efc, width: width, height: height, title: "Initial")
        let image = frameMaker.createFrame()
        if let imageData = image.tiffRepresentation {
            let bitmapRep = NSBitmapImageRep(data: imageData)
            XCTAssertNotNil(bitmapRep)
        }
        lattice.stepOneFrame(stepsPerFrame: 10, moveTracers: true)
        let frameMaker2 = try MovieFrame(lattice: lattice, foil: foil, edgeForceCalc: efc, width: width, height: height, title: "After one frame")
        let image2 = frameMaker2.createFrame()
        if let imageData2 = image2.tiffRepresentation {
            let bitmapRep = NSBitmapImageRep(data: imageData2)
            XCTAssertNotNil(bitmapRep)
        }
    }
}
