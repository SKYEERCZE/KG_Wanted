-- KG_Wanted/server/job_block.lua
-- Blokace změny jobu, pokud je hráč WANTED (bez spam loopu)

local ESX = exports['es_extended']:getSharedObject()

local bypass = {}          -- bypass[src] = true když job vracíme zpět
local lastNotifyAt = {}    -- lastNotifyAt[src] = GetGameTimer()

local function isPlayerWanted(src)
    local stars = tonumber(Player(src).state.kg_wanted or 0) or 0
    return stars > 0, stars
end

local function notifyCooldown(src, msg, cooldownMs)
    cooldownMs = cooldownMs or 2500
    local now = GetGameTimer()
    local last = lastNotifyAt[src] or 0

    if (now - last) < cooldownMs then return end
    lastNotifyAt[src] = now

    TriggerClientEvent('ox_lib:notify', src, {
        type = 'error',
        description = msg,
        position = 'top'
    })
end

AddEventHandler('playerDropped', function()
    local src = source
    bypass[src] = nil
    lastNotifyAt[src] = nil
end)

-- 🔒 Hlavní blokace
AddEventHandler('esx:setJob', function(source, job, lastJob)
    local src = source
    if not src or src <= 0 then return end
    if not job or not job.name then return end

    -- Pokud právě děláme "vrácení jobu", tak tohle volání ignoruj
    if bypass[src] then
        bypass[src] = nil
        return
    end

    local wanted, stars = isPlayerWanted(src)
    if not wanted then return end

    -- Pokud se to snaží nastavit na stejný job jako lastJob, nemá cenu nic řešit
    if lastJob and lastJob.name and lastJob.name == job.name and (lastJob.grade or 0) == (job.grade or 0) then
        return
    end

    notifyCooldown(src, ('Nemůžeš změnit práci, pokud jsi hledaný! (%d★)'):format(stars), 2500)

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Vrácení jobu zpět bez loopu
    bypass[src] = true

    if lastJob and lastJob.name then
        xPlayer.setJob(lastJob.name, lastJob.grade or 0)
    else
        xPlayer.setJob('unemployed', 0)
    end
end)
