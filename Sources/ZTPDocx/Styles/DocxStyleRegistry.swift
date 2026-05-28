// DocxStyleRegistry.swift
// ZTPDocx – Named style registry for document-wide style management

import Foundation

public struct DocxStyleRegistry: Sendable {
    private var styles: [String: DocxStyle] = [:]

    public init() {}

    /// Register a style under the given name, replacing any existing entry.
    public mutating func register(name: String, style: DocxStyle) {
        styles[name] = style
    }

    /// Resolve a style by name, returning nil if not registered.
    public func resolve(name: String) -> DocxStyle? {
        styles[name]
    }

    /// All registered styles as name-style pairs, sorted by name for deterministic output.
    public var allStyles: [(name: String, style: DocxStyle)] {
        styles.sorted { $0.key < $1.key }.map { (name: $0.key, style: $0.value) }
    }

    /// The number of registered styles.
    public var count: Int {
        styles.count
    }
}
