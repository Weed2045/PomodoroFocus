import SwiftUI

struct EditScanView: View {

    @StateObject private var viewModel: EditScanViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: EditScanViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    imagePreview
                    controlsPanel
                }
            }
            .navigationTitle(L10n.EditScan.navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.EditScan.buttonCancel) { dismiss() }
                        .foregroundStyle(AppTheme.sky)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.EditScan.buttonApply) {
                        viewModel.save()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(AppTheme.sky)
                }
            }
        }
    }

    // MARK: – Image Preview

    private var imagePreview: some View {
        ZStack {
            Color.black

            if let img = viewModel.previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .animation(.easeInOut(duration: 0.12), value: viewModel.previewImage)
            } else {
                ProgressView().tint(.white)
            }

            if viewModel.isProcessing {
                Color.black.opacity(0.25)
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    // MARK: – Controls Panel

    private var controlsPanel: some View {
        ScrollView {
            VStack(spacing: 22) {
                filterRow
                Divider()
                brightnessRow
                contrastRow
                Divider()
                rotateRow
                Divider()
                resetButton
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 22
            )
        )
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: -4)
    }

    // MARK: – Filter Row

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlLabel(L10n.EditScan.controlFilter, icon: "wand.and.sparkles")

            HStack(spacing: 10) {
                ForEach(ScanFilter.allCases) { f in
                    FilterChip(
                        filter: f,
                        isSelected: viewModel.page.filter == f
                    ) {
                        viewModel.setFilter(f)
                    }
                }
            }
        }
    }

    // MARK: – Brightness

    private var brightnessRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                controlLabel(L10n.EditScan.controlBrightness, icon: "sun.max")
                Spacer()
                Text(String(format: "%+.2f", viewModel.page.brightness))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.page.brightness) },
                    set: { viewModel.setBrightness(Float($0)) }
                ),
                in: -1.0...1.0
            )
            .tint(AppTheme.blue)
        }
    }

    // MARK: – Contrast

    private var contrastRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                controlLabel(L10n.EditScan.controlContrast, icon: "circle.lefthalf.filled")
                Spacer()
                Text(String(format: "%.2f", viewModel.page.contrast))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.page.contrast) },
                    set: { viewModel.setContrast(Float($0)) }
                ),
                in: 0.5...2.0
            )
            .tint(AppTheme.blue)
        }
    }

    // MARK: – Rotate

    private var rotateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlLabel(L10n.EditScan.controlRotate, icon: "rotate.right")

            HStack(spacing: 12) {
                Button { viewModel.rotateLeft() } label: {
                    Label(L10n.EditScan.controlRotateLeft, systemImage: "rotate.left")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(SecondaryButtonStyle())

                Button { viewModel.rotateRight() } label: {
                    Label(L10n.EditScan.controlRotateRight, systemImage: "rotate.right")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: – Reset

    private var resetButton: some View {
        Button { viewModel.resetAll() } label: {
            Label(L10n.EditScan.buttonReset, systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    // MARK: – Helpers

    private func controlLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.navy)
    }
}

// MARK: – FilterChip

private struct FilterChip: View {
    let filter: ScanFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: filter.systemIcon)
                    .font(.system(size: 18))
                Text(filter.rawValue)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : AppTheme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(AppTheme.heroGradient) : AnyShapeStyle(AppTheme.ice))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.clear : AppTheme.blue.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
