import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, title: String, body: String, color: Color)] = [
        (
            "hand.raised.fill",
            "Welcome to SlapMyMac",
            "Your MacBook can feel when you slap it. We use the built-in accelerometer to detect impacts and play sounds. Go ahead — give it a try.",
            .orange
        ),
        (
            "speaker.wave.3.fill",
            "Pick Your Sounds",
            "Choose from 3 voice packs: Pain mode (\"Ow!\"), Sexy mode (escalating 60 levels), or Halo mode (game death sounds). You can also load your own MP3 folder.",
            .purple
        ),
        (
            "slider.horizontal.3",
            "Tune Your Sensitivity",
            "Adjust how hard you need to slap. From \"earthquake detector\" (feels everything) to \"needs a running start\" (only big hits). Find your sweet spot in the menu bar.",
            Color(red: 0.2, green: 0.83, blue: 0.6)
        ),
        (
            "menubar.arrow.up.rectangle",
            "Lives in Your Menu Bar",
            "SlapMyMac runs quietly in your menu bar. Click the hand icon to see your slap count, change voice packs, and adjust settings. Enable \"Launch at login\" to always be ready.",
            .blue
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 20) {
                        Spacer()

                        // Icon
                        ZStack {
                            Circle()
                                .fill(step.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: step.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(step.color)
                        }

                        // Title
                        Text(step.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        // Body
                        Text(step.body)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 340)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.automatic)

            // Progress dots and button
            VStack(spacing: 16) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.orange : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }

                // Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            appState.settings.hasCompletedOnboarding = true
                            dismiss()
                        }
                    }
                } label: {
                    Text(currentStep < steps.count - 1 ? "Next" : "Start Slapping")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)

                // Skip button
                if currentStep < steps.count - 1 {
                    Button("Skip") {
                        appState.settings.hasCompletedOnboarding = true
                        dismiss()
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 440, height: 460)
    }
}
