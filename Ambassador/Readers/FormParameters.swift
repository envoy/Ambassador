//
//  FormParameters.swift
//  Ambassador
//

import Foundation

/// Form-encoded parameters (`foo=bar&eggs=spam`) with lookup by key: an
/// `application/x-www-form-urlencoded` request body (`URLParametersReader.readParameters`) or a
/// query string (`environ.swsgi.queryParameters`). Keys are case-sensitive and may repeat; order
/// is kept. Iterating yields the `(key, value)` pairs.
public struct FormParameters: Sequence, Sendable {
    /// The `(key, value)` pairs, in order
    public let items: [(String, String)]

    public init(_ items: [(String, String)]) {
        self.items = items
    }

    /// Parse `string` with `URLParametersReader.parseURLParameters`
    public init(parsing string: String) {
        self.init(URLParametersReader.parseURLParameters(string))
    }

    /// The first value for `key`, or `nil` when it's absent
    public subscript(key: String) -> String? {
        items.first { $0.0 == key }?.1
    }

    /// Every value for `key`, in order; empty when it's absent
    public func values(for key: String) -> [String] {
        items.filter { $0.0 == key }.map { $0.1 }
    }

    public func makeIterator() -> IndexingIterator<[(String, String)]> {
        items.makeIterator()
    }
}
