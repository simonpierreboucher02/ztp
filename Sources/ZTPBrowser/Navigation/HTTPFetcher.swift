import Foundation

public struct HTTPFetcher: Sendable {

    public struct FetchResult: Sendable {
        public let html: String
        public let statusCode: Int
        public let contentType: String?
        public let finalURL: URL
        public let headers: [String: String]

        public init(html: String, statusCode: Int, contentType: String?, finalURL: URL, headers: [String: String]) {
            self.html = html
            self.statusCode = statusCode
            self.contentType = contentType
            self.finalURL = finalURL
            self.headers = headers
        }
    }

    public enum FetchError: Error, Sendable {
        case invalidURL
        case networkError(String)
        case httpError(statusCode: Int, url: URL)
        case noData
        case decodingError(String)
    }

    public static func fetch(url: URL, timeoutMs: Int = 10000) async throws -> FetchResult {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = TimeInterval(timeoutMs) / 1000.0
        config.timeoutIntervalForResource = TimeInterval(timeoutMs) / 1000.0
        config.httpAdditionalHeaders = [
            "User-Agent": "ZTPBrowser/0.1 (macOS)"
        ]

        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw FetchError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.networkError("Response was not an HTTP response.")
        }

        let statusCode = httpResponse.statusCode
        guard (200..<300).contains(statusCode) else {
            throw FetchError.httpError(statusCode: statusCode, url: httpResponse.url ?? url)
        }

        // Build headers dictionary
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")

        // Determine encoding from Content-Type, default to UTF-8
        let encoding: String.Encoding = {
            if let ct = contentType?.lowercased(), ct.contains("charset=") {
                if ct.contains("iso-8859-1") || ct.contains("latin1") {
                    return .isoLatin1
                }
                if ct.contains("ascii") {
                    return .ascii
                }
            }
            return .utf8
        }()

        guard let html = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
            throw FetchError.decodingError("Could not decode response body as text.")
        }

        let finalURL = httpResponse.url ?? url

        return FetchResult(
            html: html,
            statusCode: statusCode,
            contentType: contentType,
            finalURL: finalURL,
            headers: headers
        )
    }
}
