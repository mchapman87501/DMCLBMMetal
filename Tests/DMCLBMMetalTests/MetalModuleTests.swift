@testable import DMCLBMMetal
import XCTest

final class MetalModuleTests: XCTestCase {
    func testNoSuchFunction() throws {
        let module = try MetalModule()

        func getPS() throws {
            _ = try module.pipelineState(name: "no_such_function")
        }

        XCTAssertThrowsError(try getPS())
    }
}
