KGW = {}

KGW.ESX = exports['es_extended']:getSharedObject()

KGW.PlayerData = {}
KGW.cache = {
    isPolice = false,
    isLawyer = false,
}

KGW.zoneBlips = {} -- [wantedSrc] = { radius = blip, center = blip }
KGW.lastHurtReport = 0

KGW.jailActive = false
KGW.jailEndTime = 0

function KGW.dbg(...)
    if Config.Debug then
        print('[KG_Wanted]', ...)
    end
end

function KGW.refreshJobCache()
    local job = KGW.PlayerData and KGW.PlayerData.job and KGW.PlayerData.job.name or nil
    KGW.cache.isPolice = (job == Config.PoliceJob)
    KGW.cache.isLawyer = (Config.Lawyer and Config.Lawyer.Enabled and job == (Config.Lawyer.JobName or 'lawyer'))
end

AddEventHandler('esx:playerLoaded', function(xPlayer)
    KGW.PlayerData = xPlayer
    KGW.refreshJobCache()
end)

RegisterNetEvent('esx:setJob', function(job)
    KGW.PlayerData.job = job
    KGW.refreshJobCache()
end)

CreateThread(function()
    while not KGW.ESX.IsPlayerLoaded() do Wait(250) end
    KGW.PlayerData = KGW.ESX.GetPlayerData()
    KGW.refreshJobCache()
end)

-- 3D text helper
function KGW.drawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextCentre(1)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(_x, _y)
end

-- ======== GTA BIG MESSAGE HELPERS ========
function KGW.showBigWasted(title, subtitle, durationMs)
    durationMs = tonumber(durationMs) or 5000

    local scaleform = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

    BeginScaleformMovieMethod(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE')
    PushScaleformMovieMethodParameterString(title)
    PushScaleformMovieMethodParameterString(subtitle)
    PushScaleformMovieMethodParameterInt(5)
    EndScaleformMovieMethod()

    local endTime = GetGameTimer() + durationMs
    while GetGameTimer() < endTime do
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        Wait(0)
    end

    SetScaleformMovieAsNoLongerNeeded(scaleform)
end
