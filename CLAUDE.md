# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ambassador is a lightweight Swift web framework built on **SWSGI** (Swift Web Server Gateway Interface), the protocol defined by its sibling project [Embassy](https://github.com/envoy/Embassy). Its primary purpose is mocking HTTP APIs in UI/automation tests. The module is `Ambassador`; consumers `import Ambassador`.

**Swift Package Manager is the only supported distribution.** CocoaPods and Carthage are no longer supported. `EnvoyAmbassador.podspec`, `Cartfile`, and `Cartfile.resolved` have been removed; don't reintroduce them. (The pod name `EnvoyAmbassador` existed only because `Ambassador` was taken on CocoaPods; that distinction is now irrelevant.) `README.md` still documents both installation paths and is stale on this point.

Embassy is the *only* dependency, and it supplies the HTTP server, event loop, `SWSGI`/`SWSGIInput` types, and `MultiDictionary`. Ambassador itself contains no socket or HTTP-parsing code.

## Build and test

SPM is the working path. It resolves Embassy from git and ignores the Xcode project entirely:

```bash
swift build
swift test                                    # 9 tests, runs in well under a second
swift test --filter RouterTests               # single suite
swift test --filter RouterTests/testRouter    # single test
```

The package is `swift-tools-version: 6.0`, so it builds in **Swift 6 language mode with strict concurrency on**. It compiles clean at that setting today — no `@unchecked Sendable`, no `swiftLanguageMode(.v5)` escape hatch. Keep it that way: if a change starts producing Sendable or actor-isolation errors, fix the code rather than downgrading the language mode. 6.0 (not 6.3) is the floor so consumers on Xcode 16 can still resolve the package.

Both targets are declared non-conventionally and deliberately:

- Sources are in `Ambassador/` and tests in `AmbassadorTests/`, not SwiftPM's default `Sources/`/`Tests/`, so both targets set an explicit `path:`.
- Each `exclude:`s its `Info.plist`, and the library target also excludes `Ambassador.h`. Those are leftovers of the Xcode framework/bundle targets, not SwiftPM resources; without the excludes SwiftPM emits `found 1 file(s) which are unhandled`.
- The test target depends on **both** `Ambassador` and `Embassy` — `DataResponseTests` and `JSONResponseTests` `import Embassy` directly for `EventLoop`/`SWSGI` types.

Don't "simplify" any of that away. The manifest declares no `platforms:`, so SPM applies the toolchain's default minimums; add one only if a consumer actually needs a specific floor.

**The Xcode project and workspace are broken and cannot build.** They are hard-wired to Carthage: `Ambassador.xcworkspace` references `group:Carthage/Checkouts/Embassy/Embassy.xcodeproj`, every target's `FRAMEWORK_SEARCH_PATHS` points at `$(PROJECT_DIR)/Carthage/Build/{iOS,tvOS}`, and the project contains zero SPM package references. With no `Carthage/` directory present, `xcodebuild` against any scheme fails to find `Embassy.framework`. Fixing this means migrating the project's Embassy dependency to an `XCRemoteSwiftPackageReference`; until then use `swift build`/`swift test` and ignore the `.xcodeproj`/`.xcworkspace`.

For reference if that migration happens: targets are `Ambassador-{iOS,macOS,tvOS}` plus matching `*Tests` bundles, and the shared `Ambassador-tvOS` scheme has an empty `<Testables>` (its test target is reachable only via the auto-generated `Ambassador-tvOSTests` scheme).

Lint with `swiftlint` (config in `.swiftlint.yaml` — `force_cast`, `force_try`, and `todo` are deliberately disabled, which the codebase relies on heavily). `pre-commit` hooks cover whitespace/EOF/JSON/YAML checks.

## Architecture

Everything is one protocol, `WebApp` (`Ambassador/WebApp.swift`):

```swift
func app(_ environ: [String: Any],
         startResponse: @escaping ((String, [(String, String)]) -> Void),
         sendBody: @escaping ((Data) -> Void))
```

That signature *is* SWSGI, expressed as a protocol instead of a closure. `Router.app` is passed to `DefaultHTTPServer(app:)` as the entry point. `SWGIWebApp` wraps a bare `SWSGI` closure back into a `WebApp` for the reverse direction.

**Composition over inheritance.** Every type in `Responses/` is a `WebApp`, and decorators wrap other `WebApp`s rather than subclassing:

- `DataResponse` — the base sink. Owns header defaulting (`Content-Type`, `Content-Length` are added only if the caller didn't supply them, matched case-insensitively via Embassy's `MultiDictionary`), and always terminates the body with an empty `Data()` to signal EOF.
- `JSONResponse` — *delegates to* an internal `DataResponse`; it only adds `JSONSerialization` on top. Changes to header/EOF behavior belong in `DataResponse`, not here.
- `DelayResponse` — a pure decorator: it doesn't produce a response, it wraps another `WebApp` and reschedules that app's `startResponse`/`sendBody` calls through `environ["embassy.event_loop"]`. `.never` returns without ever invoking the wrapped app.

Both `DataResponse` and `JSONResponse` have two initializers: a sync one (`(environ) -> Data`/`Any`) and an async one taking a `sendData`/`sendJSON` callback. The sync form is implemented in terms of the async form. `sendData` is expected to be called exactly once with the whole payload — unlike SWSGI's `sendBody`, which is a stream.

**Readers** (`Readers/`) exist because SWSGI delivers request bodies as a chunk stream terminated by an empty `Data`. `DataReader.read` buffers to EOF; `JSONReader` and `URLParametersReader` both build on `DataReader` and add parsing plus an optional `errorHandler`. Read the body via `environ["swsgi.input"] as! SWSGIInput`.

### Router specifics

Routes are keyed by string, but every key is compiled as an `NSRegularExpression` and matched with `matches(in:)` — so matching is **substring, not anchored**, and iteration order over the `routes` dictionary is undefined. Overlapping patterns therefore resolve non-deterministically; that is existing behavior tests depend on, so be careful "fixing" it. Capture groups are injected into the environ as `environ["ambassador.router_captures"]: [String]`. The subscript is guarded by a `DispatchSemaphore` because routes are typically registered from a test thread while the event loop reads them; the setter force-unwraps `newValue`, so assigning `nil` to remove a route crashes.

## Conventions

- Response and reader types are `struct`s conforming to `WebApp`/static-only namespaces; `Router` is the lone `open class`.
- The library is intentionally force-unwrap-heavy (`as!`, `try!`) on environ keys and JSON serialization — mocking-in-tests is the use case, and failing loudly is the design choice.
- Tests are XCTest, one file per type in `AmbassadorTests/`, and drive `app(_:startResponse:sendBody:)` directly with a hand-built `environ` dictionary rather than starting a real server. New tests added to that directory are picked up by `swift test` automatically. Swift Testing (`@Test`/`#expect`) is a reasonable choice for new test files, but don't churn the existing XCTest ones without reason.
- Public API changes need updating in `README.md`, which doubles as the API docs. Releases are cut as git tags `v<version>`, which is what SPM consumers resolve against.
