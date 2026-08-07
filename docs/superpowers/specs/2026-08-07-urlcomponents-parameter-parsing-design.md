# Convert `parseURLParameters` to `URLComponents`

Date: 2026-08-07
Status: Approved, ready for implementation planning

## Goal

Replace the hand-rolled string splitting in
`URLParametersReader.parseURLParameters(_:)` with Foundation's `URLComponents`,
without changing observable behavior for well-formed request bodies.

## Scope

In scope: `parseURLParameters(_:)` and one new private helper.

Out of scope, explicitly unchanged:

- `read(_:errorHandler:handler:)` and its `DataReader` layering
- `LocalError` (no new cases)
- The public signature `[(String, String)]`
- `README.md` API docs (the documented example parses identically)

No new dependency.

## Why the obvious idioms don't work

All findings below were measured on Swift 6.3.2 / macOS 26.5 SDK, comparing each
candidate to the current implementation. The corpus grew as candidates were
eliminated — 17 inputs initially, 28 once the `#` fix was in, 32 by the final
comparison — so the ratios below are stated against the corpus size at that
point.

### `components.percentEncodedQuery = string` — crashes

The setter traps on any character illegal in a query component:

```
Foundation/URLComponents.swift:1022: Fatal error:
Attempting to set percentEncodedQuery with invalid characters
```

Triggered by a raw space, `#`, or a stray `%`. Four of the first 17 corpus
inputs killed the process. Unusable for parsing arbitrary request bodies.

### `URLComponents(string: "?" + string)` — silently truncates at `#`

`#` opens the fragment, so everything after it is dropped from the query:

| input | current | naive `URLComponents` |
|---|---|---|
| `a=1&b=2#frag` | `("b", "2#frag")` | `("b", "2")` |
| `foo=a b&#x=y` | `("#x", "y")` | `("", "")` |

Fixable by pre-escaping `#` to `%23`, which brings the corpus to 26/28.

### The compat path — the finding that shaped the design

A single character illegal in a URL query puts Foundation on a lenient parse
path where it treats the **entire** query as literal text and stops
percent-decoding **every** parameter in the body:

| input | current | `URLComponents` |
|---|---|---|
| `a b=c%20d` | `("a b", "c d")` | `("a b", "c%20d")` |
| `foo=a b&x%5By%5D=z` | `("x[y]", "z")` | `("x%5By%5D", "z")` |

This is inherent, not an idiom problem. `percentEncodedQueryItems` confirms it:
for `a b=c%20d` it returns `c%2520d`, proving Foundation stored the value as
literal text and re-encoded the `%` on the way out.

The current code is immune because it decodes each field independently via
`removingPercentEncoding ?? raw`.

### An absolute fake-scheme URL does not help

`URLComponents(string: "x://h/?" + string)` produces results identical to the
relative form on every corpus input. The compat path is triggered by query
content, not by the URL being relative.

### There is no failure signal to fall back on

`URLComponents(string:)` returned non-`nil` for **all 26** hostile inputs
tested (raw control characters, `%%%`, `%ZZ`, `\`, backtick, emoji, bare `&&&`).
It never reports failure — it returns wrong values. A
`guard let … else { legacyParse() }` fallback would therefore never fire on
precisely the inputs that need it. Any fallback must be driven by an explicit
validity check we write ourselves.

## Chosen approach: normalize, then parse

Rather than *detecting* invalid input and falling back to a retained manual
parser, rewrite the input into a strictly valid query component first. Then
`URLComponents` always takes its decoding path, and the manual parser is
deleted outright.

```swift
private static let queryAllowed = CharacterSet.urlQueryAllowed
    .subtracting(CharacterSet(charactersIn: "%#"))

public static func parseURLParameters(_ string: String) -> [(String, String)] {
    guard let components = URLComponents(string: "?" + normalized(string)),
          let items = components.queryItems
    else { return [] }
    return items.map { ($0.name, $0.value ?? "") }
}
```

`normalized(_:)` is a private static scalar scan with three rules:

1. `%` followed by two hex digits — copy the triplet verbatim. This is what
   prevents double-encoding of input that is already correctly escaped. The
   lookahead must be bounds-checked: a `%` with fewer than two scalars
   remaining (`foo=a%2`, `foo=%`) falls through to rule 3 and is escaped to
   `%25`, rather than reading past the end.
2. Scalar in `queryAllowed` — copy as-is. This keeps `&` and `=` structural,
   and leaves `+` untouched rather than form-decoding it to a space, matching
   current behavior.
3. Anything else — percent-encode it. Covers raw spaces, `#`, lone `%`, and
   control characters.

Rule 3 is the point of the design: it guarantees the string reaching
`URLComponents` is strictly RFC-valid, so the compat path is unreachable.

`$0.value ?? ""` collapses a valueless key (`foo`) to `("foo", "")`, as today.

### Why not the alternatives

- **Validate-and-fall-back** reaches exact 30/30 parity but retains the current
  parser *and* adds a ~12-line validator — roughly 3x the code for identical
  observable behavior.
- **Straight swap** is the smallest code but leaves the compat path live. A mock
  server handing a test `%20` instead of a space is a baffling failure to debug.
- **Don't convert** is defensible but does not meet the goal.

## Behavior changes

Two, both narrowing:

| input | current | after |
|---|---|---|
| `""` | `[("", "")]` | `[]` |
| `x=%%20` | `("x", "%%20")` | `("x", "% ")` |

The first drops a phantom empty pair for an empty body. The second is
per-character best-effort decoding replacing today's all-or-nothing
`removingPercentEncoding ?? raw`, which discards an entire field's decoding
because of one stray `%`.

Neither is covered by an existing test. Everything else in the 32-case corpus
is byte-identical, including `foo=a=b`, `a+b=c+d`, duplicate keys, `%ZZ`,
`100%`, `a=1&b=2#frag`, `foo=👍`, and raw UTF-8 (`foo=café`).

## Testing

`URLParametersReaderTests` currently has 2 tests covering 3 inputs. Extend
`testParseURLParameter` and add cases pinning:

- Delimiter rules: `foo=a=b`, `=bar`, `foo`, `foo=`, `foo=a&&b=c`, `foo=a&b`
- Duplicate keys preserve order: `foo=a&foo=b`
- `+` is not form-decoded: `a+b=c+d`
- The `#` case naive `URLComponents` breaks: `a=1&b=2#frag`
- Malformed escapes decode best-effort: `%ZZ`, `foo=100%`, `foo=a%2`
- The compat path is avoided: `a b=c%20d` must yield `("a b", "c d")`
- Non-ASCII: `foo=caf%C3%A9`, `foo=café`
- The two behavior changes above, asserted explicitly

`testURLParameterReader` needs no change; it exercises the `DataReader` path,
which is untouched.

## Constraints

- The package is `swift-tools-version: 6.0` and builds in Swift 6 language mode
  with strict concurrency. `private static let queryAllowed: CharacterSet`
  type-checks clean under `-swift-version 6 -strict-concurrency=complete`
  (verified). Do not downgrade the language mode to resolve any diagnostic.
- SwiftLint config disables `force_cast`, `force_try`, and `todo`. The
  `addingPercentEncoding` call in rule 3 uses a force-unwrap, consistent with
  the file's existing style.

## Risk

Every measurement above comes from Swift 6.3.2 / macOS 26.5 Foundation.
`normalized(_:)` is deterministic pure Swift and immune to platform variation,
but the `URLComponents` half is not — swift-corelibs-foundation on Linux has
historically diverged on query parsing, and Embassy supports Linux. The
expanded test suite is the guard. Linux was not verified.
