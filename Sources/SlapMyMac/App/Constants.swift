import Foundation

enum Constants {
    /// Accelerometer
    static let spuUsagePage: Int = 0xFF00
    static let spuAccelerometerUsage: Int = 3
    static let rawToGForce: Double = 65536.0
    static let reportSize: Int = 22
    static let xOffset: Int = 6
    static let yOffset: Int = 10
    static let zOffset: Int = 14
    static let decimationFactor: Int = 8  // Keep 1 in 8 samples (~100Hz from ~800Hz)

    /// Detection defaults
    static let defaultSensitivity: Double = 0.05   // Minimum amplitude in g
    static let defaultCooldownMs: Int = 750
    static let highPassAlpha: Double = 0.95

    /// STA/LTA thresholds
    static let staLtaOnThresholds: [Double] = [3.0, 2.5, 2.0]
    static let staLtaOffThresholds: [Double] = [1.5, 1.3, 1.2]

    /// CUSUM parameters
    static let cusumH: Double = 0.01
    static let cusumK: Double = 0.0005

    /// Kurtosis
    static let kurtosisWindowSize: Int = 100
    static let kurtosisThreshold: Double = 6.0

    /// Peak/MAD
    static let peakMadBufferSize: Int = 200
    static let peakMadSigmaThreshold: Double = 2.0
    static let madScaleFactor: Double = 1.4826

    /// Audio
    static let volumeMin: Float = 0.125
    static let volumeMax: Float = 1.0
    static let amplitudeFloor: Double = 0.05
    static let amplitudeCeiling: Double = 0.80

    /// Escalation (sexy mode)
    static let decayHalfLife: TimeInterval = 30.0
    static let escalationScale: Double = 5.0

    /// App
    static let appName = "SlapMyMac"
    static let bundleIdentifier = "com.slapmymac.app"
}
