import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderSection()
                .environmentObject(appState)

            Divider().overlay(Theme.border)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // Slap counter hero
                    SlapCounterCard()
                        .environmentObject(appState)

                    // Lid angle (if available)
                    if appState.lidAngle.isAvailable {
                        LidAngleCard()
                            .environmentObject(appState)
                    }

                    // Voice pack picker
                    VoicePackCard()
                        .environmentObject(appState)

                    // Sensitivity control
                    SensitivityCard()
                        .environmentObject(appState)

                    // Debug info (when listening)
                    if appState.isListening {
                        DebugCard()
                            .environmentObject(appState)
                    }
                }
                .padding(12)
            }

            Divider().overlay(Theme.border)

            // Footer actions
            FooterSection()
                .environmentObject(appState)
        }
        .frame(width: Theme.popoverWidth)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header

private struct HeaderSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(appState.isListening ? Theme.green.opacity(0.2) : Theme.red.opacity(0.2))
                    .frame(width: 32, height: 32)
                Circle()
                    .fill(appState.isListening ? Theme.green : Theme.red)
                    .frame(width: 10, height: 10)
                if appState.isListening {
                    Circle()
                        .fill(Theme.green)
                        .frame(width: 10, height: 10)
                        .scaleEffect(1.8)
                        .opacity(0)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                            value: appState.isListening
                        )
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("SlapMyMac")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(appState.isListening ? "Listening for slaps..." : "Paused")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            // Pause/Resume button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    appState.toggleListening()
                }
            } label: {
                Image(systemName: appState.isListening ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.borderLight, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Slap Counter Hero

private struct SlapCounterCard: View {
    @EnvironmentObject var appState: AppState
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            // Big slap counter
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(appState.slapCount)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                    .scaleEffect(isAnimating ? 1.08 : 1.0)

                Text("slaps")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            // Lifetime counter
            Text("Lifetime: \(appState.settings.lifetimeSlaps)")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            // Last impact info
            if let impact = appState.lastImpact {
                HStack(spacing: 6) {
                    ImpactBadge(severity: impact.severity)
                    Text(String(format: "%.3fg", impact.amplitude))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Text("(\(impact.detectorCount) detectors)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .cardStyle()
        .onChange(of: appState.slapCount) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isAnimating = false
                }
            }
        }
    }
}

private struct ImpactBadge: View {
    let severity: ImpactSeverity

    var color: Color {
        switch severity {
        case .major: return Theme.red
        case .medium: return Theme.accent
        case .micro: return Theme.purple
        case .vibration: return Theme.textTertiary
        }
    }

    var body: some View {
        Text(severity.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Lid Angle Card

private struct LidAngleCard: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 16))
                .foregroundStyle(Theme.purple)
                .frame(width: 32, height: 32)
                .background(Theme.purpleSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("Lid Angle")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(Int(appState.lidAngle.angle))°")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if appState.lidAngle.velocity > 1 {
                    Text(String(format: "%.0f°/s", appState.lidAngle.velocity))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                if let event = appState.lastLidEvent {
                    Text(lidEventLabel(event))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(lidEventColor(event))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(lidEventColor(event).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .cardStyle()
    }

    private func lidEventLabel(_ event: LidEvent) -> String {
        switch event {
        case .opened: return "OPENED"
        case .closed: return "CLOSED"
        case .slammed: return "SLAMMED"
        case .creaking: return "CREAK"
        }
    }

    private func lidEventColor(_ event: LidEvent) -> Color {
        switch event {
        case .opened: return Theme.green
        case .closed: return Theme.purple
        case .slammed: return Theme.red
        case .creaking: return Theme.textTertiary
        }
    }
}

// MARK: - Voice Pack Picker

private struct VoicePackCard: View {
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Pack")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        Text(appState.settings.soundMode.displayName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Spacer()

                    if let pack = appState.currentPack {
                        Text("\(pack.count) clips")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(10)
            }
            .buttonStyle(.plain)

            // Expanded: mode list
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(SoundMode.allCases) { mode in
                        VoicePackRow(mode: mode, isSelected: appState.settings.soundMode == mode)
                            .environmentObject(appState)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
    }
}

private struct VoicePackRow: View {
    @EnvironmentObject var appState: AppState
    let mode: SoundMode
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                appState.settings.soundMode = mode
                appState.loadSoundPack()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(mode.description)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                // Test sound button
                Button {
                    appState.settings.soundMode = mode
                    appState.loadSoundPack()
                    appState.playTestSound()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.accentSoft : (isHovered ? Theme.surfaceHover : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Sensitivity Card

private struct SensitivityCard: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sensitivity")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(appState.settings.sensitivityLabel)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            Slider(value: $appState.settings.sensitivity, in: 0.005...0.50, step: 0.005)
                .tint(Theme.accent)

            HStack {
                Text("Cooldown: \(String(format: "%.1fs", Double(appState.settings.cooldownMs) / 1000.0))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Toggle("Volume scaling", isOn: $appState.settings.volumeScaling)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
        }
        .padding(10)
        .cardStyle()
    }
}

// MARK: - Debug Card

private struct DebugCard: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ACCELEROMETER")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            Text(appState.lastSampleDebug)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.green)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .cardStyle()
    }
}

// MARK: - Footer

private struct FooterSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Error banner
            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.red)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
            } else {
                Spacer()
            }

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
