import Foundation

/// Single-pole high-pass filter for removing gravity from accelerometer data.
/// Uses alpha = 0.95 for a ~2Hz cutoff at 100Hz sample rate.
final class HighPassFilter {
    private let alpha: Double
    private var prevRawX: Double = 0
    private var prevRawY: Double = 0
    private var prevRawZ: Double = 0
    private var prevOutX: Double = 0
    private var prevOutY: Double = 0
    private var prevOutZ: Double = 0
    private var initialized = false

    init(alpha: Double = Constants.highPassAlpha) {
        self.alpha = alpha
    }

    func filter(_ sample: AccelerometerSample) -> (x: Double, y: Double, z: Double) {
        guard initialized else {
            prevRawX = sample.x
            prevRawY = sample.y
            prevRawZ = sample.z
            initialized = true
            return (0, 0, 0)
        }

        let hx = alpha * (prevOutX + sample.x - prevRawX)
        let hy = alpha * (prevOutY + sample.y - prevRawY)
        let hz = alpha * (prevOutZ + sample.z - prevRawZ)

        prevRawX = sample.x
        prevRawY = sample.y
        prevRawZ = sample.z
        prevOutX = hx
        prevOutY = hy
        prevOutZ = hz

        return (hx, hy, hz)
    }

    func reset() {
        prevRawX = 0; prevRawY = 0; prevRawZ = 0
        prevOutX = 0; prevOutY = 0; prevOutZ = 0
        initialized = false
    }
}
