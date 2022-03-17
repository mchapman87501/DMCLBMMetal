import Foundation

public enum SiteType: UInt8 {
    case fluid = 0
    case obstacle = 1
    case boundary = 2
    // TODO: Support directional inflow and outflow boundaries
}

public typealias SiteTypeData = [SiteType]
