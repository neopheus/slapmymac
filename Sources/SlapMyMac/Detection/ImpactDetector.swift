import Foundation

// MARK: - Circular Buffer with Running Sum (O(1) append, evict, and average)

private struct CircularBuffer {
    private var storage: [Double]
    private var head: Int = 0
    private(set) var count: Int = 0
    let capacity: Int
    private(set) var runningSum: Double = 0

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Double](repeating: 0, count: capacity)
    }

    var average: Double {
        count > 0 ? runningSum / Double(count) : 0
    }

    var isFull: Bool { count >= capacity }

    mutating func append(_ value: Double) {
        if count < capacity {
            storage[head] = value
            runningSum += value
            head = (head + 1) % capacity
            count += 1
        } else {
            // Evict oldest, add new
            let evicted = storage[head]
            storage[head] = value
            runningSum += value - evicted
            head = (head + 1) % capacity
        }
    }

    mutating func clear() {
        head = 0
        count = 0
        runningSum = 0
        // No need to zero storage — count tracks valid data
    }

    /// Access elements (0 = oldest). Only use for infrequent operations like kurtosis.
    func forEach(_ body: (Double) -> Void) {
        let start = count < capacity ? 0 : head
        for i in 0..<count {
            body(storage[(start + i) % capacity])
        }
    }
}

/// Detects physical impacts using 4 parallel detection algorithms.
/// Ported from taigrr/spank's Go detector.
///
/// Performance: all per-sample operations are O(1). Expensive detectors
/// (kurtosis, peak/MAD) only evaluate periodically.
final class ImpactDetector: @unchecked Sendable {
    private let highPassFilter = HighPassFilter()
    private var sensitivity: Double
    private var cooldownInterval: TimeInterval
    private var lastImpactTime: TimeInterval = 0

    /// After a detection, suppress all events for this many samples.
    /// At ~100Hz, 15 samples ~ 150ms of suppression.
    private var suppressionCounter: Int = 0
    private var suppressionSamples: Int

    // STA/LTA state (3 timescales) — circular buffers with running sums
    private let staWindows: [Int] = [5, 10, 20]
    private let ltaWindows: [Int] = [50, 100, 200]
    private var staBuffers: [CircularBuffer]
    private var ltaBuffers: [CircularBuffer]

    // CUSUM state
    private var cusumPos: Double = 0
    private var cusumNeg: Double = 0
    private var cusumMean: Double = 0
    private var cusumCount: Int = 0
    private let cusumMeanAlpha: Double = 0.001

    // Kurtosis state — circular buffer, evaluated periodically
    private var kurtosisBuffer: CircularBuffer
    private var kurtosisSampleCount: Int = 0
    private var kurtosisEvalInterval: Int

    // Peak/MAD state — circular buffer, evaluated periodically
    private var peakMadBuffer: CircularBuffer
    private var peakMadSampleCount: Int = 0
    private let peakMadEvalInterval: Int = 5  // Only evaluate every 5 samples

    // Reusable scratch array for Peak/MAD sorting (avoids allocation per call)
    private var peakMadScratch: [Double]

    init(sensitivity: Double = Constants.defaultSensitivity,
         cooldownMs: Int = Constants.defaultCooldownMs,
         suppressionSamples: Int = Constants.defaultSuppressionSamples,
         kurtosisEvalInterval: Int = Constants.defaultKurtosisEvalInterval) {
        self.sensitivity = sensitivity
        self.cooldownInterval = TimeInterval(cooldownMs) / 1000.0
        self.suppressionSamples = suppressionSamples
        self.kurtosisEvalInterval = max(1, kurtosisEvalInterval)

        // Pre-allocate circular buffers
        self.staBuffers = [
            CircularBuffer(capacity: 5),
            CircularBuffer(capacity: 10),
            CircularBuffer(capacity: 20),
        ]
        self.ltaBuffers = [
            CircularBuffer(capacity: 50),
            CircularBuffer(capacity: 100),
            CircularBuffer(capacity: 200),
        ]
        self.kurtosisBuffer = CircularBuffer(capacity: Constants.kurtosisWindowSize)
        self.peakMadBuffer = CircularBuffer(capacity: Constants.peakMadBufferSize)
        self.peakMadScratch = [Double](repeating: 0, count: Constants.peakMadBufferSize)
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
            feedSTALTA(squaredMag)
            _ = checkCUSUM(magnitude)
            feedKurtosis(magnitude)
            feedPeakMAD(magnitude)
            return nil
        }

        // Step 2: Run all 4 detectors — use Int bitmask instead of Set<String>
        var fired: UInt8 = 0

        if checkSTALTA(squaredMag) { fired |= 1 }    // bit 0: sta_lta
        if checkCUSUM(magnitude) { fired |= 2 }       // bit 1: cusum
        if checkKurtosis(magnitude) { fired |= 4 }    // bit 2: kurtosis
        if checkPeakMAD(magnitude) { fired |= 8 }     // bit 3: peak_mad

        guard fired != 0 else { return nil }

        let detectorCount = Int(fired.nonzeroBitCount)

        // Step 3: Classify
        let severity: ImpactSeverity
        if detectorCount >= 4 && magnitude > 0.05 {
            severity = .major
        } else if detectorCount >= 3 && magnitude > 0.02 {
            severity = .medium
        } else if (fired & 8) != 0 && magnitude > 0.005 {
            severity = .micro   // peak_mad fired
        } else if (fired & 3) != 0 && magnitude > 0.003 {
            severity = .vibration   // sta_lta or cusum fired
        } else {
            return nil
        }

        // Step 4: Cooldown (timestamp-based)
        let now = sample.timestamp
        guard now - lastImpactTime >= cooldownInterval else { return nil }
        lastImpactTime = now

        // Step 5: Engage post-impact suppression
        suppressionCounter = suppressionSamples

        // Step 6: Reset accumulators
        cusumPos = 0
        cusumNeg = 0
        for i in 0..<3 { staBuffers[i].clear() }

        return ImpactEvent(
            severity: severity,
            amplitude: magnitude,
            timestamp: now,
            detectorCount: detectorCount
        )
    }

    func reset() {
        highPassFilter.reset()
        lastImpactTime = 0
        suppressionCounter = 0
        for i in 0..<3 {
            staBuffers[i].clear()
            ltaBuffers[i].clear()
        }
        cusumPos = 0
        cusumNeg = 0
        cusumMean = 0
        cusumCount = 0
        kurtosisBuffer.clear()
        kurtosisSampleCount = 0
        peakMadBuffer.clear()
        peakMadSampleCount = 0
    }

    // MARK: - STA/LTA (Short-Term Average / Long-Term Average)
    // O(1) per sample thanks to running sums in circular buffers.

    /// Feed buffers without checking (used during suppression).
    private func feedSTALTA(_ squaredMag: Double) {
        for i in 0..<3 {
            staBuffers[i].append(squaredMag)
            ltaBuffers[i].append(squaredMag)
        }
    }

    private func checkSTALTA(_ squaredMag: Double) -> Bool {
        for i in 0..<3 {
            staBuffers[i].append(squaredMag)
            ltaBuffers[i].append(squaredMag)

            guard ltaBuffers[i].isFull else { continue }

            let sta = staBuffers[i].average
            let lta = ltaBuffers[i].average

            guard lta > 1e-10 else { continue }

            if sta / lta > Constants.staLtaOnThresholds[i] {
                return true
            }
        }
        return false
    }

    // MARK: - CUSUM (Cumulative Sum Control Chart)

    private func checkCUSUM(_ magnitude: Double) -> Bool {
        cusumCount += 1

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

    // MARK: - Kurtosis (evaluated periodically — O(n) only every N samples)

    /// Feed buffer without evaluating (used during suppression).
    private func feedKurtosis(_ magnitude: Double) {
        kurtosisBuffer.append(magnitude)
        kurtosisSampleCount += 1
    }

    private func checkKurtosis(_ magnitude: Double) -> Bool {
        kurtosisBuffer.append(magnitude)
        kurtosisSampleCount += 1

        guard kurtosisBuffer.isFull,
              kurtosisSampleCount % kurtosisEvalInterval == 0 else {
            return false
        }

        let n = Double(kurtosisBuffer.count)
        let mean = kurtosisBuffer.runningSum / n

        var m2: Double = 0
        var m4: Double = 0
        kurtosisBuffer.forEach { val in
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

    // MARK: - Peak/MAD (evaluated periodically — O(n log n) only every N samples)

    /// Feed buffer without evaluating (used during suppression).
    private func feedPeakMAD(_ magnitude: Double) {
        peakMadBuffer.append(magnitude)
        peakMadSampleCount += 1
    }

    private func checkPeakMAD(_ magnitude: Double) -> Bool {
        peakMadBuffer.append(magnitude)
        peakMadSampleCount += 1

        // Only evaluate periodically — sorting is expensive
        guard peakMadBuffer.isFull,
              peakMadSampleCount % peakMadEvalInterval == 0 else {
            return false
        }

        // Copy into scratch array for sorting (avoids allocation)
        var idx = 0
        peakMadBuffer.forEach { val in
            peakMadScratch[idx] = val
            idx += 1
        }

        peakMadScratch[0..<idx].sort()
        let median = peakMadScratch[idx / 2]

        // Compute MAD in-place using the same scratch array
        for i in 0..<idx {
            peakMadScratch[i] = abs(peakMadScratch[i] - median)
        }
        peakMadScratch[0..<idx].sort()
        let mad = peakMadScratch[idx / 2]

        guard mad > 1e-15 else { return false }

        let sigma = Constants.madScaleFactor * mad
        let deviation = abs(magnitude - median)

        return deviation > Constants.peakMadSigmaThreshold * sigma
    }
}
