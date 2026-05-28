import SwiftUI

struct FocusDimmingModifier: ViewModifier {
    @ObservedObject var viewModel: AmbientSoundViewModel

    func body(content: Content) -> some View {
        ZStack {
            content
            if viewModel.dimmingOpacity > 0 {
                FocusDimmingOverlay(opacity: viewModel.dimmingOpacity)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.dimmingOpacity)
    }
}

struct FocusDimmingOverlay: View {
    let opacity: Double

    var body: some View {
        ZStack {
            Color.black
                .opacity(opacity * 0.45)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                FocusBadge()
                    .padding(.top, 56)
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
}

struct FocusBadge: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse ? 1.25 : 1)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            Text(L10n.Sound.focusModeActiveBadge)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.6), in: Capsule())
        .onAppear { pulse = true }
    }
}
