import SwiftUI
import VisionKit

/// Live on-device text scanner (real devices only — not supported in the simulator).
/// Streams recognized text lines up to the Scan screen as the camera reads the card.
struct CameraScanView: UIViewControllerRepresentable {
    var onText: ([String]) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onText: ([String]) -> Void
        init(onText: @escaping ([String]) -> Void) { self.onText = onText }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            emit(allItems)
        }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            emit(allItems)
        }

        private func emit(_ items: [RecognizedItem]) {
            let lines = items.compactMap { item -> String? in
                if case let .text(text) = item { return text.transcript }
                return nil
            }
            onText(lines)
        }
    }
}
