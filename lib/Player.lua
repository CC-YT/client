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
    self.playing = false
    self.dfpwm_decode = dfpwm.make_decoder()

    -- Timing
    self.fps = config.fps
    self.interval = 1/self.fps
    self.frame_timer = os.startTimer(self.interval)

    -- Connection
    self.url = nil
    self.ws = nil

    -- Static blit lines
    width, height = self.mon.getSize()
    self.text_line = string.rep(" ",width)
    self.fg_line = string.rep("0",width)

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

function Player:wait_for_ready()
    while true do
        local event, p1, p2 = os.pullEvent()
        if event == "websocket_message" and p1 == self.url then
            local ok, packet = pcall(textutils.unserialiseJSON, p2)
            if not ok then return end

            if packet.type == "ready" then
                print("ready")
                self.ws.send(textutils.serialiseJSON({
                    type="get_frames"
                }))
                self.ws.send(textutils.serialiseJSON({
                    type="get_audio"
                }))
                self.frame_timer = os.startTimer(self.interval)
                break
            end
        end
    end
end

function Player:play()
    local start_time = os.clock()
    local frame_index = 1

    while true do
        local event, p1, p2 = os.pullEvent()
        if event == "timer" and p1 == self.frame_timer then
            local targ_time = start_time + (frame_index-1) * self.interval
            self:drawFrame()
            frame_index = frame_index + 1

            local now = os.clock()
            local next_targ = start_time + (frame_index - 1) * self.interval
            local delay = next_targ - now
            self.frame_timer = os.startTimer(delay)
        elseif event == "websocket_message" and p1 == self.url then
            self:handle_packet(p2)
        elseif event == "speaker_audio_empty" then
            self:playAudio()
        elseif (event == "websocket_closed" or event == "websocket_failure") and p1 == self.url then
            print("Disconnected")
            break
        end
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

    local y = 1
    for line in packet:gmatch("[^\r\n]+") do
        self.mon.setCursorPos(1, y)
        self.mon.blit(self.text_line, self.fg_line, line)
        y = y + 1
    end

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
    while not self.spk.playAudio(pcm) do
        os.pullEvent("speaker_audio_empty")
    end

    if self.audioQ:count() <= 1 then
        self.ws.send(textutils.serialiseJSON({
            type="get_audio"
        }))
    end
end

return Player