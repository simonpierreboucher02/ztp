import Foundation

/// All content elements that can appear on a slide.
public enum PptxElement: Sendable, Equatable {
    case title(String)
    case subtitle(String)
    case paragraph(String, style: String?)
    case bullets([String])
    case numberedList([String])
    case image(PptxImage)
    case table(PptxTable)
    case shape(PptxShape)
    case kpi(label: String, value: String, delta: String?)
    case spacer(height: Int?)
}

// MARK: - Custom Codable

extension PptxElement: Codable {

    private enum TypeKey: String, Codable {
        case title
        case subtitle
        case paragraph
        case bullets
        case numberedList = "numbered_list"
        case image
        case table
        case shape
        case kpi
        case spacer
    }

    private enum CodingKeys: String, CodingKey {
        case type
        // paragraph
        case text
        case style
        // bullets / numberedList
        case items
        // image
        case path, width, height, fit, caption
        // table
        case headers, rows
        // shape
        case shape
        case fillColor = "fill"
        case borderColor = "border"
        // kpi
        case label, value, delta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(TypeKey.self, forKey: .type)

        switch typeValue {
        case .title:
            let text = try container.decode(String.self, forKey: .text)
            self = .title(text)

        case .subtitle:
            let text = try container.decode(String.self, forKey: .text)
            self = .subtitle(text)

        case .paragraph:
            let text = try container.decode(String.self, forKey: .text)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            self = .paragraph(text, style: style)

        case .bullets:
            let items = try container.decode([String].self, forKey: .items)
            self = .bullets(items)

        case .numberedList:
            let items = try container.decode([String].self, forKey: .items)
            self = .numberedList(items)

        case .image:
            let path = try container.decode(String.self, forKey: .path)
            let w = try container.decodeIfPresent(Int.self, forKey: .width)
            let h = try container.decodeIfPresent(Int.self, forKey: .height)
            let fitValue = try container.decodeIfPresent(ImageFit.self, forKey: .fit)
            let cap = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(PptxImage(path: path, width: w, height: h, fit: fitValue, caption: cap))

        case .table:
            let headers = try container.decodeIfPresent([String].self, forKey: .headers)
            let rows = try container.decode([[String]].self, forKey: .rows)
            let style = try container.decodeIfPresent(String.self, forKey: .style)
            self = .table(PptxTable(headers: headers, rows: rows, style: style))

        case .shape:
            let shapeType = try container.decode(ShapeType.self, forKey: .shape)
            let text = try container.decodeIfPresent(String.self, forKey: .text)
            let fill = try container.decodeIfPresent(String.self, forKey: .fillColor)
            let border = try container.decodeIfPresent(String.self, forKey: .borderColor)
            let w = try container.decodeIfPresent(Int.self, forKey: .width)
            let h = try container.decodeIfPresent(Int.self, forKey: .height)
            self = .shape(PptxShape(
                type: shapeType,
                text: text,
                fillColor: fill,
                borderColor: border,
                width: w,
                height: h
            ))

        case .kpi:
            let label = try container.decode(String.self, forKey: .label)
            let value = try container.decode(String.self, forKey: .value)
            let delta = try container.decodeIfPresent(String.self, forKey: .delta)
            self = .kpi(label: label, value: value, delta: delta)

        case .spacer:
            let h = try container.decodeIfPresent(Int.self, forKey: .height)
            self = .spacer(height: h)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .title(let text):
            try container.encode(TypeKey.title, forKey: .type)
            try container.encode(text, forKey: .text)

        case .subtitle(let text):
            try container.encode(TypeKey.subtitle, forKey: .type)
            try container.encode(text, forKey: .text)

        case .paragraph(let text, let style):
            try container.encode(TypeKey.paragraph, forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(style, forKey: .style)

        case .bullets(let items):
            try container.encode(TypeKey.bullets, forKey: .type)
            try container.encode(items, forKey: .items)

        case .numberedList(let items):
            try container.encode(TypeKey.numberedList, forKey: .type)
            try container.encode(items, forKey: .items)

        case .image(let img):
            try container.encode(TypeKey.image, forKey: .type)
            try container.encode(img.path, forKey: .path)
            try container.encodeIfPresent(img.width, forKey: .width)
            try container.encodeIfPresent(img.height, forKey: .height)
            try container.encodeIfPresent(img.fit, forKey: .fit)
            try container.encodeIfPresent(img.caption, forKey: .caption)

        case .table(let tbl):
            try container.encode(TypeKey.table, forKey: .type)
            try container.encodeIfPresent(tbl.headers, forKey: .headers)
            try container.encode(tbl.rows, forKey: .rows)
            try container.encodeIfPresent(tbl.style, forKey: .style)

        case .shape(let shp):
            try container.encode(TypeKey.shape, forKey: .type)
            try container.encode(shp.type, forKey: .shape)
            try container.encodeIfPresent(shp.text, forKey: .text)
            try container.encodeIfPresent(shp.fillColor, forKey: .fillColor)
            try container.encodeIfPresent(shp.borderColor, forKey: .borderColor)
            try container.encodeIfPresent(shp.width, forKey: .width)
            try container.encodeIfPresent(shp.height, forKey: .height)

        case .kpi(let label, let value, let delta):
            try container.encode(TypeKey.kpi, forKey: .type)
            try container.encode(label, forKey: .label)
            try container.encode(value, forKey: .value)
            try container.encodeIfPresent(delta, forKey: .delta)

        case .spacer(let height):
            try container.encode(TypeKey.spacer, forKey: .type)
            try container.encodeIfPresent(height, forKey: .height)
        }
    }
}
