import SwiftUI

struct CameraScanView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var scanner = CameraScanner()

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Color.black
                switch scanner.state {
                case .running, .starting:
                    CameraPreview(session: scanner.session)
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, dash: [24, 12]))
                        .frame(width: 200, height: 200)
                    if scanner.state == .starting { ProgressView().controlSize(.large) }
                case .denied:
                    message("没有摄像头权限", "请在 系统设置 → 隐私与安全性 → 摄像头 中允许 Peekey")
                case .noCamera:
                    message("未找到摄像头", "请连接摄像头，或改用「扫描屏幕二维码」")
                case .failed(let msg):
                    message("摄像头启动失败", msg)
                }
            }
            .frame(width: 400, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Text("将手机上的二维码对准摄像头").foregroundStyle(.secondary)
                Spacer()
                Button("取消") { model.sheet = nil }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .onAppear {
            scanner.onFound = { codes in
                model.sheet = nil
                // Let the camera sheet dismiss before presenting the next one.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.handlePayloads(codes) }
            }
            scanner.start()
        }
        .onDisappear { scanner.stop() }
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "video.slash").font(.largeTitle)
            Text(title).font(.headline)
            Text(detail).font(.caption).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding()
    }
}
