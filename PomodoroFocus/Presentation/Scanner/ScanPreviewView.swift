import SwiftUI

struct ScanPreviewView: View {

    @StateObject private var viewModel: ScanPreviewViewModel
    @State private var pageToEdit: ScannedPage? = nil
    @State private var showShareSheet = false
    @State private var showExportError = false
    @State private var showCompressionSheet = false
    @State private var showOCRError = false

    init(viewModel: ScanPreviewViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pageGrid
                extractTasksButton
                exportButton
                compressButton
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .background(AppTheme.ice)
        .navigationTitle(viewModel.document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.extractTasks()
                } label: {
                    Label(L10n.ScanPreview.toolbarExtractTasks, systemImage: "text.viewfinder")
                }
                .disabled(viewModel.document.pages.isEmpty)
            }
        }
        // Edit sheet
        .sheet(item: $pageToEdit) { page in
            EditScanView(viewModel: viewModel.makeEditViewModel(for: page))
        }
        // Original-PDF share sheet
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .onChange(of: viewModel.exportURL) { _, url in
            if url != nil { showShareSheet = true }
        }
        // Reset exportURL when the share sheet closes so that exporting the same
        // document again (same title → same URL path) still fires onChange next time.
        .onChange(of: showShareSheet) { _, isShowing in
            if !isShowing { viewModel.exportURL = nil }
        }
        // Compression sheet
        .sheet(isPresented: $showCompressionSheet) {
            CompressionSheet(
                pageCount: viewModel.document.pageCount,
                onCompress: { level in
                    try await viewModel.compressAndExport(level: level)
                }
            )
        }
        // Error alert — @State binding so the alert can dismiss itself
        .alert(L10n.ScanPreview.exportError, isPresented: $showExportError) {
            Button(L10n.Common.ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            showExportError = msg != nil
        }
        .overlay {
            if case .processing(let progress) = viewModel.ocrViewModel.state {
                OCRProcessingView(progress: progress) {
                    viewModel.ocrViewModel.cancelExtraction()
                }
            }
        }
        .sheet(isPresented: ocrReviewBinding) {
            TaskReviewSheet(viewModel: viewModel.ocrViewModel, documentID: viewModel.document.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(L10n.ScanPreview.ocrError, isPresented: $showOCRError) {
            Button(L10n.Common.ok) {
                viewModel.ocrViewModel.state = .idle
            }
        } message: {
            if case .error(let message) = viewModel.ocrViewModel.state {
                Text(message)
            }
        }
        .onChange(of: viewModel.ocrViewModel.state) { _, state in
            if case .error = state {
                showOCRError = true
            }
        }
    }

    // MARK: – Page Grid

    private var pageGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L10n.ScanPreview.sectionPages(viewModel.document.pageCount))

            if viewModel.document.pages.isEmpty {
                Text(L10n.ScanPreview.pagesEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(viewModel.document.pages) { page in
                        PageThumbnailCell(
                            image: viewModel.renderedImage(for: page),
                            number: page.pageIndex + 1
                        )
                        .onTapGesture { pageToEdit = page }
                        .contextMenu {
                            Button { pageToEdit = page } label: {
                                Label(L10n.ScanPreview.contextEditPage, systemImage: "slider.horizontal.3")
                            }
                            Divider()
                            Button(role: .destructive) {
                                viewModel.deletePage(id: page.id)
                            } label: {
                                Label(L10n.ScanPreview.contextDeletePage, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var ocrReviewBinding: Binding<Bool> {
        Binding(
            get: { viewModel.ocrViewModel.showReviewSheet },
            set: { viewModel.ocrViewModel.showReviewSheet = $0 }
        )
    }

    // MARK: – Export PDF Button (original quality)

    private var exportButton: some View {
        Button {
            Task { await viewModel.exportPDF() }
        } label: {
            if viewModel.isExporting {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text(L10n.ScanPreview.exporting)
                }
            } else {
                Label(L10n.ScanPreview.buttonExportPDF, systemImage: "arrow.up.doc.fill")
            }
        }
        .buttonStyle(PrimaryButtonStyle(tint: AppTheme.blue))
        .disabled(viewModel.isExporting || viewModel.document.pages.isEmpty)
    }

    private var extractTasksButton: some View {
        Button {
            viewModel.extractTasks()
        } label: {
            Label(L10n.ScanPreview.buttonExtractOCR, systemImage: "text.viewfinder")
        }
        .buttonStyle(PrimaryButtonStyle(tint: AppTheme.blue))
        .disabled(viewModel.document.pages.isEmpty)
    }

    // MARK: – Compress & Export Button

    private var compressButton: some View {
        Button {
            showCompressionSheet = true
        } label: {
            Label(L10n.ScanPreview.buttonCompress, systemImage: "arrow.down.doc.fill")
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(viewModel.isExporting || viewModel.document.pages.isEmpty)
    }

    // MARK: – Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(AppTheme.navy.opacity(0.7))
            .padding(.horizontal, 2)
    }
}

// MARK: – PageThumbnailCell

private struct PageThumbnailCell: View {
    let image: UIImage?
    let number: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(AppTheme.ice)
                        .overlay(
                            Image(systemName: "doc.text")
                                .foregroundStyle(AppTheme.blue.opacity(0.3))
                        )
                }
            }
            .frame(height: 110)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Page number badge
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 5))
                .padding(5)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: – CompressionSheet

/// Bottom sheet that lets the user pick a compression level, runs the compression,
/// then presents a share sheet with the compressed file.
private struct CompressionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let pageCount: Int
    /// Called with the chosen level; must return the compressed PDF URL.
    let onCompress: (PDFCompressionLevel) async throws -> URL

    @State private var selectedLevel: PDFCompressionLevel = .medium
    @State private var isCompressing = false
    @State private var compressedURL: URL? = nil
    @State private var showShare = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    heroHeader
                    levelPicker
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            // ── Action buttons ────────────────────────────────────────────
            VStack(spacing: 10) {
                Button { startCompression() } label: {
                    if isCompressing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text(L10n.Compression.progress(pageCount))
                        }
                    } else {
                        Label(L10n.Compression.buttonCompress, systemImage: "arrow.down.doc.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: AppTheme.blue))
                .disabled(isCompressing)

                Button { dismiss() } label: { Text(L10n.Compression.buttonCancel) }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isCompressing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                AppTheme.ice
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -4)
            )
        }
        .background(AppTheme.ice.ignoresSafeArea())
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        // Error alert
        .alert(L10n.Compression.errorTitle, isPresented: Binding(
            get:  { errorMessage != nil },
            set:  { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.Common.ok) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        // Share sheet presented from within this sheet (sheet-over-sheet, iOS 15+)
        .sheet(isPresented: $showShare, onDismiss: { dismiss() }) {
            if let url = compressedURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: – Hero header

    private var heroHeader: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(L10n.Compression.headerTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(L10n.Compression.headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(AppTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: AppTheme.blue.opacity(0.35), radius: 12, x: 0, y: 6)

            Image(systemName: "arrow.down.doc")
                .font(.system(size: 70, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.10))
                .padding(.top, 4)
                .padding(.trailing, 14)
                .allowsHitTesting(false)
        }
    }

    // MARK: – Level picker

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(L10n.Compression.fieldQuality)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
            }

            VStack(spacing: 10) {
                ForEach(PDFCompressionLevel.allCases) { level in
                    CompressionLevelCard(
                        level: level,
                        isSelected: selectedLevel == level
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedLevel = level
                        }
                    }
                }
            }
        }
    }

    // MARK: – Actions

    private func startCompression() {
        isCompressing = true
        Task {
            do {
                let url = try await onCompress(selectedLevel)
                compressedURL = url
                showShare = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isCompressing = false
        }
    }
}

// MARK: – CompressionLevelCard

private struct CompressionLevelCard: View {
    let level: PDFCompressionLevel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(level.accentColor.opacity(isSelected ? 1.0 : 0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: level.systemIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : level.accentColor)
            }
            .animation(.spring(response: 0.25), value: isSelected)

            // Text block
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(level.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.navy)
                    Spacer()
                    Text(level.reductionHint)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(level.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(level.accentColor.opacity(0.12), in: Capsule())
                }
                Text(level.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? AppTheme.blue : Color(.systemGray4))
                .animation(.spring(response: 0.25), value: isSelected)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? AppTheme.blue : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .shadow(
            color: .black.opacity(isSelected ? 0.10 : 0.04),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: isSelected ? 4 : 2
        )
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: – ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
