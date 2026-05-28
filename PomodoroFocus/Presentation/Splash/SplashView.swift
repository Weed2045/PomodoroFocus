import SwiftUI

struct SplashView: View {
    @StateObject private var viewModel: SplashViewModel
    /// 0 = hidden  1 = logo in  2 = text in  3 = dots in
    @State private var phase = 0

    let onFinished: () -> Void

    init(viewModel: SplashViewModel, onFinished: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            // ── Background gradient ──────────────────────────────────────
            AppTheme.heroGradient
                .ignoresSafeArea()

            // ── Decorative floating circles ──────────────────────────────
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 460, height: 460)
                .offset(x: 145, y: -270)
                .scaleEffect(phase >= 1 ? 1 : 0.4)
                .animation(.spring(response: 1.3, dampingFraction: 0.75), value: phase)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 340, height: 340)
                .offset(x: -165, y: 310)
                .scaleEffect(phase >= 1 ? 1 : 0.3)
                .animation(.spring(response: 1.5, dampingFraction: 0.75), value: phase)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 200, height: 200)
                .offset(x: 90, y: 280)
                .scaleEffect(phase >= 1 ? 1 : 0.2)
                .animation(.spring(response: 1.6, dampingFraction: 0.8), value: phase)

            // ── Main content ─────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Logo stack
                ZStack {
                    // Outer glow ring
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 176, height: 176)
                    // Middle fill
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 140, height: 140)
                    // White icon disc
                    Circle()
                        .fill(Color.white)
                        .frame(width: 104, height: 104)
                        .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 14)
                    // Icon
                    Image(systemName: "timer")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                }
                .scaleEffect(phase >= 1 ? 1 : 0.35)
                .opacity(phase >= 1 ? 1 : 0)
                .animation(.spring(response: 0.62, dampingFraction: 0.70), value: phase)

                Spacer().frame(height: 44)

                // Title + tagline
                VStack(spacing: 10) {
                    Text("Pomodoro Focus")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .tracking(0.4)

                    Text(L10n.Splash.tagline)
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 18)
                .animation(.easeOut(duration: 0.50), value: phase)

                Spacer()

                // Pulsing load dots
                HStack(spacing: 9) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .opacity(phase >= 3 ? 0.70 : 0)
                            .scaleEffect(phase >= 3 ? 1 : 0.4)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.65)
                                    .delay(Double(i) * 0.14),
                                value: phase
                            )
                    }
                }
                .padding(.bottom, 58)
            }
        }
        .task {
            // Stage 1 – logo + background blobs
            phase = 1

            try? await Task.sleep(nanoseconds: 320_000_000)
            // Stage 2 – title text slides up
            phase = 2

            try? await Task.sleep(nanoseconds: 280_000_000)
            // Stage 3 – loading dots appear
            phase = 3

            await viewModel.prepareLaunch()
            onFinished()
        }
    }
}
