import SwiftUI
import UIKit

struct CircularProgressView: UIViewRepresentable {
    let configuration: TimerProgressConfiguration
    let onCompleted: () -> Void

    func makeUIView(context: Context) -> CircularProgressRingView {
        let view = CircularProgressRingView()
        view.onCompleted = onCompleted
        return view
    }

    func updateUIView(_ uiView: CircularProgressRingView, context: Context) {
        uiView.onCompleted = onCompleted
        uiView.apply(configuration)
    }
}

final class CircularProgressRingView: UIView, CAAnimationDelegate {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private var currentConfiguration: TimerProgressConfiguration?
    private var hasPulsedForSession: UUID?

    var onCompleted: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        setupLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Use the actual screen scale now that we have a window reference.
        // Avoids the deprecated UIScreen.main.scale API.
        let scale = window?.screen.scale ?? UITraitCollection.current.displayScale
        trackLayer.contentsScale   = scale
        progressLayer.contentsScale = scale
    }

    func apply(_ configuration: TimerProgressConfiguration) {
        if currentConfiguration == configuration,
           configuration.status == .running,
           progressLayer.animation(forKey: AnimationKey.progress) != nil {
            return
        }

        updateColors(for: configuration)

        let previous = currentConfiguration
        currentConfiguration = configuration

        switch configuration.status {
        case .idle:
            setProgress(0)
            hasPulsedForSession = nil
        case .paused:
            let progress = currentPresentationProgress(fallback: configuration.progress())
            setProgress(progress)
        case .completed:
            setProgress(1)
            pulseIfNeeded(for: configuration.sessionID)
        case .running:
            runAnimation(configuration, previous: previous)
        }
    }

    func animationDidStop(_ animation: CAAnimation, finished flag: Bool) {
        guard flag, currentConfiguration?.status == .running else { return }
        setProgress(1)
        pulseIfNeeded(for: currentConfiguration?.sessionID)
        onCompleted?()
    }

    private func setupLayers() {
        [trackLayer, progressLayer].forEach { layer in
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 18
            layer.lineCap = .round
            // contentsScale set in didMoveToWindow once we have a real screen reference.
        }

        trackLayer.strokeEnd = 1
        progressLayer.strokeEnd = 0

        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }

    private func updatePath() {
        let lineWidth = progressLayer.lineWidth
        let side = min(bounds.width, bounds.height)
        let radius = max((side - lineWidth) / 2, 0)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        CATransaction.commit()
    }

    private func updateColors(for configuration: TimerProgressConfiguration) {
        let tint = UIColor(configuration.tint.tint)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.strokeColor = tint.withAlphaComponent(0.16).cgColor
        progressLayer.strokeColor = tint.cgColor
        CATransaction.commit()
    }

    private func runAnimation(_ configuration: TimerProgressConfiguration, previous: TimerProgressConfiguration?) {
        let now = Date()
        let calculatedProgress = configuration.progress(at: now)
        let remaining = configuration.remaining(at: now)
        let isSameSession = previous?.sessionID == configuration.sessionID
        let presentationProgress = currentPresentationProgress(fallback: calculatedProgress)
        let fromProgress = isSameSession && abs(presentationProgress - calculatedProgress) < 0.01
            ? presentationProgress
            : calculatedProgress

        guard remaining > 0, fromProgress < 1 else {
            setProgress(1)
            onCompleted?()
            return
        }

        progressLayer.removeAnimation(forKey: AnimationKey.progress)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.strokeEnd = 1
        CATransaction.commit()

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = fromProgress
        animation.toValue = 1
        animation.duration = remaining
        animation.beginTime = CACurrentMediaTime()
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = true
        animation.delegate = self

        progressLayer.add(animation, forKey: AnimationKey.progress)
    }

    private func setProgress(_ progress: CGFloat) {
        progressLayer.removeAnimation(forKey: AnimationKey.progress)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.strokeEnd = min(max(progress, 0), 1)
        CATransaction.commit()
    }

    private func currentPresentationProgress(fallback: CGFloat) -> CGFloat {
        if let presentation = progressLayer.presentation() {
            return presentation.strokeEnd
        }

        let modelValue = progressLayer.strokeEnd
        return modelValue.isFinite ? modelValue : fallback
    }

    private func pulseIfNeeded(for sessionID: UUID?) {
        guard let sessionID, hasPulsedForSession != sessionID else { return }
        hasPulsedForSession = sessionID

        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.025
        pulse.mass = 0.7
        pulse.stiffness = 180
        pulse.damping = 14
        pulse.initialVelocity = 0
        pulse.duration = pulse.settlingDuration
        pulse.autoreverses = true
        layer.add(pulse, forKey: AnimationKey.completionPulse)
    }
}

private enum AnimationKey {
    static let progress = "progress.strokeEnd"
    static let completionPulse = "progress.completionPulse"
}
