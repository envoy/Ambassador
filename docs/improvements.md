# Ambassador improvements

Tracking list for improvements to the Ambassador Swift package. Findings come from a review of
`Ambassador/` and of how envoy-ipad's UI tests use it
(`iPadVisitors/envoy-ipad-releases/EnvoyUITests`). Usage counts below refer to that directory.

Last released version: `v4.0.5`.

## How to use this file

- Each item has an ID (`B` bug, `P` performance, `A` API/ease of use, `C` consolidation).
- **Status**: `proposed` → `chosen` → `in progress` → `done` (with PR link), or `declined` (with reason).
- **Breaking** says whether the change can break consumers' source or runtime behavior.
- Mark an item `chosen` before starting work on it. Group chosen items into PRs in the
  [PR plan](#pr-plan).

## Open decisions

| # | Decision | Options | Answer |
|---|---|---|---|
| D1 | `DelayResponse` default delay (see P1) | (a) change the default to `.none` or a small fixed delay; (b) keep the default and add a process-wide override | **(b)** keep default, add override |
| D2 | Tolerance for breaking changes | (a) major bump (`v5.0.0`) allowed; (b) source-compatible only, deprecate instead of remove | **(a)** major bump allowed |
| D3 | Order of work | Suggested: bugs + P3 first, then API additions, then consolidation | Bugs + P3 first; rest stays proposed |

## Summary

| ID | Title | Lens | Breaking | Status |
|---|---|---|---|---|
| B1 | Router data race between registration and matching | Bug | No | in progress |
| B2 | Router `NSRange` uses Character count, not UTF-16 | Bug | No | in progress |
| B3 | Assigning `nil` to a route crashes | Bug | No | in progress |
| B4 | `URLParametersReader` doesn't decode `+` as space | Bug | Behavior | declined |
| B5 | Linux `DelayResponse` reseeds the RNG on every call | Bug | No | in progress |
| P1 | `DelayResponse` defaults to a 0.1–3 s random delay | Speed | Depends on D1 | proposed |
| P2 | Body-parse failures hang until client timeout | Speed | Behavior | proposed |
| P3 | Router recompiles every regex on every request | Speed | No | in progress |
| A1 | Typed environ accessors and environ-taking reader overloads | API | No (additive) | proposed |
| A2 | Keyed result from `URLParametersReader` | API | No (additive) | proposed |
| A3 | `.delayed(...)` modifier on `WebApp` | API | No (additive) | proposed |
| A4 | `JSONResponse(json:)` / `Encodable` convenience | API | No (additive) | proposed |
| A5 | Derive default status message from status code | API | Behavior | proposed |
| C1 | Typealiases for the SWSGI callback signatures | Consolidation | No | proposed |
| C2 | Sync inits delegate to async inits | Consolidation | No | proposed |
| C3 | Shared decode helper for readers; readers become `enum`s | Consolidation | Minor | proposed |
| C4 | `DelayResponse` schedules one flush instead of three timers | Consolidation | No | proposed |
| C5 | Small cleanups (`SWGIWebApp` rename, doc fixes, IUO) | Consolidation | No (with deprecation) | proposed |
| X1 | Make `WebApp` `Sendable` / add an `async` API | — | Yes | declined for now |

## Bugs

### B1 — Router data race between registration and matching
- **Where:** `Ambassador/Router.swift`, `matchRoute(to:)`.
- **Problem:** The subscript takes the `DispatchSemaphore`, but `matchRoute` iterates `routes`
  without it. Tests register routes mid-test (`router[...] = ...` throughout `Functional/`) while
  the event loop is serving requests, so reads and writes of the dictionary are unsynchronized.
  Likely source of flakiness.
- **Proposal:** Replace the semaphore with a lock (`NSLock`, portable to Linux) that guards both the
  subscript and a snapshot of the routes taken in `app(_:startResponse:sendBody:)`.
- **Test:** `RouterTests.testConcurrentRegistrationAndDispatch`. Under `swift test --sanitize=thread`
  the old Router crashes on it; the new one is clean.
- **Not covered:** `notFoundResponse` is still an unsynchronized `open var`. Low risk (it's rarely
  reassigned mid-test); revisit with X1.
- **Status:** in progress (PR 1)

### B2 — Router `NSRange` uses Character count, not UTF-16
- **Where:** `Router.matchRoute`, `NSRange(location: 0, length: searchPath.count)`.
- **Problem:** `String.count` counts grapheme clusters; `NSRegularExpression` works in UTF-16
  units. Paths containing non-ASCII characters are matched against a truncated range.
- **Proposal:** `NSRange(searchPath.startIndex..., in: searchPath)`; extract captures with
  `Range(match.range(at:), in:)`. An optional group that didn't participate now captures `""`
  (keeps capture indices stable) instead of crashing. Also switched `matches(in:)` → `firstMatch(in:)`.
- **Status:** in progress (PR 1)

### B3 — Assigning `nil` to a route crashes
- **Where:** `Router.subscript` setter, `routes[path] = newValue!`.
- **Problem:** The subscript is typed `WebApp?` but removing a route traps.
- **Proposal:** `routes[path] = newValue` (removes on `nil`).
- **Status:** in progress (PR 1)

### B4 — `URLParametersReader` doesn't decode `+` as space
- **Where:** `URLParametersReader.parseURLParameters`.
- **Problem:** `application/x-www-form-urlencoded` bodies encode spaces as `+`. They currently
  come through literally. An empty input also yields `[("", "")]`.
- **Proposal:** Replace `+` with a space before percent-decoding; drop empty pairs.
- **Breaking:** Behavior change. envoy-ipad relies on the current parsing, so this is not safe to
  change.
- **Status:** declined — envoy-ipad depends on the existing parsing behavior; leave `URLParametersReader` as is

### B5 — Linux `DelayResponse` reseeds the RNG on every call
- **Where:** `DelayResponse.app`, `#if os(Linux)` branch.
- **Problem:** `srandom(UInt32(time(nil)))` on every request gives requests in the same second the
  same "random" delay.
- **Proposal:** `TimeInterval.random(in: min...max)` for all platforms; removes the `#if`.
- **Status:** in progress (PR 1)

## Performance (consumer speed)

### P1 — `DelayResponse` defaults to a 0.1–3 s random delay
- **Where:** `DelayResponse.init(_:delay:)`, default `.random(min: 0.1, max: 3)`.
- **Evidence:** 38 `DelayResponse(` call sites in envoy-ipad; only 4 pass `delay:`. The other ~34
  mocked endpoints each wait about 1.5 s on average (up to 3 s) per request.
- **Proposal:** Depends on **D1**:
  - (a) Change the default to `.none` or a small fixed delay. Changes behavior; some tests may rely
    on the delay to observe loading states.
  - (b) Keep the default, add a process-wide override (e.g. `DelayResponse.defaultDelay`, or an
    environment variable) so CI can run without the waits.
- **Status:** proposed

### P2 — Body-parse failures hang until client timeout
- **Where:** `JSONReader.read`, `URLParametersReader.read`.
- **Problem:** When decoding fails and no `errorHandler` is passed, the error is swallowed and no
  response is sent. The client waits for the URLSession timeout (60 s by default). Only 2 of ~24
  reader call sites in envoy-ipad pass an `errorHandler`.
- **Proposal:** Make failures visible by default. Options: fail loudly (`assertionFailure` or log),
  or give readers access to `startResponse` so they can reply 400. Pick one during design.
- **Status:** proposed

### P3 — Router recompiles every regex on every request
- **Where:** `Router.matchRoute`, `try! NSRegularExpression(pattern:)` in the loop.
- **Problem:** Each request compiles a regex for every route until one matches. A bad pattern
  crashes on the event-loop thread mid-test instead of at the registration site.
- **Proposal:** Compile once in the subscript setter and store `(NSRegularExpression, WebApp)`.
- **Status:** in progress (PR 1)

## API / ease of use

### A1 — Typed environ accessors and environ-taking reader overloads
- **Evidence:** `environ["swsgi.input"] as! SWSGIInput` ×12; envoy-ipad ships its own
  `JSONReader+Extension.swift` and `Dictionary+Getters.swift` to paper over this.
- **Proposal:** Extension on `[String: Any]` with `swsgiInput`, `pathInfo`, `requestMethod`,
  `queryString`, `routerCaptures`; overloads such as `JSONReader.read(environ) { ... }`.
- **Status:** proposed

### A2 — Keyed result from `URLParametersReader`
- **Evidence:** `MultiDictionary<String, String, NoOpKeyTransform<String>>(items: params)` ×9.
- **Proposal:** An overload or companion that hands back a keyed lookup directly.
- **Status:** proposed

### A3 — `.delayed(...)` modifier on `WebApp`
- **Evidence:** envoy-ipad's `DelayResponse+minMax.swift` adds its own factories.
- **Proposal:** `extension WebApp { func delayed(_ delay: DelayResponse.Delay = ...) -> DelayResponse }`,
  so call sites read `JSONResponse(...).delayed(.delay(seconds: 0.05))`.
- **Status:** proposed

### A4 — `JSONResponse(json:)` / `Encodable` convenience
- **Evidence:** `handler: ({ _ -> Any in ... })` ×12. The annotation is needed because the two
  `handler:` initializers are ambiguous for a one-argument closure.
- **Proposal:** `JSONResponse(json: [...])` for fixed payloads; optionally an `Encodable` overload
  using `JSONEncoder`.
- **Status:** proposed

### A5 — Derive default status message from status code
- **Evidence:** `JSONResponse(statusCode: 204, ...)` sends `"204 OK"`.
- **Proposal:** Make `statusMessage` default to the standard reason phrase for the code.
- **Breaking:** Behavior change on the wire; clients rarely read the reason phrase.
- **Status:** proposed

## Consolidation

### C1 — Typealiases for the SWSGI callback signatures
- **Problem:** `(String, [(String, String)]) -> Void` and `(Data) -> Void` are spelled out 7 times.
- **Proposal:** Public `StartResponse`, `SendBody`, `Environ` typealiases. Source-compatible.
- **Status:** proposed

### C2 — Sync inits delegate to async inits
- **Problem:** `DataResponse` and `JSONResponse` each have a sync and async init with duplicated
  bodies; JSON serialization appears twice.
- **Proposal:** Sync init calls `self.init(...)` with a wrapping closure; one serialization site.
- **Status:** proposed

### C3 — Shared decode helper for readers; readers become `enum`s
- **Problem:** `JSONReader` and `URLParametersReader` repeat "read all, decode, route the error".
- **Proposal:** One private helper on `DataReader`. Make the static-only namespaces `enum`s so they
  can't be instantiated. (Breaks only code that writes `DataReader()`, which nothing does.)
- **Status:** proposed

### C4 — `DelayResponse` schedules one flush instead of three timers
- **Problem:** Headers, body, and EOF each get their own `call(withDelay:)`, relying on timer
  ordering.
- **Proposal:** Buffer the wrapped app's output and flush it in one scheduled call after EOF.
  Delaying the whole wrapped app instead is simpler, but handlers reading the request body would
  start late; that is only safe if Embassy buffers input, which is unverified.
- **Status:** proposed

### C5 — Small cleanups
- Rename `SWGIWebApp` → `SWSGIWebApp`, keep the old name as a deprecated typealias (unused in envoy-ipad).
- Fix the `DataResponse.handler` doc comment ("generating JSON response").
- Replace `var delayTime: TimeInterval!` with a `let` built from a `switch` expression.
- **Status:** proposed

## Declined / deferred

### X1 — Make `WebApp` `Sendable` / add an `async` API
- **Reason:** Would break most of envoy-ipad's handlers (they capture non-`Sendable` test state),
  and Embassy's callback-based event loop doesn't bridge cleanly to async/await. Revisit if Embassy
  adopts Swift concurrency.
- **Status:** declined for now

## PR plan

| PR | Items | Status | Link |
|---|---|---|---|
| 1 | B1, B2, B3, B5, P3 — Router fixes and reader/delay bug fixes | in progress | |

## Consumer follow-ups (envoy-ipad)

Changes to make in envoy-ipad once the corresponding items ship:

- _none yet_
