import Foundation
import SSZipArchive
import PLzmaSDK
import UnrarKit

protocol ArchiveServiceDelegate: AnyObject {
    func archiveService(_ service: ArchiveService, didUpdateProgress progress: Double)
    func archiveService(_ service: ArchiveService, didCompleteWithSuccess success: Bool)
    func archiveService(_ service: ArchiveService, didFailWithError error: Error)
}

class ArchiveService: NSObject {
    weak var delegate: ArchiveServiceDelegate?
    private let settings: CompressionSettings
    
    init(settings: CompressionSettings) {
        self.settings = settings
        super.init()
    }
    
    // MARK: - Compression Methods
    
    func compressFiles(_ urls: [URL], to destinationURL: URL, type: ArchiveType) async throws {
        print("[ARCHIVE][Compress] 类型: \(type.rawValue) -> \(destinationURL.path)")
        switch type {
        case .zip:
            try await compressZipFiles(urls, to: destinationURL)
        case .sevenZip, .tar, .xz:
            try await compressWithPLzma(urls, to: destinationURL)
        case .rar:
            print("[ARCHIVE][Compress] 不支持 RAR 压缩")
            throw ArchiveError.unsupportedOperation("不支持创建 RAR 格式文件")
        }
    }
    
    private func allFilePaths(from urls: [URL]) -> [String] {
        var allPaths: [String] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                // 是文件夹，递归收集
                if let enumerator = FileManager.default.enumerator(atPath: url.path) {
                    for case let file as String in enumerator {
                        let fullPath = url.appendingPathComponent(file).path
                        allPaths.append(fullPath)
                    }
                }
            } else {
                // 是文件
                allPaths.append(url.path)
            }
        }
        return allPaths
    }
    
    private func compressZipFiles(_ urls: [URL], to destinationURL: URL) async throws {
        let password = settings.usePassword ? settings.password : nil
        print("[ZIP][Compress] 开始压缩到: \(destinationURL.path)")
        print("[ZIP][Compress] 源文件: \(urls.map { $0.path })")
        let filePaths = allFilePaths(from: urls)
        let success = SSZipArchive.createZipFile(atPath: destinationURL.path,
                                                 withFilesAtPaths: filePaths,
                                                 withPassword: password,
            progressHandler: { [weak self] (entryNumber, total) in
                let progress = Double(entryNumber) / Double(total)
                print("[ZIP][Compress] 进度: \(entryNumber)/\(total) -> \(progress)")
                self?.delegate?.archiveService(self!, didUpdateProgress: progress)
        })
        print("[ZIP][Compress] 完成: \(success)")
        if !success {
            print("[ZIP][Compress] 失败")
            throw ArchiveError.compressionFailed
        }
        delegate?.archiveService(self, didCompleteWithSuccess: true)
    }
    
    private func compressWithPLzma(_ urls: [URL], to destinationURL: URL) async throws {
        do {
            print("[PLzma][Compress] 开始压缩到: \(destinationURL.path)")
            for url in urls {
                print("[PLzma][Compress] 源文件: \(url.path)")
            }
            let outStream = try PLzmaSDK.Path(destinationURL.path)
            let archivePathOutStream = try OutStream(path: outStream)
            let encoder = try Encoder(stream: archivePathOutStream, fileType: .sevenZ, method: .LZMA2, delegate: self)
            if settings.usePassword && !settings.password.isEmpty {
                try encoder.setPassword(settings.password)
                try encoder.setShouldEncryptContent(true)
                try encoder.setShouldEncryptHeader(true)
            }
            try encoder.setCompressionLevel(UInt8(settings.compressionLevel.rawValue))
            for url in urls {
                if FileManager.default.fileExists(atPath: url.path) {
                    let path = try PLzmaSDK.Path(url.path)
                    try encoder.add(path: path)
                }
            }
            guard try encoder.open() else {
                print("[PLzma][Compress] 打开编码器失败")
                throw ArchiveError.compressionFailed
            }
            guard try encoder.compress() else {
                print("[PLzma][Compress] 压缩失败")
                throw ArchiveError.compressionFailed
            }
            print("[PLzma][Compress] 压缩完成")
            delegate?.archiveService(self, didCompleteWithSuccess: true)
        } catch {
            print("[PLzma][Compress] 异常: \(error)")
            throw ArchiveError.compressionFailed
        }
    }
    
    // MARK: - Decompression Methods
    
    func decompressFile(_ url: URL, to destinationURL: URL) async throws {
        let type = ArchiveType.detect(from: url)
        print("[ARCHIVE][Decompress] 类型: \(type.rawValue) -> \(destinationURL.path)")
        switch type {
        case .zip:
            try await decompressZipFileWithSSZipArchive(url, to: destinationURL)
        case .sevenZip, .tar, .xz:
            try await decompressWithPLzma(url, to: destinationURL)
        case .rar:
            try await decompressRarFile(url, to: destinationURL)
        }
    }
    
    private func decompressWithPLzma(_ url: URL, to destinationURL: URL) async throws {
        do {
            print("[PLzma][Decompress] 开始解压: \(url.path) -> \(destinationURL.path)")
            let inPath = try PLzmaSDK.Path(url.path)
            let inStream = try InStream(path: inPath)
            let decoder = try Decoder(stream: inStream, fileType: .sevenZ, delegate: self)
            guard try decoder.open() else {
                print("[PLzma][Decompress] 解码器打开失败")
                throw ArchiveError.decompressionFailed
            }
            let items = try decoder.items()
            print("[PLzma][Decompress] 文件数: \(items.count)")
            for i in 0..<items.count {
                if let item = try? decoder.item(at: Size(i)) {
                    let name = try? item.path().description
                    print("[PLzma][Decompress] 文件名: \(name ?? "<未知>") 编码: \(String(describing: name?.data(using: .utf8)))")
                }
            }
            if items.count > 0 {
                let firstItem = try decoder.item(at: 0)
                if firstItem.encrypted {
                    if !settings.usePassword || settings.password.isEmpty {
                        print("[PLzma][Decompress] 需要密码")
                        throw ArchiveError.passwordRequired
                    }
                    try decoder.setPassword(settings.password)
                }
            }
            let outPath = try PLzmaSDK.Path(destinationURL.path)
            print("[PLzma][Decompress] 开始解压到: \(destinationURL.path)")
            guard try decoder.extract(to: outPath, itemsFullPath: true) else {
                print("[PLzma][Decompress] 解压失败")
                throw ArchiveError.decompressionFailed
            }
            print("[PLzma][Decompress] 解压完成")
            delegate?.archiveService(self, didCompleteWithSuccess: true)
        } catch {
            print("[PLzma][Decompress] 解压异常: \(error)")
            throw ArchiveError.decompressionFailed
        }
    }
    
    private func decompressRarFile(_ url: URL, to destinationURL: URL) async throws {
        print("[RAR][Decompress] 开始解压: \(url.path) -> \(destinationURL.path)")
        guard let archive = try? URKArchive(path: url.path) else {
            print("[RAR][Decompress] 无法打开 RAR 文件")
            throw ArchiveError.decompressionFailed
        }
        if try archive.isPasswordProtected() {
            if !settings.usePassword || settings.password.isEmpty {
                print("[RAR][Decompress] 需要密码")
                throw ArchiveError.passwordRequired
            }
            archive.password = settings.password
        }
        let fileCount = try archive.listFilenames().count
        print("[RAR][Decompress] 文件数: \(fileCount)")
        var processedCount = 0
        try archive.extractFiles(to: destinationURL.path, overwrite: true) { [weak self] (file, progress) in
            guard let self = self else { return }
            processedCount += 1
            let fileProgress = Double(processedCount) / Double(fileCount)
            let extractProgress = progress
            let currentProgress = max(fileProgress, extractProgress)
            print("[RAR][Decompress] 进度: \(processedCount)/\(fileCount) -> \(currentProgress)")
            self.delegate?.archiveService(self, didUpdateProgress: currentProgress)
            if processedCount == fileCount {
                print("[RAR][Decompress] 解压完成")
                self.delegate?.archiveService(self, didUpdateProgress: 1.0)
                self.delegate?.archiveService(self, didCompleteWithSuccess: true)
            }
        }
    }
    
    private func decompressZipFileWithSSZipArchive(_ url: URL, to destinationURL: URL) async throws {
        let password = settings.usePassword ? settings.password : nil
        print("[ZIP][Decompress][Fallback] 使用 SSZipArchive 解压: \(url.path) -> \(destinationURL.path)")
        let success = SSZipArchive.unzipFile(
            atPath: url.path,
            toDestination: destinationURL.path,
            overwrite: true,
            password: password,
            progressHandler: { [weak self] (entry, zipInfo, entryNumber, total) in
                let progress = Double(entryNumber) / Double(total)
                print("[ZIP][Decompress][Fallback] 进度: \(entryNumber)/\(total) -> \(progress)")
                self?.delegate?.archiveService(self!, didUpdateProgress: progress)
                if entryNumber == total {
                    self?.delegate?.archiveService(self!, didUpdateProgress: 1.0)
                }
            },
            completionHandler: { [weak self] (path, succeeded, error) in
                print("[ZIP][Decompress][Fallback] succeeded: \(succeeded), error: \(String(describing: error))")
                self?.delegate?.archiveService(self!, didUpdateProgress: 1.0)
                if succeeded {
                    self?.delegate?.archiveService(self!, didCompleteWithSuccess: true)
                }
            }
        )
        print("[ZIP][Decompress][Fallback] 完成: \(success)")
        if !success {
            throw ArchiveError.decompressionFailed
        }
    }
}

// MARK: - PLzmaSDK Delegates

extension ArchiveService: EncoderDelegate, DecoderDelegate {
    func encoder(encoder: PLzmaSDK.Encoder, path: String, progress: Double) {
        delegate?.archiveService(self, didUpdateProgress: progress)
    }
    
    func decoder(decoder: PLzmaSDK.Decoder, path: String, progress: Double) {
        delegate?.archiveService(self, didUpdateProgress: progress)
    }
}

// MARK: - Archive Errors

enum ArchiveError: LocalizedError {
    case compressionFailed
    case decompressionFailed
    case passwordRequired
    case invalidPassword
    case unsupportedOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "压缩失败"
        case .decompressionFailed:
            return "解压失败"
        case .passwordRequired:
            return "需要密码"
        case .invalidPassword:
            return "密码无效"
        case .unsupportedOperation(let reason):
            return reason
        }
    }
} 

