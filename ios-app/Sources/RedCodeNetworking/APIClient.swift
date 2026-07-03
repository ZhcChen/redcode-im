import Foundation
import RedCodeCore

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedCodeError.network("响应不是 HTTPURLResponse")
        }
        return (data, httpResponse)
    }
}

public actor APIClient {
    private let environment: RedCodeEnvironment
    private let transport: any HTTPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        environment: RedCodeEnvironment,
        transport: any HTTPTransport = URLSessionHTTPTransport(),
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.environment = environment
        self.transport = transport
        self.encoder = encoder
        self.decoder = decoder
    }

    public func get<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        bearerToken: String? = nil,
        as responseType: Response.Type = Response.self
    ) async throws -> Response {
        try await send(endpoint, bearerToken: bearerToken, bodyData: nil, as: responseType)
    }

    public func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: Body,
        bearerToken: String? = nil,
        as responseType: Response.Type = Response.self
    ) async throws -> Response {
        let data = try encoder.encode(body)
        return try await send(endpoint, bearerToken: bearerToken, bodyData: data, as: responseType)
    }

    public func postNoResponse<Body: Encodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: Body,
        bearerToken: String? = nil
    ) async throws {
        let data = try encoder.encode(body)
        try await sendNoResponse(endpoint, bearerToken: bearerToken, bodyData: data)
    }

    private func send<Response: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        bearerToken: String?,
        bodyData: Data?,
        as responseType: Response.Type
    ) async throws -> Response {
        let data = try await sendData(endpoint, bearerToken: bearerToken, bodyData: bodyData)
        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            throw RedCodeError.network("响应解析失败")
        }
    }

    private func sendNoResponse(
        _ endpoint: APIEndpoint,
        bearerToken: String?,
        bodyData: Data?
    ) async throws {
        _ = try await sendData(endpoint, bearerToken: bearerToken, bodyData: bodyData)
    }

    private func sendData(
        _ endpoint: APIEndpoint,
        bearerToken: String?,
        bodyData: Data?
    ) async throws -> Data {
        let url = try endpoint.url(in: environment)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let dataAndResponse: (Data, HTTPURLResponse)
        do {
            dataAndResponse = try await transport.data(for: request)
        } catch let error as RedCodeError {
            throw error
        } catch {
            throw RedCodeError.network(error.localizedDescription)
        }
        let (data, response) = dataAndResponse
        guard (200...299).contains(response.statusCode) else {
            throw RedCodeError.network(errorMessage(from: data) ?? "HTTP \(response.statusCode)")
        }
        return data
    }

    private func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)
        }
        return object["message"] as? String
            ?? object["error"] as? String
            ?? object["detail"] as? String
    }
}
