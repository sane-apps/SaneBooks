import Foundation

/// ZIP 302 memo decoder.
public enum ZIP302MemoDecoder {
    public static func decode(_ data: Data) -> MemoPayload {
        guard !data.isEmpty else { return .empty }
        let first = data[data.startIndex]
        switch first {
        case 0xF6:
            return .empty
        case 0xFF:
            return .opaque(Data(data.dropFirst()))
        case 0xF7 ... 0xFE:
            return .future(first, Data(data.dropFirst()))
        default:
            var end = data.endIndex
            while end > data.startIndex, data[data.index(before: end)] == 0 {
                end = data.index(before: end)
            }
            let trimmed = data[..<end]
            if let text = String(data: trimmed, encoding: .utf8) {
                return .text(text)
            }
            return .opaque(Data(trimmed))
        }
    }
}

public typealias ZIP302Memo = ZIP302MemoDecoder
