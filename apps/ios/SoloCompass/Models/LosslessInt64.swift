import Foundation

/// Provider IDs cross JavaScript as decimal strings; legacy numeric JSON remains readable.
@propertyWrapper
struct LosslessInt64: Decodable, Sendable {
    let wrappedValue: Int64

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let number = try? value.decode(Int64.self) {
            wrappedValue = number
        } else {
            let text = try value.decode(String.self)
            guard let number = Int64(text) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid Int64 identifier")
            }
            wrappedValue = number
        }
    }
}
