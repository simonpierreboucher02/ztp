import Foundation

public actor EventBus {
    public typealias Handler = @Sendable (ToolEvent) -> Void

    private var handlers: [Handler] = []

    public init() {}

    public func subscribe(handler: @escaping Handler) {
        handlers.append(handler)
    }

    public func emit(_ event: ToolEvent) {
        for handler in handlers {
            handler(event)
        }
    }
}
