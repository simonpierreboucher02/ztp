// StyleRegistry.swift
// ZTPExcel – Named style registry with deduplication and numeric IDs.

import Foundation

/// Manages named cell styles, deduplicates identical definitions, and
/// assigns stable numeric IDs for OpenXML serialisation.
///
/// Thread-safe: conforms to `Sendable` by using value-type internals
/// behind a controlled interface.
public struct StyleRegistry: Sendable {

    // MARK: - Internal storage

    /// Maps a style name to its numeric ID.
    private var nameToID: [String: Int] = [:]

    /// Maps a ``CellStyle`` value to its numeric ID (for deduplication).
    private var styleToID: [CellStyle: Int] = [:]

    /// Ordered list of registered styles by ID.
    private var styles: [(id: Int, style: CellStyle)] = []

    /// The next ID to assign.
    private var nextID: Int = 1

    // MARK: - Initialiser

    public init() {}

    // MARK: - Registration

    /// Registers a named style. If an identical ``CellStyle`` has already
    /// been registered (possibly under a different name), the existing
    /// numeric ID is reused.
    ///
    /// - Parameters:
    ///   - name:  The style name from the spec (e.g. "header").
    ///   - style: The style definition.
    /// - Returns: The numeric ID assigned to this style.
    @discardableResult
    public mutating func register(name: String, style: CellStyle) -> Int {
        // If this exact style value already exists, reuse its ID.
        if let existingID = styleToID[style] {
            nameToID[name] = existingID
            return existingID
        }

        let id = nextID
        nextID += 1

        styleToID[style] = id
        nameToID[name] = id
        styles.append((id: id, style: style))

        return id
    }

    // MARK: - Resolution

    /// Resolves a named style to its numeric ID and definition.
    ///
    /// - Parameter name: The style name to look up.
    /// - Returns: A tuple of `(id, style)`, or `nil` if the name is unknown.
    public func resolve(name: String) -> (id: Int, style: CellStyle)? {
        guard let id = nameToID[name] else { return nil }
        guard let entry = styles.first(where: { $0.id == id }) else { return nil }
        return entry
    }

    /// All registered styles, ordered by ID.
    public var allStyles: [(id: Int, style: CellStyle)] {
        styles
    }
}
