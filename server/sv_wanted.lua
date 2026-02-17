KGW = KGW or {}
KGW.Wanted = KGW.Wanted or {}

local ESX = exports['es_extended']:getSharedObject()
local dbg = KGW.Utils.dbg
local clamp = KGW.Utils.clamp

local Wanted = {}        -- [src] = { identifier, stars, lastReason, lastPos, lastUpdate }
local HurtCooldown = {}  -- [src] = unix ts

local function isPolice(xPlayer)
    return xPlayer and xPlayer.job and xPlayer.job.name == Config.PoliceJob
end

local function isLawyer(xPlayer)
    return Config.Lawyer and Config.Lawyer.Enabled and xPlayer and xPlayer.job and xPlayer.job.name == (Config.Lawyer.JobName or 'lawyer')
end

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function ensureEntry(src)
    if not Wanted[src] then
        Wanted[src] = {
            identifier = getIdentifier(src) or '',
            stars = 0,
            lastReason = '',
            lastPos = vec3(0.0, 0.0, 0.0),
            lastUpdate = os.time(),
        }
    end
    if Wanted[src].identifier == '' then
        Wanted[src].identifier = getIdentifier(src) or ''
    end
    return Wanted[src]
end

local function setStatebags(src, stars, reason)
    Player(src).state.kg_wanted = tonumber(stars) or 0
    Player(src).state.kg_wanted_reason = tostring(reason or '')
end

local function persistWanted(identifier, stars, reason)
    if not (Config.Persistence and Config.Persistence.Enabled) then return end
    if not identifier or identifier == '' then return end

    local tableName = Config.Persistence.Table or 'kg_wanted'
    stars = tonumber(stars) or 0
    reason = tostring(reason or '')

    if stars <= 0 then
        KGW.DB.exec(('DELETE FROM %s WHERE identifier = ?'):format(tableName), { identifier })
        return
    end

    KGW.DB.exec(
        ('INSERT INTO %s (identifier, stars, reason) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE stars = VALUES(stars), reason = VALUES(reason), updated_at = CURRENT_TIMESTAMP'):format(tableName),
        { identifier, stars, reason }
    )
end

local function loadWanted(identifier, cb)
    if not (Config.Persistence and Config.Persistence.Enabled) then cb(0, '') return end
    if not identifier or identifier == '' then cb(0, '') return end

    local tableName = Config.Persistence.Table or 'kg_wanted'
    KGW.DB.fetchAll(('SELECT stars, reason FROM %s WHERE identifier = ? LIMIT 1'):format(tableName), { identifier }, function(rows)
        if rows and rows[1] then
            cb(tonumber(rows[1].stars) or 0, tostring(rows[1].reason or ''))
        else
            cb(0, '')
        end
    end)
end

local function setStars(src, stars, reason)
    local entry = ensureEntry(src)
    local oldStars = entry.stars or 0

    entry.stars = clamp(tonumber(stars) or 0, 0, Config.MaxStars)
    entry.lastReason = reason or entry.lastReason or ''
    entry.lastUpdate = os.time()

    setStatebags(src, entry.stars, entry.lastReason)
    persistWanted(entry.identifier, entry.stars, entry.lastReason)

    if Config.NotifyOnStarsGain and entry.stars > oldStars then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            title = '🚨 WANTED',
            description = ('Ziskal jsi %d★ - %s'):format(entry.stars, (entry.lastReason ~= '' and entry.lastReason or 'Prestupek'))
        })
    end
end

local function addStars(src, add, reason)
    local entry = ensureEntry(src)
    setStars(src, (entry.stars or 0) + (tonumber(add) or 0), reason)
end

local function clearWanted(src)
    setStars(src, 0, '')
end

local function getStars(src)
    local entry = ensureEntry(src)
    return entry.stars or 0, entry.lastReason or ''
end

KGW.Wanted._ESX = ESX
KGW.Wanted._Wanted = Wanted
KGW.Wanted._HurtCooldown = HurtCooldown

KGW.Wanted.isPolice = isPolice
KGW.Wanted.isLawyer = isLawyer
KGW.Wanted.getIdentifier = getIdentifier
KGW.Wanted.ensureEntry = ensureEntry

KGW.Wanted.setStatebags = setStatebags
KGW.Wanted.persistWanted = persistWanted
KGW.Wanted.loadWanted = loadWanted

KGW.Wanted.setStars = setStars
KGW.Wanted.addStars = addStars
KGW.Wanted.clearWanted = clearWanted
KGW.Wanted.getStars = getStars
