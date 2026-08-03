import Foundation

public enum MemoPayload: Codable, Sendable, Equatable {
    case empty
    case text(String)
    case opaque(Data)
    case future(UInt8, Data)

    public var utf8Text: String? {
        if case let .text(value) = self {
            return value
        }
        return nil
    }

    public var displayText: String? {
        switch self {
        case .empty: nil
        case let .text(text): text
        case .opaque: "(binary memo)"
        case .future: "(future memo encoding)"
        }
    }
}
