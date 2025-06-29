-- ccyt.lua
local config = require("config")
local Player = require("lib.Player")

function find_peripherals()
    local monitor = peripheral.find("monitor")
    if not monitor then
        print("No monitor")
    end

    local speaker = peripheral.find("speaker")
    if not speaker then
        print("No speaker")
    end

    return monitor, speaker
end

monitor, speaker = find_peripherals()

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()
monitor.setCursorPos(1,1)

local player = Player.new(monitor, speaker)
player:connect(config.server_url)
print("Connected")
print("Enter a youtube URL: ")
local url = read()

print("Fetching media ... ")
player:get_media(url)
if player:wait_for_packet("ready") then
    player:play()
end