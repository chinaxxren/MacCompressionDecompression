import Foundation
import UniformTypeIdentifiers

enum ArchiveType: String, CaseIterable {
    case zip
    case sevenZip
    case rar
    case tar
    case xz
    
    var fileExtension: String {
        switch self {
        case .zip: return "zip"
        case .sevenZip: return "7z"
        case .rar: return "rar"
        case .tar: return "tar"
        case .xz: return "xz"
        }
    }
    
    var contentType: UTType {
        switch self {
        case .zip:
            return .zip
        case .sevenZip:
            return UTType("org.7-zip.7-zip-archive") ?? .zip
        case .rar:
            return UTType("com.rarlab.rar-archive") ?? .zip
        case .tar:
            return UTType("public.tar-archive") ?? .zip
        case .xz:
            return UTType("org.tukaani.xz") ?? .zip
        }
    }
    
    static func detect(from url: URL) -> ArchiveType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip": return .zip
        case "7z": return .sevenZip
        case "rar": return .rar
        case "tar": return .tar
        case "xz": return .xz
        default: return .zip
        }
    }
} 