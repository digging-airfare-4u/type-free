import Foundation
import XCTest
@testable import TypeFree

final class LLMServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LLMService.apiBaseURL = "https://example.com/v1"
        LLMService.apiKey = "test-key"
        LLMService.model = "test-model"
        URLProtocolStub.requestHandler = nil
    }

    func testRefineUsesLanguageSpecificPromptForEnglish() throws {
        let service = LLMService(session: makeSession())
        let completion = expectation(description: "refine completion")

        URLProtocolStub.requestHandler = { request in
            let body = try self.serializedBody(from: request)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let messages = try XCTUnwrap(payload["messages"] as? [[String: Any]])
            let systemPrompt = try XCTUnwrap(messages.first?["content"] as? String)

            XCTAssertTrue(systemPrompt.contains("Keep the original language as spoken"))
            XCTAssertFalse(systemPrompt.contains("中文同音错字"))

            let response = HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: [
                "choices": [
                    ["message": ["content": "Refined English text"]]
                ]
            ])
            return (response, data)
        }

        service.refine(text: "refine this", language: "en-US") { result in
            XCTAssertEqual(result, "Refined English text")
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
    }

    func testRefineReturnsNilWhenSanitizedContentBecomesEmpty() {
        let service = LLMService(session: makeSession())
        let completion = expectation(description: "refine completion")

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: [
                "choices": [
                    ["message": ["content": "  <think>hidden</think>  "]]
                ]
            ])
            return (response, data)
        }

        service.refine(text: "raw text", language: "zh-Hans") { result in
            XCTAssertNil(result)
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
    }

    func testRefineReturnsNilForNonSuccessStatusCode() {
        let service = LLMService(session: makeSession())
        let completion = expectation(description: "refine completion")

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            let data = Data("{\"error\":\"boom\"}".utf8)
            return (response, data)
        }

        service.refine(text: "raw text", language: "zh-Hans") { result in
            XCTAssertNil(result)
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func serializedBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            throw URLError(.badServerResponse)
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw stream.streamError ?? URLError(.cannotOpenFile)
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }

        if data.isEmpty {
            throw URLError(.zeroByteResource)
        }

        return data
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
