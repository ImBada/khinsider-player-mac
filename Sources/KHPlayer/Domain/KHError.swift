import Foundation

internal enum KHError: LocalizedError, Equatable {
    case invalidURL(String)
    case blockedByCloudflare
    case networkStatus(Int)
    case parserMissingElement(String)
    case streamNotFound(trackTitle: String)
    case cacheLimitTooSmall
    case persistence(String)

    internal var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .blockedByCloudflare:
            return "KHInsider blocked the request. Try again later."
        case .networkStatus(let status):
            return "Network request failed with status \(status)."
        case .parserMissingElement(let name):
            return "The page is missing expected content: \(name)."
        case .streamNotFound(let trackTitle):
            return "No playable stream found for \(trackTitle)."
        case .cacheLimitTooSmall:
            return "The selected cache limit is too small for streaming."
        case .persistence(let message):
            return "Local library error: \(message)"
        }
    }
}
