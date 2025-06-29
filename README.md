# 🎬 CCYT-Client

**CCYT-Client** is a video player written for [CC:Tweaked](https://tweaked.cc), designed to receive video and DFPWM audio streams over WebSockets and play them in sync using connected monitor and speaker peripherals.

This is the client-side software. Pair it with the [CCYT Server](https://github.com/CC-YT/server) to stream video files directly to your ComputerCraft computer.

---

## 🧰 Features

- ✅ Real-time video playback on monitors
- 🔊 Synchronized DFPWM audio via connected speakers
- ⚡ Buffered frame and audio queues to reduce lag
- 📡 Asynchronous WebSocket communication
- 📦 Modular, maintainable Lua class structure

---

## 📦 Folder Structure

```
ccyt-client/
├── README.md
├── ccyt.lua                 -- Entry point for the client
├── config.lua                -- Config settings
├── lib/
│   ├── Player.lua             -- Player class (handles all playback logic)
│   ├── Queue.lua            -- Lightweight FIFO queue class
|   └── util.lua             -- (optional) Utility functions

```

---

## 🧪 Requirements

- **Minecraft 1.16+** with [CC:Tweaked](https://tweaked.cc/) installed
- A **ComputerCraft computer**
- A **monitor peripheral** (minimum recommended: 4x3 monitors)
- A **speaker peripheral** nearby and wired to the computer
- Internet connection (or local network) with access to the WebSocket server
- Python-based [CCYT Server](https://github.com/CC-YT/server) running and listening for connections

---

## 🚀 Getting Started

### 1. Clone or Download

Use Git or manually download the contents of this repo to your ComputerCraft computer (pastebin or copy with FTP, etc.).

```

git clone [https://github.com/CC-YT/client](https://github.com/CC-YT/client)

````

Or manually install on your ComputerCraft computer under `/ccyt-client/`.

### 2. Set the Startup Script

Edit `config.lua` if needed:

```lua
return {
    server_url  = "ws://localhost:5000", -- Set the ip and port of the ccyt server
    fps         = 10,
    frame_scale = 0.5,                   -- setTextScale
}
````

Make sure to point the URL to your **CCYT server address**.

### 3. Run the Player

If the repo is in the root directory:

```lua
ccyt
```

---

## 🖥️ Controls

This version is fully automatic. Once the client connects to the server, video and audio playback begins. Future versions may include:

* Skipping forward/backward
* Volume controls
* Frame buffering indicator
* YouTube video search

---

## ⚙️ Configuration

You can modify the following inside the code:

| Config            | Description                     | Location         |
| ----------------- | ------------------------------- | ---------------  |
| `server_url`      | WebSocket server address        | `config.lua`     |
| `fps`             | Playback framerate              | `config.lua`     |
| `frame_scale`     | Number of monitors side-by-side | `config.lua`     |

## 📜 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## 🛠️ TODO

* [ ] Pause/resume support
* [ ] Seeking/skipping
* [ ] Metadata display (title, timestamp)
* [ ] Youtube video search
* [ ] Playlist and queueing