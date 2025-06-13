import Cocoa
import Foundation
import SSZipArchive
import PLzmaSDK
import UnrarKit

// MARK: - Main Application Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    private let archiveService: ArchiveService
    
    override init() {
        // 创建压缩设置
        let settings = CompressionSettings()
        self.archiveService = ArchiveService(settings: settings)
        super.init()
        self.archiveService.delegate = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 注册 URL Scheme
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let filePath = queryItems.first(where: { $0.name == "file" })?.value else {
            showError("Invalid URL")
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        Task {
            switch components.path {
            case "/compress":
                let destinationURL = fileURL.appendingPathExtension("zip")
                do {
                    try await archiveService.compressFiles([fileURL], to: destinationURL, type: .zip)
                    await MainActor.run {
                        showSuccess("File compressed successfully")
                    }
                } catch {
                    await MainActor.run {
                        showError("Failed to compress file: \(error.localizedDescription)")
                    }
                }
                
            case "/decompress":
                let destinationURL = fileURL.deletingPathExtension()
                do {
                    try await archiveService.decompressFile(fileURL, to: destinationURL)
                    await MainActor.run {
                        showSuccess("File extracted successfully")
                    }
                } catch {
                    await MainActor.run {
                        showError("Failed to extract file: \(error.localizedDescription)")
                    }
                }
                
            default:
                await MainActor.run {
                    showError("Invalid operation")
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Helper Methods
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private func showSuccess(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

// MARK: - ArchiveServiceDelegate
extension AppDelegate: ArchiveServiceDelegate {
    func archiveService(_ service: ArchiveService, didUpdateProgress progress: Double) {
        // 更新进度条
        NotificationCenter.default.post(name: .archiveProgressUpdated,
                                      object: nil,
                                      userInfo: ["progress": progress])
    }
    
    func archiveService(_ service: ArchiveService, didCompleteWithSuccess success: Bool) {
        if success {
            NotificationCenter.default.post(name: .archiveOperationCompleted,
                                          object: nil,
                                          userInfo: ["success": true])
        } else {
            showError("操作未能完成")
        }
    }
    
    func archiveService(_ service: ArchiveService, didFailWithError error: Error) {
        showError(error.localizedDescription)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let archiveProgressUpdated = Notification.Name("archiveProgressUpdated")
    static let archiveOperationCompleted = Notification.Name("archiveOperationCompleted")
} 