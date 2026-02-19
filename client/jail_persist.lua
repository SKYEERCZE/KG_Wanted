-- KG_Wanted/client/jail_persist.lua
-- Persist vrstva: při relogu znovu spustí normální kg_wanted:goJail s remaining časem.

local function applyFromEndAt(endAt, reason)
    endAt = tonumber(endAt or 0) or 0
    if endAt <= 0 then return end

    local remaining = endAt - os.time()
    if remaining <= 0 then return end

    local minutes = math.max(1, math.ceil(remaining / 60))

    -- po relogu většinou nemáme officer -> dáme generický text
    TriggerEvent('kg_wanted:goJail', minutes, {
        officer = reason or 'VĚZENÍ',
        cell = nil
    })
end

RegisterNetEvent('kg_wanted:jail:apply', function(endAt, reason)
    CreateThread(function()
        -- počkej na ped/spawn
        Wait(1500)
        applyFromEndAt(endAt, reason)
    end)
end)

RegisterNetEvent('kg_wanted:jail:clear', function()
    -- nic extra, goJail si to odřídí samo
end)

CreateThread(function()
    Wait(2500)
    local endAt = tonumber(LocalPlayer.state.kg_jail_endAt or 0) or 0
    if endAt > os.time() then
        applyFromEndAt(endAt, LocalPlayer.state.kg_jail_reason or 'VĚZENÍ')
    end
end)
