# URLComponents Parameter Parsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-rolled string splitting in `URLParametersReader.parseURLParameters(_:)` with Foundation's `URLComponents`, preserving observable behavior for well-formed request bodies.

**Architecture:** A private `normalized(_:)` pre-pass rewrites the raw body into a strictly valid URL query component — passing existing `%XX` escapes through verbatim, keeping characters legal in a query, and percent-encoding everything else. `URLComponents` then does all the splitting and decoding. The pre-pass exists because a single character illegal in a query (a raw space, for instance) otherwise puts Foundation on a lenient path where it treats the whole query as literal text and stops percent-decoding every parameter in the body.

**Tech Stack:** Swift 6 language mode, Foundation (`URLComponents`, `CharacterSet`), XCTest, SwiftPM.

**Spec:** `docs/superpowers/specs/2026-08-07-urlcomponents-parameter-parsing-design.md`

---

## Background the engineer needs

`Ambassador` is a Swift web framework used to mock HTTP APIs in UI tests. `URLParametersReader` parses `application/x-www-form-urlencoded` request bodies into `[(String, String)]` pairs.

Build and test with SwiftPM only — the Xcode project in this repo is broken and cannot build:

```bash
swift build
swift test --filter URLParametersReaderTests
```

Sources live in `Ambassador/` and tests in `AmbassadorTests/` (not SwiftPM's default `Sources/`/`Tests/`). This is deliberate; don't restructure it.

The package builds in Swift 6 language mode with strict concurrency on, and compiles clean at that setting today. If a change produces a Sendable or actor-isolation error, fix the code — do not downgrade the language mode.

`.swiftlint.yaml` disables `force_cast`, `force_try`, and `todo`. This library is deliberately force-unwrap-heavy; failing loudly is the design choice.

### Two facts that will save you time

1. Tuples are not `Equatable` in Swift, so `XCTAssertEqual` cannot compare `[(String, String)]` directly. Task 1 adds a helper for this. Use it.
2. `parseURLParameters` is `public` API. Its signature must not change.

---

## File Structure

- **Modify:** `Ambassador/Readers/URLParametersReader.swift` — the only source file touched. Gains one `private static let` and two `private static func`s; `parseURLParameters(_:)` body is replaced. `read(_:errorHandler:handler:)` and `LocalError` are untouched.
- **Modify:** `AmbassadorTests/URLParametersReaderTests.swift` — gains a comparison helper and three test methods. The two existing tests stay as they are.

No files created. No new dependencies.

---

### Task 1: Lock in the behavior that must survive

This is a safety net, not TDD-red. These assertions describe what the *current* implementation already does, so they must pass **before** any source change. That is what makes them useful: if Task 2 breaks one, you'll know immediately and precisely.

**Files:**
- Test: `AmbassadorTests/URLParametersReaderTests.swift`

- [ ] **Step 1: Add the comparison helper and the characterization test**

Add both of these inside the existing `URLParametersReaderTests` class, after the existing `testURLParameterReader` method.

The helper takes `file`/`line` so a failure points at the calling assertion line rather than at the helper:

```swift
    // MARK: - Helpers

    /// Tuples aren't Equatable, so compare pair-by-pair and report which pair diverged.
    private func assertParams(
        _ input: String,
        _ expected: [(String, String)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = URLParametersReader.parseURLParameters(input)
        XCTAssertEqual(
            actual.count,
            expected.count,
            "pair count for \(input.debugDescription)",
            file: file,
            line: line
        )
        for (index, pair) in zip(actual, expected).enumerated() {
            XCTAssertEqual(
                pair.0.0,
                pair.1.0,
                "key \(index) for \(input.debugDescription)",
                file: file,
                line: line
            )
            XCTAssertEqual(
                pair.0.1,
                pair.1.1,
                "value \(index) for \(input.debugDescription)",
                file: file,
                line: line
            )
        }
    }
```

Then the characterization test:

```swift
    func testParseURLParametersPreservedBehavior() {
        assertParams("foo=bar&eggs=spam", [("foo", "bar"), ("eggs", "spam")])
        assertParams("foo%5Bbar%5D=eggs%20spam", [("foo[bar]", "eggs spam")])

        // A key with no `=` yields an empty value.
        assertParams("foo", [("foo", "")])
        assertParams("foo=", [("foo", "")])
        assertParams("=bar", [("", "bar")])

        // Only the first `=` is a delimiter.
        assertParams("foo=a=b", [("foo", "a=b")])

        // `+` is NOT form-decoded to a space.
        assertParams("a+b=c+d", [("a+b", "c+d")])

        // Duplicate keys keep their order.
        assertParams("foo=a&foo=b", [("foo", "a"), ("foo", "b")])

        // Empty segments produce empty pairs.
        assertParams("foo=a&&b=c", [("foo", "a"), ("", ""), ("b", "c")])
        assertParams("foo=a&b", [("foo", "a"), ("b", "")])

        // Non-ASCII, both escaped and raw.
        assertParams("foo=caf%C3%A9", [("foo", "café")])
        assertParams("foo=café", [("foo", "café")])
        assertParams("foo=👍", [("foo", "👍")])

        // Malformed escapes are left alone rather than dropped.
        assertParams("foo=%ZZ", [("foo", "%ZZ")])
        assertParams("foo=100%", [("foo", "100%")])
        assertParams("foo=a%2", [("foo", "a%2")])

        // `#` and `?` are data in a form body, not URL delimiters.
        assertParams("foo=a#b", [("foo", "a#b")])
        assertParams("a=1&b=2#frag", [("a", "1"), ("b", "2#frag")])
        assertParams("foo=a?b", [("foo", "a?b")])

        // An unencoded character must not disable decoding for the rest of the body.
        assertParams("a b=c%20d", [("a b", "c d")])
        assertParams("foo=a b&x%5By%5D=z", [("foo", "a b"), ("x[y]", "z")])
    }
```

- [ ] **Step 2: Run the test against the unmodified source**

```bash
swift test --filter URLParametersReaderTests
```

Expected: PASS, 3 tests. Every assertion describes existing behavior.

If any assertion fails here, **stop and report it** — it means the current implementation differs from what the spec measured, and the rest of the plan rests on that measurement.

- [ ] **Step 3: Commit**

```bash
git add AmbassadorTests/URLParametersReaderTests.swift
git commit -m "test: characterize URL parameter parsing behavior

Locks in delimiter handling, percent-decoding, and malformed-input
behavior before swapping the parser to URLComponents."
```

---

### Task 2: Swap the parser to URLComponents

**Files:**
- Test: `AmbassadorTests/URLParametersReaderTests.swift`
- Modify: `Ambassador/Readers/URLParametersReader.swift:46-57` (the `parseURLParameters` body)

- [ ] **Step 1: Write the failing tests**

Add these two methods to `URLParametersReaderTests`, after `testParseURLParametersPreservedBehavior`. Both describe the deliberate behavior changes from the spec:

```swift
    /// An empty body has no parameters. The old parser reported a phantom `("", "")`.
    func testParseURLParametersEmptyString() {
        assertParams("", [])
    }

    /// A stray `%` no longer discards decoding for the whole field — only that
    /// character is treated as literal. The old parser returned `("x", "%%20")`.
    func testParseURLParametersLonePercentStillDecodesRemainingEscapes() {
        assertParams("x=%%20", [("x", "% ")])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter URLParametersReaderTests
```

Expected: FAIL, 2 failures.
- `testParseURLParametersEmptyString`: `XCTAssertEqual failed: ("1") is not equal to ("0") - pair count for ""`
- `testParseURLParametersLonePercentStillDecodesRemainingEscapes`: `XCTAssertEqual failed: ("%%20") is not equal to ("% ") - value 0 for "x=%%20"`

`testParseURLParametersPreservedBehavior` must still PASS.

- [ ] **Step 3: Add the normalization helpers**

In `Ambassador/Readers/URLParametersReader.swift`, add the `queryAllowed` constant directly below the `LocalError` enum (before `read`):

```swift
    /// Characters that may appear literally in a URL query component. `%` is excluded so
    /// existing escape sequences can be passed through explicitly rather than re-encoded,
    /// and `#` so that it can't be mistaken for the start of a fragment.
    private static let queryAllowed = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "%#"))
```

Then add these two methods at the end of the struct, after `parseURLParameters`:

```swift
    /// Rewrite a raw request body into a strictly valid URL query component, preserving any
    /// percent escapes it already contains.
    ///
    /// This pre-pass is what makes `URLComponents` usable here. Given a query containing any
    /// character that is illegal in a query component — an unencoded space, say — Foundation
    /// falls back to treating the entire query as literal text and stops percent-decoding
    /// every parameter in the body, not just the offending one.
    private static func normalized(_ string: String) -> String {
        let scalars = Array(string.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "%",
                index + 2 < scalars.count,
                isHexDigit(scalars[index + 1]),
                isHexDigit(scalars[index + 2]) {
                // Already a valid escape sequence — pass it through untouched.
                result.append(contentsOf: scalars[index...(index + 2)])
                index += 3
            } else if queryAllowed.contains(scalar) {
                result.append(scalar)
                index += 1
            } else {
                // Illegal in a query component (including a `%` that doesn't begin a valid
                // escape), so encode it and let URLComponents decode it back.
                let escaped = String(scalar)
                    .addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
                result.append(contentsOf: escaped.unicodeScalars)
                index += 1
            }
        }
        return String(result)
    }

    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar)
            || ("a"..."f").contains(scalar)
            || ("A"..."F").contains(scalar)
    }
```

The `index + 2 < scalars.count` bounds check is load-bearing: a `%` with fewer than two scalars after it (`foo=a%2`, `foo=%`) must fall through to the encode branch rather than read past the end.

- [ ] **Step 4: Replace the `parseURLParameters` body**

Replace the body only. Keep the existing doc comment and signature exactly as they are:

```swift
    /// Parse given string as URL parameters
    ///  - Parameter string: URL encoded parameter string to parse
    ///  - Returns: array of (key, value) pairs of URL encoded parameters
    public static func parseURLParameters(_ string: String) -> [(String, String)] {
        guard let components = URLComponents(string: "?" + normalized(string)),
            let items = components.queryItems else {
            return []
        }
        return items.map { ($0.name, $0.value ?? "") }
    }
```

`$0.value ?? ""` is what collapses a valueless key (`foo`) to `("foo", "")`, matching the old parser.

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter URLParametersReaderTests
```

Expected: PASS, 5 tests. All of Task 1's characterization assertions must still pass — that is the point of them.

- [ ] **Step 6: Commit**

```bash
git add Ambassador/Readers/URLParametersReader.swift AmbassadorTests/URLParametersReaderTests.swift
git commit -m "refactor: parse URL parameters with URLComponents

Replaces manual & / = splitting with URLComponents, fronted by a
normalization pass that rewrites the body into a strictly valid query
component. Without it, one character illegal in a query makes Foundation
stop percent-decoding every parameter in the body.

Two deliberate changes: an empty body now yields no pairs instead of a
phantom empty pair, and a stray % no longer discards decoding for the
rest of its field."
```

---

### Task 3: Verify the whole package

- [ ] **Step 1: Run the full test suite**

```bash
swift test
```

Expected: PASS. The suite was 9 tests before this work and is 12 after (3 added). No other suite touches `URLParametersReader`.

- [ ] **Step 2: Confirm Swift 6 strict concurrency is still clean**

The new `private static let queryAllowed: CharacterSet` is the only new global state, and `CharacterSet` is `Sendable`, so this should be clean.

```bash
swift build 2>&1 | grep -iE 'sendable|isolation|concurrency|warning|error' || echo "CLEAN"
```

Expected: `CLEAN`.

If anything appears, fix the code. Do not add `@unchecked Sendable` and do not set `swiftLanguageMode(.v5)`.

- [ ] **Step 3: Lint**

```bash
swiftlint lint --quiet Ambassador/Readers/URLParametersReader.swift
```

Expected: no output.

If `swiftlint` isn't installed, skip this step and say so in your report rather than silently passing it.

- [ ] **Step 4: Confirm the diff is scoped**

```bash
git diff --stat HEAD~2 -- Ambassador AmbassadorTests
```

Expected: exactly two files — `Ambassador/Readers/URLParametersReader.swift` and `AmbassadorTests/URLParametersReaderTests.swift`.

The working tree has unrelated pre-existing modifications (`.travis.yml`, `EnvoyAmbassador.podspec`, `Ambassador/Responses/DataResponse.swift`). Leave them alone — do not stage or revert them.

- [ ] **Step 5: Commit any fixes**

Only if Steps 2 or 3 required changes:

```bash
git add Ambassador/Readers/URLParametersReader.swift
git commit -m "fix: address lint and concurrency findings in URLParametersReader"
```

---

## Out of scope

- `README.md` needs no change. `parseURLParameters` keeps its signature, and the documented example (`foo=bar&eggs=spam`) parses identically.
- `read(_:errorHandler:handler:)`, `LocalError`, and `DataReader` are untouched. No new error case: malformed input still parses best-effort rather than routing to `errorHandler`.
- Linux is out of scope per the spec. All behavior was measured on Swift 6.3.2 / macOS 26.5 Foundation.
