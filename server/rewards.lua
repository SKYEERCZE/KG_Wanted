function KGW.rewardLawyer(lawyerSrc, stars)
    local xLawyer = KGW.ESX.GetPlayerFromId(lawyerSrc)
    if not KGW.isLawyer(xLawyer) then return 0, 1.0 end

    local perStar = tonumber(Config.Lawyer.MoneyPerStar) or 0
    local base = perStar * (tonumber(stars) or 0)
    if base <= 0 then return 0, 1.0 end

    local mult = 1.0
    if KGW.isHappyHourNow() then mult = tonumber(Config.HappyHour.Multiplier) or 2.0 end

    local amount = math.floor(base * mult)
    if amount <= 0 then return 0, mult end

    local account = (Config.Lawyer.Account or 'bank')
    if account == 'bank' then xLawyer.addAccountMoney('bank', amount)
    elseif account == 'money' then xLawyer.addMoney(amount)
    else xLawyer.addAccountMoney('bank', amount) end

    return amount, mult
end

function KGW.rewardPolice(policeSrc, stars)
    if not (Config.Rewards and Config.Rewards.Enabled) then return 0, 1.0 end
    local xPolice = KGW.ESX.GetPlayerFromId(policeSrc)
    if not KGW.isPolice(xPolice) then return 0, 1.0 end

    local perStar = tonumber(Config.Rewards.MoneyPerStar) or 0
    local base = perStar * (tonumber(stars) or 0)
    if base <= 0 then return 0, 1.0 end

    local mult = 1.0
    if KGW.isHappyHourNow() then mult = tonumber(Config.HappyHour.Multiplier) or 2.0 end

    local amount = math.floor(base * mult)
    if amount <= 0 then return 0, mult end

    local account = (Config.Rewards.Account or 'bank')
    if account == 'bank' then xPolice.addAccountMoney('bank', amount)
    elseif account == 'money' then xPolice.addMoney(amount)
    else xPolice.addAccountMoney('bank', amount) end

    TriggerClientEvent('kg_wanted:rewardBig', policeSrc, amount, mult)
    return amount, mult
end
