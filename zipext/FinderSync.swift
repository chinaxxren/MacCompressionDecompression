//
//  findersync.swift
//  zipext
//
//  由Chinaxxren于2025/6/12创建。
//

import Cocoa
import FinderSync
import os.log

private let logger = OSLog(subsystem: "com.yourcompany.zip.zipext", category: "FinderSync")
private let appGroupID = "group.com.yourname.zip.unique" // 重要：必须匹配签名和能力的小组

class FinderSync: FIFinderSync {

    // 使用共享用户默认值
    private var sharedUserDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }

    override init() {
        super.init()
        
        os_log("✅ FinderSync initialized.", log: logger, type: .debug)
        
        // 我们正在观察用户的主目录。
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: NSHomeDirectory())]
        
        os_log("🚀 FinderSync launched from: %{public}@", log: logger, type: .debug, Bundle.main.bundlePath as NSString)
    }
    
    // 标记： -主要查找器同步协议方法
    
    override func beginObservingDirectory(at url: URL) {
        // 用户现在看到容器的内容。
        // 如果他们一次看到它一次以上的视图，我们只会告诉我们一次。
        os_log("beginObservingDirectoryAtURL: %{public}@", log: logger, type: .debug, url.path as NSString)
    }
    
    
    override func endObservingDirectory(at url: URL) {
        // 用户不再看到容器的内容。
        os_log("endObservingDirectoryAtURL: %{public}@", log: logger, type: .debug, url.path as NSString)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        os_log("requestBadgeIdentifierForURL: %{public}@", log: logger, type: .debug, url.path as NSString)
        
        // 出于演示目的，这是根据文件名选择我们的两个徽章之一，或者根本没有徽章。
        let whichBadge = abs(url.path.hash) % 3
        let badgeIdentifier = ["", "One", "Two"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }
    
    // 标记： -菜单和工具栏项目支持
    
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

        // 我们只想将菜单添加到所选项目的上下文菜单中。
        guard menuKind == .contextualMenuForItems else {
            os_log("❌ Guard failed: menuKind is not .contextualMenuForItems. Returning nil.", log: logger, type: .debug)
            // 对于调试，让我们返回一个残疾项目以显示扩展名还活着。
            let item = NSMenuItem(title: "无可用操作", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }
        
        let selectedItems = FIFinderSyncController.default().selectedItemURLs() ?? []
        os_log("   %d items selected.", log: logger, type: .debug, selectedItems.count)
        
        // 如果选择了单个存档文件，请显示解压缩选项。
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
            // 否则，显示压缩选项。
            let compressMenu = NSMenu(title: "压缩")
            
            // 普通格式
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
            
            // 压缩水平子菜单
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
            
            // 密码保护选项
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
    
    // 标记： -动作
    
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
    
    // 标记： -与主应用的通信
    
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

 