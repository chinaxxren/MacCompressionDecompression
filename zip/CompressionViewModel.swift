import SwiftUI
import UniformTypeIdentifiers
import Combine
import SSZipArchive
import PLzmaSDK
import UnrarKit

@MainActor
final class CompressionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var operationType: OperationType = .compress
    @Published var showSettings = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var settings = CompressionSettings()
    @Published var selectedArchiveType: ArchiveType = .zip
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var pendingCompressionFiles: [URL]?
    private var destinationURL: URL?
    private var archiveService: ArchiveService?
    
    // 编码支持
    private let supportedEncodings: [String.Encoding] = [
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))), // GBK
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),         // Big5
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue))),     // Shift-JIS
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue))),   // GB2312
        .utf8
    ]
    
    // 添加 PLzma 相关的错误类型
    enum PLzmaError: LocalizedError {
        case streamError
        case encoderError
        case decoderError
        case passwordRequired
        case invalidPassword
        case compressionFailed(String)
        case decompressionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .streamError:
                return "创建数据流失败"
            case .encoderError:
                return "创建编码器失败"
            case .decoderError:
                return "创建解码器失败"
            case .passwordRequired:
                return "需要密码"
            case .invalidPassword:
                return "密码无效"
            case .compressionFailed(let reason):
                return "压缩失败: \(reason)"
            case .decompressionFailed(let reason):
                return "解压失败: \(reason)"
            }
        }
    }
    
    // MARK: - Compression Methods
    func showCompressDialog() {
        operationType = .compress
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK {
                self.pendingCompressionFiles = panel.urls
                self.showSettings = true
            }
        }
    }
    
    func confirmCompression() {
        guard let urls = pendingCompressionFiles else { return }
        
        let defaultFileName = urls.count == 1 ? 
            urls[0].deletingPathExtension().lastPathComponent : "archive"
        
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = true

        let contentType = selectedArchiveType.contentType
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = defaultFileName
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, var destinationURL = panel.url {
                // 强制加上正确的后缀
                let ext = self.selectedArchiveType.fileExtension
                if destinationURL.pathExtension.lowercased() != ext {
                    destinationURL.deletePathExtension()
                    destinationURL.appendPathExtension(ext)
                }
                self.destinationURL = destinationURL
                self.showSettings = false
                Task {
                    await self.compressFiles(urls, to: destinationURL)
                }
            } else {
                self.cancelOperation()
            }
        }
    }
    
    private func compressFiles(_ urls: [URL], to destinationURL: URL) async {
        isProcessing = true
        progress = 0
        
        do {
            archiveService = ArchiveService(settings: settings)
            archiveService?.delegate = self
            try await archiveService?.compressFiles(urls, to: destinationURL, type: selectedArchiveType)
        } catch let error {
            handleError(error)
        }
    }
    
    // MARK: - Decompression Methods
    func showDecompressDialog() {
        operationType = .decompress
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        let supportedTypes = ArchiveType.allCases.map { $0.contentType }
        panel.allowedContentTypes = supportedTypes
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.selectDecompressionDestination(for: url)
            }
        }
    }
    
    private func selectDecompressionDestination(for sourceURL: URL) {
        let panel = NSOpenPanel()
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "选择解压目标文件夹"
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let destinationURL = panel.url {
                Task {
                    await self.decompressFile(sourceURL, to: destinationURL)
                }
            }
        }
    }
    
    func decompressFile(_ url: URL, to destinationURL: URL) async {
        isProcessing = true
        progress = 0
        
        do {
            archiveService = ArchiveService(settings: settings)
            archiveService?.delegate = self
            try await archiveService?.decompressFile(url, to: destinationURL)
        } catch let error {
            handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    func handleDroppedFiles(_ urls: [URL]) {
        pendingCompressionFiles = urls
        showSettings = true
    }
    
    func cancelOperation() {
        showSettings = false
        pendingCompressionFiles = nil
        destinationURL = nil
    }
    
    private func handleError(_ error: Error) {
        isProcessing = false
        progress = 0
        errorMessage = error.localizedDescription
        showError = true
    }
    
    private func handleCompletion(destinationURL: URL) {
        isProcessing = false
        progress = 1.0
        
        if settings.openAfterCompletion {
            NSWorkspace.shared.selectFile(
                destinationURL.path,
                inFileViewerRootedAtPath: ""
            )
        }
        
        if settings.deleteSourceAfterCompletion, let sourceURLs = pendingCompressionFiles {
            for url in sourceURLs {
                try? fileManager.removeItem(at: url)
            }
        }
        
        self.pendingCompressionFiles = nil
        self.destinationURL = nil
    }
    
    // MARK: - DecoderDelegate Methods
    func decoder(decoder: PLzmaSDK.Decoder, path: String, progress: Double) {
        Task { @MainActor in
            // 确保进度值在有效范围内
            self.progress = max(0, min(progress, 1.0))
            
            // 如果进度接近完成但未到100%，等待一小段时间后设置为完成
            if progress >= 0.99 && progress < 1.0 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 等待0.5秒
                if self.progress < 1.0 {
                    self.progress = 1.0
                }
            }
        }
    }
    
    // MARK: - EncoderDelegate Methods
    func encoder(encoder: PLzmaSDK.Encoder, path: String, progress: Double) {
        Task { @MainActor in
            self.progress = max(0, min(progress, 1.0))
        }
    }
    
    private func getArchiveInfo(_ url: URL) async throws -> ArchiveInfo {
        do {
            let inPath = try PLzmaSDK.Path(url.path)
            let inStream = try InStream(path: inPath)
            let decoder = try Decoder(stream: inStream, fileType: .sevenZ)
            
            let opened = try decoder.open()
            if !opened {
                throw PLzmaError.decoderError
            }
            
            let itemsArray = try decoder.items()
            let itemsCount = itemsArray.count
            var items: [String] = []
            var totalSize: UInt64 = 0
            var isEncrypted = false
            
            for i in 0..<itemsCount {
                if let item = try? decoder.item(at: Size(i)) {
                    items.append(try item.path().description)
                    totalSize += item.size
                    if item.encrypted {
                        isEncrypted = true
                    }
                }
            }
            
            return ArchiveInfo(
                itemsCount: Int(itemsCount),
                uncompressedSize: totalSize,
                isEncrypted: isEncrypted,
                items: items
            )
        } catch {
            throw PLzmaError.decoderError
        }
    }
    
    private func testArchive(_ url: URL) async throws -> Bool {
        do {
            let inPath = try PLzmaSDK.Path(url.path)
            let inStream = try InStream(path: inPath)
            let decoder = try Decoder(stream: inStream, fileType: .sevenZ)
            
            let opened = try decoder.open()
            if !opened {
                throw PLzmaError.decoderError
            }
            
            let items = try decoder.items()
            if items.count > 0 {
                let firstItem = try decoder.item(at: 0)
                if firstItem.encrypted && settings.usePassword && !settings.password.isEmpty {
                    try decoder.setPassword(settings.password)
                }
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                do {
                    let tested = try decoder.test()
                    continuation.resume(returning: tested)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            return true
        } catch {
            throw PLzmaError.decoderError
        }
    }
    
    private func listArchiveContents(_ url: URL) async throws -> [String] {
        do {
            let inPath = try PLzmaSDK.Path(url.path)
            let inStream = try InStream(path: inPath)
            let decoder = try Decoder(stream: inStream, fileType: .sevenZ)
            
            let opened = try decoder.open()
            if !opened {
                throw PLzmaError.decoderError
            }
            
            let items = try decoder.items()
            if items.count > 0 {
                let firstItem = try decoder.item(at: 0)
                if firstItem.encrypted && settings.usePassword && !settings.password.isEmpty {
                    try decoder.setPassword(settings.password)
                }
            }
            
            let itemsArray = try decoder.items()
            let itemsCount = itemsArray.count
            
            var itemStrings: [String] = []
            
            for i in 0..<itemsCount {
                if let item = try? decoder.item(at: Size(i)) {
                    itemStrings.append(try item.path().description)
                }
            }
            
            return itemStrings
        } catch {
            throw PLzmaError.decoderError
        }
    }
    
    // 解压 ZIP 文件
    private func unzipFile(_ url: URL, to destinationURL: URL) async throws {
        let password = settings.usePassword ? settings.password : nil
        
        var success = false
        if let password = password {
            success = SSZipArchive.unzipFile(
                atPath: url.path,
                toDestination: destinationURL.path,
                preserveAttributes: true,
                overwrite: true,
                nestedZipLevel: 1,
                password: password,
                error: nil,
                delegate: nil,
                progressHandler: { [weak self] (entry, zipInfo, entryNumber, total) in
                    let progress = Double(entryNumber) / Double(total)
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // 确保进度值在有效范围内
                        self.progress = max(0, min(progress, 1.0))
                        
                        // 如果是最后一个文件，确保进度能到达100%
                        if entryNumber == total {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 等待0.1秒
                            self.progress = 1.0
                        }
                    }
                },
                completionHandler: { [weak self] (path, succeeded, error) in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if succeeded {
                            self.progress = 1.0
                            if self.settings.openAfterCompletion {
                                NSWorkspace.shared.selectFile(
                                    destinationURL.path,
                                    inFileViewerRootedAtPath: ""
                                )
                            }
                        }
                    }
                }
            )
        } else {
            success = SSZipArchive.unzipFile(
                atPath: url.path,
                toDestination: destinationURL.path,
                preserveAttributes: true,
                overwrite: true,
                nestedZipLevel: 1,
                password: nil,
                error: nil,
                delegate: nil,
                progressHandler: { [weak self] (entry, zipInfo, entryNumber, total) in
                    let progress = Double(entryNumber) / Double(total)
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // 确保进度值在有效范围内
                        self.progress = max(0, min(progress, 1.0))
                        
                        // 如果是最后一个文件，确保进度能到达100%
                        if entryNumber == total {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 等待0.1秒
                            self.progress = 1.0
                        }
                    }
                },
                completionHandler: { [weak self] (path, succeeded, error) in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if succeeded {
                            self.progress = 1.0
                            if self.settings.openAfterCompletion {
                                NSWorkspace.shared.selectFile(
                                    destinationURL.path,
                                    inFileViewerRootedAtPath: ""
                                )
                            }
                        }
                    }
                }
            )
        }
        
        if !success {
            throw CompressionError.processingFailed("解压 ZIP 文件失败")
        }
        
        // 确保在方法结束时更新UI状态
        await MainActor.run {
            self.isProcessing = false
            self.progress = 1.0
        }
    }
    
    // 解压 RAR 文件
    private func unrarFile(_ url: URL, to destinationURL: URL) async throws {
        guard let archive = try? URKArchive(path: url.path) else {
            throw CompressionError.processingFailed("无法打开 RAR 文件")
        }
        
        if try archive.isPasswordProtected() {
            if !settings.usePassword || settings.password.isEmpty {
                throw PLzmaError.passwordRequired
            }
            archive.password = settings.password
        }
        
        try archive.extractFiles(to: destinationURL.path, overwrite: true) { (file, progress) in
            Task { @MainActor in
                self.progress = progress
            }
        }
    }
}

// 压缩文件信息结构
struct ArchiveInfo {
    let itemsCount: Int
    let uncompressedSize: UInt64
    let isEncrypted: Bool
    let items: [String]
}

// MARK: - ArchiveServiceDelegate
extension CompressionViewModel: ArchiveServiceDelegate {
    nonisolated func archiveService(_ service: ArchiveService, didUpdateProgress progress: Double) {
        Task { @MainActor in
            self.progress = progress
        }
    }
    
    nonisolated func archiveService(_ service: ArchiveService, didCompleteWithSuccess success: Bool) {
        Task { @MainActor in
            if success, let destinationURL = self.destinationURL {
                self.handleCompletion(destinationURL: destinationURL)
            }

            self.isProcessing = false
        }
    }
    
    nonisolated func archiveService(_ service: ArchiveService, didFailWithError error: Error) {
        Task { @MainActor in
            self.handleError(error)
        }
    }
}




