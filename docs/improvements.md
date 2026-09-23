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
| P1 | `DelayResponse` defaults to a 0.1–3 s random delay | Speed | Depends on D1 | deferred |
| P2 | Body-parse failures hang until client timeout | Speed | No | in progress |
| P3 | Router recompiles every regex on every request | Speed | No | in progress |
| A1 | Typed environ accessors and environ-taking reader overloads | API | No (additive) | in progress |
| A2 | Keyed result from `URLParametersReader` | API | No (additive) | in progress |
| A3 | `.delayed(...)` modifier on `WebApp` | API | No (additive) | in progress |
| A4 | `JSONResponse(json:)` / `Encodable` convenience | API | No (additive) | in progress |
| A5 | Derive default status message from status code | API | Behavior | proposed |
| A6 | Ambassador owns the SWSGI types in its public API | API | No (additive) | in progress |
| A7 | Server wrapper so consumers don't drive Embassy directly | API | No (additive) | proposed |
| C1 | Typealiases for the SWSGI callback signatures | Consolidation | No | done |
| C2 | Sync inits delegate to async inits | Consolidation | No | proposed |
| C3 | Shared decode helper for readers; readers become `enum`s | Consolidation | Minor | in progress |
| C4 | `DelayResponse` schedules one flush instead of three timers | Consolidation | No | deferred |
| C5 | Small cleanups (`SWGIWebApp` rename, doc fixes, IUO) | Consolidation | No (with deprecation) | partly done |
| C6 | SwiftLint config is never loaded (`.swiftlint.yaml` vs `.swiftlint.yml`) | Consolidation | No | done |
| C7 | `DataResponse` checks headers without `MultiDictionary` | Consolidation | No | in progress |
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
- **Status:** deferred — design sketched (lock-guarded `DelayResponse.defaultDelay`, read at request time); parked for now

### P2 — Body-parse failures hang until client timeout
- **Where:** `JSONReader.read`, `URLParametersReader.read`.
- **Problem:** When decoding fails and no `errorHandler` is passed, the error is swallowed and no
  response is sent. The client waits for the URLSession timeout (60 s by default). None of
  envoy-ipad's 9 `JSONReader` call sites pass an `errorHandler` (its `JSONReader+Extension` defaults
  it to `nil`); each sends its response and fulfills its test expectation only from the success
  handler.
- **Constraint:** Existing tests must not see a different response. Any response Ambassador sends on
  a parse failure (400, 500, empty 200) is a behavior change, so the default must be diagnostic only.
- **Decision:** Diagnostic only, no change on the wire. When a reader fails and no `errorHandler`
  was passed, it writes one line to stderr:
  `Ambassador: JSONReader failed to parse request body (N bytes): <error>. Handler not called; no response will be sent.`
  Consumers that want the test to fail fast pass an `errorHandler` (see consumer follow-ups).
- **Rejected:** replying 400/500 (changes responses tests see); `assertionFailure` (the server runs
  inside the UI-test process, so it would crash the whole run); a global error-hook setting in
  Ambassador (needs `nonisolated(unsafe)` / `@unchecked Sendable` under Swift 6).
- **Implementation:** `DataReader.logReadFailure`; `JSONReader`/`URLParametersReader` gain an
  internal `read(_:errorHandler:log:handler:)` overload so tests can capture the log.
- **Status:** in progress (PR 1)

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
- **Naming decision:** envoy-ipad's `Dictionary+Getters.swift` already defines `requestMethod`,
  `queryString`, `httpAuthorization` on `[String: Any]`, and `JSONReader+Extension` defines
  `JSONReader.read(environ:)`. Same-named public members would make envoy-ipad's call sites
  ambiguous, so Ambassador's accessors live under one property: `environ.swsgi.*`.
- **Implementation:** `SWSGIEnvironment` struct (`Ambassador/SWSGIEnvironment.swift`) with `input`,
  `requestMethod`, `pathInfo`, `queryString`, `contentType`, `routerCaptures`,
  `header(_:)`, and the raw `environ`. (`eventLoop` exists too but is internal; see A6.) `DataReader`/`JSONReader`/`URLParametersReader` gain
  unlabeled `read(_ environ:)` overloads (distinct from envoy-ipad's `read(environ:)`). Router and
  DelayResponse use the new accessors internally.
- **Status:** in progress

### A2 — Keyed result from `URLParametersReader`
- **Evidence:** `MultiDictionary<String, String, NoOpKeyTransform<String>>(items: params)` ×9.
- **Proposal:** An overload or companion that hands back a keyed lookup directly.
- **Naming:** `FormParameters`, not `URLParameters`: the reader parses the request body, not the
  URL; the format is the form encoding shared by bodies and query strings.
- **Implementation:** `FormParameters` (`Ambassador/Readers/FormParameters.swift`): ordered pairs,
  `params["key"]` (first value, case-sensitive, like the `MultiDictionary`/`NoOpKeyTransform`
  envoy-ipad uses), `values(for:)`, iterable as pairs, `init(parsing:)` over the unchanged
  `parseURLParameters` (B4 still declined). `URLParametersReader.readParameters(environ)` hands it
  to the handler; a `read` overload differing only in the handler's parameter type would make
  existing `{ params in ... }` calls ambiguous, hence the new name. `environ.swsgi.queryParameters`
  parses `QUERY_STRING` (empty when absent or empty), replacing envoy-ipad's
  `TestHelper.parseQueryParameters`.
- **Status:** in progress

### A3 — `.delayed(...)` modifier on `WebApp`
- **Evidence:** envoy-ipad's `DelayResponse+minMax.swift` adds its own factories.
- **Proposal:** `extension WebApp { func delayed(_ delay: DelayResponse.Delay = ...) -> DelayResponse }`,
  so call sites read `JSONResponse(...).delayed(.delay(seconds: 0.05))`.
- **Implementation:** Default is the same `.random(min: 0.1, max: 3)` literal as `DelayResponse.init`.
  A shared `defaultDelay` constant was left out on purpose: it would have to be public (it's used in
  a default argument) and would pre-empt P1's override API.
- **Status:** in progress

### A4 — `JSONResponse(json:)` / `Encodable` convenience
- **Evidence:** `handler: ({ _ -> Any in ... })` ×12. The annotation is needed because the two
  `handler:` initializers are ambiguous for a one-argument closure.
- **Proposal:** `JSONResponse(json: [...])` for fixed payloads; optionally an `Encodable` overload
  using `JSONEncoder`.
- **Implementation:** `JSONResponse(json:)` and `JSONResponse(encoding:encoder:)`, plus the reader
  side `JSONReader.decode(_:from:decoder:)` (input or environ) built on C3's helper. Encoder and
  decoder are injectable for key/date strategies. Separate labels rather than more `handler:`
  overloads: an `Encodable`-returning `handler:` would silently switch a closure returning
  `["a": "b"]` from `JSONSerialization` (pretty-printed) to `JSONEncoder`.
- **Timing decision:** `json:` and `encoding:` are `@autoclosure`s, evaluated per request like a
  handler body. envoy-ipad's handlers read state (e.g. `self.deviceConfig`) that tests change after
  registration, so evaluating once would serve stale data.
- **Test:** `AmbassadorTests/JSONConvenienceTests.swift` (Swift Testing), including a check that
  existing trailing-closure calls still pick the `handler:` initializers.
- **Status:** in progress

### A6 — Ambassador owns the SWSGI types in its public API
- **Problem:** Ambassador's public API names Embassy types (`SWSGIStartResponse`, `SWSGISendBody`
  in `WebApp`; `SWSGI` in `SWGIWebApp`; `SWSGIInput` in `environ.swsgi.input` and the readers;
  `EventLoop` in `environ.swsgi.eventLoop`) without re-exporting them. Conforming to `WebApp` or
  calling a reader with an input therefore needs `import Embassy` as well.
- **Constraint:** Don't `@_exported import Embassy`; keep the server/event-loop side of Embassy
  out of Ambassador's surface.
- **Implementation:** `Ambassador/SWSGI.swift` declares `SWSGI`, `SWSGIStartResponse`,
  `SWSGISendBody`, `SWSGIInput` with the same function types as Embassy, so they are the same
  types. Verified in a scratch package that a module importing both Ambassador and Embassy still
  compiles with no ambiguity. (`Embassy.SWSGI` can't be written because Embassy's `enum Embassy`
  shadows the module name, so the types are spelled out.) `environ.swsgi.eventLoop` is internal
  (it was unreleased; only `DelayResponse` uses it). Tests drop `import Embassy`. In the library,
  only `SWSGIEnvironment` and `DelayResponse` still `import Embassy` (since C7).
- **Keep in sync:** if Embassy changes these signatures, `SWSGI.swift` must follow, or
  `Router.app` stops matching `DefaultHTTPServer(app:)`.
- **Status:** in progress

### A7 — Server wrapper so consumers don't drive Embassy directly
- **Evidence:** envoy-ipad's `UITestBase` builds `SelectorEventLoop(selector: KqueueSelector())`
  and `DefaultHTTPServer`, runs the loop on its own `Thread`, and tears down with an `NSCondition`
  wait loop. `EventCenter` holds an `EventLoop`. These are the remaining reasons (with A2's
  `MultiDictionary`) that envoy-ipad imports Embassy.
- **Proposal:** Something like `MockServer(port:router:)` with `start()` / `stop()` that owns the
  loop, server, and thread. Needs its own design pass (logging, port selection, scheduling work
  on the loop from tests).
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
- **Status:** done — `WebApp` and the responses use `SWSGIStartResponse` / `SWSGISendBody`
  (`@Sendable`), declared by Ambassador since A6. `Environ` still proposed.

### C2 — Sync inits delegate to async inits
- **Problem:** `DataResponse` and `JSONResponse` each have a sync and async init with duplicated
  bodies; JSON serialization appears twice.
- **Proposal:** Sync init calls `self.init(...)` with a wrapping closure; one serialization site.
- **Status:** proposed

### C3 — Shared decode helper for readers; readers become `enum`s
- **Problem:** `JSONReader` and `URLParametersReader` repeat "read all, decode, route the error".
- **Proposal:** One private helper on `DataReader`. Make the static-only namespaces `enum`s so they
  can't be instantiated. (Breaks only code that writes `DataReader()`, which nothing does.)
- **Implementation:** internal `DataReader.decode(_:reader:errorHandler:log:decode:handler:)`;
  `JSONReader.read`, `JSONReader.decode`, and `URLParametersReader.read` call it. Logging and
  error routing unchanged (existing tests pass as is). envoy-ipad's `extension JSONReader` still
  compiles against the `enum`.
- **Status:** in progress

### C4 — `DelayResponse` schedules one flush instead of three timers
- **Problem:** Headers, body, and EOF each get their own `call(withDelay:)`, relying on timer
  ordering.
- **Proposal:** Buffer the wrapped app's output and flush it in one scheduled call after EOF.
  Delaying the whole wrapped app instead is simpler, but handlers reading the request body would
  start late; that is only safe if Embassy buffers input, which is unverified.
- **Findings (2026-09-23):**
  - Where the timers come from: `DelayResponse.app` wraps `startResponse` and `sendBody` so every
    call goes through its own `loop.call(withDelay:)`. `DataResponse.app` (and so `JSONResponse`)
    makes three calls per response: `startResponse`, `sendBody(data)` if non-empty, and
    `sendBody(Data())` for EOF. So each delayed response puts three entries on Embassy's timer heap.
  - Ordering: Embassy's `SelectorEventLoop.call(withDelay:)` schedules at `.now() + delay` and
    pushes onto a heap ordered only by deadline (`$0.0 < $1.0`), so equal deadlines have no
    guaranteed order. In practice the deadlines always differ: each `schedule` takes a lock, pushes,
    and calls `interruptSelector()` (a write syscall), microseconds apart, while the clock ticks every
    ~42 ns on Apple silicon. envoy-ipad's heavy `DelayResponse` use shows no ordering problems.
  - Cost: three heap entries and up to three loop wakeups instead of one per delayed response;
    negligible at UI-test volumes.
  - Fix trade-offs: buffering and flushing once after EOF changes timing for handlers that respond
    asynchronously (the delay would count from EOF, not from each call); delaying the whole wrapped
    app starts request-body reading late.
  - Leaning: decline unless a test shows reordering.
- **To test later:** drive a delayed `DataResponse`/`JSONResponse` through a real
  `SelectorEventLoop` many times (and with a zero delay, the tightest case) and assert the recorded
  order is always status → body → EOF; optionally force equal deadlines to confirm the heap can
  reorder them.
- **Status:** deferred — findings above; test before deciding

### C7 — `DataResponse` checks headers without `MultiDictionary`
- **Problem:** `DataResponse.app` built a `MultiDictionary<String, String, LowercaseKeyTransform>`
  only to ask whether `Content-Type`/`Content-Length` were already set. That was the last
  non-event-loop reason for `import Embassy` in the library, and the two tests that checked
  headers imported Embassy for the same type.
- **Implementation:** a file-private `contains(named:)` on `[(String, String)]` using
  `caseInsensitiveCompare`; `ResponseRecorder.lastHeader(_:)` replaces it in tests. New test
  `testCallerHeadersAreNotDuplicated` pins the case-insensitive behavior. Behavior unchanged.
  The test target still depends on Embassy for the planned C4 event-loop test.
- **Status:** in progress (PR 2)

### C5 — Small cleanups
- Rename `SWGIWebApp` → `SWSGIWebApp`, keep the old name as a deprecated typealias (unused in envoy-ipad).
- Fix the `DataResponse.handler` doc comment ("generating JSON response").
- Replace `var delayTime: TimeInterval!` with a `let` built from a `switch` expression. (done)
- **Status:** partly done — IUO replaced; rename and doc comment still proposed

### C6 — SwiftLint config is never loaded
- **Problem:** SwiftLint auto-discovers only `.swiftlint.yml`. The repo's file is `.swiftlint.yaml`,
  so its rules (disabling `force_cast`, `force_try`, `todo`; excluding `Carthage`/`Pods`/`fastlane`)
  are ignored unless `--config .swiftlint.yaml` is passed. Plain `swiftlint` reports every `as!`
  as an error.
- **Proposal:** Rename to `.swiftlint.yml` and drop the stale `Carthage`/`Pods`/`fastlane` excludes.
  Update the CLAUDE.md lint note.
- **Status:** done (renamed; `excluded:` now lists `.build` and `SourcePackages`; CLAUDE.md updated).

## Declined / deferred

### X1 — Make `WebApp` `Sendable` / add an `async` API
- **Reason:** Would break most of envoy-ipad's handlers (they capture non-`Sendable` test state),
  and Embassy's callback-based event loop doesn't bridge cleanly to async/await. Revisit if Embassy
  adopts Swift concurrency.
- **Status:** declined for now

## PR plan

| PR | Items | Status | Link |
|---|---|---|---|
| 1 | B1, B2, B3, B5, P3, P2 — Router fixes, delay RNG fix, reader failure logging | in progress | |
| 2 | A1, A2, A3, A4, A6, C3, C7 — `environ.swsgi` accessors, environ reader overloads, `.delayed()`, Ambassador-owned SWSGI types, keyed `FormParameters`, `JSONResponse(json:)`/Codable, shared reader decode, `MultiDictionary` dropped from `DataResponse`; README fixes | in progress | |

## Consumer follow-ups (envoy-ipad)

Changes to make in envoy-ipad once the corresponding items ship:

- **P2 (optional):** in `EnvoyUITests/Extensions/JSONReader+Extension.swift`, change the
  `errorHandler` default from `nil` to
  `{ XCTFail("Request body wasn't valid JSON: \($0)") }` so a malformed body fails the test with
  a reason instead of only timing out. Requires `import XCTest` in that file. Without this change,
  the stderr log from Ambassador is the only signal.
- **A1:** replace `environ["swsgi.input"] as! SWSGIInput` (×12) with `environ.swsgi.input`, or pass
  `environ` straight to the reader. Once nothing uses them, delete `JSONReader+Extension.swift` and
  the `requestMethod`/`queryString` getters in `Dictionary+Getters.swift` in favor of
  `environ.swsgi.*` (`httpAuthorization` → `environ.swsgi.header("Authorization")`). Optional;
  nothing breaks if left as is.
- **A3:** `DelayResponse+minMax.swift` can go; `DelayResponse.response(for: app, withMinDelay: a,
  andMaxDelay: b)` → `app.delayed(.random(min: a, max: b))`. Optional.
- **A6:** once A1's overloads are adopted, files that imported Embassy only for `SWSGIInput`
  (or `SWSGIStartResponse`/`SWSGISendBody`) can drop `import Embassy`. Files using
  `MultiDictionary` (A2) or the server/event loop (A7) still need it.
- **A2:** replace `MultiDictionary<String, String, NoOpKeyTransform<String>>(items: params)` (×11)
  with `URLParametersReader.readParameters(environ) { params in ... params["key"] }`, and
  `TestHelper.parseQueryParameters(URL:)` (×2) with `environ.swsgi.queryParameters`, or
  `FormParameters(parsing:)` on the text after `?` when only a URL string is at hand. Optional.
