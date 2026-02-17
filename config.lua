Config = {}

Config.Debug = false

Config.PoliceJob = 'police'
Config.UnemployedJob = 'unemployed'

Config.MaxStars = 5
Config.HurtCooldownSeconds = 20

-- Pokud už máš wanted v HUDu a nechceš ox_lib notify při přidání hvězd:
Config.NotifyOnStarsGain = false

Config.Stars = {
    -- PVP:
    HurtPlayer = 1,     -- zatím se u tebe používá jen pro report, můžeš později měnit pravidla
    KillPlayer = 2,

    HurtPoliceBonus = 1,
    KillPoliceBonus = 2,

    -- Police codex:
    PoliceExtraStars = 1,
}

Config.Persistence = {
    Enabled = true,
    Driver = 'auto', -- 'auto' | 'oxmysql' | 'mysql-async'
    Table = 'kg_wanted',
}

Config.Visibility = {
    Show3D = true,
    Show3DMaxDistance = 120.0,

    ZoneMinStars = 2,
    ZoneUpdateSeconds = 8,
    ZoneRadius = 220.0,
    ZoneRandomize = true,
    ZoneRandomizeMeters = 60.0,
}

Config.Interaction = {
    Distance = 2.2,
    MinStarsToJail = 1,

    UseAnimations = true,
    ActionTimeMs = 3500,

    PoliceAnim = { dict = 'mp_arrest_paired', name = 'cop_p2_back_left' },
    SuspectAnim = { dict = 'mp_arrest_paired', name = 'crook_p2_back_left' },
}

Config.Jail = {
    Enabled = true,

    MinMinutes = 2,
    MinutesPerStar = 2,

    FreezeInJail = true,

    JailCoords = vector4(459.2, -994.4, 24.9, 90.0),

    Cells = {
        vector4(460.127472,  -994.246155, 24.898926, 272.125977),
        vector4(459.758240,  -997.832947, 24.898926, 269.291351),
        vector4(459.349457, -1001.538452, 24.898926, 269.291351),
        vector4(467.775818,  -994.325256, 24.898926, 175.748032),
        vector4(472.206604,  -994.681335, 24.898926, 184.251968),
        vector4(476.624176,  -994.246155, 24.898926, 178.582672),
        vector4(480.909882,  -994.430786, 24.898926, 175.748032),
    },

    ReleaseCoords = vector4(427.3, -979.5, 30.7, 90.0),
}

Config.Rewards = {
    Enabled = true,
    MoneyPerStar = 20000,
    Account = 'bank',
}

Config.HappyHour = {
    Enabled = true,
    StartHour = 18,
    EndHour = 22,
    Multiplier = 2.0,
}

Config.Lawyer = {
    Enabled = true,
    JobName = 'lawyer',

    CooldownMinutes = 30,
    CooldownTable = 'kg_wanted_lawyer',

    Mode = 'clear', -- 'clear' nebo 'reduce'
    ReduceBy = 1,

    MoneyPerStar = 15000,
    Account = 'bank',

    Distance = 2.2,
    ActionTimeMs = 5500,

    RequestLabel = 'Pozadat o ocistu',
    RequestIcon  = 'fa-solid fa-scale-balanced',

    -- jak často server posílá wanted hráčům seznam právníků (aby šel filtrovat ox_target + šipka)
    SyncSeconds = 5,
}

-- ✅ POLICE DUTY (ITEMY + přesná hláška)
Config.PoliceDuty = {
    Enabled = true,

    DutyCoords = vector4(441.178009, -976.193420, 30.678345, 187.086609),
    Radius = 2.0,

    EnforceStationOnly = true,
    EnforceCheckSeconds = 10,

    PoliceGrade = 0,

    Requirements = {
        Enabled = true,
        Mode = 'items',

        ItemMap = {
            driver = { item = 'driver_license', label = 'Ridicak' },
            weapon = { item = 'weaponlicense',  label = 'Zbrojni prukaz' },
        }
    },

    Target = {
        IconOn  = 'fa-solid fa-badge',
        IconOff = 'fa-solid fa-badge',
        LabelOn  = 'Nastoupit sluzbu LSPD',
        LabelOff = 'Ukoncit sluzbu LSPD',
    }
}

Config.TestCommands = {
    Enabled = true,

    UseAcePermission = true,
    AceName = 'kg_wanted.test',

    AllowedIdentifiers = {
        -- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    },
}
