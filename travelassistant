-- Travel Assistant (All Zones Version for Project Lazarus, with Fuzzy/Long Name/Shortname Search)
-- Original Script by Monkeyman618
-- Modified by Alektra <Lederhosen>, Adapted for Project Lazarus (2025-05-22)
-- Version: 1.1.0-plaz

local mq = require('mq')
local imgui = require('ImGui')

local is_running = false
local is_paused = false
local selected_zone = nil
local selected_zone_shortname = nil
local selected_expansion = nil
local is_gui_open = true
local debug_mode = false
local zone_cache = {}

local function log_debug(message)
    if debug_mode then
        print("[DEBUG]: " .. message)
    end
end

-- Helper: Get all zones (with long/shortnames)
local function query_all_zones()
    local zone_table = {}
    if mq.TLO and mq.TLO.Zone then
        local i = 1
        while mq.TLO.Zone(i).Name() do
            local name = mq.TLO.Zone(i).Name()
            local shortname = mq.TLO.Zone(i).ShortName()
            if name and #name > 0 and shortname and #shortname > 0 then
                table.insert(zone_table, {name=name, shortname=shortname})
            end
            i = i + 1
        end
    elseif mq.TLO and mq.TLO.Zones then
        local i = 1
        while mq.TLO.Zones(i)() do
            local name = mq.TLO.Zones(i).Name() or mq.TLO.Zones(i)()
            local shortname = mq.TLO.Zones(i).ShortName() or ""
            if name and #name > 0 and shortname and #shortname > 0 then
                table.insert(zone_table, {name=name, shortname=shortname})
            end
            i = i + 1
        end
    end
    table.sort(zone_table, function(a, b) return a.name:lower() < b.name:lower() end)
    log_debug(("Loaded %d zones from TLO."):format(#zone_table))
    return zone_table
end

local all_zones = nil
local available_expansions = {
    "All Zones (Alphabetical)",
    "Quick Travels",
}
local zones_by_expansion = {
    ["Quick Travels"] = {
        "Guild Lobby", "Guild Hall", "Palatial Guild Hall", "Modest Guild Hall", "The Plane of Knowledge", "Bazaar", "Sunrise Hills",
    },
    ["All Zones (Alphabetical)"] = false,
}

local function get_zones_for_expansion(expansion)
    if expansion == "All Zones (Alphabetical)" then
        if not all_zones then
            all_zones = query_all_zones()
        end
        return all_zones or {}
    end
    if not zone_cache[expansion] then
        zone_cache[expansion] = zones_by_expansion[expansion] or {}
    end
    local result = {}
    for _, z in ipairs(zone_cache[expansion]) do
        table.insert(result, {name=z, shortname=z})
    end
    return result
end

-- Fuzzy search helpers
local function fuzzy_score(str, pattern)
    -- Cheap fuzzy: sequential match with gaps = score penalty, but full substring = best
    local s, p = str:lower(), pattern:lower()
    if s == p then return 100 end
    if s:find(p, 1, true) then return 90 end
    local score, j = 0, 1
    for i=1,#p do
        local c = p:sub(i,i)
        local found = false
        while j <= #s do
            if s:sub(j,j) == c then
                score = score + 2 -- bonus for matching
                found = true
                j = j + 1
                break
            end
            score = score - 1 -- penalty for skipping
            j = j + 1
        end
        if not found then return -999 end -- not a match
    end
    return score
end

local function fuzzy_search_zones(query, search_field)
    if not all_zones then all_zones = query_all_zones() end
    local results = {}
    local field = search_field or "name"
    for _, z in ipairs(all_zones) do
        local target = z[field]
        local score = fuzzy_score(target, query)
        if score > 0 then
            table.insert(results, {zone=z, score=score})
        end
    end
    table.sort(results, function(a,b) return a.score > b.score end)
    local matches = {}
    for i,v in ipairs(results) do
        table.insert(matches, v.zone)
        if #matches > 30 then break end
    end
    return matches
end

local function search_zones(query)
    -- Try both long name and shortname, with fuzzy
    local results = {}
    local shortname_results = fuzzy_search_zones(query, "shortname")
    local longname_results = fuzzy_search_zones(query, "name")
    local seen = {}
    for _,z in ipairs(shortname_results) do
        local key = z.name .. z.shortname
        if not seen[key] then
            table.insert(results, z)
            seen[key] = true
        end
    end
    for _,z in ipairs(longname_results) do
        local key = z.name .. z.shortname
        if not seen[key] then
            table.insert(results, z)
            seen[key] = true
        end
    end
    return results
end

local function start_travel()
    if selected_zone then
        is_running = true
        is_paused = false
        local zone_to_travel = selected_zone_shortname or selected_zone
        mq.cmdf('/travelto "%s"', zone_to_travel)
        log_debug(string.format("Starting travel to: %s", zone_to_travel))
    else
        print("No zone selected! Please choose a zone first.")
    end
end

local function pause_travel()
    if is_running then
        is_paused = not is_paused
        print(is_paused and "Travel paused." or "Travel resumed.")
    else
        print("Travel is not running.")
    end
end

local function end_travel()
    is_running = false
    is_paused = false
    print("Travel ended.")
end

local function close_gui()
    is_gui_open = false
end

local function broadcast_status()
    if mq.TLO.DanNet then
        local status_message = "Zone Travel Assistant Status: " ..
            (is_running and "Running" or "Stopped") ..
            (is_paused and " (Paused)" or "") ..
            ", Current Zone: " .. (selected_zone or "None") ..
            ", Current Expansion: " .. (selected_expansion or "None")
        mq.cmdf('/dgga %s', status_message)
    else
        print("DanNet is not available. Group communication disabled.")
    end
end

local function group_travel()
    if selected_zone then
        if mq.TLO.DanNet then
            local zone_to_travel = selected_zone_shortname or selected_zone
            mq.cmdf('/dgga /travelto "%s"', zone_to_travel)
            print(string.format("Group travel initiated to %s.", zone_to_travel))
        else
            print("DanNet is not available. Cannot initiate group travel.")
        end
    else
        print("No zone selected! Cannot initiate group travel.")
    end
end

local function receive_commands()
    if mq.TLO.DanNet then
        local command = mq.TLO.DanNet.Command() or ""
        if command == "start" then
            start_travel()
        elseif command == "pause" then
            pause_travel()
        elseif command == "stop" then
            end_travel()
        elseif command:match("^zone:(.+)") then
            local new_zone = command:match("^zone:(.+)"):match("^%s*(.-)%s*$")
            local matches = search_zones(new_zone)
            if #matches > 0 then
                selected_zone = matches[1].name
                selected_zone_shortname = matches[1].shortname
                log_debug(string.format("Received command to set zone to %s (%s).", matches[1].name, matches[1].shortname))
                return
            end
            print("Invalid zone received in command. Please check the zone name/shortname and try again.")
        end
    end
end

-- GUI state for search
local search_text = ""
local search_matches = {}
local last_search_text = ""
local search_mode = "All" -- All, Shortname, Longname

local function render_gui()
    local open_status = imgui.Begin("Zone Travel Assistant", is_gui_open)
    if not open_status then
        imgui.End()
        return
    end

    if imgui.BeginCombo("Select Expansion", selected_expansion or "Choose an expansion") then
        for _, expansion in ipairs(available_expansions) do
            if imgui.Selectable(expansion, expansion == selected_expansion) then
                selected_expansion = expansion
                selected_zone = nil
                selected_zone_shortname = nil
            end
        end
        imgui.EndCombo()
    end

    -- ----------- Search -------------
    imgui.Text("Zone Search:")
    imgui.SameLine()
    if imgui.RadioButton("All", search_mode=="All") then search_mode = "All" end
    imgui.SameLine()
    if imgui.RadioButton("Short", search_mode=="Shortname") then search_mode = "Shortname" end
    imgui.SameLine()
    if imgui.RadioButton("Long", search_mode=="Longname") then search_mode = "Longname" end

    local changed, value = imgui.InputText("##zonesearch", search_text, 64)
    if changed or search_text ~= last_search_text or search_mode ~= last_search_text_mode then
        search_text = value
        search_matches = {}
        if #search_text > 0 then
            if search_mode == "Shortname" then
                search_matches = fuzzy_search_zones(search_text, "shortname")
            elseif search_mode == "Longname" then
                search_matches = fuzzy_search_zones(search_text, "name")
            else
                search_matches = search_zones(search_text)
            end
        end
        last_search_text = search_text
        last_search_text_mode = search_mode
    end

    if #search_text > 0 and #search_matches > 0 then
        imgui.Text("Matches:")
        imgui.BeginChild("##zonelist", 0, 80, true)
        for _, z in ipairs(search_matches) do
            local label = string.format("%s (%s)", z.name, z.shortname)
            if imgui.Selectable(label, selected_zone == z.name) then
                selected_zone = z.name
                selected_zone_shortname = z.shortname
                selected_expansion = "All Zones (Alphabetical)"
            end
        end
        imgui.EndChild()
    elseif #search_text > 0 then
        imgui.Text("No matches.")
    end

    imgui.Spacing()
    -- ------------ End Search -------------

    if selected_expansion then
        if imgui.BeginCombo("Select Zone", selected_zone or "Choose a zone") then
            local zones = get_zones_for_expansion(selected_expansion)
            for _, zone in ipairs(zones) do
                local label = string.format("%s (%s)", zone.name, zone.shortname)
                if imgui.Selectable(label, selected_zone == zone.name) then
                    selected_zone = zone.name
                    selected_zone_shortname = zone.shortname
                end
            end
            imgui.EndCombo()
        end
    else
        imgui.Text("Please select an expansion first.")
    end

    if imgui.Button("Start") then
        start_travel()
    end

    imgui.SameLine()
    if imgui.Button("Pause") then
        pause_travel()
    end

    imgui.SameLine()
    if imgui.Button("End") then
        end_travel()
    end

    if imgui.Button("Group Travel") then
        group_travel()
    end

    if imgui.Button("Broadcast Status") then
        broadcast_status()
    end

    imgui.Text(is_running and (is_paused and "Status: Paused" or "Status: Running") or "Status: Idle")
    imgui.Text("Selected Zone: " .. (selected_zone or "None"))
    imgui.Text("Shortname: " .. (selected_zone_shortname or "None"))

    if imgui.Button("Close") then
        close_gui()
    end

    if imgui.Button("Toggle Debug Mode") then
        debug_mode = not debug_mode
        print(debug_mode and "Debug mode enabled." or "Debug mode disabled.")
    end

    imgui.End()
end

local function main()
    all_zones = query_all_zones()
    while is_gui_open do
        if is_running and not is_paused then
            -- Perform ongoing actions here
        end
        receive_commands()
        mq.doevents()
        mq.delay(50)
    end
    print("Script ended.")
end

mq.imgui.init("ZoneTravelUI", render_gui)

mq.bind('/show TA', function()
    is_gui_open = true
end)

main()
