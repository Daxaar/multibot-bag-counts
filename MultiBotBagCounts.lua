local frame = CreateFrame("Frame")
local CACHE_SECONDS, TIMEOUT = 10, 5
local roster, pending, queue, cache = nil, nil, {}, {}
local cachedAt, nextSend, sequence = nil, 0, 0
local sessionScanned = false
local update, showCounts, hover

local function send(payload)
    SendAddonMessage("MBOT", "GET~" .. payload, "WHISPER", UnitName("player"))
end

local function split(text)
    local fields = {}
    for field in (text .. "~"):gmatch("(.-)~") do fields[#fields + 1] = field end
    return fields
end

local function integer(value)
    local n = tonumber(value)
    if n and n >= 0 and n <= 4294967295 and n == math.floor(n) then return n end
end

local function receive(message)
    local f = split(message)
    local op = f[1]
    if op == "ALT_ROSTER_BEGIN" and roster then
        roster.expected = integer(f[2])
        roster.entries, roster.seen = {}, 0
    elseif op == "ALT_ROSTER_ENTRY" and roster and roster.entries then
        roster.seen = roster.seen + 1
        local name = (f[3] or ""):gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
        if f[6] == "ONLINE" and #name > 0 and #name <= 48
            and not name:find("[%c~]") and name ~= UnitName("player") then
            roster.entries[name] = true
        end
    elseif op == "ALT_ROSTER_END" and roster then
        if roster.entries and roster.expected == roster.seen and integer(f[2]) == roster.seen then
            queue = {}
            for name in pairs(cache) do if not roster.entries[name] then cache[name] = nil end end
            for name in pairs(roster.entries) do queue[#queue + 1] = name end
            table.sort(queue)
        end
        roster = nil
    elseif pending and f[2] == pending.name and f[3] == pending.token then
        if op == "INV_EXACT_BEGIN" then
            pending.begun = true
        elseif op == "INV_EXACT_ERROR" then
            pending.failed = true
        elseif op == "INV_BAG" and pending.begun and (f[4] == "BACKPACK" or f[4] == "BAG") then
            local bag, first, count = integer(f[5]), integer(f[6]), integer(f[7])
            if bag and first and count and first + count <= 256 then
                pending.bags[bag] = {first, first + count}
            else pending.failed = true end
        elseif op == "INV_ITEM_LOC" and pending.begun then
            local bag, slot, item, count = integer(f[4]), integer(f[5]), integer(f[6]), integer(f[7])
            local range = bag and pending.bags[bag]
            if range and slot and slot >= range[1] and slot < range[2] and item and item > 0 and count and count > 0 then
                local location = bag * 256 + slot
                if not pending.slots[location] then
                    pending.slots[location] = true
                    pending.items[item] = (pending.items[item] or 0) + count
                end
            end
        elseif op == "INV_EXACT_END" then
            if pending.begun and not pending.failed and pending.bags[255] then
                cache[pending.name] = pending.items
            else cache[pending.name] = nil end
            pending = nil
        end
    end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, prefix, message, distribution, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == "MBOT" and sender and sender:gsub("%-.*$", "") == UnitName("player") then
            receive(message)
        end
    else
        if event == "PLAYER_ENTERING_WORLD" then
            roster, pending, queue, cache = nil, nil, {}, {}
            sessionScanned = false
        end
        cachedAt = nil
        hover = nil
        if event == "PLAYER_ENTERING_WORLD" then frame:SetScript("OnUpdate", nil) end
    end
end)

local elapsed = 0
update = function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    local now = GetTime()
    if pending and now >= pending.deadline then
        cache[pending.name] = nil
        pending = nil
    end
    if roster and now >= roster.deadline then roster = nil end
    if roster or pending or now < nextSend then return end
    if #queue > 0 then
        sequence = sequence + 1
        local token = "lbc" .. math.floor(now * 1000) .. "x" .. sequence
        pending = {name = table.remove(queue, 1), token = token, deadline = now + TIMEOUT,
                   bags = {}, items = {}, slots = {}}
        nextSend = now + 0.75
        send("INVENTORY_EXACT~" .. pending.name .. "~" .. token)
    else
        cachedAt = now
        frame:SetScript("OnUpdate", nil)
        showCounts()
    end
end

local added = false
GameTooltip:HookScript("OnTooltipCleared", function() added, hover = false, nil end)
GameTooltip:HookScript("OnHide", function() hover = nil end)

showCounts = function()
    if not hover or added then return end
    local tooltip = GameTooltip
    if not tooltip:IsShown() or tooltip:GetOwner() ~= hover.owner then return end
    local _, link = tooltip:GetItem()
    if not link or tonumber(link:match("item:(%d+)")) ~= hover.item then return end
    local item = hover.item
    local names = {}
    for name in pairs(cache) do names[#names + 1] = name end
    if #names == 0 then return end
    table.sort(names)
    added = true
    tooltip:AddLine("Multibot Bag Counts", 0.76, 0.53, 0.31)
    local empty = {}
    for _, name in ipairs(names) do
        local count = cache[name][item]
        if count and count > 0 then
            tooltip:AddLine("  " .. name .. " (" .. count .. ")", 0.45, 0.85, 0.45)
        else
            empty[#empty + 1] = name
        end
    end
    if #empty > 0 then
        tooltip:AddLine("  " .. table.concat(empty, ", ") .. " (0)", 0.45, 0.85, 0.45, true)
    end
    tooltip:Show()
end

hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
    hover = nil
    if type(bag) ~= "number" or bag < 0 or bag > 4 then return end
    local link = GetContainerItemLink(bag, slot)
    local item = link and tonumber(link:match("item:(%d+)"))
    if not item then return end
    hover = {item = item, owner = tooltip:GetOwner()}
    local now = GetTime()
    if roster or pending or #queue > 0 then return end
    if sessionScanned or (cachedAt and now - cachedAt < CACHE_SECONDS) then
        sessionScanned = true
        showCounts()
        return
    end
    sessionScanned = true
    cache = {}
    roster = {deadline = now + TIMEOUT}
    frame:SetScript("OnUpdate", update)
    send("ALT_ROSTER")
end)

local function bagHidden()
    for i = 1, NUM_CONTAINER_FRAMES do
        if _G["ContainerFrame" .. i]:IsShown() then return end
    end
    sessionScanned = false
end

for i = 1, NUM_CONTAINER_FRAMES do
    _G["ContainerFrame" .. i]:HookScript("OnHide", bagHidden)
end
