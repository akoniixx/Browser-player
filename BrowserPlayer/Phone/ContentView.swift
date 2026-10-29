import SwiftUI

struct ContentView: View {
    @ObservedObject private var engine = BrowserEngine.shared
    @ObservedObject private var safety = DrivingSafetyMonitor.shared
    @State private var address = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            if engine.isCarConnected {
                carRemote
            } else {
                WebViewContainer(engine: engine)
            }
            playbackBar
        }
        .onChange(of: engine.currentURL) { url in
            if !addressFocused { address = url?.absoluteString ?? "" }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 12) {
            Button { engine.goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!engine.canGoBack)
            Button { engine.goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!engine.canGoForward)
            TextField("ค้นหา YouTube หรือพิมพ์ URL", text: $address)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.webSearch)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit {
                    engine.open(address)
                    addressFocused = false
                }
            Button {
                engine.isLoading ? engine.stopLoading() : engine.reload()
            } label: {
                Image(systemName: engine.isLoading ? "xmark" : "arrow.clockwise")
            }
            Button { engine.goHome() } label: { Image(systemName: "house") }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var carRemote: some View {
        VStack(spacing: 10) {
            Label("กำลังแสดงบนจอรถ", systemImage: "car.fill")
                .font(.headline)
            Text(engine.pageTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            if safety.isMoving {
                Text("รถกำลังเคลื่อนที่ — ซ่อนวิดีโอบนจอรถ (เสียงยังเล่นได้)")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
            TrackpadView(
                onMove: { engine.moveCursor(dx: $0, dy: $1) },
                onScroll: { engine.scroll(dx: $0, dy: $1) },
                onTap: { engine.clickAtCursor() }
            )
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            .overlay(
                Text("ลาก 1 นิ้ว = เลื่อนเมาส์ • แตะ = คลิก • ลาก 2 นิ้ว = เลื่อนหน้า")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .allowsHitTesting(false),
                alignment: .bottom
            )
        }
        .padding()
    }

    private var playbackBar: some View {
        VStack(spacing: 6) {
            if !safety.hasPermission && safety.authorization != .notDetermined {
                Text("ไม่ได้อนุญาตตำแหน่ง: แอพตรวจไม่ได้ว่ารถกำลังวิ่ง โปรดดูวิดีโอเฉพาะตอนจอดรถ")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            HStack {
                barButton("gobackward.10") { engine.seek(by: -10) }
                barButton("playpause.fill") { engine.togglePlayPause() }
                barButton("goforward.10") { engine.seek(by: 10) }
                barButton(engine.isVideoFill ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    engine.toggleVideoFill()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func barButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}
