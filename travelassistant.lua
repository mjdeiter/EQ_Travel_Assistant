-- Travel Assistant (All Zones Version for Project Lazarus, with Fuzzy/Long Name/Shortname Search)
-- Original Script by Monkeyman618
-- Modified by Alektra <Lederhosen>, Adapted for Project Lazarus (2025-05-22)


local mq = require('mq')
local imgui = require('ImGui')

-- ===============================
-- Runtime State
-- ===============================
local my_name = mq.TLO.Me.Name() or ""
local COMMANDER_NAME = nil
local is_commander = false

local selected_zone = nil
local selected_zone_shortname = nil

local is_running = false
local is_paused = false
local is_gui_open = true

-- ===============================
-- Agent Telemetry Table
-- ===============================
local agent_status = {}
-- agent_status[name] = {
--   state = "Waiting" | "Zone Set" | "Traveling" | "Arrived" | "Timeout"
--   last_update = os.clock()
--   sent_time = os.clock()
--   latency = seconds
--   retries = number
-- }

-- ===============================
-- Utility Functions
-- ===============================
local function all_agents_ready()
    for name, data in pairs(agent_status) do
        if data.state ~= "Zone Set" then
            return false
        end
    end
    return true
end

local function all_agents_arrived()
    for name, data in pairs(agent_status) do
        if data.state ~= "Arrived" then
            return false
        end
    end
    return true
end

local function start_travel()
    if not selected_zone_shortname then
        print("No zone selected.")
        return
    end
    is_running = true
    is_paused = false
    mq.cmdf('/travelto "%s"', selected_zone_shortname)
end

local function pause_travel()
    if is_running then
        is_paused = not is_paused
    end
end

local function stop_travel()
    is_running = false
    is_paused = false
end

-- ===============================
-- Agent Receiver (/ta agent ...)
-- ===============================
mq.bind('/ta agent', function(line)
    if is_commander then return end
    if not line then return end

    local args = {}
    for w in line:gmatch("%S+") do table.insert(args, w) end
    local cmd = args[1] and args[1]:lower()

    if cmd == "zone" and args[2] then
        selected_zone_shortname = args[2]:gsub('"','')
        selected_zone = selected_zone_shortname
        mq.cmdf('/dgge %s %s Zone Set', COMMANDER_NAME, my_name)

    elseif cmd == "start" then
        if not selected_zone_shortname then
            mq.cmdf('/dgge %s %s ERROR-NoZone', COMMANDER_NAME, my_name)
            return
        end
        start_travel()
        mq.cmdf('/dgge %s %s Traveling', COMMANDER_NAME, my_name)

    elseif cmd == "pause" then
        pause_travel()
        mq.cmdf('/dgge %s %s Paused', COMMANDER_NAME, my_name)

    elseif cmd == "stop" then
        stop_travel()
        mq.cmdf('/dgge %s %s Stopped', COMMANDER_NAME, my_name)
    end
end)

-- ===============================
-- Commander Confirmation Receiver
-- ===============================
mq.bind('/dgge', function(line)
    if not is_commander then return end
    if not line then return end

    local sender, message = line:match("(%S+)%s+(.+)")
    if sender and agent_status[sender] then
        local now = os.clock()
        agent_status[sender].state = message
        agent_status[sender].last_update = now
        agent_status[sender].latency = now - agent_status[sender].sent_time
    end
end)

-- ===============================
-- Commander Slash Handler
-- ===============================
mq.bind('/ta', function(line)
    if not is_commander then return end
    if not mq.TLO.Me.GroupLeader() then
        print("You must be group leader.")
        return
    end

    if not line then return end

    local args = {}
    for w in line:gmatch("%S+") do table.insert(args, w) end
    local cmd = args[1] and args[1]:lower()

    if cmd == "zone" and args[2] then
        selected_zone_shortname = args[2]
        selected_zone = selected_zone_shortname

        local now = os.clock()

        agent_status = {}

        for i = 1, mq.TLO.Group.Members() or 0 do
            local member = mq.TLO.Group.Member(i).Name()
            if member and member ~= my_name then
                agent_status[member] = {
                    state = "Waiting",
                    last_update = now,
                    sent_time = now,
                    latency = 0,
                    retries = 0
                }
            end
        end

        mq.cmdf('/dgga /ta agent zone "%s"', selected_zone_shortname)

    elseif cmd == "start" then
        if not selected_zone_shortname then
            print("Set zone first.")
            return
        end

        if all_agents_ready() then
            mq.cmd('/dgga /ta agent start')
            start_travel()
        else
            print("Agents not ready.")
        end
    end
end)

-- ===============================
-- GUI Drawing
-- ===============================
local function draw_status(name, data)
    local status = data.state
    local latency = string.format("%.2fs", data.latency or 0)

    if status == "Arrived" then
        imgui.PushStyleColor(imgui.Col.Text, 0, 1, 0, 1)
    elseif status == "Timeout" then
        imgui.PushStyleColor(imgui.Col.Text, 1, 0, 0, 1)
    else
        imgui.PushStyleColor(imgui.Col.Text, 1, 1, 0, 1)
    end

    imgui.Text(string.format("%-15s : %-12s (%s)", name, status, latency))
    imgui.PopStyleColor()
end

local function render_gui()
    if not is_gui_open then return end
    if not imgui.Begin("Zone Travel Assistant", true) then
        imgui.End()
        return
    end

    imgui.Text("Role: " .. (is_commander and "Commander" or "Agent"))
    imgui.Text("Commander: " .. (COMMANDER_NAME or "None"))
    imgui.Separator()

    if is_commander then
        if imgui.CollapsingHeader("Commander Control", imgui.TreeNodeFlags.DefaultOpen) then

            local changed, value = imgui.InputText("Zone Shortname", selected_zone_shortname or "", 32)
            if changed then selected_zone_shortname = value end

            if imgui.Button("Broadcast Zone") then
                mq.cmdf('/ta zone %s', selected_zone_shortname)
            end

            imgui.SameLine()

            if imgui.Button("Force Start") then
                mq.cmd('/dgga /ta agent start')
                start_travel()
            end
        end

        imgui.Separator()
        imgui.Text("Agent Telemetry")
        imgui.BeginChild("##tracker", 0, 150, true)

        for name, data in pairs(agent_status) do
            draw_status(name, data)
        end

        imgui.EndChild()
    end

    imgui.End()
end

-- ===============================
-- Main Loop
-- ===============================
local function main()
    while is_gui_open do

        -- Auto role detection
        if mq.TLO.Me.GroupLeader() then
            is_commander = true
            COMMANDER_NAME = my_name
        else
            is_commander = false
            COMMANDER_NAME = mq.TLO.Group.Leader()
        end

        -- Commander timeout + retry logic
        if is_commander then
            local now = os.clock()

            for name, data in pairs(agent_status) do
                if data.state ~= "Arrived" and now - data.last_update > 5 then
                    if data.retries < 2 then
                        mq.cmdf('/dgga /ta agent zone "%s"', selected_zone_shortname)
                        data.retries = data.retries + 1
                        data.last_update = now
                    else
                        data.state = "Timeout"
                    end
                end
            end

            if all_agents_arrived() and next(agent_status) ~= nil then
                mq.cmd('/beep')
                print("All agents arrived.")
                agent_status = {}
            end
        end

        -- Agent arrival detection
        if not is_commander and is_running and not is_paused then
            if mq.TLO.Zone.ShortName() == selected_zone_shortname then
                is_running = false
                mq.cmdf('/dgge %s %s Arrived', COMMANDER_NAME, my_name)
            end
        end

        mq.doevents()
        mq.delay(50)
    end
end

mq.imgui.init("ZoneTravelUI", render_gui)
main()
