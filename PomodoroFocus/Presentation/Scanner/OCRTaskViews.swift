import SwiftUI

struct OCRProcessingView: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                ScannerBeamAnimation()
                    .frame(width: 118, height: 118)

                VStack(spacing: 6) {
                    Text(L10n.OCR.processingTitle)
                        .font(.system(size: 16, weight: .semibold))
                    Text(L10n.OCR.processingStage(for: progress))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.blue)
                    .frame(width: 210)

                Button(L10n.OCR.processingCancel, action: onCancel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.blue)
            }
            .padding(28)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
        }
    }
}

private struct ScannerBeamAnimation: View {
    @State private var beamOffset: CGFloat = -46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.blue.opacity(0.35), lineWidth: 2)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, AppTheme.blue.opacity(0.7), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .offset(y: beamOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                beamOffset = 46
            }
        }
    }
}

struct TaskReviewSheet: View {
    @ObservedObject var viewModel: OCRTaskViewModel
    let documentID: UUID
    @State private var editingItemID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ReviewHeaderView(
                    totalFound: viewModel.extractedItems.count,
                    selectedCount: viewModel.selectedCount
                )
                .padding(16)

                Divider()

                if viewModel.extractedItems.isEmpty {
                    ContentUnavailableView(L10n.OCR.empty, systemImage: "text.viewfinder")
                } else {
                    List {
                        ForEach($viewModel.extractedItems) { $item in
                            ExtractedTaskRow(
                                item: $item,
                                isEditing: editingItemID == item.id,
                                onTapEdit: { editingItemID = item.id },
                                onEndEdit: { editingItemID = nil },
                                onToggle: { viewModel.toggleItem(item.id) },
                                onDelete: { viewModel.deleteItem(item.id) }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onMove { source, destination in
                            viewModel.extractedItems.move(fromOffsets: source, toOffset: destination)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteItem(viewModel.extractedItems[index].id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Divider()

                ReviewActionBar(
                    selectedCount: viewModel.selectedCount,
                    isCreating: viewModel.state == .creating,
                    onConfirm: { viewModel.confirmCreation(documentID: documentID) },
                    onCancel: { viewModel.showReviewSheet = false }
                )
                .padding(16)
            }
            .background(AppTheme.ice)
            .navigationTitle(L10n.OCR.reviewNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.OCR.reviewSelectAll) {
                        viewModel.selectAll()
                    }
                    .font(.system(size: 14))
                }
            }
        }
    }
}

private struct ExtractedTaskRow: View {
    @Binding var item: ExtractedTaskItem
    let isEditing: Bool
    let onTapEdit: () -> Void
    let onEndEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var editTitle = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isSelected ? AppTheme.blue : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    TextField(L10n.OCR.reviewRowPlaceholder, text: $editTitle)
                        .font(.system(size: 15, weight: .medium))
                        .focused($titleFocused)
                        .onSubmit {
                            item.title = editTitle
                            onEndEdit()
                        }
                        .onAppear {
                            editTitle = item.title
                            titleFocused = true
                        }
                } else {
                    Text(item.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(item.isSelected ? AppTheme.navy : .secondary)
                        .strikethrough(!item.isSelected)
                        .onTapGesture(count: 2, perform: onTapEdit)
                }

                HStack(spacing: 8) {
                    DeadlineControl(date: $item.deadline)
                    DurationControl(minutes: $item.estimatedMinutes)
                    Spacer(minLength: 0)
                    ConfidenceBadge(confidence: item.confidence)
                }

                if isEditing, !item.rawLine.isEmpty {
                    Text(L10n.OCR.reviewRowFrom(item.rawLine))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.75))
            }
            .buttonStyle(.plain)
            .padding(.top, 3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.isSelected ? Color.white : Color(.systemGray6))
                .shadow(color: item.isSelected ? .black.opacity(0.06) : .clear, radius: 5, y: 2)
        )
        .opacity(item.isSelected ? 1 : 0.65)
    }
}

private struct ConfidenceBadge: View {
    let confidence: ExtractedTaskItem.Confidence

    var body: some View {
        Text(confidence.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color(hex: confidence.colorHex))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(hex: confidence.colorHex).opacity(0.12), in: Capsule())
    }
}

private struct DeadlineControl: View {
    @Binding var date: Date?
    @State private var showPicker = false
    @State private var draftDate = Date()

    var body: some View {
        Button {
            draftDate = date ?? Date()
            showPicker = true
        } label: {
            Label(label, systemImage: date == nil ? "calendar.badge.plus" : "calendar")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(date == nil ? Color.secondary : Color.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((date == nil ? Color(.systemGray6) : Color.orange.opacity(0.1)), in: Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("Deadline", selection: $draftDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle(L10n.OCR.deadlineNavTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.OCR.deadlineRemove) {
                                date = nil
                                showPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.OCR.deadlineDone) {
                                date = draftDate
                                showPicker = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var label: String {
        date?.formatted(.dateTime.day().month(.abbreviated)) ?? "Deadline"
    }
}

private struct DurationControl: View {
    @Binding var minutes: Int
    private let options = [15, 25, 50, 90]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { value in
                Button(L10n.OCR.durationFormat(value)) {
                    minutes = value
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("\(minutes)m")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(.systemGray6), in: Capsule())
        }
    }
}

private struct ReviewHeaderView: View {
    let totalFound: Int
    let selectedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 26))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 44, height: 44)
                .background(AppTheme.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.OCR.reviewFound(totalFound))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                Text(L10n.OCR.reviewSelected(selectedCount))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private struct ReviewActionBar: View {
    let selectedCount: Int
    let isCreating: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(L10n.OCR.actionCancel, action: onCancel)
                .buttonStyle(SecondaryButtonStyle())

            Button(action: onConfirm) {
                if isCreating {
                    HStack {
                        ProgressView().tint(.white)
                        Text(L10n.OCR.actionCreating)
                    }
                } else {
                    Label(L10n.OCR.actionCreate(selectedCount), systemImage: "plus.circle.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: selectedCount > 0 ? AppTheme.blue : .gray))
            .disabled(selectedCount == 0 || isCreating)
        }
    }
}

struct DocumentCellOCRButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(L10n.OCR.cellExtract, systemImage: "text.viewfinder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppTheme.blue.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
