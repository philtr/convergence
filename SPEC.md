# Sync Service Spec (Elixir/Phoenix)

## Goal

A small Phoenix service that syncs a small JSON game-state blob (<= a few KB) across browsers in “rooms”.
Conflict policy: last write wins.
Storage: in-memory only (no persistence).

## Non-goals (for now)

- Persistence / durability across restarts
- Diffs/patches
- Presence, auth, rate limiting (can add later)
- Horizontal scaling / multi-node state sharing

---

## Public API

### Data model

- room_id: string (URL-safe; max 64 chars recommended)
- state: arbitrary JSON object (opaque to server)
- version: monotonically increasing integer per room (starts at 1)
- updated_at: server timestamp (ISO8601)

Server canonical record per room:

```json
{
  "room_id": "abc123",
  "version": 7,
  "updated_at": "2026-01-21T20:00:00Z",
  "state": { "...": "..." }
}
```

### HTTP endpoints

#### 1) Fetch current state

GET /api/rooms/:room_id

Response (200):

```json
{
  "room_id": "abc123",
  "version": 7,
  "updated_at": "2026-01-21T20:00:00Z",
  "state": { ... }
}
```

If room does not exist:

- 404 with:

```json
{ "error": "room_not_found" }
```

#### 2) Upsert state (last write wins)

PUT /api/rooms/:room_id

Request body:

```json
{
  "state": { ... },
  "client_id": "optional-string",
  "client_ts": "optional-iso8601"
}
```

Semantics:

- Always accepts and overwrites server state for that room (“last write wins”).
- Server increments version by 1 each successful write (create -> version 1).
- Server broadcasts the new room record to subscribers.

Response (200):

```json
{
  "room_id": "abc123",
  "version": 8,
  "updated_at": "2026-01-21T20:00:00Z",
  "state": { ... }
}
```

Constraints:

- Reject if payload > 32KB (413) to prevent abuse.
- Reject if state is not valid JSON object/array (422).

#### 3) Subscribe to updates (SSE)

GET /api/rooms/:room_id/stream

Headers:

- Content-Type: text/event-stream
- Cache-Control: no-cache
- Connection: keep-alive

Event format:

- event: state
- data: <json-room-record>

Example stream chunk:

```
event: state
data: {"room_id":"abc123","version":8,"updated_at":"...","state":{...}}

```

Notes:

- On connect, server should immediately emit the current room record if it exists.
- If room doesn’t exist, emit event: state with version:0 and state:null OR emit event: error with room_not_found (recommended: version:0/state:null to simplify clients).
- Heartbeat: send a comment line every 15s:
  : heartbeat\n\n
  to keep proxies from closing the connection.

---

## Client flow (recommended)

1. GET /api/rooms/:room_id (optional; can rely on SSE initial message)
2. Open SSE: EventSource(/api/rooms/:room_id/stream)
3. When user makes a change:
   - PUT /api/rooms/:room_id with full state
4. All clients receive broadcasts from SSE and replace their local state with received state.

Last write wins means clients always treat server updates as authoritative.

---

## Phoenix Implementation

### App structure

- Phoenix API-only (no HTML).
- JSON: use Phoenix default Jason.
- CORS: enable for Netlify origin(s) (configurable env var).

Proposed modules:

- Sync.RoomRegistry (GenServer)
- Sync.RoomSupervisor (DynamicSupervisor, optional; can be single GenServer)
- SyncWeb.RoomController
- SyncWeb.RoomStreamController (SSE)
- SyncWeb.Endpoint (CORS)

### In-memory state & broadcast

Use a single GenServer to store rooms in a map and to broadcast updates.

GenServer state shape:

- %{rooms: %{room_id => room_record}, subscribers: %{room_id => MapSet<pid>}}

Room record in memory:

- %{room_id: binary, version: integer, updated_at: DateTime.t(), state: map | list | nil}

API:

- get_room(room_id) -> {:ok, room} | :not_found
- put_room(room_id, state) -> {:ok, room}
- subscribe(room_id, pid) -> :ok
- unsubscribe(room_id, pid) -> :ok

Broadcast mechanism:

- When put_room succeeds, GenServer sends {:room_update, room_record} to all subscriber PIDs for that room.
- Each SSE connection process (controller process) receives messages and writes to the socket.

### SSE controller behavior

- Set response headers for streaming.
- Call subscribe(room_id, self()).
- Immediately send current state (or {version:0,state:null}).
- Enter receive loop:
  - on {:room_update, room} -> write SSE event
  - every 15s -> write heartbeat comment
  - on client disconnect -> ensure unsubscribe in terminate/2 or after block

### Room TTL (optional but recommended)

Add cleanup to avoid unbounded memory:

- Env var: ROOM_TTL_SECONDS default 86400
- Periodic sweep every N minutes:
  - delete rooms with updated_at < now - ttl
  - also cleanup subscriber sets that are empty

---

## Configuration (env vars)

- PORT (default 4000)
- CORS_ORIGINS (comma-separated; e.g. https://your-site.netlify.app,http://localhost:5173)
- MAX_STATE_BYTES (default 32768)
- ROOM_TTL_SECONDS (default 86400)
- HEARTBEAT_SECONDS (default 15)

---

## Docker

### Dockerfile requirements

- Multi-stage build
- Produce small runtime image
- Expose PORT (4000)
- Run as non-root user if feasible
- Include basic healthcheck endpoint:
  - GET /healthz returns { "ok": true }

### Image naming

- GHCR repo: ghcr.io/<owner>/<repo>:<tag>
  Tags:
- :sha-<shortsha>
- :latest on main branch
- :vX.Y.Z on git tags (optional)

---

## GitHub Actions

### Workflow: build & push image to GHCR

Triggers:

- On push to main
- On tag push v\* (optional)

Steps:

1. Checkout
2. Set up Docker Buildx
3. Login to GHCR using GITHUB_TOKEN
4. Build and push (cache enabled)
5. Validate docker-compose.yml image reference matches ghcr.io/<owner>/<repo>:latest

### Keeping sample docker-compose up to date

- Store canonical docker-compose.yml in repo root
- CI fails if image reference drifts

---

## Docker Compose (sample)

docker-compose.yml should define:

- service sync
- environment vars for CORS and TTL
- port mapping 4000:4000
- restart policy

Example fields:

- image: ghcr.io/<owner>/<repo>:latest
- environment: PORT=4000, CORS_ORIGINS=..., ROOM_TTL_SECONDS=..., MAX_STATE_BYTES=...

---

## Observability / logging

- Log each PUT: room_id, bytes, new version
- Log subscriber connect/disconnect counts per room at debug level
- No PII in logs

---

## Testing

- Controller tests:
  - GET returns 404 for unknown room
  - PUT creates room with version 1
  - PUT overwrites and increments version
  - payload size limit enforced
- SSE integration test:
  - open stream, PUT update, assert stream receives event

---

## Security basics

- CORS restricted by env var
- Payload size limit
- Room id validation ([A-Za-z0-9_-], max 64 chars)
- Optional room secret later
