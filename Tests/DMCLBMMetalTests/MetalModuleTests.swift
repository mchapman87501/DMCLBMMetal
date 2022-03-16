import XCTest
@testable import DMCLBMMetal

final class MetalModuleTests: XCTestCase {
    func testNoSuchFunction() throws {
        let module = try MetalModule()
        
        func getPS() throws {
            let _ = try module.pipelineState(name: "no_such_function")
        }

        XCTAssertThrowsError(try getPS())
    }
}
