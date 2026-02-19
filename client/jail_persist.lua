-- KG_Wanted/client/jail_persist.lua
-- Persist vrstva: nepoužívá os.time() (na clientu není).
-- Při relogu znovu spustí normální kg_wanted:goJail s remaining časem.

local function nowSeconds()
    -- GetGameTimer() je ms od startu session, takže si držíme offset vůči server endAt.
    -- Nejjednodušší a nejspolehlivější: remaining si spočítáme na SERVERU,
    -- ale protože server posílá endAt (unix), uděláme to tak, že client nepočítá unix čas vůbec:
    -- jen přepočítá "zbývá" z endAt pomocí serverTime, který si jednorázově vezmeme přes event.
    return nil
end

local serverUnixNow = nil
local serverUnixSyncAt = 0

RegisterNetEvent('kg_wanted:jail:syncTime', function(unixNow)
    serverUnixNow = tonumber(unixNow or 0) or 0
    serverUnixSyncAt = GetGameTimer()
end)

local function getApproxServerUnix()
    if not serverUnixNow or serverUnixNow <= 0 then return 0 end
    local dt = (GetGameTimer() - serverUnixSyncAt) / 1000.0
    return math.floor(serverUnixNow + dt)
end

local function applyFromEndAt(endAt, reason)
    endAt = tonumber(endAt or 0) or 0
    if endAt <= 0 then return end

    local srv = getApproxServerUnix()
    if srv <= 0 then
        -- nemáme sync času, zkusíme si o něj říct a aplikovat o chvilku později
        TriggerServerEvent('kg_wanted:jail:requestTime')
        CreateThread(function()
            Wait(350)
            local srv2 = getApproxServerUnix()
            if srv2 <= 0 then return end

            local remaining = endAt - srv2
            if remaining <= 0 then return end
            local minutes = math.max(1, math.ceil(remaining / 60))
            TriggerEvent('kg_wanted:goJail', minutes, { officer = reason or 'VĚZENÍ', cell = nil })
        end)
        return
    end

    local remaining = endAt - srv
    if remaining <= 0 then return end

    local minutes = math.max(1, math.ceil(remaining / 60))

    -- napojení na tvoje původní vězení (client/jail.lua)
    TriggerEvent('kg_wanted:goJail', minutes, {
        officer = reason or 'VĚZENÍ',
        cell = nil
    })
end

RegisterNetEvent('kg_wanted:jail:apply', function(endAt, reason)
    CreateThread(function()
        -- počkej na spawn/ped
        Wait(1500)
        applyFromEndAt(endAt, reason)
    end)
end)

RegisterNetEvent('kg_wanted:jail:clear', function()
    -- nic – goJail si to odřídí sám
end)

CreateThread(function()
    Wait(2000)
    -- hned po startu si vyžádáme server time, ať máme přesný remaining
    TriggerServerEvent('kg_wanted:jail:requestTime')

    Wait(700)
    local endAt = tonumber(LocalPlayer.state.kg_jail_endAt or 0) or 0
    if endAt > 0 then
        applyFromEndAt(endAt, LocalPlayer.state.kg_jail_reason or 'VĚZENÍ')
    end
end)
