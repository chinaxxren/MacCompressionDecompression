import Foundation

enum CompressionLevel: Int, CaseIterable {
    case none = 0
    case fastest = 1
    case fast = 3
    case normal = 5
    case maximum = 7
    case ultra = 9
    
    var description: String {
        switch self {
        case .none: return "不压缩"
        case .fastest: return "最快"
        case .fast: return "快速"
        case .normal: return "标准"
        case .maximum: return "最大"
        case .ultra: return "极限"
        }
    }
    
    static func from(_ string: String?) -> CompressionLevel {
        guard let str = string else { return .normal }
        switch str {
        case "low": return .fastest
        case "high": return .ultra
        default: return .normal
        }
    }
}

struct CompressionSettings {
    var usePassword: Bool = false
    var password: String = ""
    var compressionLevel: CompressionLevel = .normal
    var openAfterCompletion: Bool = true
    var deleteSourceAfterCompletion: Bool = false
} 
