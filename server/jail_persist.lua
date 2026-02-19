-- KG_Wanted/server/jail_persist.lua

local ESX = exports['es_extended']:getSharedObject()

local function notify(src, msg)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'error',
        description = msg,
        position = 'top'
    })
end

local function getJailMeta(xPlayer)
    local meta = xPlayer.getMeta and xPlayer.getMeta('kg_jail') or nil
    if type(meta) ~= 'table' then return nil end

    local endAt = tonumber(meta.endAt or 0) or 0
    if endAt <= 0 then return nil end

    return {
        endAt = endAt,
        reason = tostring(meta.reason or 'VĚZENÍ')
    }
end

local function setJailMeta(xPlayer, endAt, reason)
    xPlayer.setMeta('kg_jail', {
        endAt = endAt,
        reason = reason or 'VĚZENÍ'
    })
end

local function clearJailMeta(xPlayer)
    xPlayer.setMeta('kg_jail', nil)
end

exports('SetJail', function(src, seconds, reason)
    seconds = tonumber(seconds or 0) or 0
    if seconds <= 0 then return false end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local endAt = os.time() + seconds
    setJailMeta(xPlayer, endAt, reason or 'VĚZENÍ')

    Player(src).state:set('kg_jail_endAt', endAt, true)
    Player(src).state:set('kg_jail_reason', reason or 'VĚZENÍ', true)

    TriggerClientEvent('kg_wanted:jail:apply', src, endAt, reason or 'VĚZENÍ')
    return true
end)

exports('ClearJail', function(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    clearJailMeta(xPlayer)

    Player(src).state:set('kg_jail_endAt', 0, true)
    Player(src).state:set('kg_jail_reason', nil, true)

    TriggerClientEvent('kg_wanted:jail:clear', src)
    return true
end)

exports('IsJailed', function(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local meta = getJailMeta(xPlayer)
    if not meta then return false end

    return os.time() < meta.endAt
end)

-- ✅ client oznámí, že trest doběhl -> server vyčistí meta
RegisterNetEvent('kg_wanted:jailFinished', function()
    local src = source
    exports['KG_Wanted']:ClearJail(src)
end)

-- ✅ relog fix
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if not xPlayer then return end

    local meta = getJailMeta(xPlayer)
    if not meta then return end

    local now = os.time()
    if now >= meta.endAt then
        clearJailMeta(xPlayer)
        return
    end

    Player(playerId).state:set('kg_jail_endAt', meta.endAt, true)
    Player(playerId).state:set('kg_jail_reason', meta.reason, true)

    CreateThread(function()
        Wait(1500)
        TriggerClientEvent('kg_wanted:jail:apply', playerId, meta.endAt, meta.reason)
        notify(playerId, ('Stále jsi ve vězení (%ds zbývá).'):format(meta.endAt - os.time()))
    end)
end)

RegisterNetEvent('kg_wanted:jail:requestTime', function()
    TriggerClientEvent('kg_wanted:jail:syncTime', source, os.time())
end)
