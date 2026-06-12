import XCTest
@testable import CopyTranslateCore

final class EnvParsingTests: XCTestCase {
    func testPlain() {
        XCTAssertEqual(EnvParsing.parseAPIKey(fromFileContents: "ANTHROPIC_API_KEY=sk-abc"), "sk-abc")
    }
    func testExportPrefix() {
        XCTAssertEqual(EnvParsing.parseAPIKey(fromFileContents: "export ANTHROPIC_API_KEY=sk-xyz"), "sk-xyz")
    }
    func testDoubleQuoted() {
        XCTAssertEqual(EnvParsing.parseAPIKey(fromFileContents: "ANTHROPIC_API_KEY=\"sk-q\""), "sk-q")
    }
    func testSingleQuoted() {
        XCTAssertEqual(EnvParsing.parseAPIKey(fromFileContents: "ANTHROPIC_API_KEY='sk-s'"), "sk-s")
    }
    func testIgnoresOtherKeysAndComments() {
        let body = "# comment\nOTHER=1\nANTHROPIC_API_KEY=sk-real\nMORE=2"
        XCTAssertEqual(EnvParsing.parseAPIKey(fromFileContents: body), "sk-real")
    }
    func testMissingAndEmpty() {
        XCTAssertNil(EnvParsing.parseAPIKey(fromFileContents: "NOPE=1"))
        XCTAssertNil(EnvParsing.parseAPIKey(fromFileContents: "ANTHROPIC_API_KEY="))
        XCTAssertNil(EnvParsing.parseAPIKey(fromFileContents: "ANTHROPIC_API_KEY=\"\""))
    }
}

final class PromptCacheTests: XCTestCase {
    func testPromptIncludesTarget() {
        let p = PromptBuilder.translationPrompt(target: "French")
        XCTAssertTrue(p.contains("to French"))
        XCTAssertTrue(p.contains("Output ONLY the translation"))
    }
    func testCacheKeyDistinguishesLanguagePrefixes() {
        // "Chinese (Simplified)" vs "Chinese (Traditional)" must not collide.
        let a = CacheKey.make(language: "Chinese (Simplified)", source: "hi")
        let b = CacheKey.make(language: "Chinese (Traditional)", source: "hi")
        XCTAssertNotEqual(a, b)
    }
    func testCacheKeyStable() {
        XCTAssertEqual(CacheKey.make(language: "Spanish", source: "hi"), "7:Spanish|hi")
    }
}

final class DoubleTapTests: XCTestCase {
    func testFirstTapStartsTimer() {
        let r = DoubleTap.evaluate(now: 1000.0, last: 0, window: 0.4)
        XCTAssertFalse(r.isDouble)
        XCTAssertEqual(r.newLast, 1000.0)
    }
    func testSecondTapInsideWindowFires() {
        let r = DoubleTap.evaluate(now: 1000.3, last: 1000.0, window: 0.4)
        XCTAssertTrue(r.isDouble)
        XCTAssertEqual(r.newLast, 0)
    }
    func testSecondTapOutsideWindowResets() {
        let r = DoubleTap.evaluate(now: 1001.0, last: 1000.0, window: 0.4)
        XCTAssertFalse(r.isDouble)
        XCTAssertEqual(r.newLast, 1001.0)
    }
    func testWindowBoundaryInclusive() {
        let r = DoubleTap.evaluate(now: 1000.4, last: 1000.0, window: 0.4)
        XCTAssertTrue(r.isDouble)
    }
}

final class SSEParserTests: XCTestCase {
    func testParsesTextDelta() {
        let line = #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hola"}}"#
        let json = SSEParser.dataPayload(from: line)
        XCTAssertNotNil(json)
        XCTAssertEqual(SSEParser.textDelta(fromDataJSON: json!), "Hola")
    }
    func testIgnoresEventAndOtherLines() {
        XCTAssertNil(SSEParser.dataPayload(from: "event: content_block_delta"))
        XCTAssertNil(SSEParser.dataPayload(from: ""))
        XCTAssertNil(SSEParser.dataPayload(from: "data: [DONE]"))
    }
    func testNonTextDeltaReturnsNil() {
        let line = #"data: {"type":"message_start","message":{"id":"msg_1"}}"#
        let json = SSEParser.dataPayload(from: line)!
        XCTAssertNil(SSEParser.textDelta(fromDataJSON: json))
    }
    func testMessageStop() {
        let json = SSEParser.dataPayload(from: #"data: {"type":"message_stop"}"#)!
        XCTAssertTrue(SSEParser.isMessageStop(json))
    }
    func testAccumulateMultiChunk() {
        let lines = [
            "event: message_start",
            #"data: {"type":"message_start","message":{}}"#,
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Bon"}}"#,
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"jour"}}"#,
            "garbage line that should be skipped",
            #"data: {"type":"message_stop"}"#,
        ]
        XCTAssertEqual(SSEParser.accumulatedText(from: lines), "Bonjour")
    }
}
