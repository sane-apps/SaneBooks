import Foundation

func formatZEC(_ value: Decimal) -> String {
    let n = NSDecimalNumber(decimal: value)
    let f = NumberFormatter()
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 8
    f.numberStyle = .decimal
    return f.string(from: n) ?? "\(value)"
}

func formatFiat(_ value: Decimal) -> String {
    let n = NSDecimalNumber(decimal: value)
    let f = NumberFormatter()
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.numberStyle = .decimal
    return f.string(from: n) ?? "\(value)"
}
