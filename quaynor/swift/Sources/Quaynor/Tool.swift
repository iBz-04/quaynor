import Foundation
import QuaynorFFI

public struct ToolParameterDefinition: Sendable, Hashable {
    public let name: String
    public let schema: ToolSchema

    public init(name: String, schema: ToolSchema) {
        self.name = name
        self.schema = schema
    }
}

public struct ToolProperty: Sendable, Hashable {
    public let name: String
    public let schema: ToolSchema

    public init(name: String, schema: ToolSchema) {
        self.name = name
        self.schema = schema
    }
}

public indirect enum ToolSchema: Sendable, Hashable {
    case string(description: String? = nil, enumValues: [String]? = nil)
    case integer(description: String? = nil)
    case number(description: String? = nil)
    case boolean(description: String? = nil)
    case array(items: ToolSchema, description: String? = nil)
    case object(properties: [ToolProperty], description: String? = nil)

    fileprivate func toJSONObject() -> [String: Any] {
        switch self {
        case let .string(description, enumValues):
            var object: [String: Any] = ["type": "string"]
            if let description {
                object["description"] = description
            }
            if let enumValues {
                object["enum"] = enumValues
            }
            return object
        case let .integer(description):
            return toolObject(type: "integer", description: description)
        case let .number(description):
            return toolObject(type: "number", description: description)
        case let .boolean(description):
            return toolObject(type: "boolean", description: description)
        case let .array(items, description):
            var object = toolObject(type: "array", description: description)
            object["items"] = items.toJSONObject()
            return object
        case let .object(properties, description):
            var object = toolObject(type: "object", description: description)
            var mappedProperties: [String: Any] = [:]
            for property in properties {
                mappedProperties[property.name] = property.schema.toJSONObject()
            }
            object["properties"] = mappedProperties
            object["required"] = properties.map(\.name)
            return object
        }
    }
}

public final class Tool: @unchecked Sendable {
    private var inner: RustTool?
    private let parameters: [ToolParameterDefinition]
    private var pollTask: Task<Void, Never>?

    public init(
        name: String,
        description: String,
        parameters: [ToolParameterDefinition],
        call: @escaping @Sendable ([Any?]) throws -> String
    ) {
        self.parameters = parameters
        let rustTool = RustTool.newAsync(
            name: name,
            description: description,
            parameters: parameters.map(\.ffiParameter)
        )
        self.inner = rustTool
        self.pollTask = Task { [weak self] in
            await self?.poll(tool: rustTool) { args in
                try call(args)
            }
        }
    }

    public init(
        name: String,
        description: String,
        parameters: [ToolParameterDefinition],
        call: @escaping @Sendable ([Any?]) async throws -> String
    ) {
        self.parameters = parameters
        let rustTool = RustTool.newAsync(
            name: name,
            description: description,
            parameters: parameters.map(\.ffiParameter)
        )
        self.inner = rustTool
        self.pollTask = Task { [weak self] in
            await self?.poll(tool: rustTool, call: call)
        }
    }

    deinit {
        pollTask?.cancel()
    }

    public func getSchemaJson() throws -> String {
        try requireInner().getSchemaJson()
    }

    public func destroy() {
        pollTask?.cancel()
        pollTask = nil
        inner = nil
    }

    func requireInner() throws -> RustTool {
        guard let inner else {
            throw QuaynorBindingError.destroyedInstance(typeName: "Tool")
        }
        return inner
    }

    fileprivate func poll(
        tool: RustTool,
        call: @escaping @Sendable ([Any?]) async throws -> String
    ) async {
        while !Task.isCancelled {
            guard let pendingCall = await tool.nextPendingCall() else {
                break
            }

            do {
                let arguments = try parseArguments(argumentsJSON: pendingCall.argumentsJson)
                let result = try await call(arguments)
                tool.resolvePendingCall(callId: pendingCall.callId, result: result)
            } catch {
                tool.resolvePendingCall(
                    callId: pendingCall.callId,
                    result: "Error: \(error.localizedDescription)"
                )
            }
        }
    }

    private func parseArguments(argumentsJSON: String) throws -> [Any?] {
        let data = Data(argumentsJSON.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let arguments = object as? [String: Any] else {
            throw QuaynorBindingError.invalidToolArguments(
                "Tool arguments must decode to a JSON object."
            )
        }

        return parameters.map { parameter in
            convertToolValue(arguments[parameter.name], schema: parameter.schema)
        }
    }
}

private func toolObject(type: String, description: String?) -> [String: Any] {
    var object: [String: Any] = ["type": type]
    if let description {
        object["description"] = description
    }
    return object
}

private func convertToolValue(_ value: Any?, schema: ToolSchema) -> Any? {
    guard let value else {
        return nil
    }

    switch schema {
    case .integer:
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value
    case .number:
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value
    case .boolean:
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return NSString(string: string).boolValue
        }
        return value
    case .string:
        if let string = value as? String {
            return string
        }
        return String(describing: value)
    case let .array(items, _):
        guard let array = value as? [Any] else {
            return value
        }
        return array.map { convertToolValue($0, schema: items) }
    case let .object(properties, _):
        guard let dictionary = value as? [String: Any] else {
            return value
        }
        var converted: [String: Any?] = [:]
        for property in properties {
            converted[property.name] = convertToolValue(
                dictionary[property.name],
                schema: property.schema
            )
        }
        return converted
    }
}

private extension ToolParameterDefinition {
    var ffiParameter: QuaynorFFI.ToolParameter {
        QuaynorFFI.ToolParameter(name: name, schema: schema.jsonString)
    }
}

private extension ToolSchema {
    var jsonString: String {
        let data = try! JSONSerialization.data(withJSONObject: toJSONObject())
        return String(decoding: data, as: UTF8.self)
    }
}
