# Shared policy and sync contract (version 1)

## Decision order

1. If Focus is not actively running, allow.
2. Internal safety: normal foreground apps only; protected IDs and LockIn always allowed. Websites: only HTTP(S) main-frame navigation is eligible. Browser internal/extension pages are untouched.
3. Global Never Block match → allow.
4. Websites: active Block AI match → block (curated domains, extra AI domains and supported AI routes).
5. Block mode: selected → block; otherwise allow.
6. Only Allow mode: selected → allow; otherwise block.

Application permission and website permission are independent. App identities use exact bundle identifiers. Domain rules use lowercase ASCII hosts, matching `host == rule` or `host.endsWith("." + rule)`. The browser uses the same policy to create high-priority allow rules and lower-priority redirect rules. Explicit domain syntax and length limits prevent regex injection. Swift and JS cannot literally share executable code; both implementations follow this contract and have behavioral tests.

## Transport

The app binds a TCP listener explicitly to **127.0.0.1:19287**, not all interfaces. HTTP requests are bounded to 16 KiB total, 4 KiB bodies, 32 connections, 28-second lifetime. Chunked request bodies and unexpected Host headers are rejected. Ordinary website Origin headers are rejected and no CORS allowance is emitted. There is no unauthenticated state read or remote mutation API.

`POST /pair`: JSON `{ "name": "Safari" | "Chrome" | "Chromium", "code": "..." }`. A 48-bit random one-time code is issued only from Settings, expires after 120 seconds, and requires a native approval dialog. Response `{ "token": "64 hex characters" }` is a random 256-bit credential. Pairing must finish inside the extension request timeout (25 seconds); otherwise generate a fresh code. Credentials are persisted in Keychain before success. Stale paired entries can be removed from Settings.

`GET /state?revision=N&installation=ID`: `Authorization: Bearer TOKEN`. If current, held up to 20 seconds, flushed immediately when app state changes; otherwise responds immediately. Successful responses are also heartbeats. Extension-local revision never changes Mac state. A 5-second retry handles a live worker's network loss; a 1-minute alarm recovers a suspended worker. The browser cache is applied before reconnecting. Each successful response touches extension storage to keep Chromium's active sync below its worker-idle deadline.

Payload: `protocolVersion`, `installationID`, `revision`, optional `sessionID`, `sessionMode`, `isFocusActive`, `ruleMode`, `presetName`, optional `endDate` (Unix milliseconds), `domains`, `neverBlockDomains`, `appCount`, optional `blockAI`, `extraAIDomains`, `activityMode`, `indefinite`, control capabilities and clock metadata. Swift omits nil optional values. Revision is persisted and increases on durable changes. Lower revisions from the same installation are rejected. A new installation ID can establish a new sequence through authenticated state. Deadlines always govern enforcement even if the cached boolean is still true.

Browser scripts are identical in both packaged extensions; only their background manifest declarations differ. Policy changes are serialized, replace the dynamic DNR rules atomically, then check already-open tabs. Blocked-page URL fragments retain an original address locally for restoration; they are not sent to the Mac. Runtime calls from content scripts can only obtain a boolean decision, deadline and AI-hiding flag for their own tab; pairing and state inspection require an extension-page sender.

## AI policy

Block AI is website-only. Never Block priority 30 beats AI redirect priority 25, which beats Only Allow priority 20 and ordinary redirects. The same AI domain/route module feeds the content verdict and DNR generator. Google DOM hiding receives only an active/non-exempt boolean; pause, expiry, global Google exceptions and toggle changes turn it off. Safe DOM markers are recomputed after mutations, so a reused ordinary-result container does not retain its hidden state. Existing optional-free payloads remain valid. Native preset/controller mutation paths refuse changes during Nuclear Focus.

## Exit controls (1.5)

State exposes optional nuclear, emergencyExitsRemaining, pauseRequiresChallenge and stopRequiresChallenge. Control still accepts only action/sessionID. Native controller checks live policy: Nuclear pause always denied; Nuclear stop requires remaining quota and a native check. Ordinary checks snapshot from the preset into the timed Focus session. No externally supplied proof, answer or entitlement is accepted. Resume never requires friction. Challenge completion is bound to session UUID; quota and emergency end are one atomic state transaction. Cancel preserves persisted kind/failure count. Quit during any existing session hides, preserving state and recovery. Natural deadline expiration remains authoritative.
