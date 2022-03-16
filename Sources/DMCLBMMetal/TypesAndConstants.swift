import Foundation

public typealias FieldData = [Float]
public typealias SiteData = [Float]

public enum Direction: Int, CaseIterable {
    case none = 0
    case n, ne, e, se, s, sw, w, nw
}

// Direction components per field
// center, n, ne, e, se, s, sw, w, nw
let idvx = [0, 0, 1, 1, 1, 0, -1, -1, -1]
let idvy = [0, 1, 1, 0, -1, -1, -1, 0, 1]

public let numDirections = Direction.allCases.count
public let fieldsPerSite = numDirections
