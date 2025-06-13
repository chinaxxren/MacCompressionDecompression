import Foundation

enum CompressionError: LocalizedError {
    case createArchiveFailed
    case processingFailed(String)
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .createArchiveFailed:
            return "无法创建压缩文件"
        case .processingFailed(let reason):
            return "处理失败：\(reason)"
        case .invalidOperation(let reason):
            return reason
        }
    }
} 