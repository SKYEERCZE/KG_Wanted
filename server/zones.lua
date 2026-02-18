-- KG_Wanted/server/zones.lua
-- ZONE BLIPS DISABLED (moc bordelu na mapě)
-- Pozice hráčů si Wanted systém pořád ukládá přes kg_wanted:updatePos,
-- ale nic už nebroadcastujeme policii.

RegisterNetEvent('kg_wanted:updatePos', function(pos)
    local src = source
    if type(pos) ~= 'table' or pos.x == nil or pos.y == nil or pos.z == nil then return end
    local entry = KGW.ensureEntry(src)
    entry.lastPos = vec3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
end)
