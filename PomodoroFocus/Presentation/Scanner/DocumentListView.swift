import SwiftUI

struct DocumentListView: View {

    @ObservedObject var viewModel: DocumentListViewModel
    @State private var documentForPreview: ScannedDocument? = nil
    @State private var documentToDelete: ScannedDocument? = nil
    @State private var showDeleteAlert = false
    @State private var showError = false
    @State private var showOCRError = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.ice.ignoresSafeArea()
            content
            scanFAB
            if case .processing(let progress) = viewModel.ocrViewModel.state {
                OCRProcessingView(progress: progress) {
                    viewModel.ocrViewModel.cancelExtraction()
                }
                .transition(.opacity)
                .zIndex(3)
            }
            if case .success(let count) = viewModel.ocrViewModel.state {
                successToast(count: count)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .navigationTitle(L10n.Scanner.navTitle)
        .navigationBarTitleDisplayMode(.large)
        // Camera — presented fullscreen so VisionKit owns the screen
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            DocumentCameraView(
                onScan:    { viewModel.handleScannedImages($0) },
                onDismiss: { viewModel.cancelScan() }
            )
            .ignoresSafeArea()
        }
        // Navigate to preview after scan completes
        .navigationDestination(item: $documentForPreview) { doc in
            ScanPreviewView(viewModel: viewModel.makePreviewViewModel(for: doc))
        }
        .onChange(of: viewModel.pendingDocument) { _, new in
            if let new {
                documentForPreview = new
                viewModel.consumePendingDocument()   // reset so repeated scans re-trigger nav
            }
        }
        // Error — use a proper @State binding so the alert can dismiss itself
        .alert(L10n.Scanner.errorTitle, isPresented: $showError) {
            Button(L10n.Common.ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            showError = msg != nil
        }
        .sheet(isPresented: ocrReviewBinding) {
            if let documentID = viewModel.selectedOCRDocumentID {
                TaskReviewSheet(viewModel: viewModel.ocrViewModel, documentID: documentID)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
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
        // Delete confirmation
        .alert(L10n.Scanner.deleteAlertTitle, isPresented: $showDeleteAlert) {
            Button(L10n.Scanner.deleteButtonConfirm, role: .destructive) {
                if let d = documentToDelete { viewModel.delete(d) }
            }
            Button(L10n.Scanner.deleteButtonCancel, role: .cancel) {}
        } message: {
            Text(L10n.Scanner.deleteAlertMessage)
        }
    }

    // MARK: – Content

    @ViewBuilder
    private var content: some View {
        if viewModel.documents.isEmpty {
            emptyState
        } else {
            documentGrid
        }
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.blue.opacity(0.25))

            Text(L10n.Scanner.emptyTitle)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.navy)

            Text(L10n.Scanner.emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    // MARK: – Document grid

    private var documentGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(viewModel.documents) { doc in
                    DocumentCard(
                        document: doc,
                        thumbnail: viewModel.thumbnail(for: doc),
                        onExtract: { viewModel.extractTasks(from: doc) }
                    )
                    .onTapGesture { documentForPreview = doc }
                    .contextMenu {
                        Button(role: .destructive) {
                            documentToDelete = doc
                            showDeleteAlert = true
                        } label: {
                            Label(L10n.Scanner.actionDelete, systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)   // FAB clearance
        }
    }

    // MARK: – FAB

    private var scanFAB: some View {
        Button { viewModel.startScan() } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.viewfinder.fill")
                    .font(.headline)
                Text(L10n.Scanner.buttonNewScan)
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(AppTheme.heroGradient, in: Capsule())
            .shadow(color: AppTheme.blue.opacity(0.40), radius: 14, x: 0, y: 7)
        }
        .padding(.bottom, 28)
    }

    private func successToast(count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(L10n.Scanner.tasksCreated(count))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
    }

    private var ocrReviewBinding: Binding<Bool> {
        Binding(
            get: { viewModel.selectedOCRDocumentID != nil && viewModel.ocrViewModel.showReviewSheet },
            set: { viewModel.ocrViewModel.showReviewSheet = $0 }
        )
    }
}

// MARK: – DocumentCard

private struct DocumentCard: View {
    let document: ScannedDocument
    let thumbnail: UIImage?
    let onExtract: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 130)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(AppTheme.ice)
                        .frame(height: 130)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.blue.opacity(0.25))
                        )
                }

                DocumentCellOCRButton(onTap: onExtract)
                    .padding(8)
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 14
            ))

            // Meta
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.navy)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                    Text(L10n.Scanner.pageCount(document.pageCount))
                        .font(.caption2)
                    Spacer()
                    Text(document.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
    }
}
