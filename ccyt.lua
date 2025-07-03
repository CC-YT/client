-- ccyt.lua
local config = require("config")
local Player = require("lib.Player")

local monitor = peripheral.find("monitor")
if not monitor then
    print("No monitor")
end

local speaker = peripheral.find("speaker")
if not speaker then
    print("No speaker")
end

monitor.setTextScale(config.frame_scale)
monitor.setBackgroundColor(colors.black)
monitor.clear()
monitor.setCursorPos(1,1)

local player = Player.new(monitor, speaker)
player:connect(config.server_url)
print("Connected")

function get_url()
    print("Enter a youtube URL: ")
    local url = read()
    print("Fetching media ... ")
    player:get_media(url)
    if player:wait_for_packet("ready") then
        player:start()
    end
end

get_url()

while true do
    local event, p1, p2 = os.pullEvent()

    if event == "key" and p1 == keys.c then
        print("Stopping playback")
        player:stop()
        get_url()
    elseif event == "key" and p1 == keys.d then
        print("Disconnecting")
        player:disconnect()
        break
    elseif event == "key" and p1 == keys.p then
        if player.paused then
            print("Resuming ...")
            player:resume()
        else
            print("Pausing ...")
            player:pause()
        end
    end

    -- Pass event to player to handle playing logic
    player:handle_event(event, p1, p2)
end