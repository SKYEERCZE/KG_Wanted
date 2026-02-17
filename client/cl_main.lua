KGW = KGW or {}

local ESX = exports['es_extended']:getSharedObject()

KGW.Client = KGW.Client or {}
KGW.Client.PlayerData = {}
KGW.Client.isPoliceCached = false
KGW.Client.isLawyerCached = false

local function refreshJobCache()
    local job = KGW.Client.PlayerData and KGW.Client.PlayerData.job and KGW.Client.PlayerData.job.name or nil
    KGW.Client.isPoliceCached = (job == Config.PoliceJob)
    KGW.Client.isLawyerCached = (Config.Lawyer and Config.Lawyer.Enabled and job == (Config.Lawyer.JobName or 'lawyer'))
end

AddEventHandler('esx:playerLoaded', function(xPlayer)
    KGW.Client.PlayerData = xPlayer
    refreshJobCache()
end)

RegisterNetEvent('esx:setJob', function(job)
    KGW.Client.PlayerData.job = job
    refreshJobCache()
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(250) end
    KGW.Client.PlayerData = ESX.GetPlayerData()
    refreshJobCache()
end)

-- pos update pro server (zóny)
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            TriggerServerEvent(KGW.Const.Events.UpdatePos, { x = c.x, y = c.y, z = c.z })
        end
    end
end)
