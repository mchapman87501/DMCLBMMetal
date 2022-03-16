import XCTest

import DMCLBMMetal
import DMC2D
@testable import DMCMovieWriter

class WorldWriterTests: XCTestCase {
    private let movieURL = URL(fileURLWithPath: "world_writer_tests.mov")

    override func tearDownWithError() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: movieURL.path) {
            try fm.removeItem(at: movieURL)
        }
    }
    
    private func newLattice(width: Int, height: Int, shape: DMC2D.Polygon) -> Lattice {
        let numSites = width * height
        let numFields = numSites * fieldsPerSite
        
        let fields0 = (0..<numFields).map {
            Float($0)
        }
        var siteTypes = SiteTypeData()
        for y in 0..<height {
            for x in 0..<width {
                let siteType: SiteType = shape.contains(x: x, y: y) ? .obstacle : .fluid
                siteTypes.append(siteType)
            }
        }

        let tracers = Tracers(latticeWidth: width, latticeHeight: height, spacing: 1)

        return Lattice(
            fields: fields0, width: width, height: height, siteTypes: siteTypes,
            tracers: tracers, omega: 9.1)
    }

    func testWorldWriter() throws {
        let width = 16
        let height = 8

        let foil = AirFoil(
            x: Double(width) / 4.0, y: Double(height) / 2.0, width: Double(width) / 3.0,
            alphaRad: 4.0 * .pi / 180.0)
        
        let lattice = newLattice(width: width, height: height, shape: foil.shape)
        let efc = EdgeForceCalc(lattice: lattice, shape: foil.shape)

        let movieWidth = 40 * width
        let movieHeight = 40 * height
        guard
            let movieWriter = try? DMCMovieWriter(
                outpath: movieURL, width: movieWidth, height: movieHeight)
        else {
            XCTFail("Could not create movie writer.")
            return
        }
        guard
            let writer = try? WorldWriter(lattice: lattice, edgeForceCalc: efc, width: movieWidth, height: movieHeight, foil: foil, writingTo: movieWriter)
        else {
            XCTFail("Could not create world writer.")
            return
        }

        try writer.showTitle("Your Title Here")

        for _ in 0..<10 {
            lattice.stepOneFrame(stepsPerFrame: 1, moveTracers: false)
            try writer.writeNextFrame()
        }

        let frameWidth = Double(movieWidth) / 2.0
        let frameHeight = Double(movieHeight) / 2.0
        let frameImage = writer.getCurrFrame(width: frameWidth)
        XCTAssertEqual(frameImage.size.width, frameWidth)
        XCTAssertEqual(frameImage.size.height, frameHeight)

        try movieWriter.finish()
        let moviePath = movieURL.path
        let fm = FileManager.default
        XCTAssert(
            fm.fileExists(atPath: moviePath), "No such file: \(moviePath)")

        let attrs = try fm.attributesOfItem(atPath: moviePath)
        let fileSize = (attrs[.size]! as? Int) ?? -1
        XCTAssertTrue(fileSize > 0)
    }
}
