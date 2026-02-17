-- ===== Wanted persistence =====
function KGW.persistWanted(identifier, stars, reason)
    if not (Config.Persistence and Config.Persistence.Enabled) then return end
    if not identifier or identifier == '' then return end

    local tableName = Config.Persistence.Table or 'kg_wanted'
    stars = tonumber(stars) or 0
    reason = tostring(reason or '')

    if stars <= 0 then
        KGW.db_exec(('DELETE FROM %s WHERE identifier = ?'):format(tableName), { identifier })
        return
    end

    KGW.db_exec(
        ('INSERT INTO %s (identifier, stars, reason) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE stars = VALUES(stars), reason = VALUES(reason), updated_at = CURRENT_TIMESTAMP'):format(tableName),
        { identifier, stars, reason }
    )
end

function KGW.loadWanted(identifier, cb)
    if not (Config.Persistence and Config.Persistence.Enabled) then cb(0, '') return end
    if not identifier or identifier == '' then cb(0, '') return end

    local tableName = Config.Persistence.Table or 'kg_wanted'
    KGW.db_fetchAll(('SELECT stars, reason FROM %s WHERE identifier = ? LIMIT 1'):format(tableName), { identifier }, function(rows)
        if rows and rows[1] then
            cb(tonumber(rows[1].stars) or 0, tostring(rows[1].reason or ''))
        else
            cb(0, '')
        end
    end)
end

-- ===== Lawyer cooldown persistence =====
local function lawyerTable()
    return (Config.Lawyer and Config.Lawyer.CooldownTable) or 'kg_wanted_lawyer'
end

function KGW.persistLawyerCooldown(identifier, unixTs)
    if not (Config.Persistence and Config.Persistence.Enabled) then return end
    if not (Config.Lawyer and Config.Lawyer.Enabled) then return end
    if not identifier or identifier == '' then return end

    unixTs = tonumber(unixTs) or 0
    local t = lawyerTable()

    KGW.db_exec(
        ('INSERT INTO %s (identifier, last_help_unix) VALUES (?, ?) ON DUPLICATE KEY UPDATE last_help_unix = VALUES(last_help_unix), updated_at = CURRENT_TIMESTAMP'):format(t),
        { identifier, unixTs }
    )
end

function KGW.loadLawyerCooldown(identifier, cb)
    if not (Config.Persistence and Config.Persistence.Enabled) then cb(0) return end
    if not (Config.Lawyer and Config.Lawyer.Enabled) then cb(0) return end
    if not identifier or identifier == '' then cb(0) return end

    local t = lawyerTable()
    KGW.db_fetchAll(('SELECT last_help_unix FROM %s WHERE identifier = ? LIMIT 1'):format(t), { identifier }, function(rows)
        if rows and rows[1] then cb(tonumber(rows[1].last_help_unix) or 0) else cb(0) end
    end)
end
