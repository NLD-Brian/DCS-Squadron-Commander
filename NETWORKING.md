# Lua Networking in DCS - Understanding UDP Sockets

## What We Learned from DCS-SRS

### 1. Loading DCS's JSON Library

```lua
local JSON = loadfile("Scripts\\JSON.lua")()
DCSSC.JSON = JSON
```

**Explanation:**
- `loadfile("path")` - Loads a Lua file, returns a function
- The trailing `()` - Executes that function immediately
- DCS includes `JSON.lua` in its Scripts folder
- Methods: `JSON:encode(table)` and `JSON:decode(string)`

### 2. UDP Socket Basics

**Create a socket:**
```lua
local socket = require("socket")  -- Load Lua socket library
local udpSocket = socket.udp()    -- Create UDP socket
```

### 3. Socket Modes: Sender vs Receiver

#### **Sender Socket (Send Only)**
```lua
local sendSocket = socket.udp()
-- No binding needed, just send
sendSocket:sendto(data, host, port)
```

#### **Receiver Socket (Listen)**
```lua
local receiveSocket = socket.udp()
receiveSocket:setsockname("*", port)  -- BIND to port (listen)
receiveSocket:settimeout(0)           -- Non-blocking mode
local data = receiveSocket:receive()  -- Read data (returns nil if none)
```

### 4. Key Socket Methods

| Method | Purpose | Example |
|--------|---------|---------|
| `socket.udp()` | Create new UDP socket | `local sock = socket.udp()` |
| `:setsockname(ip, port)` | Bind to port (for receiving) | `sock:setsockname("*", 9090)` |
| `:settimeout(seconds)` | Set read timeout (0 = non-blocking) | `sock:settimeout(0)` |
| `:sendto(data, ip, port)` | Send UDP packet | `sock:sendto("hello", "127.0.0.1", 8080)` |
| `:receive()` | Read incoming data | `local data = sock:receive()` |

### 5. Understanding `setsockname("*", port)`

```lua
receiveSocket:setsockname("*", 10309)
```

- **First parameter `"*"`** - Listen on ALL network interfaces
  - Could be `"127.0.0.1"` (localhost only)
  - Or `"0.0.0.0"` (same as `"*"`)
- **Second parameter** - The port number to listen on
- **Effect** - Socket now "owns" this port and can receive data sent to it

### 6. Blocking vs Non-Blocking

```lua
-- BLOCKING (will wait forever for data)
sock:settimeout(nil)  
local data = sock:receive()  -- Hangs here until data arrives

-- NON-BLOCKING (returns immediately)
sock:settimeout(0)
local data = sock:receive()  -- Returns nil instantly if no data

-- TIMEOUT (waits X seconds)
sock:settimeout(2)
local data = sock:receive()  -- Waits up to 2 seconds
```

### 7. Error Handling with socket.try()

```lua
-- Basic send (errors are ignored)
socket:sendto(data, host, port)

-- Protected send (throws error if fails)
socket.try(socket:sendto(data, host, port))

-- With pcall for error catching
local success, error = pcall(function()
    socket.try(socket:sendto(data, host, port))
end)
```

## Our Updated Architecture

```
DCS World
    │
    ├─── DCSSC.UDPSendSocket ──────> Port 10308 ──> .NET App
    │                                                   │
    └─── DCSSC.UDPReceiveSocket <──── Port 10309 <─────┘
         (Listening on port 10309)
```

## Common Patterns

### Pattern 1: Send Only (Simple)
```lua
local sock = socket.udp()
sock:sendto(data, "127.0.0.1", 8080)
```

### Pattern 2: Receive Only (Listener)
```lua
local sock = socket.udp()
sock:setsockname("*", 8080)  -- Bind to port
sock:settimeout(0)           -- Non-blocking
local data = sock:receive()  -- Check for data
```

### Pattern 3: Two-Way Communication (Like We Have Now)
```lua
-- Sender socket
local sendSock = socket.udp()

-- Receiver socket  
local recvSock = socket.udp()
recvSock:setsockname("*", 9090)
recvSock:settimeout(0)

-- Send data
sendSock:sendto("hello", "127.0.0.1", 8080)

-- Check for responses
local response = recvSock:receive()
if response then
    print("Got: " .. response)
end
```

## Why DCS-SRS Has 3 Sockets

Looking at their code:
```lua
SR.UDPSendSocket = socket.udp()          -- Send radio data to SRS app
SR.UDPLosReceiveSocket = socket.udp()    -- Receive LOS check requests
SR.UDPSeatReceiveSocket = socket.udp()   -- Receive seat position updates
```

Each socket has a **specific job**:
1. **Send radio state** → SRS application (one-way)
2. **Receive LOS requests** → From SRS, check terrain visibility (two-way)
3. **Receive seat info** → Get player's seat position (two-way)

They need multiple **receive** sockets because each listens on a different port.

## Our Implementation (2 Sockets)

```lua
-- Send events to .NET
DCSSC.UDPSendSocket = socket.udp()

-- Receive commands from .NET
DCSSC.UDPReceiveSocket = socket.udp()
DCSSC.UDPReceiveSocket:setsockname("*", 10309)
DCSSC.UDPReceiveSocket:settimeout(0)
```

We can **expand** this later if we need more communication channels!

## Data Flow Example

**DCS → .NET:**
```lua
local eventData = {
    eventType = "player_connect",
    playerName = "Maverick",
    timestamp = os.time()
}
-- DCS's JSON library converts table to JSON string
local json = DCSSC.JSON:encode(eventData)
-- Send via UDP
socket.try(DCSSC.UDPSendSocket:sendto(json .. "\n", "127.0.0.1", 10308))
```

**.NET → DCS:**
```lua
-- Check for incoming data (non-blocking)
local received = DCSSC.UDPReceiveSocket:receive()
if received then
    -- Parse JSON back to Lua table
    local command = DCSSC.JSON:decode(received)
    -- Act on command
    if command.action == "kick_player" then
        kickPlayer(command.playerId)
    end
end
```

## Testing Your Setup

You can test with Python:
```python
import socket
import json

# Send to DCS (to port 10309)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
message = json.dumps({"command": "ping"})
sock.sendto(message.encode(), ("127.0.0.1", 10309))

# Receive from DCS (from port 10308)
listen_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
listen_sock.bind(("127.0.0.1", 10308))
data, addr = listen_sock.recvfrom(4096)
print(f"Received: {data.decode()}")
```

## Key Takeaways

1. ✅ `loadfile()` loads external Lua files (like DCS's JSON.lua)
2. ✅ Separate sockets for sending vs receiving
3. ✅ `setsockname()` binds a socket to a port (required for receiving)
4. ✅ `settimeout(0)` makes reads non-blocking (essential in DCS)
5. ✅ Use `socket.try()` for better error handling
6. ✅ Always add `"\n"` to sent data (helps parsers)
