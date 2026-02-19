fx_version 'cerulean'
game 'gta5'

name 'KG_Wanted'
author 'Kaficko Gaming'
description 'Simple GTA-style wanted stars + police send-to-jail interaction (ESX job)'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/_init.lua',
    'client/threads/position.lua',
    'client/threads/crime_detection.lua',
    'client/threads/vehicle_theft.lua', -- ✅ NEW
    'client/threads/wanted_3d.lua',
    'client/threads/lawyer_highlight.lua',
    'client/police_zones.lua',
    'client/ui_messages.lua',
    'client/target.lua',
    'client/jail.lua',
    'client/jail_persist.lua',
}

server_scripts {
    'server/_init.lua',
    'server/db.lua',
    'server/persistence.lua',
    'server/wanted.lua',
    'server/happyhour.lua',
    'server/rewards.lua',
    'server/police_duty.lua',
    'server/zones.lua',
    'server/crime.lua',
    'server/jail.lua',
    'server/playerload.lua',
    'server/job_block.lua',
    'server/jail_persist.lua',
    'server/auto_unemployed.lua',
}

dependencies {
    'ox_lib',
    'es_extended',
    'oxmysql',
    'ox_target'
}
