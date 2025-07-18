-- lib/Player.lua
local config = require("config")
local Queue = require("lib.Queue")
local b64 = require("lib.base64")
local dfpwm = require("cc.audio.dfpwm")

local Player = {}
Player.__index = Player

function Player.new(monitor, speaker)
    local self = setmetatable({}, Player)

    -- Queues
    self.frameQ = Queue.new()
    self.audioQ = Queue.new()

    -- Peripherals
    self.mon = monitor
    self.spk = speaker
    self.dfpwm_decode = dfpwm.make_decoder()

    -- Timing
    self.fps = config.fps
    self.interval = 1/self.fps
    self.frame_timer = os.startTimer(self.interval)
    self.frame_index = 1
    self.start_time = 0
    self.audio_time = 0

    -- Connection
    self.url = nil
    self.ws = nil

    -- Static blit lines
    width, height = self.mon.getSize()
    self.text_line = string.rep(" ",width)
    self.fg_line = string.rep("0",width)

    -- Controls
    self.playing = false
    self.paused = false

    return self
end

function Player:connect(url)
    self.url = url
    self.ws = http.websocket(self.url)
    if not self.ws then
        error("Failed to connect to server")
    end

    -- Send the init message to the server
    local width, height = self.mon.getSize()
    msg = textutils.serialiseJSON({
        type="init",
        width=width,
        height=height,
        fps=config.fps,
    })
    self.ws.send(msg)
end

function Player:wait_for_packet(type)
    while true do
        local event, p1, p2 = os.pullEvent()
        if event == "websocket_message" and p1 == self.url then
            local ok, packet = pcall(textutils.unserialiseJSON, p2)
            if not ok then return end

            if packet.type == type then
                return packet
            end
        elseif (event == "websocket_closed" or event == "websocket_failure") and p1 == self.url then
            print("Disconnected")
            return false
        end
    end
end

function Player:get_media(url)
    self.ws.send(textutils.serializeJSON({
        type="get_media",
        url=url
    }))
end

function Player:start()
    self.ws.send(textutils.serialiseJSON({
        type="get_frames"
    }))
    self.ws.send(textutils.serialiseJSON({
        type="get_audio"
    }))
    self.frame_timer = os.startTimer(self.interval)
    self.start_time = os.clock()
end

-- Maybe implement event hooks in the future if needed
-- Might be overengineering tho
function Player:handle_event(event, p1, p2)
    if event == "timer" and p1 == self.frame_timer then
        if not self.paused then
            self:drawFrame()
        end

        -- Calculate when the next frame needs to be drawn and start a timer for that time
        local now = os.clock()
        local next_targ = self.start_time + (self.frame_index - 1) * self.interval
        local delay = next_targ - now

        self.frame_timer = os.startTimer(delay)
    elseif event == "websocket_message" and p1 == self.url then
        self:handle_packet(p2)
    elseif event == "speaker_audio_empty" then
        if self.paused then return end
        self:playAudio()
    elseif (event == "websocket_closed" or event == "websocket_failure") and p1 == self.url then
        print("Disconnected")
    end
end

function Player:handle_packet(raw)
    local ok, packet = pcall(textutils.unserialiseJSON, raw)
    if not ok then return end

    if packet.type == "frame" then
        for _, frame in ipairs(packet.data) do
            self.frameQ:push(frame)
        end
    elseif packet.type == "audio" then
        -- DFPWM audio is sent base64 encoded, so it needs to be decoded
        local decoded = b64.decode(packet.data)
        self.audioQ:push(decoded)

        -- Kickstart audio playback if it isn't started yet
        if not self.playing then
            os.queueEvent("speaker_audio_empty")
            self.playing = true
        end
    elseif packet.type == "frames_end" then
        self.ws.close()
        os.queueEvent("websocket_closed")
    end
end

function Player:drawFrame()
    local packet = self.frameQ:pop()
    if not packet then return end

    -- FRAME-AUDIO SYNCING --
    -- Calculate the desync between audio and video playback
    local video_time = (self.frame_index-1) * self.interval
    local desync = video_time - self.audio_time
    local threshold = 0.15 -- 0.15 second threshold before correcting

    if desync > threshold then
        -- Video is ahead, delay next frame
        -- print("video ahead")
        -- This adds a delay to the frame_timer
        self.start_time = self.start_time + desync
    elseif desync < -threshold then
        -- Video is behind, skip to catch up
        -- print("video behind")
        self.frame_index = self.frame_index + 1
        return
    end

    -- Draw frame
    local y = 1
    for line in packet:gmatch("[^\r\n]+") do
        self.mon.setCursorPos(1, y)
        self.mon.blit(self.text_line, self.fg_line, line)
        y = y + 1
    end

    self.frame_index = self.frame_index + 1

    -- Request more frames if the queue is about to be empty
    if self.frameQ:count() <= 1 then
        self.ws.send(textutils.serialiseJSON({
            type="get_frames"
        }))
    end
end

function Player:playAudio()
    local chunk = self.audioQ:pop()
    if not chunk then return end

    local pcm = self.dfpwm_decode(chunk)
    local duration = #pcm / 48000 -- 48kHz sample rate
    while not self.spk.playAudio(pcm) do
        os.pullEvent("speaker_audio_empty")
    end

    if self.audioQ:count() <= 1 then
        self.ws.send(textutils.serialiseJSON({
            type="get_audio"
        }))
    end

    self.audio_time = self.audio_time + duration
end

-- Player controls

-- Fully stops the video playback without disconnecting
function Player:stop()
    self.ws.send(textutils.serialiseJSON({
        type = "stop"
    }))

    self.playing = false
    self.paused = false
    self.frameQ = Queue.new()
    self.audioQ = Queue.new()
    self.frame_index = 1
    self.audio_time = 0
    self.start_time = os.clock()
end

-- Resumes the currently playing video
function Player:resume()
    self.paused = false
    os.queueEvent("speaker_audio_empty")
end

-- Pauses the currently playing video
function Player:pause()
    self.paused = true
end

function Player:seek(time)
    time = math.max(time,0) -- No negative seek times
    self.ws.send(textutils.serialiseJSON({
        type = "seek",
        time = time
    }))

    -- Clear queues
    self.frameQ = Queue.new()
    self.audioQ = Queue.new()

    -- Adjust timers
    self.frame_index = math.floor(time * self.fps) + 1
    self.audio_time = time
    self.start_time = os.clock() - time

    if self:wait_for_packet("seek_ready") then
        self.ws.send(textutils.serialiseJSON({
            type="get_frames"
        }))
        self.ws.send(textutils.serialiseJSON({
            type="get_audio"
        }))
    end
    self.frame_timer = os.startTimer(self.interval)
    self.playing = false
end

function Player:disconnect()
    self.ws.close()
end

-- Getters
function Player:get_time()
    return self.audio_time
end

return Player