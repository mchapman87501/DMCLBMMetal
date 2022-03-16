import XCTest
@testable import DMCLBMMetal

final class EdgePressureCalcTests: XCTestCase {
    func testEPC() throws {
        let width = 128
        let height = 64
        let numSites = width * height
        
        let singleSite: [Float] = [
            4.0/9.0,
            1.0/9.0,
            1.0/36.0,
            1.0/9.0,
            1.0/36.0,
            1.0/9.0,
            1.0/36.0,
            1.0/9.0,
            1.0/36.0
        ]

        let fields: [Float] = (0..<numSites).flatMap{_ in singleSite}
        let foil = AirFoil(
            x: Double(width) / 4.0, y: Double(height) / 2.0, width: Double(width) / 3.0,
            alphaRad: 4.0 * .pi / 180.0)
        let shape = foil.shape
        
        var siteTypes = SiteTypeData()
        for y in 0..<height {
            for x in 0..<width {
                let siteType: SiteType = foil.shape.contains(x: x, y: y) ? .obstacle : .fluid
                siteTypes.append(siteType)
            }
        }

        let tracers = Tracers(latticeWidth: width, latticeHeight: height, spacing: 1)

        let lattice = Lattice(
            fields: fields, width: width, height: height, siteTypes: siteTypes,
            tracers: tracers, omega: 9.1)

        let calc = EdgeForceCalc(lattice: lattice, shape: foil.shape)

        let numEdges = shape.edges.count
        
        // Iterate enough so that the field values have a chance to settle
        lattice.stepOneFrame(stepsPerFrame: 100, moveTracers: false)
        calc.calculate()
        
        // Weak!
        XCTAssertEqual(calc.numEdges, numEdges)
        let edgeForces = calc.edgeForceBM.values()
        XCTAssertEqual(edgeForces.count, shape.edges.count)
        XCTAssertTrue(edgeForces.allSatisfy{ $0 >= 0.0 })
    }
}
