import Foundation

enum MetalError: Error {
    case noDevice
    case cannotMakeCommandQueue
    case defaultLibraryNotFound
    case cannotFindFunction(name: String)
}
