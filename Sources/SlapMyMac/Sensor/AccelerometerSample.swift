import Foundation

/// A single accelerometer reading in g-force units.
struct AccelerometerSample: Sendable {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: TimeInterval

    var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }
}
