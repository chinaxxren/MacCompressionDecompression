import SwiftUI
import UniformTypeIdentifiers

@main
struct ZipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowAccessor())
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.setContentSize(NSSize(width: 600, height: 400))
                window.maxSize = NSSize(width: 600, height: 400)
                window.minSize = NSSize(width: 600, height: 400)
                window.styleMask.remove(.resizable)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var viewModel = CompressionViewModel()
    @State private var showFileImporter = false
    @State private var showDestinationPicker = false
    @State private var currentOperation: FileOperation = .compress
    @State private var sourceURL: URL?
    @State private var showSettings = false
    @State private var dragOver = false
    @State private var showQRCode = false
    
    enum FileOperation {
        case compress
        case decompress
    }
    
    var body: some View {
        ZStack {
            Color(NSColor.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showQRCode = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                                .foregroundColor(.black)
                            Text("联系反馈").foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    
                    Button(action: {
                        if let url = URL(string: "http://drawui.cn/user.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock")
                                .foregroundColor(.black)
                            Text("隐私政策").foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }
                                
                Image("logo")
                    .resizable()
                    .frame(width: 128, height: 128)
                
                Text("方便快捷 值得信赖")
                    .foregroundColor(.black)
                    .font(.system(size: 14))
                    .padding(.top, 8)
                    .padding(.bottom, 25)
                
                HStack(spacing: 20) {
                    CompressButton(
                        title: "压缩文件",
                        isNew: true,
                        action: viewModel.showCompressDialog,
                        supportedText: "zip、7z、tar、xz"
                    )
                    CompressButton(
                        title: "解压文件",
                        isNew: false,
                        action: viewModel.showDecompressDialog,
                        supportedText: "zip、7z、rar、tar、xz"
                    )
                }

                Text("点击上方按钮/拖拽文件至按钮区域")
                    .foregroundColor(.black)
                    .font(.caption)
                    .padding(.top, 15)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.isProcessing {
                ProcessingView(
                    progress: viewModel.progress,
                    type: viewModel.operationType
                )
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            Task {
                guard let provider = providers.first else { return false }
                guard let data = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data else { return false }
                guard let urlString = String(data: data, encoding: .utf8) else { return false }
                guard let url = URL(string: urlString) else { return false }
                
                sourceURL = url
                if url.pathExtension.lowercased() == "zip" {
                    currentOperation = .decompress
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    let response = panel.runModal()
                    if response == .OK, let destinationURL = panel.url {
                        await viewModel.decompressFile(url, to: destinationURL)
                    }
                } else {
                    currentOperation = .compress
                    viewModel.handleDroppedFiles([url])
                }
                return true
            }
            return false
        }
        .background(dragOver ? Color.blue.opacity(0.2) : Color.clear)
        .animation(.default, value: dragOver)
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeView()
        }
    }
}

struct CompressButton: View {
    let title: String
    let isNew: Bool
    let action: () -> Void
    let supportedText: String?
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: isNew ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.yellow)
                
                Text(title)
                    .foregroundColor(.black)
                    .padding(.top, 8)
                if let supportedText = supportedText {
                    Text(supportedText)
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                        .padding(.top, 4)
                }
            }
            .frame(width: 140, height: 140)
            .background(Color(NSColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1.0)))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            isNew ? Badge() : nil,
            alignment: .topTrailing
        )
    }
}

struct Badge: View {
    var body: some View {
        Text("NEW")
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .cornerRadius(8)
            .offset(x: 5, y: -5)
    }
}

struct ProcessingView: View {
    let progress: Double
    let type: OperationType
    
    private var clampedProgress: Double {
        max(0, min(progress, 1.0))
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(type == .compress ? "压缩" : "解压")
                    .font(.title2)
                    .foregroundColor(.black)
                
                Text("正在\(type == .compress ? "压缩" : "解压")，请稍等...")
                    .foregroundColor(.black)
                
                ProgressView(value: clampedProgress, total: 1.0)
                    .frame(width: 200)
                    .tint(.black)
                
                Text("\(Int(clampedProgress * 100))%")
                    .foregroundColor(.black)
                
                Button("完成后通知我") {
                    // Notification handling
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1.0)))
                .cornerRadius(6)
                .buttonStyle(.plain)
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
}

struct QRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if let image = NSImage(named: "qrcore") {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                } else {
                    Text("无法加载二维码图片")
                        .foregroundColor(.red)
                }
                
                Text("zixin_2019@126.com")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("关闭")
                        .foregroundColor(.black)
                        .frame(minWidth: 60,minHeight: 30)
                }
                .buttonStyle(.plain)
                .background(Color(NSColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1.0)))
                .cornerRadius(6)
                .keyboardShortcut(.escape)
            }
            .padding(30)
        }
        .frame(width: 300, height: 320)
    }
}

extension UTType {
    static var archive: UTType {
        UTType(exportedAs: "public.item")
    }
    
    static var item: UTType {
        UTType(exportedAs: "public.item")
    }
}

