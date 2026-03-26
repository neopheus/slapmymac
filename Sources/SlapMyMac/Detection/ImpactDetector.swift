import Foundation

/// Detects physical impacts using 4 parallel detection algorithms.
/// Ported from taigrr/spank's Go detector.
final class ImpactDetector {
    private let highPassFilter = HighPassFilter()
    private var sensitivity: Double
    private var cooldownInterval: TimeInterval
    private var lastImpactTime: TimeInterval = 0

    /// After a detection, suppress all events for this many samples.
    /// At ~200Hz, 15 samples ≈ 75ms of suppression.
    /// This prevents the "aftershock" tail of a slap from re-triggering.
    private var suppressionCounter: Int = 0
    private var suppressionSamples: Int

    // STA/LTA state (3 timescales)
    private var staWindows: [Int] = [5, 10, 20]       // short-term window sizes
    private var ltaWindows: [Int] = [50, 100, 200]     // long-term window sizes
    private var staBuffers: [[Double]] = [[], [], []]
    private var ltaBuffers: [[Double]] = [[], [], []]

    // CUSUM state
    private var cusumPos: Double = 0
    private var cusumNeg: Double = 0
    private var cusumMean: Double = 0
    private var cusumCount: Int = 0
    private let cusumMeanAlpha: Double = 0.001  // Slow-adapting mean

    // Kurtosis state
    private var kurtosisBuffer: [Double] = []
    private var kurtosisSampleCount: Int = 0
    private var kurtosisEvalInterval: Int

    // Peak/MAD state
    private var peakMadBuffer: [Double] = []

    init(sensitivity: Double = Constants.defaultSensitivity,
         cooldownMs: Int = Constants.defaultCooldownMs,
         suppressionSamples: Int = Constants.defaultSuppressionSamples,
         kurtosisEvalInterval: Int = Constants.defaultKurtosisEvalInterval) {
        self.sensitivity = sensitivity
        self.cooldownInterval = TimeInterval(cooldownMs) / 1000.0
        self.suppressionSamples = suppressionSamples
        self.kurtosisEvalInterval = max(1, kurtosisEvalInterval)
    }

    func updateSensitivity(_ value: Double) {
        sensitivity = value
    }

    func updateCooldown(_ ms: Int) {
        cooldownInterval = TimeInterval(ms) / 1000.0
    }

    func updateSuppressionSamples(_ value: Int) {
        suppressionSamples = max(1, value)
    }

    func updateKurtosisEvalInterval(_ value: Int) {
        kurtosisEvalInterval = max(1, value)
    }

    /// Process a single sample. Returns an ImpactEvent if an impact is detected.
    func process(_ sample: AccelerometerSample) -> ImpactEvent? {
        // Step 1: High-pass filter to remove gravity
        let filtered = highPassFilter.filter(sample)
        let magnitude = (filtered.x * filtered.x + filtered.y * filtered.y + filtered.z * filtered.z).squareRoot()
        let squaredMag = magnitude * magnitude

        // Post-impact suppression: skip detection entirely while aftershock fades
        if suppressionCounter > 0 {
            suppressionCounter -= 1
            // Still feed buffers so they adapt, but never fire
            _ = checkSTALTA(squaredMag)
            _ = checkCUSUM(magnitude)
            _ = checkKurtosis(magnitude)
            _ = checkPeakMAD(magnitude)
            return nil
        }

        // Step 2: Run all 4 detectors
        var detectorsFired: Set<String> = []

        if checkSTALTA(squaredMag) {
            detectorsFired.insert("sta_lta")
        }
        if checkCUSUM(magnitude) {
            detectorsFired.insert("cusum")
        }
        if checkKurtosis(magnitude) {
            detectorsFired.insert("kurtosis")
        }
        if checkPeakMAD(magnitude) {
            detectorsFired.insert("peak_mad")
        }

        // Step 3: Classify
        guard !detectorsFired.isEmpty else { return nil }

        let severity: ImpactSeverity
        if detectorsFired.count >= 4 && magnitude > 0.05 {
            severity = .major
        } else if detectorsFired.count >= 3 && magnitude > 0.02 {
            severity = .medium
        } else if detectorsFired.contains("peak_mad") && magnitude > 0.005 {
            severity = .micro
        } else if (detectorsFired.contains("sta_lta") || detectorsFired.contains("cusum")) && magnitude > 0.003 {
            severity = .vibration
        } else {
            return nil  // Below all thresholds
        }

        // Step 4: Cooldown (timestamp-based)
        let now = sample.timestamp
        guard now - lastImpactTime >= cooldownInterval else { return nil }
        lastImpactTime = now

        // Step 5: Engage post-impact suppression to prevent double-triggers
        suppressionCounter = suppressionSamples

        // Step 6: Reset CUSUM accumulators so the spike doesn't linger
        cusumPos = 0
        cusumNeg = 0

        // Clear STA buffers so the energy spike doesn't carry over
        for i in 0..<3 {
            staBuffers[i].removeAll()
        }

        return ImpactEvent(
            severity: severity,
            amplitude: magnitude,
            timestamp: now,
            detectorCount: detectorsFired.count
        )
    }

    func reset() {
        highPassFilter.reset()
        lastImpactTime = 0
        suppressionCounter = 0
        staBuffers = [[], [], []]
        ltaBuffers = [[], [], []]
        cusumPos = 0
        cusumNeg = 0
        cusumMean = 0
        cusumCount = 0
        kurtosisBuffer = []
        kurtosisSampleCount = 0
        peakMadBuffer = []
    }

    // MARK: - STA/LTA (Short-Term Average / Long-Term Average)

    private func checkSTALTA(_ squaredMag: Double) -> Bool {
        for i in 0..<3 {
            staBuffers[i].append(squaredMag)
            ltaBuffers[i].append(squaredMag)

            if staBuffers[i].count > staWindows[i] {
                staBuffers[i].removeFirst()
            }
            if ltaBuffers[i].count > ltaWindows[i] {
                ltaBuffers[i].removeFirst()
            }

            guard ltaBuffers[i].count >= ltaWindows[i] else { continue }

            let sta = staBuffers[i].reduce(0, +) / Double(staBuffers[i].count)
            let lta = ltaBuffers[i].reduce(0, +) / Double(ltaBuffers[i].count)

            guard lta > 1e-10 else { continue }

            let ratio = sta / lta
            if ratio > Constants.staLtaOnThresholds[i] {
                return true
            }
        }
        return false
    }

    // MARK: - CUSUM (Cumulative Sum Control Chart)

    private func checkCUSUM(_ magnitude: Double) -> Bool {
        cusumCount += 1

        // Slowly adapt the mean
        if cusumCount == 1 {
            cusumMean = magnitude
        } else {
            cusumMean = cusumMean * (1 - cusumMeanAlpha) + magnitude * cusumMeanAlpha
        }

        let deviation = magnitude - cusumMean

        cusumPos = max(0, cusumPos + deviation - Constants.cusumK)
        cusumNeg = max(0, cusumNeg - deviation - Constants.cusumK)

        let triggered = cusumPos > Constants.cusumH || cusumNeg > Constants.cusumH

        if triggered {
            cusumPos = 0
            cusumNeg = 0
        }

        return triggered
    }

    // MARK: - Kurtosis

    private func checkKurtosis(_ magnitude: Double) -> Bool {
        kurtosisBuffer.append(magnitude)
        kurtosisSampleCount += 1

        if kurtosisBuffer.count > Constants.kurtosisWindowSize {
            kurtosisBuffer.removeFirst()
        }

        // Compute every kurtosisEvalInterval samples once buffer is full
        guard kurtosisBuffer.count >= Constants.kurtosisWindowSize,
              kurtosisSampleCount % kurtosisEvalInterval == 0 else {
            return false
        }

        let n = Double(kurtosisBuffer.count)
        let mean = kurtosisBuffer.reduce(0, +) / n

        var m2: Double = 0
        var m4: Double = 0
        for val in kurtosisBuffer {
            let diff = val - mean
            let diff2 = diff * diff
            m2 += diff2
            m4 += diff2 * diff2
        }
        m2 /= n
        m4 /= n

        guard m2 > 1e-15 else { return false }

        let kurtosis = m4 / (m2 * m2)
        return kurtosis > Constants.kurtosisThreshold
    }

    // MARK: - Peak/MAD (Median Absolute Deviation)

    private func checkPeakMAD(_ magnitude: Double) -> Bool {
        peakMadBuffer.append(magnitude)

        if peakMadBuffer.count > Constants.peakMadBufferSize {
            peakMadBuffer.removeFirst()
        }

        guard peakMadBuffer.count >= Constants.peakMadBufferSize else { return false }

        let sorted = peakMadBuffer.sorted()
        let median = sorted[sorted.count / 2]

        var absDeviations: [Double] = []
        for val in peakMadBuffer {
            absDeviations.append(abs(val - median))
        }
        absDeviations.sort()
        let mad = absDeviations[absDeviations.count / 2]

        guard mad > 1e-15 else { return false }

        let sigma = Constants.madScaleFactor * mad
        let deviation = abs(magnitude - median)

        return deviation > Constants.peakMadSigmaThreshold * sigma
    }
}
