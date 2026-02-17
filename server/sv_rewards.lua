KGW = KGW or {}
KGW.Rewards = KGW.Rewards or {}

local ESX = KGW.Wanted._ESX
local isPolice = KGW.Wanted.isPolice
local isLawyer = KGW.Wanted.isLawyer

local function rewardPolice(policeSrc, stars)
    if not (Config.Rewards and Config.Rewards.Enabled) then return 0, 1.0 end
    local xPolice = ESX.GetPlayerFromId(policeSrc)
    if not isPolice(xPolice) then return 0, 1.0 end

    local perStar = tonumber(Config.Rewards.MoneyPerStar) or 0
    local base = perStar * (tonumber(stars) or 0)
    if base <= 0 then return 0, 1.0 end

    local mult = KGW.Utils.happyHourMultiplier()
    local amount = math.floor(base * mult)
    if amount <= 0 then return 0, mult end

    local account = (Config.Rewards.Account or 'bank')
    if account == 'bank' then xPolice.addAccountMoney('bank', amount)
    elseif account == 'money' then xPolice.addMoney(amount)
    else xPolice.addAccountMoney('bank', amount) end

    TriggerClientEvent(KGW.Const.Events.RewardBig, policeSrc, amount, mult)
    return amount, mult
end

local function rewardLawyer(lawyerSrc, stars)
    local xLawyer = ESX.GetPlayerFromId(lawyerSrc)
    if not isLawyer(xLawyer) then return 0, 1.0 end

    local perStar = tonumber(Config.Lawyer.MoneyPerStar) or 0
    local base = perStar * (tonumber(stars) or 0)
    if base <= 0 then return 0, 1.0 end

    local mult = KGW.Utils.happyHourMultiplier()
    local amount = math.floor(base * mult)
    if amount <= 0 then return 0, mult end

    local account = (Config.Lawyer.Account or 'bank')
    if account == 'bank' then xLawyer.addAccountMoney('bank', amount)
    elseif account == 'money' then xLawyer.addMoney(amount)
    else xLawyer.addAccountMoney('bank', amount) end

    return amount, mult
end

KGW.Rewards.rewardPolice = rewardPolice
KGW.Rewards.rewardLawyer = rewardLawyer
