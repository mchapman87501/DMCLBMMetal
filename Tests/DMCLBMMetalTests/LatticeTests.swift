import XCTest
@testable import DMCLBMMetal

extension Lattice {
    func extractFields(firstField: Bool) -> FieldData {
        // Which buffer holds the most recent streaming results?
        // `useFields1' is toggled after each argument sequence.
        // If it is true, then the last streaming step used fields1, etc.
        return firstField ? fields1BM.values() : fields2BM.values()
    }

    func extractProps() -> [SiteProps] {
        return sitePropsBM.values()
    }

    func extractTracers() -> TracerCoordData {
        tracerBM.values()
    }
}

final class LatticeTests: XCTestCase {
    func testStreaming() throws {
        // The approach: Create a lattice whose field values are a function of their
        // streaming direction.
        // Stream.
        // Verify that the resulting field values represent streaming in the expected directions.
        let fields0 = (0..<36).map {
            Float($0)
        }
        let expFields1: [Float] = [
            0, 19, 29, 12, 31, 23, 33, 16, 35,
            9, 28, 20, 3, 22, 32, 24, 7, 26,
            18, 1, 11, 30, 13, 5, 15, 34, 17,
            27, 10, 2, 21, 4, 14, 6, 25, 8,
        ].map { Float($0) }

        let siteTypes = SiteTypeData(repeating: .fluid, count: 4)

        let tracers = Tracers(latticeWidth: 2, latticeHeight: 2, spacing: 1)

        let lbm = Lattice(
            fields: fields0, width: 2, height: 2, siteTypes: siteTypes,
            tracers: tracers, omega: 9.1)

        let cmdBuff = lbm.module.cmdBuff()!
        let encoder = cmdBuff.makeComputeCommandEncoder()!
        lbm.encodeStreamCmd(encoder)
        encoder.endEncoding()
        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()

        let actFields = lbm.extractFields(firstField: false)

        for i in 0..<expFields1.count {
            let expected = expFields1[i]
            let actual = actFields[i]
            XCTAssertEqual(
                expected, actual,
                "Field \(i) expected \(expected), got \(actual)")
        }
    }

    private func printTracers(lbm: Lattice) {
        let tracerCoords = lbm.extractTracers()
        print("Tracers:")
        for (i, coords) in tracerCoords.enumerated() {
            print(String(format: "  %2d: (%.2g, %.2g)", i, coords.x, coords.y))
        }
        print("")
    }

    private func printSiteVels(lbm: Lattice) {
        let props = lbm.extractProps()
        print("Site velocities")
        for y in 0..<lbm.height {
            let rowVal: [String] = (0..<lbm.width).map { x in
                let index = y * lbm.width + x
                let ux = props[index].ux
                let uy = props[index].uy
                return String(format: "(%.2g, %.2g)", ux, uy)
            }
            print(rowVal.joined(separator: ", "))
        }
    }

    func testMoveTracers() throws {
        // Approach:
        // Build a small lattice with known small ux, uy.
        // Iterate a fixed number of times, verify tracer positions integrate as expected.
        //
        // Ideally, extend this to multiple (ux, uy) scenarios.

        let singleSite = [1.0, 1.0, 1.0, 1.2, 1.0, 1.0, 1.0, 0.8, 1.0].map {
            Float($0)
        }
        let width = 6
        let height = 3
        let numSites = width * height
        var fields = FieldData()
        for _ in 0..<numSites {
            for iField in 0..<fieldsPerSite {
                fields.append(singleSite[iField])
            }
        }

        let siteTypes = SiteTypeData(repeating: .fluid, count: 4)
        let tracers = Tracers(
            latticeWidth: width, latticeHeight: height, spacing: 1)
        XCTAssertEqual(tracers.count, width * height)
        // We will follow the first tracer through the lattice.
        let txInitial = tracers.coords[0].x
        let tyInitial = tracers.coords[0].y

        let lbm = Lattice(
            fields: fields, width: width, height: height, siteTypes: siteTypes,
            tracers: tracers, omega: 9.1)

        // Collide so as to establish equilibrium
        for _ in 0..<100 {
            let cmdBuff = lbm.module.cmdBuff()!
            let encoder = cmdBuff.makeComputeCommandEncoder()!
            lbm.encodeCollideCmd(encoder)
            encoder.endEncoding()
            cmdBuff.commit()
            cmdBuff.waitUntilCompleted()
        }

        // Extract example site velocity (all should be the same.)
        let propsOut = lbm.extractProps()
        let ux = propsOut[0].ux
        let uy = propsOut[0].uy
        printSiteVels(lbm: lbm)

        let numSteps = 5 * 30 * 10

        //        printTracers(lbm: lbm)
        for _ in 0..<numSteps {
            // Move the tracers:
            let cmdBuff = lbm.module.cmdBuff()!
            let encoder = cmdBuff.makeComputeCommandEncoder()!
            lbm.encodeMoveTracersCmd(encoder)
            encoder.endEncoding()
            cmdBuff.commit()
            cmdBuff.waitUntilCompleted()
        }

        //        print("per-step velocities: (\(ux), \(uy))")
        // Assume lattice wrap-around behavior.
        var txExpected = txInitial
        var tyExpected = tyInitial
        for _ in 0..<numSteps {
            txExpected += ux
            tyExpected += uy
            if txExpected < 0 {
                txExpected += Float(width)
            } else if txExpected >= Float(width) {
                txExpected -= Float(width)
            }

            if tyExpected < 0 {
                tyExpected += Float(height)
            } else if tyExpected >= Float(height) {
                tyExpected -= Float(height)
            }
        }

        //        printTracers(lbm: lbm)
        let tracerCoords = lbm.extractTracers()

        let txActual = tracerCoords[0].x
        let tyActual = tracerCoords[0].y
        XCTAssertEqual(txExpected, txActual, accuracy: 1.0e-3)
        XCTAssertEqual(tyExpected, tyActual, accuracy: 1.0e-3)
    }
    
    func testStepOneFrame() throws {
        // The approach: Create a lattice whose field values are a function of their
        // streaming direction.
        // Stream.
        // Verify that the resulting field values represent streaming in the expected directions.
        let fields0 = (0..<36).map {
            Float($0)
        }
        let siteTypes = SiteTypeData(repeating: .fluid, count: 4)

        let tracers = Tracers(latticeWidth: 2, latticeHeight: 2, spacing: 1)
        
        let lbm = Lattice(
            fields: fields0, width: 2, height: 2, siteTypes: siteTypes,
            tracers: tracers, omega: 9.1)

        // Weak! Really, this is just to verify that the lattice can
        // step through a few iterations without crashing.
        let tracerCoords0 = lbm.extractTracers()
        lbm.stepOneFrame(stepsPerFrame: 30, moveTracers: true)
        let tracerCoordsF = lbm.extractTracers()
        XCTAssertNotEqual(tracerCoords0, tracerCoordsF)
        
    }
}
