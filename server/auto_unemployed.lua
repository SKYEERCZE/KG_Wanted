-- KG_Wanted/server/auto_unemployed.lua
-- Jakmile hráč dostane wanted (kg_wanted > 0), automaticky dostane job "unemployed".

local ESX = exports['es_extended']:getSharedObject()

-- aby to nespamovalo setJob pořád dokola
local lastWanted = {} -- [src] = number

local function getSrcFromBagName(bagName)
    -- bagName typicky "player:123"
    if type(bagName) ~= 'string' then return nil end
    local id = bagName:match('player:(%d+)')
    return id and tonumber(id) or nil
end

local function isEnabled()
    return Config.AutoUnemployed and Config.AutoUnemployed.Enabled == true
end

local function isExemptJob(jobName)
    local ex = Config.AutoUnemployed and Config.AutoUnemployed.ExemptJobs
    if type(ex) ~= 'table' then return false end
    return ex[jobName] == true
end

local function setUnemployed(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local job = xPlayer.getJob and xPlayer.getJob() or nil
    local jobName = job and job.name or nil
    if not jobName then return end

    if jobName == (Config.AutoUnemployed.UnemployedJob or 'unemployed') then return end
    if isExemptJob(jobName) then return end

    -- Důležité: tady nastavujeme unemployed i když je wanted (job_block to musí povolit)
    xPlayer.setJob(Config.AutoUnemployed.UnemployedJob or 'unemployed', 0)

    if Config.AutoUnemployed.Notify then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = Config.AutoUnemployed.NotifyText or 'Jsi hledaný – byl jsi vyřazen z práce.',
            position = 'top'
        })
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    lastWanted[src] = nil
end)

-- OneSync: posloucháme statebag změnu wantedu
AddStateBagChangeHandler('kg_wanted', nil, function(bagName, key, value, _unused, replicated)
    if not isEnabled() then return end
    if key ~= 'kg_wanted' then return end

    local src = getSrcFromBagName(bagName)
    if not src or src <= 0 then return end
    if not GetPlayerName(src) then return end

    local stars = tonumber(value) or 0
    local prev = lastWanted[src] or 0
    lastWanted[src] = stars

    -- spouštíme jen při přechodu 0 -> >0
    if prev <= 0 and stars > 0 then
        setUnemployed(src)
    end
end)
