import Foundation

struct ArchiveItem {
    let name: String
    let size: UInt64
    let modificationDate: Date
    var children: [ArchiveItem]
    let path: String
    
    init(name: String, size: UInt64, modificationDate: Date, children: [ArchiveItem] = [], path: String) {
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.children = children
        self.path = path
    }
    
    static func createTree(from entries: [(path: String, size: UInt64, date: Date)]) -> [ArchiveItem] {
        var root: [String: ArchiveItem] = [:]
        
        for entry in entries {
            let components = entry.path.components(separatedBy: "/")
            var currentPath = ""
            var currentDict = root
            
            for (index, component) in components.enumerated() {
                if currentPath.isEmpty {
                    currentPath = component
                } else {
                    currentPath = currentPath + "/" + component
                }
                
                if index == components.count - 1 {
                    // 叶子节点
                    let item = ArchiveItem(name: component,
                                        size: entry.size,
                                        modificationDate: entry.date,
                                        path: currentPath)
                    currentDict[currentPath] = item
                } else {
                    // 目录节点
                    if currentDict[currentPath] == nil {
                        let item = ArchiveItem(name: component,
                                            size: 0,
                                            modificationDate: entry.date,
                                            path: currentPath)
                        currentDict[currentPath] = item
                    }
                    
                    if let nextDict = currentDict[currentPath] {
                        currentDict = [currentPath: nextDict]
                    }
                }
            }
        }
        
        // 构建树形结构
        for (path, item) in root {
            let parentPath = (path as NSString).deletingLastPathComponent
            if !parentPath.isEmpty {
                root[parentPath]?.children.append(item)
            }
        }
        
        // 返回根节点
        return root.filter { $0.key.components(separatedBy: "/").count == 1 }.map { $0.value }
    }
} 