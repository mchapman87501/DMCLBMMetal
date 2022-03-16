import Foundation

struct StopWatch {
    let t0 = DispatchTime.now()

    func finish(_ msg: String) {
        let tf = DispatchTime.now()
        let dt = Double(tf.uptimeNanoseconds - t0.uptimeNanoseconds) / 1.0e9
        print(String(format: "\(msg): %.4f seconds", dt))
    }

    func time(_ msg: String, _ block: () throws -> Void) {
        defer { finish(msg) }

        do {
            try block()
        } catch {
            print("Failed timing \(msg): \(error)")
        }
    }
}
