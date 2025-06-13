//
//  FinderSync.swift
//  zipext
//
//  Created by chinaxxren on 2025/6/12.
//

import Cocoa
import FinderSync
import os.log

private let logger = OSLog(subsystem: "com.yourcompany.zip.zipext", category: "FinderSync")
private let appGroupID = "group.com.yourname.zip.unique" // IMPORTANT: MUST MATCH a group in Signing & Capabilities

class FinderSync: FIFinderSync {

    // Use shared user defaults
    private var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }

    override init() {
        super.init()
        
        os_log("✅ FinderSync initialized.", log: logger, type: .debug)
        
        // We are observing the user's home directory.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: NSHomeDirectory())]
        
        os_log("🚀 FinderSync launched from: %{public}@", log: logger, type: .debug, Bundle.main.bundlePath as NSString)
    }
    
    // MARK: - Primary Finder Sync protocol methods
    
    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        os_log("beginObservingDirectoryAtURL: %{public}@", log: logger, type: .debug, url.path as NSString)
    }
    
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        os_log("endObservingDirectoryAtURL: %{public}@", log: logger, type: .debug, url.path as NSString)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        os_log("requestBadgeIdentifierForURL: %{public}@", log: logger, type: .debug, url.path as NSString)
        
        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
        let whichBadge = abs(url.path.hash) % 3
        let badgeIdentifier = ["", "One", "Two"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }
    
    // MARK: - Menu and toolbar item support
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        os_log("➡️ menu(for:) called.", log: logger, type: .debug)
        switch menuKind {
        case .contextualMenuForItems:
            os_log("   menuKind is .contextualMenuForItems", log: logger, type: .debug)
        case .contextualMenuForContainer:
            os_log("   menuKind is .contextualMenuForContainer", log: logger, type: .debug)
        case .contextualMenuForSidebar:
            os_log("   menuKind is .contextualMenuForSidebar", log: logger, type: .debug)
        case .toolbarItemMenu:
            os_log("   menuKind is .toolbarItemMenu", log: logger, type: .debug)
        @unknown default:
            os_log("   menuKind is unknown", log: logger, type: .debug)
        }
        
        let menu = NSMenu(title: "")

        // We only want to add a menu to the contextual menu for selected items.
        guard menuKind == .contextualMenuForItems else {
            os_log("❌ Guard failed: menuKind is not .contextualMenuForItems. Returning nil.", log: logger, type: .debug)
            // For debugging, let's return a disabled item to show the extension is alive.
            let item = NSMenuItem(title: "无可用操作", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }
        
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        os_log("   %d items selected.", log: logger, type: .debug, selectedItems.count)
        
        // Show decompression options if a single archive file is selected.
        if selectedItems.count == 1,
           let firstItem = selectedItems.first,
           isArchiveFile(firstItem) {
            
            let extractHereMenuItem = NSMenuItem(title: "解压到当前文件夹",
                                              action: #selector(extractHere(_:)),
                                              keyEquivalent: "")
            extractHereMenuItem.target = self
            menu.addItem(extractHereMenuItem)
            
            let extractToNewFolderMenuItem = NSMenuItem(title: "解压到新文件夹",
                                                      action: #selector(extractToNewFolder(_:)),
                                                      keyEquivalent: "")
            extractToNewFolderMenuItem.target = self
            menu.addItem(extractToNewFolderMenuItem)
            
        } else if !selectedItems.isEmpty {
            // Otherwise, show compression options.
            let compressMenu = NSMenu(title: "压缩")
            
            // Common formats
            let formats: [(title: String, type: String, shortcut: String)] = [
                ("压缩为 ZIP", "zip", "z"),
                ("压缩为 7Z", "7z", "7"),
                ("压缩为 TAR", "tar", "t")
            ]
            
            for format in formats {
                let menuItem = NSMenuItem(title: format.title,
                                        action: #selector(compress(_:)),
                                        keyEquivalent: format.shortcut)
                menuItem.target = self
                menuItem.representedObject = format.type
                compressMenu.addItem(menuItem)
            }
            
            compressMenu.addItem(NSMenuItem.separator())
            
            // Compression level submenu
            let levelMenu = NSMenu(title: "压缩级别")
            let levels = [(title: "低（较快）", level: "low"),
                         (title: "中（默认）", level: "normal"),
                         (title: "高（较慢）", level: "high")]
            
            for level in levels {
                let levelItem = NSMenuItem(title: level.title,
                                         action: #selector(setCompressionLevel(_:)),
                                         keyEquivalent: "")
                levelItem.target = self
                levelItem.representedObject = level.level
                if level.level == sharedUserDefaults?.string(forKey: "CompressionLevel") ?? "normal" {
                    levelItem.state = .on
                }
                levelMenu.addItem(levelItem)
            }
            
            let levelMenuItem = NSMenuItem(title: "压缩级别", action: nil, keyEquivalent: "")
            levelMenuItem.submenu = levelMenu
            compressMenu.addItem(levelMenuItem)
            
            // Password protection option
            let passwordItem = NSMenuItem(title: "添加密码",
                                        action: #selector(togglePasswordProtection(_:)),
                                        keyEquivalent: "p")
            passwordItem.target = self
            passwordItem.state = sharedUserDefaults?.bool(forKey: "UsePassword") ?? false ? .on : .off
            compressMenu.addItem(passwordItem)
            
            let compressMenuItem = NSMenuItem(title: "压缩", action: nil, keyEquivalent: "")
            compressMenuItem.submenu = compressMenu
            menu.addItem(compressMenuItem)
        }
        
        if menu.items.isEmpty {
            os_log("🤔 No menu items were created. Returning nil.", log: logger, type: .debug)
            return nil
        } else {
            os_log("✅ Returning menu with %d items.", log: logger, type: .debug, menu.items.count)
            return menu
        }
    }
    
    private func isArchiveFile(_ url: URL) -> Bool {
        let supportedExtensions = ["zip", "7z", "rar", "tar", "gz", "bz2", "xz"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    // MARK: - Actions
    
    @objc func compress(_ sender: NSMenuItem) {
        guard let type = sender.representedObject as? String else { return }
        communicateWithMainApp(action: "compress", type: type)
    }
    
    @objc func extractHere(_ sender: AnyObject?) {
        communicateWithMainApp(action: "decompress", createNewFolder: false)
    }
    
    @objc func extractToNewFolder(_ sender: AnyObject?) {
        communicateWithMainApp(action: "decompress", createNewFolder: true)
    }
    
    @objc func setCompressionLevel(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? String else { return }
        if let menu = sender.menu {
            menu.items.forEach { $0.state = .off }
        }
        sender.state = .on
        sharedUserDefaults?.set(level, forKey: "CompressionLevel")
    }
    
    @objc func togglePasswordProtection(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        sharedUserDefaults?.set(sender.state == .on, forKey: "UsePassword")
    }
    
    // MARK: - Communication with Main App
    
    private func communicateWithMainApp(action: String, type: String? = nil, createNewFolder: Bool? = nil) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else {
            showError("无法获取所选项目。")
            return
        }
        
        let paths = items.map { $0.path }.joined(separator: ",")
        guard let encodedPaths = paths.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            showError("无法编码文件路径。")
            return
        }
        
        var urlComponents = URLComponents(string: "zipapp://\(action)")
        var queryItems = [URLQueryItem(name: "files", value: encodedPaths)]
        
        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type))
            let level = sharedUserDefaults?.string(forKey: "CompressionLevel") ?? "normal"
            let usePassword = sharedUserDefaults?.bool(forKey: "UsePassword") ?? false
            queryItems.append(URLQueryItem(name: "level", value: level))
            queryItems.append(URLQueryItem(name: "usePassword", value: String(usePassword)))
        }
        
        if let createNewFolder = createNewFolder {
            queryItems.append(URLQueryItem(name: "createNewFolder", value: String(createNewFolder)))
        }
        
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            showError("无法创建用于与主应用通信的URL。")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "访达扩展错误"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }
}

 