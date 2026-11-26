import AppKit
import Vision

enum QRDecoder {
    static func decode(cgImage: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }

    static func decode(pixelBuffer: CVPixelBuffer) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }

    static func decode(image: NSImage) -> [String] {
        // Try every representation; prefer the largest bitmap.
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return [] }
        return decode(cgImage: cg)
    }

    static func decode(fileURL: URL) -> [String] {
        guard let image = NSImage(contentsOf: fileURL) else { return [] }
        return decode(image: image)
    }
}

/// Uses the system `screencapture -i` selection UI, then decodes any QR code in the selection.
enum ScreenQRScanner {
    enum Result { case cancelled, found([String]), notFound, failed(String) }

    static func scan(completion: @escaping (Result) -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekey-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path]
        process.terminationHandler = { _ in
            defer { try? FileManager.default.removeItem(at: url) }
            let result: Result
            if !FileManager.default.fileExists(atPath: url.path) {
                result = .cancelled
            } else {
                let codes = QRDecoder.decode(fileURL: url)
                result = codes.isEmpty ? .notFound : .found(codes)
            }
            DispatchQueue.main.async { completion(result) }
        }
        do {
            try process.run()
        } catch {
            completion(.failed(error.localizedDescription))
        }
    }
}
