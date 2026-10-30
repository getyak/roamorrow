import XCTest
@testable import SoloCompass

/// Exercises the production URLSession/SSE transport with isolated responses.
/// The request builder supplies a non-routable URL, so no key, account or
/// UserDefaults mutation is needed and no request can leave the process.
@MainActor
final class AIServiceStreamingTests: XCTestCase {
    private final class Plan: @unchecked Sendable {
        let status: Int
        let contentType: String?
        let body: String
        let error: URLError?
        let holdOpen: Bool
        private let lock = NSLock()
        private var requests = 0
        private var cancellations = 0

        init(status: Int = 200, contentType: String? = "text/event-stream", body: String = "", error: URLError? = nil, holdOpen: Bool = false) {
            self.status = status
            self.contentType = contentType
            self.body = body
            self.error = error
            self.holdOpen = holdOpen
        }

        func started() { lock.lock(); defer { lock.unlock() }; requests += 1 }
        func cancelled() { lock.lock(); defer { lock.unlock() }; cancellations += 1 }
        var counts: (requests: Int, cancellations: Int) {
            lock.lock(); defer { lock.unlock() }
            return (requests, cancellations)
        }
    }

    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var plans: [URL: Plan] = [:]
        func set(_ plan: Plan, at url: URL) { lock.lock(); defer { lock.unlock() }; plans[url] = plan }
        func remove(_ url: URL) { lock.lock(); defer { lock.unlock() }; plans.removeValue(forKey: url) }
        func get(_ url: URL) -> Plan? { lock.lock(); defer { lock.unlock() }; return plans[url] }
    }

    private final class Metrics: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: AIService.AgentStreamMetrics?
        func record(_ value: AIService.AgentStreamMetrics) { lock.lock(); defer { lock.unlock() }; stored = value }
        var value: AIService.AgentStreamMetrics? { lock.lock(); defer { lock.unlock() }; return stored }
    }

    private final class StubProtocol: URLProtocol, @unchecked Sendable {
        static let registry = Registry()
        private var plan: Plan?
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let url = request.url, let plan = Self.registry.get(url) else {
                client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
                return
            }
            self.plan = plan
            plan.started()
            if let error = plan.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            let headers = plan.contentType.map { ["Content-Type": $0] }
            guard let response = HTTPURLResponse(url: url, statusCode: plan.status, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !plan.body.isEmpty { client?.urlProtocol(self, didLoad: Data(plan.body.utf8)) }
            if !plan.holdOpen { client?.urlProtocolDidFinishLoading(self) }
        }
        override func stopLoading() { plan?.cancelled() }
    }

    @MainActor
    private struct Transport {
        let service: AIService
        let session: URLSession
        let request: URLRequest

        init(_ plan: Plan) {
            let url = URL(string: "https://transport.invalid/\(UUID().uuidString)")!
            StubProtocol.registry.set(plan, at: url)
            request = URLRequest(url: url)
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubProtocol.self]
            session = URLSession(configuration: config)
            service = AIService(session: session)
        }

        func events() -> AsyncThrowingStream<AIService.StreamEvent, Error> {
            let request = request
            return service.streamAgentMessage(requestBuilder: { request })
        }

        func close() {
            session.invalidateAndCancel()
            if let url = request.url { StubProtocol.registry.remove(url) }
        }
    }

    func testValidSSETextCompletesWithoutAnotherRequest() async throws {
        let plan = Plan(body: "data: {\"choices\":[{\"delta\":{\"content\":\"Tokyo\"},\"finish_reason\":null}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n")
        let transport = Transport(plan)
        defer { transport.close() }
        var text = ""
        var done = false
        for try await event in transport.events() {
            switch event {
            case .contentDelta(let delta): text += delta
            case .done: done = true
            case .toolCall: XCTFail("Unexpected tool call")
            }
        }
        XCTAssertEqual(text, "Tokyo")
        XCTAssertTrue(done)
        XCTAssertEqual(plan.counts.requests, 1)
    }

    func testValidJSONCompatibilityConsumesTheSameResponse() async throws {
        let plan = Plan(contentType: "application/json; charset=utf-8", body: #"{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"Tokyo"}}]}"#)
        let transport = Transport(plan)
        defer { transport.close() }
        var text = ""
        for try await event in transport.events() {
            if case .contentDelta(let delta) = event { text += delta }
        }
        XCTAssertEqual(text, "Tokyo")
        XCTAssertEqual(plan.counts.requests, 1, "A valid JSON response needs parsing, not another paid request")
    }

    func testSSEWithoutMIMEHeaderRemainsCompatible() async throws {
        let plan = Plan(contentType: nil, body: "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"},\"finish_reason\":\"stop\"}]}\n\n")
        let transport = Transport(plan)
        defer { transport.close() }
        var text = ""
        for try await event in transport.events() {
            if case .contentDelta(let delta) = event { text += delta }
        }
        XCTAssertEqual(text, "OK")
    }

    func testToolArgumentFragmentsAreAssembledBeforeEmission() async throws {
        let plan = Plan(body: "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"function\":{\"name\":\"search_places\",\"arguments\":\"{\\\"query\\\":\"}}]},\"finish_reason\":null}]}\n\ndata: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"\\\"books\\\"}\"}}]},\"finish_reason\":null}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\ndata: [DONE]\n\n")
        let transport = Transport(plan)
        defer { transport.close() }
        var calls: [String] = []
        for try await event in transport.events() {
            if case .toolCall(let id, let name, let args) = event { calls.append("\(id)|\(name)|\(args)") }
        }
        XCTAssertEqual(calls, [#"call_1|search_places|{"query":"books"}"#])
    }

    func testExplicitStreamRejectionAllowsOneCallerFallback() async throws {
        for plan in [Plan(status: 406), Plan(status: 400, contentType: "application/json", body: #"{"error":{"code":"unsupported_parameter","param":"stream"}}"#)] {
            let transport = Transport(plan)
            defer { transport.close() }
            do {
                for try await _ in transport.events() {}
                XCTFail("A rejected stream must not succeed empty")
            } catch {
                XCTAssertTrue(AIService.shouldFallbackFromAgentStreaming(after: error))
            }
            XCTAssertEqual(plan.counts.requests, 1)
        }
    }

    func testAuthenticationQuotaServerAndTransportFailuresDoNotAllowFallback() async throws {
        for plan in [Plan(status: 401), Plan(status: 429), Plan(status: 500), Plan(status: 400, contentType: "application/json", body: #"{"error":{"code":"invalid_request_error"}}"#), Plan(error: URLError(.timedOut)), Plan(error: URLError(.cancelled))] {
            let transport = Transport(plan)
            defer { transport.close() }
            do {
                for try await _ in transport.events() {}
                XCTFail("The failing response must throw")
            } catch {
                XCTAssertFalse(AIService.shouldFallbackFromAgentStreaming(after: error))
            }
            XCTAssertEqual(plan.counts.requests, 1)
        }
    }

    func testPartialSSEAndLengthLimitedResponsesCannotBeCommittedOrRetried() async throws {
        for body in ["data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n", "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n"] {
            let transport = Transport(Plan(body: body))
            defer { transport.close() }
            var completed = false
            do {
                for try await event in transport.events() { if case .done = event { completed = true } }
                XCTFail("An incomplete reply must throw")
            } catch {
                XCTAssertFalse(AIService.shouldFallbackFromAgentStreaming(after: error))
            }
            XCTAssertFalse(completed)
        }
    }

    func testUnexpectedHTMLAndEmptySSEFailWithoutCompatibilityRetry() async throws {
        for plan in [Plan(contentType: "text/html", body: "<html>upstream error</html>"), Plan(body: "data: [DONE]\n\n")] {
            let transport = Transport(plan)
            defer { transport.close() }
            do {
                for try await _ in transport.events() {}
                XCTFail("No valid assistant output must not count as success")
            } catch { XCTAssertFalse(AIService.shouldFallbackFromAgentStreaming(after: error)) }
        }
    }

    func testConsumerCancellationStopsUnderlyingRequest() async throws {
        let plan = Plan(body: ": keepalive\n\n", holdOpen: true)
        let transport = Transport(plan)
        defer { transport.close() }
        let consumer = Task { for try await _ in transport.events() {} }
        for _ in 0..<100 {
            if plan.counts.requests > 0 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(plan.counts.requests, 1)
        consumer.cancel()
        for _ in 0..<100 {
            if plan.counts.cancellations > 0 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(plan.counts.cancellations, 1, "Cancellation must reach URLSession instead of leaving a paid request alive")
    }

    func testMetricsDistinguishCompletedAndInterruptedOutputWithoutRecordingText() async throws {
        for complete in [true, false] {
            let body = "data: {\"choices\":[{\"delta\":{\"content\":\"Tokyo\"},\"finish_reason\":null}]}\n\n" + (complete ? "data: [DONE]\n\n" : "")
            let transport = Transport(Plan(body: body))
            defer { transport.close() }
            let metrics = Metrics()
            let request = transport.request
            do {
                for try await _ in transport.service.streamAgentMessage(requestBuilder: { request }, onMetrics: { metrics.record($0) }) {}
            } catch { XCTAssertFalse(complete) }
            for _ in 0..<100 {
                if metrics.value != nil { break }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            let value = try XCTUnwrap(metrics.value)
            XCTAssertEqual(value.completed, complete)
            let first = try XCTUnwrap(value.firstOutputLatencyMs)
            XCTAssertGreaterThanOrEqual(first, 0)
            XCTAssertGreaterThanOrEqual(value.totalLatencyMs, first)
        }
    }
}
