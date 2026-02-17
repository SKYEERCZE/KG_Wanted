exports('GetLocalStars', function()
    return tonumber(LocalPlayer.state.kg_wanted or 0) or 0
end)

exports('IsLocalWanted', function()
    return (tonumber(LocalPlayer.state.kg_wanted or 0) or 0) > 0
end)

exports('ShowBigMessage', function(title, subtitle, ms)
    if KGW and KGW.UI and KGW.UI.showBigWasted then
        KGW.UI.showBigWasted(title, subtitle, ms or 5000)
    end
end)
