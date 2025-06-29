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
player:wait_for_ready()
player:play()