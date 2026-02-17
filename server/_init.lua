KGW = {}

KGW.ESX = exports['es_extended']:getSharedObject()

KGW.Wanted = {}
KGW.HurtCooldown = {}

function KGW.dbg(...)
    if Config.Debug then
        print('[KG_Wanted]', ...)
    end
end

function KGW.clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

function KGW.isPolice(xPlayer)
    return xPlayer and xPlayer.job and xPlayer.job.name == Config.PoliceJob
end

function KGW.isLawyer(xPlayer)
    return Config.Lawyer and Config.Lawyer.Enabled and xPlayer and xPlayer.job and xPlayer.job.name == (Config.Lawyer.JobName or 'lawyer')
end
