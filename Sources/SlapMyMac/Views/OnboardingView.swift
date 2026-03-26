import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    private var steps: [(icon: String, title: String, body: String, color: Color)] {
        [
            (
                "hand.raised.fill",
                L10n.tr("onboarding.welcome.title"),
                L10n.tr("onboarding.welcome.body"),
                .orange
            ),
            (
                "speaker.wave.3.fill",
                L10n.tr("onboarding.sounds.title"),
                L10n.tr("onboarding.sounds.body"),
                .purple
            ),
            (
                "slider.horizontal.3",
                L10n.tr("onboarding.sensitivity.title"),
                L10n.tr("onboarding.sensitivity.body"),
                Color(red: 0.2, green: 0.83, blue: 0.6)
            ),
            (
                "menubar.arrow.up.rectangle",
                L10n.tr("onboarding.menubar.title"),
                L10n.tr("onboarding.menubar.body"),
                .blue
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 20) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(step.color.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: step.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(step.color)
                        }

                        Text(step.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

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

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.orange : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }

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
                    Text(currentStep < steps.count - 1 ? L10n.tr("onboarding.next") : L10n.tr("onboarding.start"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)

                if currentStep < steps.count - 1 {
                    Button(L10n.tr("onboarding.skip")) {
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
