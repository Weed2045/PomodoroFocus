import Charts
import SwiftUI
import UIKit

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel

    init(viewModel: AnalyticsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.analyticsData == nil {
                AnalyticsSkeletonView()
            } else if let data = viewModel.analyticsData, !data.sessions.isEmpty {
                analyticsContent(data)
            } else {
                AnalyticsEmptyView()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.Analytics.navTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.exportCSV()
                } label: {
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .accessibilityLabel(L10n.Analytics.exportCSVAccessibility)
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.exportURL {
                AnalyticsShareSheet(items: [url])
            }
        }
        .alert(L10n.Analytics.errorTitle, isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.Common.ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    private func analyticsContent(_ data: AnalyticsData) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                AnalyticsRangePicker(selected: $viewModel.selectedRange)
                    .onChange(of: viewModel.selectedRange) { _, newValue in
                        viewModel.rangeChanged(newValue)
                    }

                SummaryCardsView(summary: data.summary)

                FocusBarChartView(
                    data: Array(data.dailyFocusMinutes.suffix(7)),
                    title: L10n.Analytics.chartFocusMinutesTitle,
                    subtitle: L10n.Analytics.chartFocusMinutesSubtitle
                )

                SessionsLineChartView(
                    data: Array(data.dailySessions.suffix(30)),
                    title: L10n.Analytics.chartSessionsTitle,
                    subtitle: L10n.Analytics.chartSessionsSubtitle
                )

                HeatmapView(matrix: data.heatmapMatrix)

                HealthKitBannerView(
                    status: viewModel.healthKitStatus,
                    onConnect: { viewModel.requestHealthKitAccess() }
                )

                Spacer(minLength: 32)
            }
            .padding(20)
        }
        .refreshable {
            viewModel.loadAnalytics()
        }
    }
}

struct AnalyticsRangePicker: View {
    @Binding var selected: AnalyticsRange

    var body: some View {
        Picker("Range", selection: $selected) {
            ForEach(AnalyticsRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct SummaryCardsView: View {
    let summary: AnalyticsData.Summary

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                MetricCard(icon: "flame.fill", iconColor: .orange, label: L10n.Analytics.metricStreak, value: L10n.Analytics.metricStreakUnit(summary.currentStreak))
                MetricCard(icon: "clock.fill", iconColor: .blue, label: L10n.Analytics.metricTotalTime, value: L10n.Analytics.minutesSummary(summary.totalFocusMinutes))
            }
            HStack(spacing: 10) {
                MetricCard(icon: "chart.bar.fill", iconColor: .green, label: L10n.Analytics.metricDailyAvg, value: L10n.Analytics.metricDailyAvgValue(Int(summary.averageDailyMinutes)))
                MetricCard(icon: "checkmark.seal.fill", iconColor: .purple, label: L10n.Analytics.metricTotalSessions, value: "\(summary.totalSessions)")
            }
            if let bestDay = summary.bestDay {
                BestDayBanner(date: bestDay.date, minutes: bestDay.minutes, hour: summary.mostProductiveHour)
            }
        }
    }
}

struct MetricCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BestDayBanner: View {
    let date: Date
    let minutes: Int
    let hour: Int?

    var body: some View {
        HStack {
            Label(L10n.Analytics.bestDayLabel, systemImage: "star.fill")
                .foregroundStyle(.orange)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.Analytics.minutesSummary(minutes) + (hour.map { " " + L10n.Analytics.bestDayHour($0) } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FocusBarChartView: View {
    let data: [AnalyticsData.DailyValue]
    let title: String
    let subtitle: String

    private var maxValue: Double {
        max((data.map(\.value).max() ?? 60) * 1.2, 10)
    }

    var body: some View {
        ChartCard(title: title, subtitle: subtitle) {
            Chart(data) { item in
                BarMark(
                    x: .value("Ngày", item.date, unit: .day),
                    y: .value("Phút", item.value)
                )
                .foregroundStyle(barColor(for: item.value))
                .cornerRadius(6)
                .annotation(position: .top) {
                    if item.value > 0 {
                        Text("\(Int(item.value))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 11))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))m")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(.systemGray5))
                }
            }
            .frame(height: 200)
        }
    }

    private func barColor(for value: Double) -> Color {
        switch value {
        case 0..<25:
            return Color(red: 0.72, green: 0.87, blue: 0.99)
        case 25..<50:
            return Color(red: 0.28, green: 0.60, blue: 0.95)
        default:
            return Color(red: 0.93, green: 0.31, blue: 0.20)
        }
    }
}

struct SessionsLineChartView: View {
    let data: [AnalyticsData.DailyValue]
    let title: String
    let subtitle: String

    private var smoothedData: [AnalyticsData.DailyValue] {
        guard !data.isEmpty else { return [] }
        return data.enumerated().map { index, item in
            let start = max(0, index - 3)
            let end = min(data.count - 1, index + 3)
            let window = data[start...end]
            let average = window.reduce(0) { $0 + $1.value } / Double(window.count)
            return .init(id: item.date, date: item.date, value: average)
        }
    }

    var body: some View {
        ChartCard(title: title, subtitle: subtitle) {
            Chart {
                ForEach(data) { item in
                    AreaMark(
                        x: .value("Ngày", item.date, unit: .day),
                        y: .value("Phiên", item.value)
                    )
                    .foregroundStyle(.linearGradient(colors: [.orange.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                }

                ForEach(data) { item in
                    LineMark(
                        x: .value("Ngày", item.date, unit: .day),
                        y: .value("Phiên", item.value)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }

                ForEach(smoothedData) { item in
                    LineMark(
                        x: .value("Ngày", item.date, unit: .day),
                        y: .value("TB", item.value)
                    )
                    .foregroundStyle(.secondary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(x: .value("Today", Date(), unit: .day))
                    .foregroundStyle(.orange.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(.systemGray5))
                }
            }
            .frame(height: 200)
        }
    }
}

struct HeatmapView: View {
    let matrix: AnalyticsData.HeatmapMatrix
    private let hours = Array(0..<24)
    private var weekdays: [String] { (0..<7).map { L10n.Analytics.weekday($0) } }
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3

    private var maxValue: Int {
        max(matrix.flatMap { $0 }.max() ?? 0, 1)
    }

    var body: some View {
        ChartCard(title: L10n.Analytics.heatmapTitle, subtitle: L10n.Analytics.heatmapSubtitle) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: cellSpacing) {
                    HStack(spacing: cellSpacing) {
                        Text("").frame(width: 24)
                        ForEach(hours, id: \.self) { hour in
                            Text(hour % 6 == 0 ? "\(hour)h" : "")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(width: cellSize)
                        }
                    }

                    ForEach(0..<7, id: \.self) { day in
                        HStack(spacing: cellSpacing) {
                            Text(weekdays[day])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)

                            ForEach(0..<24, id: \.self) { hour in
                                let value = matrix[safe: day]?[safe: hour] ?? 0
                                HeatmapCell(value: value, maxValue: maxValue, tooltip: "\(weekdays[day]) \(hour)h: \(value)m")
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
                .padding(4)
            }

            HeatmapLegendView(maxValue: maxValue)
        }
    }
}

struct HeatmapCell: View {
    let value: Int
    let maxValue: Int
    let tooltip: String
    @State private var showTooltip = false

    private var intensity: Double {
        guard maxValue > 0 else { return 0 }
        return Double(value) / Double(maxValue)
    }

    private var cellColor: Color {
        if value == 0 { return Color(.systemGray6) }
        return Color(
            hue: max(0.05, 0.55 - intensity * 0.5),
            saturation: 0.7 + intensity * 0.3,
            brightness: 0.95 - intensity * 0.2
        )
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .overlay(alignment: .center) {
                if showTooltip {
                    Text(tooltip)
                        .font(.system(size: 9))
                        .padding(4)
                        .background(Color(.systemBackground).opacity(0.96), in: RoundedRectangle(cornerRadius: 4))
                        .shadow(radius: 2)
                        .offset(y: -20)
                        .zIndex(1)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showTooltip.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showTooltip = false
                }
            }
            .accessibilityLabel(tooltip)
    }
}

struct HeatmapLegendView: View {
    let maxValue: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(L10n.Analytics.heatmapLegendLow)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(intensity == 0 ? Color(.systemGray6) : Color(
                        hue: max(0.05, 0.55 - intensity * 0.5),
                        saturation: 0.7 + intensity * 0.3,
                        brightness: 0.95 - intensity * 0.2
                    ))
                    .frame(width: 12, height: 12)
            }
            Text(L10n.Analytics.heatmapLegendHigh(maxValue))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

struct HealthKitBannerView: View {
    let status: AnalyticsViewModel.HealthKitStatus
    let onConnect: () -> Void

    var body: some View {
        switch status {
        case .unknown:
            HealthKitConnectCard(onConnect: onConnect)
        case .authorized:
            HealthKitConnectedBadge()
        case .denied:
            HealthKitDeniedCard()
        case .unavailable:
            EmptyView()
        }
    }
}

struct HealthKitConnectCard: View {
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Analytics.healthKitConnectTitle)
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.Analytics.healthKitConnectSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.Analytics.healthKitConnectButton, action: onConnect)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.pink, in: Capsule())
        }
        .padding(14)
        .background(.pink.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.pink.opacity(0.2), lineWidth: 0.5))
    }
}

struct HealthKitConnectedBadge: View {
    var body: some View {
        Label(L10n.Analytics.healthKitConnected, systemImage: "heart.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.pink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.pink.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct HealthKitDeniedCard: View {
    var body: some View {
        HStack {
            Label(L10n.Analytics.healthKitDeniedLabel, systemImage: "heart.slash.fill")
                .foregroundStyle(.secondary)
            Spacer()
            Link(L10n.Analytics.healthKitDeniedSettings, destination: URL(string: UIApplication.openSettingsURLString)!)
        }
        .font(.subheadline)
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AnalyticsSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: [.init(), .init()], spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(shimmer ? Color(.systemGray4) : Color(.systemGray5))
                        .frame(height: 70)
                }
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmer ? Color(.systemGray4) : Color(.systemGray5))
                .frame(height: 240)
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmer ? Color(.systemGray4) : Color(.systemGray5))
                .frame(height: 160)
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

struct AnalyticsEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.orange)
            Text(L10n.Analytics.emptyTitle)
                .font(.title3.weight(.semibold))
            Text(L10n.Analytics.emptySubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChartHeaderView(title: title, subtitle: subtitle)
            content
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ChartHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AnalyticsShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
