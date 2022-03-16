import XCTest
@testable import DMCLBMMetal

final class TracerTests: XCTestCase {
    
    func testNoShapeInitializer() throws {
        let width = 4
        let height = 4
        
        let tracers = Tracers(latticeWidth: width, latticeHeight: height, spacing: 1)
        XCTAssertEqual(tracers.count, width * height)
    }
    
    func testShapeInitializer() throws {
        let width = 16
        let height = 16
        
        let foil = AirFoil(x: 1.0, y: Double(height)/2.0, width: 0.75 * Double(width), alphaRad: 0.0)
        
        let tracers = Tracers(shape: foil.shape, latticeWidth: width, latticeHeight: height, spacing: 1)
        
        XCTAssertLessThan(tracers.count, width * height)
        XCTAssertGreaterThan(tracers.count, 0)
    }
}
