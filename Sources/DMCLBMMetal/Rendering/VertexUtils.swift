import Foundation

struct VertexUtils {
    static func hullToTriangleStrip<T>(values: [T]) -> [T] {
        // https://www.gamedev.net/forums/topic/199741-convex-polygon-to-triangle-strip/2264099
        var result = [T]()
        var iLeft = 0
        var iRight = values.count - 1
        var addLeft = true
        for _ in 0..<values.count {
            if addLeft {
                result.append(values[iLeft])
                iLeft += 1
            } else {
                result.append(values[iRight])
                iRight -= 1
            }
            addLeft.toggle()
        }
        return result
    }
}
