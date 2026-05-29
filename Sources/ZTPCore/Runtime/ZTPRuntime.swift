import Foundation
import ZTPProtocols

public actor ZTPRuntime {
    private var registry: ToolRegistry
    private let eventBus: EventBus

    public init() {
        self.registry = ToolRegistry()
        self.eventBus = EventBus()
    }

    public func register(tool: any ZTPTool) {
        registry.register(tool: tool)
    }

    public func execute(
        toolName: String,
        input: ToolInput,
        context: ToolContext
    ) async throws -> ToolResult {
        guard let tool = registry.get(name: toolName) else {
            return ToolResult.failure(
                tool: toolName,
                error: ToolErrorInfo(code: "NOT_FOUND", message: "Tool '\(toolName)' not found")
            )
        }

        let start = ContinuousClock.now

        await eventBus.emit(ToolEvent(
            event: .start,
            tool: toolName,
            traceID: context.traceID
        ))

        do {
            let result = try await tool.execute(input: input, context: context)
            let elapsed = start.duration(to: .now)
            let ms = elapsed.components.seconds * 1000
                + elapsed.components.attoseconds / 1_000_000_000_000_000
            let duration = result.durationMs ?? ms

            // Preserve the tool's actual outcome — a tool that returns a
            // failure must NOT be reported as success. Only the duration and
            // event emission are added by the runtime.
            await eventBus.emit(ToolEvent(
                event: result.ok ? .done : .error,
                tool: toolName,
                traceID: context.traceID
            ))

            if result.ok {
                return ToolResult.success(tool: toolName, durationMs: duration, data: result.data ?? [:])
            } else {
                return ToolResult.failure(
                    tool: toolName,
                    durationMs: duration,
                    error: result.error ?? ToolErrorInfo(code: "TOOL_FAILED", message: "Tool reported failure")
                )
            }
        } catch {
            let elapsed = start.duration(to: .now)
            let ms = elapsed.components.seconds * 1000
                + elapsed.components.attoseconds / 1_000_000_000_000_000

            await eventBus.emit(ToolEvent(
                event: .error,
                tool: toolName,
                traceID: context.traceID
            ))

            return ToolResult.failure(
                tool: toolName,
                durationMs: ms,
                error: ToolErrorInfo(
                    code: "EXECUTION_FAILED",
                    message: error.localizedDescription
                )
            )
        }
    }

    public func listTools() -> [ToolManifest] {
        registry.listAll()
    }

    public func getTool(name: String) -> (any ZTPTool)? {
        registry.get(name: name)
    }
}
