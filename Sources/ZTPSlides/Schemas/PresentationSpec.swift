import Foundation

// MARK: - Errors

/// Errors that can occur when parsing or converting a presentation spec.
public enum PptxSpecError: Error, Sendable, Equatable {
    case unsupportedVersion(String)
    case invalidAspectRatio(String)
    case invalidLayout(String)
    case missingRequiredField(String)
    case invalidContentType(String)
}

extension PptxSpecError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "Unsupported spec version: \(v)"
        case .invalidAspectRatio(let r):
            return "Invalid aspect ratio: \(r)"
        case .invalidLayout(let l):
            return "Invalid layout: \(l)"
        case .missingRequiredField(let f):
            return "Missing required field: \(f)"
        case .invalidContentType(let t):
            return "Invalid content type: \(t)"
        }
    }
}

// MARK: - Spec Types

/// Top-level JSON spec for a presentation.
public struct PresentationSpec: Codable, Sendable, Equatable {
    public let version: String
    public let presentation: PresentationMeta?
    public let theme: ThemeSpec?
    public let slides: [SlideSpec]

    public init(
        version: String,
        presentation: PresentationMeta? = nil,
        theme: ThemeSpec? = nil,
        slides: [SlideSpec]
    ) {
        self.version = version
        self.presentation = presentation
        self.theme = theme
        self.slides = slides
    }
}

/// Metadata about the presentation (title, author, size).
public struct PresentationMeta: Codable, Sendable, Equatable {
    public let title: String?
    public let author: String?
    public let size: String?

    public init(title: String? = nil, author: String? = nil, size: String? = nil) {
        self.title = title
        self.author = author
        self.size = size
    }
}

/// Theme specification from JSON. Accent may include a "#" prefix.
public struct ThemeSpec: Codable, Sendable, Equatable {
    public let name: String?
    public let font: String?
    public let accent: String?
    public let background: String?
    public let textColor: String?

    public init(
        name: String? = nil,
        font: String? = nil,
        accent: String? = nil,
        background: String? = nil,
        textColor: String? = nil
    ) {
        self.name = name
        self.font = font
        self.accent = accent
        self.background = background
        self.textColor = textColor
    }
}

/// Shorthand table specification that can appear directly on a slide.
public struct TableContentSpec: Codable, Sendable, Equatable {
    public let headers: [String]?
    public let rows: [[String]]
    public let style: String?

    public init(headers: [String]? = nil, rows: [[String]], style: String? = nil) {
        self.headers = headers
        self.rows = rows
        self.style = style
    }
}

/// A single slide in the JSON spec.
public struct SlideSpec: Codable, Sendable, Equatable {
    public let layout: String?
    public let title: String?
    public let subtitle: String?
    public let content: [ContentSpec]?
    public let table: TableContentSpec?
    public let notes: String?

    public init(
        layout: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        content: [ContentSpec]? = nil,
        table: TableContentSpec? = nil,
        notes: String? = nil
    ) {
        self.layout = layout
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.table = table
        self.notes = notes
    }
}

// MARK: - ContentSpec

/// A content element in the JSON spec, decoded using a "type" discriminator.
public enum ContentSpec: Sendable, Equatable {
    case bullets([String])
    case numberedList([String])
    case table(TableContentSpec)
    case image(path: String, width: Int?, height: Int?, fit: String?, caption: String?)
    case kpi(label: String, value: String, delta: String?)
    case shape(shape: String, text: String?, fill: String?, border: String?, width: Int?, height: Int?)
    case paragraph(text: String, style: String?)
    case spacer(height: Int?)
}

extension ContentSpec: Codable {

    private enum TypeValue: String, Codable {
        case bullets
        case numberedList = "numbered_list"
        case table
        case image
        case kpi
        case shape
        case paragraph
        case spacer
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case items
        case text
        case style
        case path
        case width
        case height
        case fit
        case caption
        case headers
        case rows
        case shape
        case fill
        case border
        case label
        case value
        case delta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(TypeValue.self, forKey: .type)

        switch typeValue {
        case .bullets:
            let items = try container.decode([String].self, forKey: .items)
            self = .bullets(items)

        case .numberedList:
            let items = try container.decode([String].self, forKey: .items)
            self = .numberedList(items)

        case .table:
            let headers = try container.decodeIfPresent([String].self, forKey: .headers)
            let rows = try container.decode([[String]].self, forKey: .rows)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            self = .table(TableContentSpec(headers: headers, rows: rows, style: style))

        case .image:
            let path = try container.decode(String.self, forKey: .path)
            let w = try container.decodeIfPresent(Int.self, forKey: .width)
            let h = try container.decodeIfPresent(Int.self, forKey: .height)
            let fitVal = try container.decodeIfPresent(String.self, forKey: .fit)
            let cap = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(path: path, width: w, height: h, fit: fitVal, caption: cap)

        case .kpi:
            let label = try container.decode(String.self, forKey: .label)
            let value = try container.decode(String.self, forKey: .value)
            let delta = try container.decodeIfPresent(String.self, forKey: .delta)
            self = .kpi(label: label, value: value, delta: delta)

        case .shape:
            let shapeVal = try container.decode(String.self, forKey: .shape)
            let text = try container.decodeIfPresent(String.self, forKey: .text)
            let fill = try container.decodeIfPresent(String.self, forKey: .fill)
            let border = try container.decodeIfPresent(String.self, forKey: .border)
            let w = try container.decodeIfPresent(Int.self, forKey: .width)
            let h = try container.decodeIfPresent(Int.self, forKey: .height)
            self = .shape(shape: shapeVal, text: text, fill: fill, border: border, width: w, height: h)

        case .paragraph:
            let text = try container.decode(String.self, forKey: .text)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            self = .paragraph(text: text, style: style)

        case .spacer:
            let h = try container.decodeIfPresent(Int.self, forKey: .height)
            self = .spacer(height: h)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .bullets(let items):
            try container.encode(TypeValue.bullets, forKey: .type)
            try container.encode(items, forKey: .items)

        case .numberedList(let items):
            try container.encode(TypeValue.numberedList, forKey: .type)
            try container.encode(items, forKey: .items)

        case .table(let spec):
            try container.encode(TypeValue.table, forKey: .type)
            try container.encodeIfPresent(spec.headers, forKey: .headers)
            try container.encode(spec.rows, forKey: .rows)
            try container.encodeIfPresent(spec.style, forKey: .style)

        case .image(let path, let w, let h, let fit, let caption):
            try container.encode(TypeValue.image, forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encodeIfPresent(w, forKey: .width)
            try container.encodeIfPresent(h, forKey: .height)
            try container.encodeIfPresent(fit, forKey: .fit)
            try container.encodeIfPresent(caption, forKey: .caption)

        case .kpi(let label, let value, let delta):
            try container.encode(TypeValue.kpi, forKey: .type)
            try container.encode(label, forKey: .label)
            try container.encode(value, forKey: .value)
            try container.encodeIfPresent(delta, forKey: .delta)

        case .shape(let shape, let text, let fill, let border, let w, let h):
            try container.encode(TypeValue.shape, forKey: .type)
            try container.encode(shape, forKey: .shape)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(fill, forKey: .fill)
            try container.encodeIfPresent(border, forKey: .border)
            try container.encodeIfPresent(w, forKey: .width)
            try container.encodeIfPresent(h, forKey: .height)

        case .paragraph(let text, let style):
            try container.encode(TypeValue.paragraph, forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(style, forKey: .style)

        case .spacer(let height):
            try container.encode(TypeValue.spacer, forKey: .type)
            try container.encodeIfPresent(height, forKey: .height)
        }
    }
}

// MARK: - Conversion to Domain Models

extension PresentationSpec {

    /// Strips a leading "#" from a hex color string if present.
    private static func stripHash(_ hex: String?) -> String? {
        guard let hex = hex else { return nil }
        if hex.hasPrefix("#") {
            return String(hex.dropFirst())
        }
        return hex
    }

    /// Converts this JSON spec into a `PptxPresentation` domain model.
    /// - Throws: `PptxSpecError` if the spec contains invalid values.
    public func toPresentation() throws -> PptxPresentation {
        // Validate version
        guard version.hasPrefix("ztp-slides/") else {
            throw PptxSpecError.unsupportedVersion(version)
        }

        // Resolve slide size
        let slideSize: SlideSize
        if let sizeStr = presentation?.size {
            guard let resolved = SlideSize(aspect: sizeStr) else {
                throw PptxSpecError.invalidAspectRatio(sizeStr)
            }
            slideSize = resolved
        } else {
            slideSize = .widescreen
        }

        // Resolve theme
        let resolvedTheme: PptxTheme
        if let ts = theme {
            resolvedTheme = PptxTheme(
                name: ts.name ?? "zyquo-business",
                font: ts.font ?? "Aptos",
                accent: Self.stripHash(ts.accent) ?? "3B82F6",
                background: Self.stripHash(ts.background),
                textColor: Self.stripHash(ts.textColor)
            )
        } else {
            resolvedTheme = .defaultTheme
        }

        // Convert slides
        let convertedSlides = try slides.map { spec -> PptxSlide in
            try Self.convertSlide(spec)
        }

        return PptxPresentation(
            title: presentation?.title,
            author: presentation?.author,
            size: slideSize,
            theme: resolvedTheme,
            slides: convertedSlides
        )
    }

    private static func convertSlide(_ spec: SlideSpec) throws -> PptxSlide {
        // Resolve layout
        let layout: PptxLayout
        if let layoutStr = spec.layout {
            guard let resolved = PptxLayout(rawValue: layoutStr) else {
                throw PptxSpecError.invalidLayout(layoutStr)
            }
            layout = resolved
        } else {
            layout = .blank
        }

        // Build content elements
        var elements: [PptxElement] = []

        // If the slide has a shorthand "table" field, treat it as a single table element
        if let tableSpec = spec.table {
            elements.append(.table(PptxTable(
                headers: tableSpec.headers,
                rows: tableSpec.rows,
                style: tableSpec.style
            )))
        }

        // Convert content array
        if let contentSpecs = spec.content {
            for contentSpec in contentSpecs {
                let element = try convertContent(contentSpec)
                elements.append(element)
            }
        }

        return PptxSlide(
            layout: layout,
            title: spec.title,
            subtitle: spec.subtitle,
            content: elements,
            notes: spec.notes
        )
    }

    private static func convertContent(_ spec: ContentSpec) throws -> PptxElement {
        switch spec {
        case .bullets(let items):
            return .bullets(items)

        case .numberedList(let items):
            return .numberedList(items)

        case .table(let tableSpec):
            return .table(PptxTable(
                headers: tableSpec.headers,
                rows: tableSpec.rows,
                style: tableSpec.style
            ))

        case .image(let path, let w, let h, let fit, let caption):
            let imageFit: ImageFit?
            if let fitStr = fit {
                guard let resolved = ImageFit(rawValue: fitStr) else {
                    throw PptxSpecError.invalidContentType("Unknown image fit: \(fitStr)")
                }
                imageFit = resolved
            } else {
                imageFit = nil
            }
            return .image(PptxImage(path: path, width: w, height: h, fit: imageFit, caption: caption))

        case .kpi(let label, let value, let delta):
            return .kpi(label: label, value: value, delta: delta)

        case .shape(let shapeStr, let text, let fill, let border, let w, let h):
            guard let shapeType = ShapeType(rawValue: shapeStr) else {
                throw PptxSpecError.invalidContentType("Unknown shape type: \(shapeStr)")
            }
            return .shape(PptxShape(
                type: shapeType,
                text: text,
                fillColor: stripHash(fill),
                borderColor: stripHash(border),
                width: w,
                height: h
            ))

        case .paragraph(let text, let style):
            return .paragraph(text, style: style)

        case .spacer(let height):
            return .spacer(height: height)
        }
    }
}
