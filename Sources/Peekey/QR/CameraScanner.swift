import AVFoundation
import AppKit
import SwiftUI

/// Captures frames from the default camera and reports the first QR payload found.
final class CameraScanner: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum State: Equatable { case starting, running, denied, noCamera, failed(String) }

    @Published var state: State = .starting
    let session = AVCaptureSession()
    var onFound: (([String]) -> Void)?

    private let queue = DispatchQueue(label: "app.peekey.camera")
    private var lastScan = Date.distantPast
    private var done = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { ok ? self.configure() : (self.state = .denied) }
            }
        default: state = .denied
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            state = .noCamera
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .high
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        queue.async {
            self.session.startRunning()
            DispatchQueue.main.async { self.state = .running }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !done, Date().timeIntervalSince(lastScan) > 0.25,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastScan = Date()
        let codes = QRDecoder.decode(pixelBuffer: buffer).filter { $0.lowercased().hasPrefix("otpauth") }
        guard !codes.isEmpty else { return }
        done = true
        DispatchQueue.main.async { self.onFound?(codes) }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
