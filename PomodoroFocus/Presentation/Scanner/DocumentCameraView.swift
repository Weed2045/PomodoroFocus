import SwiftUI
import VisionKit

/// UIViewControllerRepresentable wrapper for VNDocumentCameraViewController.
/// Handles the three delegate callbacks: success, cancel, and error.
struct DocumentCameraView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onDismiss: onDismiss)
    }

    // MARK: – Coordinator

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScan: ([UIImage]) -> Void
        private let onDismiss: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onDismiss: @escaping () -> Void) {
            self.onScan    = onScan
            self.onDismiss = onDismiss
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            AppLogger.scanner.info("📷 VNDocumentCamera didFinish — pageCount=\(scan.pageCount, privacy: .public)")
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            AppLogger.scanner.info("📷 VNDocumentCamera cancelled by user")
            onDismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            AppLogger.scanner.error("❌ VNDocumentCamera failed: \(error.localizedDescription, privacy: .public)")
            // VisionKit already shows an alert for permission denial;
            // we just close the sheet here.
            onDismiss()
        }
    }
}
