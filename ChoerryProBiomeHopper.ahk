;#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; 2026 BIOME HOPPER - GUI CONTROLLED VERSION
;
; REQUIRED:
;   2026biomehop_UI_v3.ahk
;   Lib\OCR.ahk
;
; There are NO function hotkeys in this version.
; Everything is controlled from the GUI.
;
; OCR library:
; https://github.com/Descolada/OCR
; ============================================================

#Include Lib\OCR.ahk

SetWorkingDir(A_ScriptDir)
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
SendMode("Input")
SetTitleMatchMode(2)
SetControlDelay(1)
SetWinDelay(0)
SetKeyDelay(-1)
SetMouseDelay(-1)

; ============================================================
; GLOBALS
; ============================================================
global PanelRegistry := Map()
global ViewMenuObj := 0
global BiomeSelectorGui := 0
global AttackEditorGui := 0
global OreSelectorGui := 0
global DiscordConfigGui := 0
global LuckCalcGui := 0
global SelectedMonitor := 1
global LastErrorCheckTick := 0 ; used by the currently disabled error-screen check. may be relevant later.

global WatchdogLastStatus := ""
global WatchdogLastStatusChangeTick := 0
global WatchdogAlertSent := false

global BiomeNotifyCooldownMs := 60000        ; 1 minute
global LastBiomeNotifyTick := Map()          ; biome id -> last notify A_TickCount
global LastBossNotifyTick := Map()

global MacroRunning := false
global MacroPaused := false
global MacroMode := ""

; ---- Orenga (priority roaming boss) ----
global OrengaAlertActive := false
global OrengaLastDetectTick := 0
global OrengaDetectCooldownMs := 500     ; rate-limit OCR to 5x/second
; Match on a set of fragments so common OCR misreads still hit.
; Each of these is unlikely to appear in any other boss name.
global OrengaKeywords := ["oreng", "0reng", "oren9", "0ren9", "oreng4"]
global OrengaRoleID := "1545938717594620045" ;insert your own role ID for Orenga

global AutoAttackEnabled := false
global AutoAttackIntervalMs := 80    ; clicks per interval
global AutoAttackHotkey := "^+a"     ; Ctrl+Shift+A
global AttackMinGapMs := 60

global AttackSequencesFile := A_ScriptDir . "\attack_sequences.txt"
global AttackSequences := Map()          ; name -> array of command objects
global ActiveSequenceName := ""
global ActiveSequenceCommands := []
global ActiveSequenceIndex := 1
global AttackTickWaitUntil := 0

global InjectedLines := []   ; test-only: lines to appear in the next OCR pass
global CommunityAutoStage := true

global ErrorCheckRegion := { x: 0, y: 0, w: 0, h: 0 }   ; computed on demand

global BadBiomeSeenCount := 0

; Original OCR defaults from your script.
global OCR_X := 12
global OCR_Y := 67
global OCR_WIDTH := 461
global OCR_HEIGHT := 285
global OCR_Calibrated := false
global ChatDisplayName := "Pro"   ; e.g. "Pro" — matches "Pro: hello" chat lines

; Target-biome / boss detection.
global TargetBiomeDef := ""           ; the def object for the biome we're camping
global TargetPingedBosses := Map()    ; boss names pinged this biome visit (bar OCR dedup)
global TargetBiomeActive := false
global TargetBiomeKeyword := ""
global TargetBiomeName := ""
global TargetBiomeStartedTick := 0
global TargetChatBaseline := Map()
global BadBiomeSeenCount := 0
global BadBiomeSeenId    := ""
global TargetTimeoutMs := 0  ; 0 = wait indefinitely; safer so a wanted boss is never lost by timeout

global AttackHoldX := -1
global AttackHoldY := -1
global AttackHoldConfigured := false
global PlayButtonX := -1
global PlayButtonY := -1
global PlayButtonConfigured := false
global AutoAttackActive := false
global AutoAttackStartedTick := 0
global AutoAttackMaxMs := 5 * 60 * 1000   ; safety: release after 5 min

; ---- Anti-AFK / idle-kick prevention ----
global AntiAfkEnabled         := true       ; on by default
global AntiAfkIntervalMs      := 10000      ; ~45s between jiggles; well under Roblox's ~20 min kick timer
global LastAntiAfkTick        := 0
global AntiAfkJigglePixels    := 4          ; how far the cursor drifts each jiggle
global AntiAfkLastDir         := 1          ; alternate direction each tick

global JoinWindowExe := "Roblox Account Manager.exe" ;firefox.exe
global JoinWindowTitle := ""
global JoinButtonX := 660 ;1472
global JoinButtonY := 905 ;1140/1170
global JoinButtonRelX := -1
global JoinButtonRelY := -1

global FollowButtonX := 0
global FollowButtonY := 0
global FollowButtonRelX := -1
global FollowButtonRelY := -1
global FollowButtonConfigured := false

global SafeClickX := 100 ;1200
global SafeClickY := 888 ;150
global SafeClickRelX := -1
global SafeClickRelY := -1
global SafeClickConfigured := false
global RobloxLaunchTimeout := 60000
global ChatFocusInterval := 4000
global LastChatFocusTick := 0

global UsernameFieldX := 0
global UsernameFieldY := 0
global UsernameFieldRelX := -1
global UsernameFieldRelY := -1
global UsernameFieldConfigured := false
global AltNames := []

; How long to wait after resuming before scanning for a biome/boss again.
; "/clear" wipes stale chat text, but the boss health bar is a sprite,
; not text, so this is a small safety margin in case it takes a moment
; to visually disappear after a real kill.
global PostResumeGraceMs := 3000

global PauseHotkey := "F6"
global StopHotkey := "F7"
global ExitHotkey := "F8"
global StartTrueHotkey := "F9"
global StartModifiedHotkey := "F10"

global ChatOCR_X := 12
global ChatOCR_Y := 67
global ChatOCR_WIDTH := 461
global ChatOCR_HEIGHT := 285

; Boss-bar OCR is calculated from the Roblox window dynamically.
; This is more reliable across your 3840x2400 / 2560x1440 displays.

; GUI references.
global MainGui := 0
global StatusText := 0
global ModeText := 0
global RegionText := 0
global OCRResultEdit := 0
global PauseButton := 0
global DiscordURLEdit := 0
global DiscordRoleIDEdit := 0
global DiscordTestResultEdit := 0

; The webhook URL is saved here so you don't have to re-paste it every
; time you restart the script.
global ConfigFile := A_ScriptDir . "\biome_hopper_config.ini"

; Calibration state.
global Calibrating := false
global CalibrationStarted := false
global CalibrationStartX := 0
global CalibrationStartY := 0
global CalibrationOverlay := 0
global CalibrationInfo := 0
global CalibrationInstruction := 0
global SelectionTop := 0
global SelectionBottom := 0
global SelectionLeft := 0
global SelectionRight := 0
global SelectionFill := 0

; Discord.
; Replace this with a NEW webhook because the old webhook was exposed.
global DiscordWebhookURL := "PASTE_NEW_DISCORD_WEBHOOK_HERE"
global DiscordDefaultRoleID := ""

; Included automatically in every notification so you never have to
; manually copy/paste the join link when you get pinged. Each account
; (each copy of this script) should have its own, since each has its own
; private server.
global PrivateServerLink := "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE"

; Optional SECOND Discord destination (e.g. a community server). This
; needs its OWN role ID maps below, because role IDs are specific to one
; Discord server - the same boss will have a different role ID on a
; different server. Leave SecondaryWebhookURL blank/unset and this is
; simply never used. Toggle SecondaryEnabled from the GUI checkbox.
global SecondaryWebhookURL := "PASTE_SECONDARY_WEBHOOK_HERE"
global SecondaryEnabled := false

; Same keys as RoleMap/BossRoleMap below, but with the SECOND server's
; role IDs. Fill these in once you have them - leave a key out (or blank)
; and that ping just won't @ mention anyone on the 2nd server.
global SecondaryRoleMap := Map()
global SecondaryBossRoleMap := Map()

; ============================================================
; BOSS MAP
; ============================================================

;; ============================================================
; BIOME / BOSS DEFINITIONS  (single source of truth)
;
; Each entry:
;   id            - stable INI key, never change once shipped
;   keywords      - substrings that appear in the BIOME chat line
;   biomeName     - canonical message shown in Discord / OCR box
;   boss          - boss display name ("" if biome has no boss we track)
;   bossKeywords  - substrings that appear on the BOSS bar / spawn line
;   roleID        - Discord role to ping for this biome
;   defaultGood   - first-run default; user can flip it in the GUI
; ============================================================

global BiomeDefs := [
    ; ============================================================
    ; RARE  (default GOOD)
    ; ============================================================
    { id: "lux", keywords: ["bright light"], biomeName: "A bright light is shining over the world!",
      roleID: "1545936596514119871", defaultGood: true,
      bosses: [ { name: "Lux", keywords: ["lux"], roleID: "1545936596514119871", notify: true } ] },

    { id: "rex", keywords: ["being torn"], biomeName: "The world is being torn apart!",
      roleID: "1545936767457300502", defaultGood: true,
      bosses: [ { name: "Rex", keywords: ["rex"], roleID: "1545936767457300502", notify: true } ] },

    { id: "aqua", keywords: ["begins to flood"], biomeName: "The ocean begins to flood around the world!",
      roleID: "1544373254867648552", defaultGood: true,
      bosses: [ { name: "Aqua", keywords: ["aqua"], roleID: "1544373254867648552", notify: true } ] },

    { id: "chaos", keywords: ["losing its"], biomeName: "The world is losing its existence!",
      roleID: "1545936824734584902", defaultGood: true,
      bosses: [ { name: "Chaos", keywords: ["chaos"], roleID: "1545936824734584902", notify: true } ] },

    { id: "ignis", keywords: ["air begins to warm"], biomeName: "The air begins to warm around the world!",
      roleID: "1545936886919602238", defaultGood: true,
      bosses: [ { name: "Ignis", keywords: ["ignis"], roleID: "1545936886919602238", notify: true } ] },

    { id: "tenebris", keywords: ["has consumed"], biomeName: "Darkness has consumed the world!",
      roleID: "1545937023947382864", defaultGood: true,
      bosses: [ { name: "Tenebris", keywords: ["tenebris"], roleID: "1545937023947382864", notify: true } ] },

    { id: "firegod", keywords: ["fire god is here"], biomeName: "The fire god is here...",
      roleID: "", defaultGood: true,
      bosses: [
        { name: "The Fire God", keywords: ["the fire god", "fire god is here"], roleID: "", notify: false, leave: false},
        { name: "nacker, the True Fire God", keywords: ["true fire god"], roleID: "1550309162830008401", notify: true, leave: false }
      ] },

    ; ============================================================
    ; ULTRA RARE  (default GOOD)
    ; ============================================================
    { id: "pressure", keywords: ["strange pressure"], biomeName: "A strange pressure fills the air... and then.. nothing...",
      roleID: "1545971465139003513", defaultGood: true,
      bosses: [
        { name: "The Old Dragon", keywords: ["old dragon"], roleID: "1545971539332046879", notify: true },
        { name: "Angry Man", keywords: ["angry man"], roleID: "1546219292893118596", notify: true },
        { name: "Chrono", keywords: ["chrono"], roleID: "1545937140557418656", notify: true }
      ] },

    { id: "chronos", keywords: ["time itself"], biomeName: "Time itself is beginning to fall apart!",
      roleID: "1545937140557418656", defaultGood: true,
      bosses: [ { name: "Chrono", keywords: ["chrono"], roleID: "1545937140557418656", notify: true } ] },

    { id: "caedes", keywords: ["eternal suffering"], biomeName: "Your eternal suffering will begin soon...",
      roleID: "1545937208253620234", defaultGood: true,
      bosses: [ { name: "Caedes", keywords: ["caedes"], roleID: "1545937208253620234", notify: true } ] },

    { id: "malvrock", keywords: ["crimson warrior"], biomeName: "The Crimson Warrior is here...",
      roleID: "1545937316777033738", defaultGood: true,
      bosses: [ { name: "Malvrock", keywords: ["malvrock"], roleID: "1545937316777033738", notify: true } ] },

    { id: "inanis", keywords: ["blackhole to a"], biomeName: "A blackhole to a sealed realm has appeared!",
      roleID: "1545937421097771119", defaultGood: true,
      bosses: [ { name: "Inanis", keywords: ["inanis"], roleID: "1545937421097771119", notify: true } ] },

    { id: "finalrex", keywords: ["galaxy is being"], biomeName: "The galaxy is being destroyed at the blink of your eye. It is time for your final challenge.",
      roleID: "1545937664791023706", defaultGood: true,
      bosses: [ { name: "Final Rex", keywords: ["final rex"], roleID: "1545937664791023706", notify: true } ] },

    { id: "plat", keywords: ["be right back"], biomeName: "Be right back.",
      roleID: "1545937727495737374", defaultGood: true,
      bosses: [ { name: "Platformation123", keywords: ["platformation123"], roleID: "1545937727495737374", notify: true } ] },

    ; ============================================================
    ; UNCOMMON EXCEPTIONS  (user-flagged)
    ; ============================================================
    { id: "hydra", keywords: ["hydra has come"], biomeName: "Hydra has come to the overworld!",
      roleID: "1544373201893851168", defaultGood: true, autoAttack: true, attackSequence : "autoswing",
      bosses: [
        { name: "Hydra", keywords: ["hydra"], roleID: "", notify: false },
        { name: "The Dragon God", keywords: ["dragon god"], roleID: "", notify: false },
        { name: "The Old Dragon", keywords: ["old dragon"], roleID: "1545971539332046879", notify: true }
      ] },

    { id: "void", keywords: ["void broke through"], biomeName: "The Void broke through a dimensional barrier!",
      roleID: "", defaultGood: false,
      bosses: [
        { name: "Opticus", keywords: ["opticus"], roleID: "1550369749555216494", notify: false },
        { name: "The Triplets", keywords: ["triplets", "ruby", "sapphire", "emerald"], roleID: "", notify: false },
        { name: "The Eye of Azurewrath", keywords: ["azurewrath"], roleID: "1550310349427703919", notify: true }
      ] },

    { id: "dungeon", keywords: ["dungeon has escaped"], biomeName: "The dungeon has escaped onto the island!",
      roleID: "", defaultGood: false,
      bosses: [
        { name: "nacker", keywords: ["nacker"], roleID: "1550311068667093102", notify: false, leave: true },
        { name: "Hades", keywords: ["hades"], roleID: "", notify: false },
        { name: "Medusa", keywords: ["medusa"], roleID: "", notify: false }
      ] },

    ; ============================================================
    ; UNCOMMON  (default BAD)
    ; ============================================================
    { id: "elewars", keywords: ["elemental wars have"], biomeName: "The Elemental Wars have reached the island!",
      roleID: "1544373232914661377", defaultGood: false,
      bosses: [
        { name: "Fire",  keywords: ["fire"],  roleID: "", notify: false },
        { name: "Earth", keywords: ["earth"], roleID: "", notify: false },
        { name: "Air",   keywords: ["air"],   roleID: "", notify: false },
        { name: "Dark",  keywords: ["dark"],  roleID: "", notify: false },
        { name: "Water", keywords: ["water"], roleID: "", notify: false },
        { name: "Light", keywords: ["light"], roleID: "", notify: false },
        { name: "Life",  keywords: ["life"],  roleID: "", notify: false },
        { name: "Death", keywords: ["death"], roleID: "", notify: false }
      ] },

    { id: "ocean",    keywords: ["ocean temple"],            biomeName: "The ocean temple is taking over the island!", roleID: "", defaultGood: false, bosses: [] },
    { id: "midas",    keywords: ["king midas"],              biomeName: "King Midas is invading the island!",         roleID: "", defaultGood: false, bosses: [
        { name: "King Midas", keywords: ["midas"], roleID: "", notify: false },
        { name: "Greed",      keywords: ["greed"], roleID: "", notify: false }
      ] },
    { id: "cthulhu",  keywords: ["cthulhu has invaded"],     biomeName: "Cthulhu has invaded the island!",            roleID: "", defaultGood: false, bosses: [
        { name: "Poseidon", keywords: ["poseidon"], roleID: "", notify: false },
        { name: "Cthulhu",  keywords: ["cthulhu"],  roleID: "", notify: false }
      ] },
    { id: "hercules", keywords: ["hercules has made"],       biomeName: "Hercules has made his way onto the island...", roleID: "", defaultGood: false, bosses: [] },

    ; ============================================================
    ; COMMON  (default BAD)
    ; ============================================================
    { id: "army",       keywords: ["zombie army"],              biomeName: "A zombie Army is invading!",        roleID: "", defaultGood: false, bosses: [] },
    { id: "moon",       keywords: ["moon is rising"],           biomeName: "The moon is rising!",               roleID: "", defaultGood: false, bosses: [
        { name: "Medusa",      keywords: ["medusa"],      roleID: "", notify: false },
        { name: "Zeus",        keywords: ["zeus"],        roleID: "", notify: false },
        { name: "Zombie Boss", keywords: ["zombie boss"], roleID: "", notify: false },
        { name: "nacker",      keywords: ["nacker"],      roleID: "1550311068667093102", notify: false, leave: true},
        { name: "Ninja",       keywords: ["ninja"],       roleID: "", notify: false },
        { name: "Garen",       keywords: ["garen"],       roleID: "", notify: false },
        { name: "Elco",        keywords: ["elco, god of flames"],        roleID: "", notify: false }
      ] },
    { id: "underworld", keywords: ["underworld is attacking"],  biomeName: "The underworld is attacking!",      roleID: "", defaultGood: false, bosses: [] },
    { id: "sand",       keywords: ["sandstorm has arrived"],    biomeName: "A sandstorm has arrived!",          roleID: "", defaultGood: false, bosses: [] },
    { id: "blizzard",   keywords: ["blizzard has arrived"],     biomeName: "A blizzard has arrived!",           roleID: "", defaultGood: false, bosses: [] },
    { id: "wizards",    keywords: ["wizards of arbor"],     biomeName: "The Wizards of Arbor have invaded the island!",         roleID: "", defaultGood: false, bosses: [] },
    { id: "pirate",     keywords: ["pirate army"],              biomeName: "A pirate army is attacking!",       roleID: "", defaultGood: false, bosses: [] },

    ; ============================================================
    ; Defaults to GOOD: on a fresh server the script enters TARGET BIOME
    ; mode and camps `normal`, pinging if a boss spawns and rejoining when
    ; a boss with leave:true appears. Flip to IGNORED if you'd rather the
    ; script keep hopping regardless.
    ; ============================================================
        { id: "normal", keywords: ["world has returned to normal"], biomeName: "The world has returned to normal.",
      roleID: "", defaultStatus: "good", autoAttack: true, attackSequence: "autoswing",
      bosses: [
        { name: "Medusa",      keywords: ["medusa"],      roleID: "", notify: false, leave: true },
        { name: "Zeus",        keywords: ["Zeus"],        roleID: "", notify: false, leave: true },
        { name: "Zombie Boss", keywords: ["zombie boss"], roleID: "", notify: false, leave: true },
        { name: "nacker",      keywords: ["nacker"],      roleID: "1550311068667093102", notify: false, leave: true },
        { name: "Ninja",       keywords: ["ninja"],       roleID: "", notify: false, leave: true },
        { name: "Garen",       keywords: ["garen"],       roleID: "", notify: false, leave: true },
        { name: "Elco",        keywords: ["elco, god of flames"],        roleID: "", notify: false, leave: true }
      ] }
]

; Ore spawn names would otherwise false-positive on "has spawned".
; ============================================================
; ORE DEFINITIONS
; ============================================================
global OreDefs := [
    { id: "iron",          name: "Iron",              keywords: ["iron"],           roleID: "", defaultNotify: false },
    { id: "optimum",       name: "Optimum",           keywords: ["optimum"],        roleID: "", defaultNotify: true  },
    { id: "ultimus",       name: "Ultimus",           keywords: ["ultimus"],        roleID: "", defaultNotify: true  },
    { id: "pure_vermite",  name: "Pure Vermite",      keywords: ["pure vermite"],   roleID: "", defaultNotify: true  },
    { id: "pure_amber",    name: "Pure Amberstone",   keywords: ["pure amberstone"],roleID: "", defaultNotify: true  },
    { id: "destinium",     name: "Destinium",         keywords: ["destinium"],      roleID: "", defaultNotify: true  },
    { id: "rainbowite",    name: "Rainbowite",        keywords: ["rainbowite"],     roleID: "", defaultNotify: true  },
    { id: "salt",          name: "Salt",              keywords: ["salt"],           roleID: "", defaultNotify: false },
    { id: "black_vermite", name: "Black Vermite",     keywords: ["black vermite"],  roleID: "", defaultNotify: true  },
    { id: "chaotic_ore",   name: "Chaotic Ore",       keywords: ["chaotic ore"],    roleID: "", defaultNotify: true  },
    { id: "strange_ore",   name: "A Strange Ore",     keywords: ["a strange ore"],  roleID: "", defaultNotify: true  }
]

; Derived from OreDefs - kept for backwards-compat with boss filtering.
global OreSpawnNames := []
for def in OreDefs
    for kw in def.keywords
        OreSpawnNames.Push(kw)

global OreNotifyEnabled := Map()
global LastOreNotifyTick := Map()
global OreByKeyword := Map()

BuildOreLookups()
{
    global OreDefs, OreByKeyword
    OreByKeyword := Map()
    for def in OreDefs
        for kw in def.keywords
            OreByKeyword[StrLower(kw)] := def
}

LoadOreChoices()
{
    global OreDefs, OreNotifyEnabled, ConfigFile
    for def in OreDefs
        OreNotifyEnabled[def.id] := def.defaultNotify
    if !FileExist(ConfigFile)
        return
    for def in OreDefs
    {
        try
        {
            v := IniRead(ConfigFile, "Ores", def.id, "")
            if (v = "notify")
                OreNotifyEnabled[def.id] := true
            else if (v = "ignore")
                OreNotifyEnabled[def.id] := false
        }
    }
}

SaveOreChoice(id, state)
{
    global ConfigFile
    try IniWrite(state, ConfigFile, "Ores", id)   ; state: "notify" | "ignore"
}

; Runtime state.
global BiomeGood := Map()   ; id -> true/false
global BiomeBad  := Map()   ; id -> true/false

; Lookup maps built once.
global BiomeByKeyword := Map()   ; keyword   -> def

; ============================================================
; COMMUNITY (CRCW DISCORD) STAGING
;
; No webhook exists for the official CRCW Discord. Instead of
; sending automatically, the script formats the message and either:
;   - copies it to the clipboard (always), or
;   - if Discord is running, Ctrl+K's to the target channel and
;     types the message WITHOUT pressing Enter.
;
; Triggers:
;   Ctrl+Alt+S -> stage the last boss ping
;   Ctrl+Alt+W -> stage the last biome ping
; ============================================================

global CommunityEnabled        := true
global CommunityBossChannel    := "boss-raids"
global CommunityBiomeChannel   := "biomes-drop"
global CommunityBiomePing      := false   ; set true to @ping biome roles too

global CommunityBossRoles := Map(
    "Lux",              "1265714070640922737",
    "Rex",              "1265714070640922737",
    "Aqua",             "1265714070640922737",
    "Ignis",            "1265714070640922737",
    "Tenebris",         "1265714070640922737",
    "Chaos",            "1266118818741354576",
    "Chrono",           "1266104850794418197",
    "Inanis",           "1266106084137894041",
    "Malvrock",         "1266105909038284881",
    "Angry Man",        "1266105305507561576",
    "The Old Dragon",   "1266105141392707594",
    "Platformation123", "1266106252505649164",
    "Final Rex",        "1266105605702287423",
    "Caedes",           "1266104692631670905",
    "Orenga",           "1266121986866938007"
)

global CommunityBiomeRoles := Map(
    "cthulhu",    "1266121758948331662",
    "hercules",   "1266121715227033640",
    "dungeon",    "1266121787310215168",
    "firegod",    "1266121622423601173",
    "underworld", "1266121559639326921",
    "void",       "1266121836413059124",
    "hydra",      "1266121853601320992",
    "elewars",    "1266121813281472716",
    "wizards",    "1266121867580932117"
)

global LastHandledBiomeDef := ""
global LastHandledBossObj  := ""

FormatCommunityBossMessage(bossObj)
{
    global CommunityBossRoles, PrivateServerLink

    if !IsObject(bossObj) || !CommunityBossRoles.Has(bossObj.name)
        return ""

    msg := "<@&" . CommunityBossRoles[bossObj.name] . "> " . bossObj.name

    link := Trim(PrivateServerLink)
    if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        msg .= "`n" . link

    return msg
}

FormatCommunityBiomeMessage(biomeDef)
{
    global CommunityBiomeRoles, CommunityBiomePing

    if !IsObject(biomeDef) || !CommunityBiomeRoles.Has(biomeDef.id)
        return ""

    msg := biomeDef.biomeName
    if CommunityBiomePing
        msg := "<@&" . CommunityBiomeRoles[biomeDef.id] . "> " . msg
    return msg
}

StageCommunityBossPing(bossObj)
{
    global CommunityEnabled

    if !CommunityEnabled
    {
        UpdateOCRResult("Community staging is disabled.")
        return false
    }

    msg := FormatCommunityBossMessage(bossObj)
    if (msg = "")
    {
        UpdateOCRResult("Boss '" . (IsObject(bossObj) ? bossObj.name : "?") . "' has no community role mapping.")
        return false
    }

    A_Clipboard := msg
    UpdateOCRResult("📋 Copied to clipboard:`n`n" . msg)
    UpdateOCRResult("📋 Copied to clipboard - paste into Discord.")
    return true
}

StageCommunityBiomePing(biomeDef)
{
    global CommunityEnabled

    if !CommunityEnabled
        return false

    msg := FormatCommunityBiomeMessage(biomeDef)
    if (msg = "")
    {
        UpdateOCRResult("Biome '" . (IsObject(biomeDef) ? biomeDef.biomeName : "?") . "' has no community role mapping.")
        return false
    }

    A_Clipboard := msg
    UpdateOCRResult("📋 Copied to clipboard:`n`n" . msg)
    UpdateOCRResult("📋 Copied to clipboard - paste into Discord.")
    return true
}

StageLastBoss()
{
    global LastHandledBossObj
    if !IsObject(LastHandledBossObj)
    {
        UpdateOCRResult("No boss has been handled yet this session.")
        return
    }
    StageCommunityBossPing(LastHandledBossObj)
}

StageLastBiome()
{
    global LastHandledBiomeDef
    if !IsObject(LastHandledBiomeDef)
    {
        UpdateOCRResult("No biome has been handled yet this session.")
        return
    }
    StageCommunityBiomePing(LastHandledBiomeDef)
}

BuildBiomeLookups()
{
    global BiomeDefs, BiomeByKeyword
    BiomeByKeyword := Map()
    for def in BiomeDefs
        for kw in def.keywords
            BiomeByKeyword[StrLower(kw)] := def
}

; ============================================================
; GLOBAL BOSSES
;
; Bosses that can spawn in ANY biome (roaming / event bosses).
; Rather than duplicating these entries in every biome's boss list,
; we inject them at startup so the existing detection code finds them
; no matter which biome you're in or scanning.
;
; To add another roaming boss later, just append to GlobalBosses.
; ============================================================

global GlobalBosses := [
    { name: "Orenga", keywords: ["orenga"], roleID: "1543785808178184202", notify: true, leave: false, isGlobal: true, priority: true}
]

InjectGlobalBosses()
{
    global BiomeDefs, GlobalBosses

    for def in BiomeDefs
    {
        for gb in GlobalBosses
        {
            ; Skip if the biome already has this boss defined explicitly.
            already := false
            for bossObj in def.bosses
            {
                if (bossObj.name = gb.name)
                {
                    already := true
                    break
                }
            }
            if !already
                def.bosses.Push(gb)
        }
    }
}

; ============================================================
; PRIORITY BOSS DETECTION
;
; A priority boss (Orenga etc.) overrides ALL other logic. When
; detected, the script:
;   1. Fires a Discord ping immediately
;   2. Stops the macro entirely
;   3. Cancels any pending rejoin
;
; Detection uses a tight scan region for the boss name so it can
; run every ~100ms without slowing the main loop. It also checks
; chat as a fallback in case the bar hasn't rendered yet.
; ============================================================

GetBossNameRect()
{
    try
    {
        hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        if hwnd
        {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)
            return {
                x: wx + Round(ww * 0.35),
                y: wy + Round(wh * 0.70),
                w: Round(ww * 0.30),
                h: Round(wh * 0.10)
            }
        }
    }
    catch
    {
    }
    return {
        x: Round(A_ScreenWidth * 0.35),
        y: Round(A_ScreenHeight * 0.70),
        w: Round(A_ScreenWidth * 0.30),
        h: Round(A_ScreenHeight * 0.10)
    }
}

CheckPriorityBoss()
{
    global GlobalBosses, ChatOCR_X, ChatOCR_Y, ChatOCR_WIDTH, ChatOCR_HEIGHT

    if !IsObject(GlobalBosses)
        return ""

    ; --- 1) Boss name strip — fast, small region ---
    nameText := ""
    try
    {
        r := GetBossNameRect()
        res := OCR.FromRect(r.x, r.y, r.w, r.h, {lang: "en-US"})
        nameText := StrLower(res.Text)
    }
    catch
    {
    }

    if (nameText != "")
    {
        for gb in GlobalBosses
        {
            if !(gb.HasProp("priority") && gb.priority)
                continue
            for kw in gb.keywords
            {
                if InStr(nameText, kw)
                    return gb
            }
        }
    }

    ; --- 2) Chat fallback, in case the bar hasn't rendered yet ---
    chatText := ""
    try
    {
        res := OCR.FromRect(ChatOCR_X, ChatOCR_Y, ChatOCR_WIDTH, ChatOCR_HEIGHT, {lang: "en-US"})
        chatText := StrLower(res.Text)
    }
    catch
    {
    }

    if (chatText != "")
    {
        for gb in GlobalBosses
        {
            if !(gb.HasProp("priority") && gb.priority)
                continue
            for kw in gb.keywords
            {
                if InStr(chatText, kw)
                    return gb
            }
        }
    }

    return ""
}

HandlePriorityBoss(bossDef)
{
    global MacroRunning, PrivateServerLink, DiscordWebhookURL
    global MacroMode

    ; Fire the ping FIRST, before anything else can interfere.
    if (Trim(DiscordWebhookURL) != ""
    &&  DiscordWebhookURL != "PASTE_NEW_DISCORD_WEBHOOK_HERE")
    {
        msg := "🚨🚨 **PRIORITY BOSS SPAWNED: " . bossDef.name . "** 🚨🚨`n`n"
             . "The script has **STOPPED**. Get in-game ASAP."

        link := Trim(PrivateServerLink)
        if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
            msg .= "`n" . link

        try SendDiscordWebhook(DiscordWebhookURL, msg, bossDef.roleID)
    }

    ; Halt everything.
    StopAutoAttack()
    SetTimer(AntiAfkTick, 0)
    SetTimer(WatchdogTick, 0)
    MacroRunning := false

    UpdateStatus("PRIORITY BOSS", bossDef.name)
    UpdateOCRResult(
        "!!! PRIORITY BOSS DETECTED: " . bossDef.name . " !!!`n`n"
        . "Script has been STOPPED. Rejoin flow cancelled.`n`n"
        . "Get into the game now - the server is still open."
    )
}

; ============================================================
; COLOR-AWARE CHAT LINE CLASSIFICATION
;
; Roblox game messages render in yellow (~FFFF00); messages the user
; types render in white / grey. We sample pixels inside each OCR line's
; bounding box so the macro never fires on text the user typed as a test.
;
; If the OCR library doesn't expose per-line boxes, ExtractChatLines
; falls back to "everything is game text" (the old behaviour).
; ============================================================


; Returns an array of { text, isGame } for every detected chat line.
; No color sampling. Filtering of user-typed messages is done in
; FindChatEvent using the display-name prefix (e.g. "Pro: hello").
ExtractChatLines(ocrResult)
{
    global InjectedLines
    lines := []

    ; --- real lines from OCR ---
    if IsObject(ocrResult)
    {
        lineArr := 0
        try lineArr := ocrResult.Lines
        catch
            lineArr := 0

        if IsObject(lineArr) && lineArr.Length > 0
        {
            for lineObj in lineArr
            {
                lineText := ""
                try lineText := lineObj.Text
                lines.Push({ text: lineText, isGame: true })
            }
        }

        if (lines.Length = 0)
        {
            rawText := ""
            try rawText := ocrResult.Text
            catch
                rawText := ""
            for t in StrSplit(rawText, "`n")
                lines.Push({ text: t, isGame: true })
        }
    }

    ; --- injected test lines (simulator) ---
    if (IsObject(InjectedLines) && InjectedLines.Length > 0)
    {
        fresh := []
        for inj in InjectedLines
        {
            if (A_TickCount < inj.expiresAtTick)
            {
                lines.Push({ text: inj.text, isGame: true })
                fresh.Push(inj)
            }
        }
        InjectedLines := fresh
    }

    return lines
}

FindChatEvent(lines)
{
    global BiomeGood, BiomeBad, BiomeByKeyword, OreSpawnNames
    global ChatDisplayName

    ; Pre-lowercase the name prefix once per call.
    namePrefix := ""
    if (Trim(ChatDisplayName) != "")
        namePrefix := StrLower(Trim(ChatDisplayName)) . ":"

    Loop lines.Length
    {
        idx  := lines.Length - A_Index + 1
        line := lines[idx]

        txt := Trim(line.text)
        if (txt = "")
            continue

        ; Skip any line that starts with "<DisplayName>:" — that's
        ; user-typed text, not a game message. Spaces in the display
        ; name (e.g. "My Name") and OCR's inconsistent spacing are
        ; both tolerated: the name's spaces become \s+ so "My Name:"
        ; and "My  Name:" both match.
        if (namePrefix != "")
        {
            lowName := StrLower(Trim(ChatDisplayName))
            ; Build the pattern once and cache it if you want, but it's
            ; cheap enough at this size.
            pattern := "^\s*" . StrReplace(lowName, " ", "\s+") . "\s*:"
            if RegExMatch(StrLower(txt), pattern)
                continue
        }

        low := StrLower(txt)

        ; 2) Good biome.
        for kw, def in BiomeByKeyword
        {
            if InStr(low, kw) && BiomeGood[def.id]
                return { type: "WANTED", def: def, keyword: kw, lineText: txt, idx: idx}
        }

        ; 4) Bad biome.
        for kw, def in BiomeByKeyword
        {
            if InStr(low, kw) && BiomeBad[def.id]
                return { type: "BAD", def: def, keyword: kw, lineText: txt, idx: idx}
        }
    }

    return { type: "", def: "", keyword: "", lineText: "" }
}

; ------------------------------------------------------------
; Small helpers used by the rest of the script.
; ------------------------------------------------------------
RebuildBiomeList(lv)
{
    global BiomeDefs, BiomeGood, BiomeBad

    lv.Delete()

    for def in BiomeDefs
    {
        label := def.biomeName
        if (def.bosses.Length > 0)
        {
            bossNames := ""
            for bossObj in def.bosses
            {
                if (bossNames != "")
                    bossNames .= ", "
                bossNames .= bossObj.name
            }
            label .= "   —   " . bossNames
        }

        status := ""
        if BiomeGood[def.id]
            status := "GOOD"
        else if BiomeBad[def.id]
            status := "BAD"
        else
            status := "IGNORED"

        lv.Add("", label, status)
    }
}

ForceClassicListViewTheme(lv)
{
    ; Tell Windows to render this ListView using the classic (light) theme
    ; instead of the current system theme. This makes the selection
    ; highlight use black-on-light-blue, which is always readable, and
    ; avoids the dark-mode "black on black" bug on Windows 11.
    try DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "Explorer", "Ptr", 0)
    catch
    {
    }
}

ProbeOCRLines()
{
    global OCR_X, OCR_Y, OCR_WIDTH, OCR_HEIGHT
    try
    {
        r := OCR.FromRect(OCR_X, OCR_Y, OCR_WIDTH, OCR_HEIGHT, {lang: "en-US"})

        info := "Type: " . Type(r) . "`n"
        info := info . "Has Text: "  . (r.HasProp("Text")  ? "yes" : "no") . "`n"
        info := info . "Has Lines: " . (r.HasProp("Lines") ? "yes" : "no")

        if r.HasProp("Lines")
        {
            lines := r.Lines
            info := info . "`nLines type: " . Type(lines)

            if IsObject(lines)
            {
                info := info . "`nLength: " . lines.Length

                if (lines.Length > 0)
                {
                    L := lines[1]
                    info := info . "`nFirst line type: " . Type(L)

                    if L.HasProp("Text")
                        info := info . "`nText: " . L.Text

                    if (L.HasProp("x") && L.HasProp("y") && L.HasProp("w") && L.HasProp("h"))
                        info := info . "`nx/y/w/h: " . L.x . "," . L.y . "," . L.w . "," . L.h

                    if (L.HasProp("Left") && L.HasProp("Top") && L.HasProp("Right") && L.HasProp("Bottom"))
                        info := info . "`nL/T/R/B: " . L.Left . "," . L.Top . "," . L.Right . "," . L.Bottom
                }
            }
        }

        MsgBox(info, "OCR Probe")
    }
    catch Error as err
    {
        MsgBox("Probe failed: " . err.Message, "OCR Probe")
    }
}

; ============================================================
; SHOW GUI IMMEDIATELY
; ============================================================

InjectGlobalBosses()
BuildBiomeLookups()
BuildOreLookups()
LoadOreChoices()
LoadSavedWebhookURL()
LoadJoinSettings()
LoadAlts()
LoadAttackSettings()
LoadAttackSequences()
CreateMainUI()
UpdateRegionDisplay()
UpdateStatus("IDLE", "None")
ApplyHotkeys()

; ============================================================
; DISCORD WEBHOOK URL PERSISTENCE
; ============================================================

LoadSavedWebhookURL()
{
    global DiscordWebhookURL, ConfigFile
    global PrivateServerLink, SecondaryWebhookURL, SecondaryEnabled
    global BiomeDefs, BiomeGood, BiomeBad

    ; Seed good/bad state from each def's default, every startup.
    ; INI values below will override.
    for def in BiomeDefs
    {
        ; Support either `defaultStatus` ("good"/"bad"/"ignored") or the
        ; legacy `defaultGood` boolean. defaultStatus wins if present.
        dflt := "bad"
        if def.HasProp("defaultStatus")
            dflt := def.defaultStatus
        else if (def.HasProp("defaultGood") && def.defaultGood)
            dflt := "good"

        switch dflt
        {
            case "good":
                BiomeGood[def.id] := true
                BiomeBad[def.id]  := false
            case "ignored":
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := false
            default: ; "bad"
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := true
        }
    }

    if !FileExist(ConfigFile)
        return

    try
    {
        s := IniRead(ConfigFile, "Discord", "WebhookURL", "")
        if (Trim(s) != "")
            DiscordWebhookURL := Trim(s)
    }
    try
    {
        s := IniRead(ConfigFile, "Discord", "PrivateServerLink", "")
        if (Trim(s) != "")
            PrivateServerLink := Trim(s)
    }
    try
    {
        s := IniRead(ConfigFile, "Discord", "SecondaryWebhookURL", "")
        if (Trim(s) != "")
            SecondaryWebhookURL := Trim(s)
    }
    try
    {
        s := IniRead(ConfigFile, "Discord", "SecondaryEnabled", "0")
        SecondaryEnabled := (s = "1")
    }

    ; Per-biome good / bad / ignored overrides.
    for def in BiomeDefs
    {
        try
        {
            v := IniRead(ConfigFile, "Biomes", def.id, "")
            if (v = "good")
            {
                BiomeGood[def.id] := true
                BiomeBad[def.id]  := false
            }
            else if (v = "bad")
            {
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := true
            }
            else if (v = "ignored")
            {
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := false
            }
        }
    }
        try
    {
        s := IniRead(ConfigFile, "Discord", "ChatDisplayName", "")
        if (Trim(s) != "")
            ChatDisplayName := Trim(s)
    }
}

SaveBiomeChoice(id, state)
{
    global ConfigFile
    try IniWrite(state, ConfigFile, "Biomes", id)   ; state: "good" | "bad" | "ignored"
}

SaveConfigValue(key, value)
{
    global ConfigFile
    try IniWrite(value, ConfigFile, "Discord", key)
}

SaveJoinSettings()
{
    global ConfigFile
    global JoinWindowExe, JoinWindowTitle
    global JoinButtonX, JoinButtonY, JoinButtonRelX, JoinButtonRelY
    global FollowButtonX, FollowButtonY, FollowButtonRelX, FollowButtonRelY, FollowButtonConfigured 
    global SafeClickX, SafeClickY, SafeClickRelX, SafeClickRelY, SafeClickConfigured
    global UsernameFieldX, UsernameFieldY, UsernameFieldRelX, UsernameFieldRelY, UsernameFieldConfigured

    try
    {
        IniWrite(JoinWindowExe, ConfigFile, "Join", "WindowExe")
        IniWrite(JoinWindowTitle, ConfigFile, "Join", "WindowTitle")
        IniWrite(JoinButtonX, ConfigFile, "Join", "ButtonX")
        IniWrite(JoinButtonY, ConfigFile, "Join", "ButtonY")
        IniWrite(JoinButtonRelX, ConfigFile, "Join", "ButtonRelX")
        IniWrite(JoinButtonRelY, ConfigFile, "Join", "ButtonRelY")
        IniWrite(SafeClickX, ConfigFile, "Join", "SafeClickX")
        IniWrite(SafeClickY, ConfigFile, "Join", "SafeClickY")
        IniWrite(SafeClickRelX, ConfigFile, "Join", "SafeClickRelX")
        IniWrite(SafeClickRelY, ConfigFile, "Join", "SafeClickRelY")
        IniWrite(SafeClickConfigured ? "1" : "0", ConfigFile, "Join", "SafeClickConfigured")
        IniWrite(UsernameFieldX, ConfigFile, "Join", "UsernameFieldX")
        IniWrite(UsernameFieldY, ConfigFile, "Join", "UsernameFieldY")
        IniWrite(UsernameFieldRelX, ConfigFile, "Join", "UsernameFieldRelX")
        IniWrite(UsernameFieldRelY, ConfigFile, "Join", "UsernameFieldRelY")
        IniWrite(UsernameFieldConfigured ? "1" : "0", ConfigFile, "Join", "UsernameFieldConfigured")
        IniWrite(FollowButtonX, ConfigFile, "Join", "FollowButtonX")
        IniWrite(FollowButtonY, ConfigFile, "Join", "FollowButtonY")
        IniWrite(FollowButtonRelX, ConfigFile, "Join", "FollowButtonRelX")
        IniWrite(FollowButtonRelY, ConfigFile, "Join", "FollowButtonRelY")
        IniWrite(FollowButtonConfigured ? "1" : "0", ConfigFile, "Join", "FollowButtonConfigured")
    }
}

LoadJoinSettings()
{
    global ConfigFile
    global JoinWindowExe, JoinWindowTitle
    global JoinButtonX, JoinButtonY, JoinButtonRelX, JoinButtonRelY
    global FollowButtonX, FollowButtonY, FollowButtonRelX, FollowButtonRelY, FollowButtonConfigured 
    global SafeClickX, SafeClickY, SafeClickRelX, SafeClickRelY, SafeClickConfigured
    global UsernameFieldX, UsernameFieldY, UsernameFieldRelX, UsernameFieldRelY, UsernameFieldConfigured

    if !FileExist(ConfigFile)
        return

    try
    {
        v := IniRead(ConfigFile, "Join", "WindowExe", "")
        if (Trim(v) != "")
            JoinWindowExe := v
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "WindowTitle", "")
        JoinWindowTitle := v
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "ButtonX", "")
        if (v != "")
            JoinButtonX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "ButtonY", "")
        if (v != "")
            JoinButtonY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "ButtonRelX", "")
        if (v != "")
            JoinButtonRelX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "ButtonRelY", "")
        if (v != "")
            JoinButtonRelY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "SafeClickX", "")
        if (v != "")
            SafeClickX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "SafeClickY", "")
        if (v != "")
            SafeClickY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "SafeClickRelX", "")
        if (v != "")
            SafeClickRelX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "SafeClickRelY", "")
        if (v != "")
            SafeClickRelY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "SafeClickConfigured", "0")
        SafeClickConfigured := (v = "1")
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "UsernameFieldX", "")
        if (v != "")
            UsernameFieldX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "UsernameFieldY", "")
        if (v != "")
            UsernameFieldY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "UsernameFieldRelX", "")
        if (v != "")
            UsernameFieldRelX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "UsernameFieldRelY", "")
        if (v != "")
            UsernameFieldRelY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "UsernameFieldConfigured", "0")
        UsernameFieldConfigured := (v = "1")
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "FollowButtonX", "")
        if (v != "")
            FollowButtonX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "FollowButtonY", "")
        if (v != "")
            FollowButtonY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "FollowButtonRelX", "")
        if (v != "")
            FollowButtonRelX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "FollowButtonRelY", "")
        if (v != "")
            FollowButtonRelY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Join", "FollowButtonConfigured", "0")
        FollowButtonConfigured := (v = "1")
    }
}

; ============================================================
; MAIN GUI
; ============================================================

CreateMainUI()
{
    global MainGui
    global StatusText
    global ModeText
    global RegionText
    global OCRResultEdit
    global PauseButton
    global JoinSettingsText
    global PauseHotkey, StopHotkey, ExitHotkey, StartTrueHotkey, StartModifiedHotkey
    global DiscordURLEdit, DiscordRoleIDEdit, DiscordTestResultEdit
    global DiscordWebhookURL, DiscordDefaultRoleID
    global PanelRegistry
    global DesignWidth := 560
    global DesignHeight := 492    ; update if you changed the Show height

    PanelRegistry := Map()

    MainGui := Gui("+AlwaysOnTop -MaximizeBox", "2026 Biome Hopper")
    MainGui.BackColor := "111318"
    BuildMenuBar(MainGui)
    MainGui.SetFont("s10 cFFFFFF", "Segoe UI")

    ; Header - always visible.
    MainGui.AddText("x0 y0 w560 h72 Background20242C")
    MainGui.SetFont("s16 cFFFFFF Bold", "Segoe UI")
    MainGui.AddText("x22 y13 w516 h28 Center", "2026 BIOME HOPPER")
    MainGui.SetFont("s9 c8F9AAA", "Segoe UI")
    MainGui.AddText("x22 y42 w516 h20 Center", "Roblox OCR detector  •  GUI CONTROLLED")

    ; ---- Panel: STATUS ----
    statusGroup := MainGui.AddGroupBox("x18 y86 w524 h82", "CURRENT STATUS")
    MainGui.SetFont("s11 c55D6BE Bold", "Segoe UI")
    StatusText := MainGui.AddText("x35 y96 w484 h22", "IDLE")
    MainGui.SetFont("s9 c9AA4B2", "Segoe UI")
    ModeText := MainGui.AddText("x35 y120 w484 h40", "Mode: None")
    RegisterPanel("status", statusGroup, [StatusText, ModeText])

    ; ---- Panel: BIOME HOPPING ----
    hopGroup := MainGui.AddGroupBox("x18 y178 w524 h165", "BIOME HOPPING")
    MainGui.SetFont("s10 cFFFFFF Bold", "Segoe UI")
    trueButton := MainGui.AddButton("x34 y203 w238 h43", "TRUE BIOME HOP")
    trueButton.OnEvent("Click", StartTrue)
    modifiedButton := MainGui.AddButton("x288 y203 w238 h43", "MANUAL HOP")
    modifiedButton.OnEvent("Click", ManualHop)
    PauseButton := MainGui.AddButton("x34 y258 w153 h40", "PAUSE")
    PauseButton.OnEvent("Click", TogglePause)
    stopButton := MainGui.AddButton("x203 y258 w153 h40", "STOP")
    stopButton.OnEvent("Click", StopMacro)
    exitButton := MainGui.AddButton("x372 y258 w154 h40", "EXIT")
    exitButton.OnEvent("Click", ExitProgram)
    resumeButton := MainGui.AddButton("x34 y302 w492 h28", "RESUME HOPPING AFTER BOSS")
    resumeButton.OnEvent("Click", ResumeAfterBoss)
    RegisterPanel("hop", hopGroup, [trueButton, modifiedButton, PauseButton, stopButton, exitButton, resumeButton])

    ; ---- Panel: LAST OCR RESULT ----
    ocrGroup := MainGui.AddGroupBox("x18 y354 w524 h122", "LAST OCR RESULT")
    MainGui.SetFont("s9 c000000", "Segoe UI")
    OCRResultEdit := MainGui.AddEdit("x34 y381 w492 h76 ReadOnly -Wrap", "")
    RegisterPanel("ocr", ocrGroup, [OCRResultEdit])

    ; Hidden utility controls (needed by other functions).
    MainGui.SetFont("s9 c9AA4B2", "Segoe UI")
    RegionText := MainGui.AddText("x34 y0 w10 h10 Hidden", "")
    JoinSettingsText := MainGui.AddText("x34 y0 w10 h10 Hidden", "")
    UpdateJoinSettingsText()

    MainGui.OnEvent("Close", ExitProgram)
    MainGui.Show("w" . DesignWidth . " h" . DesignHeight)
    MainGui.MinSize := "w" . DesignWidth . " h" . DesignHeight
    MainGui.Opt("+Resize")
}


ApplyPanelPositions()
{
    global PanelRegistry, MainGui, DesignWidth, DesignHeight

    if !IsObject(MainGui)
        return

    MainGui.GetPos(, , &curW, &curH)
    scaleX := curW / DesignWidth
    scaleY := curH / DesignHeight

    for name, panel in PanelRegistry
    {
        for entry in panel.entries
        {
            newX := Round(entry.x * scaleX)
            newY := Round(entry.y * scaleY)
            newW := Round(entry.w * scaleX)
            newH := Round(entry.h * scaleY)

            if panel.visible
                entry.ctrl.Move(newX, newY, newW, newH)
            else
                entry.ctrl.Move(newX, -4000, newW, newH)
        }
    }
}

OnGuiResize(gui, minMax, width, height)
{
    if (minMax = -1)
        return
    ApplyPanelPositions()
}

RegisterPanel(name, groupBox, controls)
{
    global PanelRegistry
    entries := []
    gx := gy := gw := gh := 0
    groupBox.GetPos(&gx, &gy, &gw, &gh)
    entries.Push({ ctrl: groupBox, x: gx, y: gy, w: gw, h: gh })
    for ctrl in controls
    {
        cx := cy := cw := ch := 0
        ctrl.GetPos(&cx, &cy, &cw, &ch)
        entries.Push({ ctrl: ctrl, x: cx, y: cy, w: cw, h: ch })
    }
    PanelRegistry[name] := { entries: entries, visible: true }
}

SetPanelVisible(name, visible)
{
    global PanelRegistry
    if !PanelRegistry.Has(name)
        return
    PanelRegistry[name].visible := visible
    ApplyPanelPositions()
}

TogglePanelFromMenu(panelName, menuItemName, *)
{
    global PanelRegistry, ViewMenuObj
    if !PanelRegistry.Has(panelName)
        return
    p := PanelRegistry[panelName]
    SetPanelVisible(panelName, !p.visible)
    if p.visible
        ViewMenuObj.Check(menuItemName)
    else
        ViewMenuObj.Uncheck(menuItemName)
}

ToggleAllPanels(visible, *)
{
    global PanelRegistry, ViewMenuObj
    for name, p in PanelRegistry
        SetPanelVisible(name, visible)
    for item in ["Status Card", "Biome Hopping", "Last OCR Result", "Discord Notifications"]
    {
        if visible
            ViewMenuObj.Check(item)
        else
            ViewMenuObj.Uncheck(item)
    }
}

BuildMenuBar(gui)
{
    mb := MenuBar()

    fileMenu := Menu()
    fileMenu.Add("Start True Hop`tF9",     (*) => StartTrue())
    fileMenu.Add("Manual Hop`tF10",        (*) => ManualHop())
    fileMenu.Add()
    fileMenu.Add("Pause / Resume`tF6",     (*) => TogglePause())
    fileMenu.Add("Stop`tF7",               (*) => StopMacro())
    fileMenu.Add("Force Resume`tCtrl+Alt+R", (*) => ForceResume())
    fileMenu.Add()
    fileMenu.Add("Exit`tF8",               (*) => ExitProgram())
    mb.Add("File", fileMenu)

    toolsMenu := Menu()
    toolsMenu.Add("Select Biomes / Bosses...", (*) => ShowBiomeSelector())
    toolsMenu.Add("Select Ores to Notify...",   (*) => ShowOreSelector())
    toolsMenu.Add("Discord Notifications...", (*) => ShowDiscordConfig())
    toolsMenu.Add()
    toolsMenu.Add("Simulate Events...",        (*) => ShowSimulator())
    toolsMenu.Add("Alt Joiner...",             (*) => ShowAltJoiner())
    toolsMenu.Add("Biome Luck Calculator...",  (*) => ShowLuckCalculator())
    toolsMenu.Add()
    toolsMenu.Add("Capture Join Window",       (*) => CaptureJoinWindow())
    toolsMenu.Add("Capture Join Click",        (*) => CaptureJoinButton())
    toolsMenu.Add("Capture Safe Click",        (*) => CaptureSafeClick())
    toolsMenu.Add("Capture Follow Click",      (*) => CaptureFollowButton())
    toolsMenu.Add()
    toolsMenu.Add("Calibrate OCR Region",      (*) => CalibrateOCR())
    toolsMenu.Add("Reset OCR to Defaults",     (*) => ResetOCR())
    toolsMenu.Add("Test OCR Now",              (*) => TestOCR())
    toolsMenu.Add("Capture Play Button",       (*) => CapturePlayButton())
    toolsMenu.Add("")
    toolsMenu.Add("Capture Attack Hold Point", (*) => CaptureAttackHold())
    toolsMenu.Add("Edit Attack Sequences...", (*) => ShowAttackEditor())
    mb.Add("Tools", toolsMenu)


    global ViewMenuObj
    viewMenu := Menu()
    viewMenu.Add("Status Card",           (*) => TogglePanelFromMenu("status",  "Status Card"))
    viewMenu.Add("Biome Hopping",         (*) => TogglePanelFromMenu("hop",     "Biome Hopping"))
    viewMenu.Add("Last OCR Result",       (*) => TogglePanelFromMenu("ocr",     "Last OCR Result"))
    viewMenu.Add("Discord Notifications", (*) => TogglePanelFromMenu("discord", "Discord Notifications"))
    viewMenu.Add()
    viewMenu.Add("Expand All",  (*) => ToggleAllPanels(true))
    viewMenu.Add("Collapse All",(*) => ToggleAllPanels(false))
    viewMenu.Check("Status Card")
    viewMenu.Check("Biome Hopping")
    viewMenu.Check("Last OCR Result")
    viewMenu.Check("Discord Notifications")
    mb.Add("View", viewMenu)
    ViewMenuObj := viewMenu    
    helpMenu := Menu()
    helpMenu.Add("About", (*) => MsgBox("2026 Biome Hopper`nUI build.", "About"))
    mb.Add("Help", helpMenu)

    gui.MenuBar := mb
}

ShowAttackEditor(*)
{
    global AttackEditorGui, AttackSequencesFile

    if IsObject(AttackEditorGui)
    {
        try
        {
            AttackEditorGui.Show()
            WinActivate("ahk_id " . AttackEditorGui.Hwnd)
            return
        }
        catch
            AttackEditorGui := 0
    }

    ; Read the file as-is.
    raw := ""
    try raw := FileRead(AttackSequencesFile)
    catch
        raw := "; (file did not exist - will be created on save)`n`n[default]`nclick 961 713`nsleep 800`n"

    g := Gui("+AlwaysOnTop -MaximizeBox +Resize", "Edit Attack Sequences")
    g.BackColor := "20242A"

    g.SetFont("s10 cFFFFFF Bold", "Segoe UI")
    g.AddText("x14 y12 w800 h20", "Attack Sequences")
    g.SetFont("s9 c9AA4B2", "Segoe UI")
    g.AddText("x14 y32 w800 h40",
        "Edit the file below. Each [SectionName] starts a new sequence.`n"
        . "Biomes with autoAttack:true use attackSequence: `"name`" or fall back to [default].")

    g.SetFont("s10 c000000", "Consolas")
    edit := g.AddEdit("x14 y78 w800 h480 Multi VScroll", raw)

    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddButton("x14 y566 w140 h32", "SAVE").OnEvent("Click",
        (*) => AttackEditorSave(g, edit))
    g.AddButton("x164 y566 w140 h32", "RELOAD").OnEvent("Click",
        (*) => AttackEditorReload(g, edit))
    g.AddButton("x314 y566 w140 h32", "TEST ACTIVE SEQ").OnEvent("Click",
        (*) => AttackEditorTest(g, edit))
    g.AddButton("x464 y566 w140 h32", "STOP TEST").OnEvent("Click",
        (*) => AttackEditorStopTest())
    g.AddButton("x670 y566 w144 h32", "CLOSE").OnEvent("Click",
        (*) => AttackEditorClose())

    g.SetFont("s8 c9AA4B2", "Segoe UI")
    g.AddText("x14 y608 w800 h60",
        "Commands: click X Y  |  hold X Y  |  release  |  move X Y  |  send KEY  |  equip N  |  sleep MS`n"
        . "TEST ACTIVE SEQ runs the sequence that the current biome would use, once, to help you verify timing.`n"
        . "Click SAVE to persist changes. RELOAD discards unsaved edits.")

    AttackEditorGui := g
    g.OnEvent("Close", (*) => AttackEditorClose())
    g.OnEvent("Escape", (*) => AttackEditorClose())

    g.Show("w830 h670")
}

AttackEditorSave(g, edit)
{
    global AttackSequencesFile
    text := edit.Text
    try FileDelete(AttackSequencesFile)
    try FileAppend(text, AttackSequencesFile)
    LoadAttackSequences()
    UpdateOCRResult("Attack sequences saved and reloaded.")
}

AttackEditorReload(g, edit)
{
    global AttackSequencesFile
    raw := ""
    try raw := FileRead(AttackSequencesFile)
    catch
        raw := ""
    edit.Text := raw
    LoadAttackSequences()
    UpdateOCRResult("Attack sequences reloaded from disk.")
}

AttackEditorTest(g, edit)
{
    global TargetBiomeDef

    ; Save first so we test what's on screen.
    AttackEditorSave(g, edit)

    seqName := "default"
    if IsObject(TargetBiomeDef) && TargetBiomeDef.HasProp("attackSequence")
        seqName := TargetBiomeDef.attackSequence

    ; Stop any existing attack first.
    StopAutoAttack()
    Sleep(100)

    ; Focus Roblox BEFORE starting. If we don't do this, the sequence's
    ; "send q" style commands go to the editor's own text field.
    if !ActivateRoblox()
    {
        ;UpdateOCRResult("Test: Roblox is not running - cannot test.")
        ;return
        ActivateRoblox()
    }

    Sleep(250)

    StartAutoAttack(seqName)
    UpdateOCRResult("Testing sequence '" . seqName . "'. Click STOP TEST (or press F7) to end.")
}

AttackEditorStopTest()
{
    StopAutoAttack()
    UpdateOCRResult("Test stopped.")
}

AttackEditorClose()
{
    global AttackEditorGui
    if IsObject(AttackEditorGui)
    {
        try AttackEditorGui.Destroy()
        catch
        {
        }
        AttackEditorGui := 0
    }
}

ShowDiscordConfig(*)
{
    global DiscordConfigGui
    global DiscordWebhookURL, PrivateServerLink, ChatDisplayName
    global SecondaryWebhookURL, SecondaryEnabled, DiscordDefaultRoleID

    if IsObject(DiscordConfigGui)
    {
        try
        {
            DiscordConfigGui.Show()
            WinActivate("ahk_id " . DiscordConfigGui.Hwnd)
            return
        }
        catch
            DiscordConfigGui := 0
    }

    g := Gui("+AlwaysOnTop -MaximizeBox", "Discord Notifications")
    g.BackColor := "20242A"
    g.SetFont("s10 cFFFFFF", "Segoe UI")
    g.AddText("x16 y14 w500 h22", "Discord Notifications")
    g.SetFont("s9 c9AA4B2", "Segoe UI")
    g.AddText("x16 y34 w500 h18", "Everything here is saved to disk automatically.")

    y := 62

    ; Webhook URL
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x16 y" . y . " w130 h22", "Webhook URL")
    urlEdit := g.AddEdit("x150 y" . (y - 2) . " w340 h25", Trim(DiscordWebhookURL))
    urlEdit.SetFont("s9 c000000", "Segoe UI")
    y += 36

    ; Role ID (test only)
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x16 y" . y . " w130 h22", "Role ID (test ping)")
    roleEdit := g.AddEdit("x150 y" . (y - 2) . " w340 h25", DiscordDefaultRoleID)
    roleEdit.SetFont("s9 c000000", "Segoe UI")
    y += 36

    ; Chat display name
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x16 y" . y . " w130 h22", "Chat Display Name")
    chatEdit := g.AddEdit("x150 y" . (y - 2) . " w340 h25", Trim(ChatDisplayName))
    chatEdit.SetFont("s9 c000000", "Segoe UI")
    y += 36

    ; Private server link
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x16 y" . y . " w130 h22", "Private Server Link")
    psEdit := g.AddEdit("x150 y" . (y - 2) . " w340 h25", Trim(PrivateServerLink))
    psEdit.SetFont("s9 c000000", "Segoe UI")
    y += 44

    ; Secondary
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    secCb := g.AddCheckbox("x16 y" . y . " w474 h22" . (SecondaryEnabled ? " Checked" : ""),
        "Also send to a 2nd Discord server")
    secCb.SetFont("s9 cFFFFFF", "Segoe UI")
    y += 30

    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x16 y" . y . " w130 h22", "2nd Webhook URL")
    secEdit := g.AddEdit("x150 y" . (y - 2) . " w340 h25", Trim(SecondaryWebhookURL))
    secEdit.SetFont("s9 c000000", "Segoe UI")
    y += 40

    ; Buttons
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddButton("x16 y" . y . " w200 h32", "SEND TEST PING").OnEvent("Click",
        (*) => DoDiscordTestFromConfig(g, urlEdit, roleEdit))
    g.AddButton("x230 y" . y . " w260 h32", "SAVE & CLOSE").OnEvent("Click",
        (*) => SaveDiscordConfig(g, urlEdit, roleEdit, chatEdit, psEdit, secCb, secEdit))

    g.OnEvent("Close", (*) => SaveDiscordConfig(g, urlEdit, roleEdit, chatEdit, psEdit, secCb, secEdit))
    g.OnEvent("Escape", (*) => CloseDiscordConfig())

    DiscordConfigGui := g
    g.Show("w520 h" . (y + 60))
}

SaveDiscordConfig(g, urlEdit, roleEdit, chatEdit, psEdit, secCb, secEdit)
{
    global DiscordWebhookURL, PrivateServerLink, ChatDisplayName
    global SecondaryWebhookURL, SecondaryEnabled, DiscordDefaultRoleID

    DiscordWebhookURL    := Trim(urlEdit.Text)
    DiscordDefaultRoleID := Trim(roleEdit.Text)
    ChatDisplayName      := Trim(chatEdit.Text)
    PrivateServerLink    := Trim(psEdit.Text)
    SecondaryWebhookURL  := Trim(secEdit.Text)
    SecondaryEnabled     := secCb.Value

    SaveConfigValue("WebhookURL",        DiscordWebhookURL)
    SaveConfigValue("PrivateServerLink", PrivateServerLink)
    SaveConfigValue("ChatDisplayName",   ChatDisplayName)
    SaveConfigValue("SecondaryWebhookURL", SecondaryWebhookURL)
    SaveConfigValue("SecondaryEnabled",  SecondaryEnabled ? "1" : "0")
    SaveConfigValue("DiscordDefaultRoleID", DiscordDefaultRoleID)

    CloseDiscordConfig()
}

CloseDiscordConfig()
{
    global DiscordConfigGui
    if IsObject(DiscordConfigGui)
    {
        try DiscordConfigGui.Destroy()
        catch
        {
        }
        DiscordConfigGui := 0
    }
}

DoDiscordTestFromConfig(g, urlEdit, roleEdit)
{
    global DiscordWebhookURL
    DiscordWebhookURL := Trim(urlEdit.Text)
    SaveConfigValue("WebhookURL", DiscordWebhookURL)

    roleID := Trim(roleEdit.Text)
    testMessage := "🔔 Test ping from 2026 Biome Hopper."

    sent := SendDiscordBossNotification("TEST", "TEST", testMessage, roleID)

    if sent
        MsgBox("Sent successfully. Check the Discord channel.", "Test Ping", "Iconi")
    else
        MsgBox("Failed. Check the webhook URL is a valid Discord webhook link.", "Test Ping", "Icon!")
}

; ============================================================
; MODE BUTTONS
; ============================================================

StartTrue(*)
{
    global MacroRunning
    if MacroRunning
    {
        ResumeAfterBoss()
        return
    }
    StartBiomeHop("True")
}

StartModified(*)
{
    global MacroRunning
    if MacroRunning
    {
        ResumeAfterBoss()
        return
    }
    StartBiomeHop("Modified")
}

; ============================================================
; START BIOME HOP
; ============================================================

StartBiomeHop(mode)
{
    global AutoAttackActive, AutoAttackStartedTick, AutoAttackMaxMs
    global MacroRunning, MacroPaused, MacroMode
    global OrengaAlertActive
    global OCR_X, OCR_Y, OCR_WIDTH, OCR_HEIGHT
    global TargetBiomeActive, TargetBiomeKeyword, TargetBiomeName
    global TargetBiomeDef, TargetPingedBosses
    global TargetBiomeStartedTick, TargetChatBaseline
    global LastChatFocusTick, LastHandledBiomeDef, LastHandledBossObj
    global BadBiomeSeenCount, BadBiomeSeenId
    global LastErrorCheckTick

    if MacroRunning
    {
        UpdateStatus("ALREADY RUNNING", MacroMode)
        return
    }

    MacroRunning := true
    MacroPaused := false
    MacroMode := mode
    OrengaAlertActive := false
    TargetBiomeActive := false
    TargetBiomeKeyword := ""
    TargetBiomeName := ""
    TargetBiomeStartedTick := 0
    TargetChatBaseline := Map()
    LastChatFocusTick := 0

    UpdateStatus("RUNNING", mode)
    ; Kick off anti-AFK. Fires every 5s but only acts if it's been
    ; AntiAfkIntervalMs since the last real jiggle.
    LastAntiAfkTick := A_TickCount
    SetTimer(AntiAfkTick, 5000)
    WatchdogLastStatus := ""
    WatchdogLastStatusChangeTick := A_TickCount
    WatchdogAlertSent := false
    SetTimer(WatchdogTick, 30000)

    ; If Roblox is already running, just focus it and (optionally) click
    ; Play in case it's sitting on the menu screen. If it's not running,
    ; hand off to RejoinRoblox(), which already knows how to launch the
    ; game via the captured join window + join click.
    if ActivateRoblox()
    {
        global PlayButtonConfigured
        if PlayButtonConfigured && IsPlayButtonVisible()
        {
            ; Same nudge-click the rejoin path uses. Pixel-detect the
            ; green Play button, nudge 1px (forces a fresh mouse-move
            ; event so Roblox registers the click), then click.
            Sleep(300)
            MouseMove(PlayButtonX, PlayButtonY, 0)
            Sleep(120)
            MouseMove(PlayButtonX + 1, PlayButtonY + 1, 0)
            Sleep(60)
            Click("Left")
            Sleep(2000)
        }
    }
    else
    {
        UpdateStatus("LAUNCHING ROBLOX", mode)
        UpdateOCRResult("Roblox is not running. Launching via the join flow...")
        if !RejoinRoblox()
        {
            UpdateStatus("ROBLOX LAUNCH FAILED", mode)
            MacroRunning := false
            return
        }
    }

    FocusRobloxChat()

    while MacroRunning
    {
        ; Safety: release auto-attack if it's been held too long.
        if (AutoAttackActive && (A_TickCount - AutoAttackStartedTick > AutoAttackMaxMs))
            StopAutoAttack()

        if !WaitWhilePaused()
            break

        ; ---- PRIORITY CHECK: Orenga ----
        ; Runs before any biome/boss logic. If it's visible, we pause
        ; immediately so nothing else (especially a rejoin) can fire.
        if CheckForOrenga()
        {
            HandleOrengaFound()
            if !WaitWhilePaused()
                break
            continue
        }
        else if OrengaAlertActive
        {
            ; Orenga no longer visible - clear alert so a new spawn can
            ; re-fire later.
            OrengaAlertActive := false
        }        

        if TargetBiomeActive
        {
            result := MonitorTargetBiome()

            if (result = "WORLD_RESET" || result = "TARGET_TIMEOUT")
            {
                StopAutoAttack()
                TargetBiomeActive      := false
                TargetBiomeKeyword     := ""
                TargetBiomeName        := ""
                TargetBiomeDef         := ""
                TargetPingedBosses     := Map()
                TargetBiomeStartedTick := 0
                TargetChatBaseline     := Map()
                UpdateStatus("RUNNING", MacroMode)
                UpdateOCRResult("World returned to normal - target biome ended. Resuming scan.")
                continue
            }

            if (result = "LEAVE_BIOME")
            {
                StopAutoAttack()
                TargetBiomeActive      := false
                TargetBiomeKeyword     := ""
                TargetBiomeName        := ""
                TargetBiomeDef         := ""
                TargetPingedBosses     := Map()
                TargetBiomeStartedTick := 0
                TargetChatBaseline     := Map()

                UpdateStatus("REJOINING", "Unwanted boss in ignored biome")
                if !RejoinRoblox()
                {
                    if !MacroRunning
                        break
                    UpdateOCRResult("REJOIN ATTEMPT DID NOT CONFIRM.")
                }
                FocusRobloxChat()
                continue
            }

            Sleep(100)
            continue
        }

        ; The slash is intentional: it keeps Roblox chat focused/visible.
        ; Do it periodically rather than every OCR pass so it does not spam the chat box.
        KeepRobloxChatFocused()

        ; ------------------------------------------------------------------
        ; Roblox error-screen check.
        ;
        ; DISABLED in v1.0.0: the OCR regions used here false-positive on
        ; freshly-joined servers (something in the loading screen / chat
        ; scroll matches one of the error phrases), which caused an instant
        ; rejoin loop before the chat scanner ever ran.
        ;
        ; To try it, change `false` to `A_TickCount - LastErrorCheckTick > 2000`
        ; and re-test. Expect to tune the phrase list or the OCR regions.
        ; ------------------------------------------------------------------
        if (false)
        {
            LastErrorCheckTick := A_TickCount
            if CheckRobloxErrorScreen()
            {
                UpdateStatus("ROBLOX ERROR", "Closing and rejoining")
                UpdateOCRResult("Detected Roblox error screen. Closing Roblox fully and rejoining.")

                ; Close Roblox: send window-close, wait, force-kill if needed.
                hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
                if hwnd
                {
                    try WinClose("ahk_id " . hwnd)
                    closeDeadline := A_TickCount + 3000
                    while WinExist("ahk_exe RobloxPlayerBeta.exe") && A_TickCount < closeDeadline
                        Sleep(50)
                }
                ; Still alive? Force-kill.
                if WinExist("ahk_exe RobloxPlayerBeta.exe")
                {
                    try Run("taskkill /F /IM RobloxPlayerBeta.exe", , "Hide")
                    Sleep(1500)
            }
        }

            ; Rejoin.
            if !RejoinRoblox()
            {
                if !MacroRunning
                    break
            }
            FocusRobloxChat()
            continue
        }
        Sleep(20)

        if !MacroRunning
            break

        lines := []
        try
        {
            result := OCR.FromRect(OCR_X, OCR_Y, OCR_WIDTH, OCR_HEIGHT, {lang: "en-US"})
            lines := ExtractChatLines(result)
            UpdateOCRResult(result.Text)
        }
        catch Error as err
        {
            UpdateOCRResult("OCR failed: " . err.Message)
        }

        if !MacroRunning
            break

        evt := FindChatEvent(lines)
        DetectOreSpawns(lines)

                ; -------- Fallback: boss spawned but no biome message --------
        ; Sometimes Roblox drops the biome announcement but still shows
        ; the boss spawn line. If we can resolve the boss to a biome, act
        ; on that biome's current status.
        if (evt.type = "")
        {
            for line in lines
            {
                if !line.isGame
                    continue
                lowB := StrLower(line.text)
                if !InStr(lowB, "has spawned")
                    continue

                fallback := ResolveBossWithoutBiome(line.text)
                if (fallback = "")
                    continue

                if (fallback.action = "bad")
                {
                    UpdateStatus("BAD BOSS", fallback.bossName . " (no biome)")
                    UpdateOCRResult("Unwanted boss '" . fallback.bossName . "' spawned with no biome message - rejoining.")
                    if !RejoinRoblox()
                    {
                        if !MacroRunning
                            break
                    }
                    FocusRobloxChat()
                    break
                }
                else if (fallback.action = "good")
                {
                    UpdateStatus("BOSS (no biome)", fallback.bossName)
                    if fallback.bossObj.notify
                        HandleDetectedBoss(fallback.biomeDef, fallback.bossObj, "Chat (no biome)")
                    break
                }
            }
            if !MacroRunning
                break
            if (evt.type = "")
            {
                Sleep(100)
                continue
            }
        }

        if (evt.type = "WANTED")
        {
            BadBiomeSeenCount := 0
            BadBiomeSeenId := ""
            TargetBiomeActive      := true
            TargetBiomeKeyword     := evt.keyword
            TargetBiomeName        := evt.def.biomeName
            TargetBiomeDef         := evt.def
            LastHandledBiomeDef    := evt.def
            TargetPingedBosses     := Map()
            TargetBiomeStartedTick := A_TickCount
            TargetChatBaseline     := CaptureChatBaseline()

            UpdateStatus("TARGET BIOME", TargetBiomeName)
            SendBiomeArrivalNotification(evt.keyword, evt.def)
            UpdateOCRResult(
                "TARGET BIOME DETECTED: " . TargetBiomeName
                . "`nWaiting for boss spawn..."
            )

            ; Roblox chat is oldest-at-top. Any line with a HIGHER index
            ; than the biome announcement is newer than the biome, so
            ; a boss spawn that appeared in the SAME OCR pass as the
            ; biome still counts. Lines above are stale and must be
            ; ignored (otherwise a Medusa line from a previous biome
            ; would kick us out immediately).
            leftBiome := false
            if (evt.HasProp("idx") && evt.idx > 0)
            {
                Loop lines.Length - evt.idx
                {
                    i := evt.idx + A_Index
                    if (i > lines.Length)
                        break

                    bossObj := ResolveSpawnedBossName(lines[i].text, evt.def)
                    if (bossObj = "")
                        continue
                    if TargetPingedBosses.Has(bossObj.name)
                        continue
                    TargetPingedBosses[bossObj.name] := true

                    if bossObj.notify
                        HandleDetectedBoss(evt.def, bossObj, "Chat")

                    if (bossObj.HasProp("leave") && bossObj.leave)
                    {
                        leftBiome := true
                        UpdateOCRResult("Boss '" . bossObj.name . "' spawned - leaving biome.")
                        break
                    }
                }
            }

            if leftBiome
            {
                TargetBiomeActive      := false
                TargetBiomeKeyword     := ""
                TargetBiomeName        := ""
                TargetBiomeDef         := ""
                TargetPingedBosses     := Map()
                TargetBiomeStartedTick := 0
                TargetChatBaseline     := Map()

                UpdateStatus("REJOINING", "Unwanted boss spawned")
                if !RejoinRoblox()
                {
                    if !MacroRunning
                        break
                    UpdateOCRResult("REJOIN ATTEMPT DID NOT CONFIRM.")
                }
                FocusRobloxChat()
            }

            continue
        }

        if (evt.type = "BAD")
        {
            ; Rejoin immediately - no second confirmation pass.
            ; This shaves ~150ms per bad biome, which is noticeable
            ; when you're hopping fast. The keyword matching is specific
            ; enough that a single hit is reliable.
            BadBiomeSeenCount := 0
            BadBiomeSeenId := ""

            UpdateStatus("BAD BIOME", evt.def.biomeName)
            UpdateOCRResult("BAD BIOME DETECTED: " . evt.def.biomeName . "`nRejoining...")
            if !RejoinRoblox()
            {
                if !MacroRunning
                    break
                UpdateOCRResult("REJOIN ATTEMPT DID NOT CONFIRM.")
            }
            FocusRobloxChat()
            continue
        }

        Sleep(100)
    }

    if !Calibrating
    {
        MacroRunning := false
        MacroPaused := false
        MacroMode := ""
        TargetBiomeActive := false
        TargetBiomeKeyword := ""
        TargetBiomeName := ""
        TargetBiomeStartedTick := 0
        TargetChatBaseline := Map()
        try PauseButton.Text := "PAUSE"
        UpdateStatus("STOPPED", "None")
    }
}

KeepRobloxChatFocused()
{
    global LastChatFocusTick, ChatFocusInterval, AutoAttackActive

    ; No chat interaction while AA is running.
    if AutoAttackActive
    {
        LastChatFocusTick := A_TickCount
        return
    }

    if (A_TickCount - LastChatFocusTick < ChatFocusInterval)
        return

    if !ActivateRoblox()
    {
        LastChatFocusTick := A_TickCount
        return
    }

    ; Hover over the chat area to expand it visually. No key press,
    ; no click, no focus theft.
    MouseGetPos(&origX, &origY)
    MouseMove(OCR_X + 100, OCR_Y + 100, 3)
    Sleep(40)
    MouseMove(origX, origY, 3)
    Sleep(20)

    LastChatFocusTick := A_TickCount
}

FocusRobloxChat()
{
    if !ActivateRoblox()
        return false

    ; DO NOT send "/" here. It opens the chat input box, which:
    ;   - covers the newest chat lines with the command dropdown
    ;   - steals keyboard focus from the game (AA abilities go to chat)
    ;   - persists across scan passes
    ;
    ; Just activating the window is enough. Roblox chat is visible by
    ; default; we don't need to force it open.
    return true
}

; ============================================================
; TARGET BIOME MONITOR
; ============================================================

; Tracks a good biome we're camping on. Returns:
;   "WAITING"      - no world reset yet, still watching
;   "WORLD_RESET"  - world returned to normal; caller should clear & resume
;   "STOPPED"      - macro was stopped

MonitorTargetBiome()
{
    global TargetBiomeDef, TargetChatBaseline, TargetTimeoutMs
    global TargetBiomeStartedTick, TargetPingedBosses
    global ChatOCR_X, ChatOCR_Y, ChatOCR_WIDTH, ChatOCR_HEIGHT
    global MacroRunning, BiomeByKeyword

    if !MacroRunning
        return "STOPPED"
    if !IsObject(TargetBiomeDef)
        return "WORLD_RESET"

    KeepRobloxChatFocused()

    ; ---- 1) Chat OCR ----
    chatLines := []
    try
    {
        chatResult := OCR.FromRect(ChatOCR_X, ChatOCR_Y, ChatOCR_WIDTH, ChatOCR_HEIGHT, {lang: "en-US"})
        chatLines := ExtractChatLines(chatResult)
        UpdateOCRResult("TARGET CHAT OCR:`n" . chatResult.Text)
    }
    catch Error as err
    {
        UpdateOCRResult("TARGET CHAT OCR FAILED: " . err.Message)
    }
    ; Priority boss check overrides camp behaviour too.
    priorityBoss := CheckPriorityBoss()
    if (priorityBoss != "")
    {
        HandlePriorityBoss(priorityBoss)
        return "STOPPED"
    }

    ; Ore spawns can happen while camping too — check every pass.
    DetectOreSpawns(chatLines)

    ; ---- 2) Count occurrences of each normalized line ----
    currentCounts := Map()
    for line in chatLines
    {
        if !line.isGame
            continue
        n := NormalizeLine(line.text)
        if (n = "")
            continue
        currentCounts[n] := currentCounts.Has(n) ? currentCounts[n] + 1 : 1
    }

    ; ---- 3) Which texts have MORE instances now than in the baseline? ----
    ; Keep the original (un-normalized) line text for each new text so
    ; boss keyword matching sees real casing.
    newTexts := []
    origByNorm := Map()
    for line in chatLines
    {
        if !line.isGame
            continue
        n := NormalizeLine(line.text)
        if (n = "")
            continue
        baseC := TargetChatBaseline.Has(n) ? TargetChatBaseline[n] : 0
        curC  := currentCounts[n]
        if (curC > baseC) && !origByNorm.Has(n)
        {
            origByNorm[n] := line.text
            newTexts.Push(n)
        }
    }

    ; ---- 4) Baseline = current frame's counts (rolling) ----
    TargetChatBaseline := currentCounts.Clone()

    ; ---- 5) Process new texts ----
    for n in newTexts
    {
        origText := origByNorm[n]
        low := StrLower(origText)

        ; Any other biome? -> world cycled.
        otherBiome := false
        for kw, def in BiomeByKeyword
        {
            if (def.id = TargetBiomeDef.id)
                continue
            if InStr(low, kw)
            {
                otherBiome := true
                break
            }
        }
        if otherBiome
            return "WORLD_RESET"

        ; Boss spawn?
        bossObj := ResolveSpawnedBossName(origText, TargetBiomeDef)
        if (bossObj = "")
            continue
        if TargetPingedBosses.Has(bossObj.name)
            continue

        TargetPingedBosses[bossObj.name] := true
        if bossObj.notify
            HandleDetectedBoss(TargetBiomeDef, bossObj, "Chat")
        if (bossObj.HasProp("leave") && bossObj.leave)
        {
            UpdateOCRResult("Boss '" . bossObj.name . "' spawned - leaving biome.")
            return "LEAVE_BIOME"
        }
        
        ; Start auto-attack if this biome is flagged for it and we aren't
        ; already attacking.
        if (TargetBiomeDef.HasProp("autoAttack") && TargetBiomeDef.autoAttack)
        {
            seqName := TargetBiomeDef.HasProp("attackSequence") ? TargetBiomeDef.attackSequence : "default"
            StartAutoAttack(seqName)
        }

        ; One boss per pass. Baseline stops repeats.
        break
    }

    ; ---- 6) Boss-bar OCR fallback ----
    bossText := ""
    try
    {
        bossRect := GetBossBarRect()
        bossResult := OCR.FromRect(bossRect.x, bossRect.y, bossRect.w, bossRect.h, {lang: "en-US"})
        bossText := bossResult.Text
    }
    catch
    {
    }

    if (bossText != "")
    {
        normalized := StrLower(bossText)
        for bossObj in TargetBiomeDef.bosses
        {
            if TargetPingedBosses.Has(bossObj.name)
                continue
            for kw in bossObj.keywords
            {
                if InStr(normalized, kw)
                {
                    TargetPingedBosses[bossObj.name] := true
                    if bossObj.notify
                        HandleDetectedBoss(TargetBiomeDef, bossObj, "Boss Bar")
                    if (bossObj.HasProp("leave") && bossObj.leave)
                    {
                        UpdateOCRResult("Boss '" . bossObj.name . "' (boss bar) - leaving biome.")
                        return "LEAVE_BIOME"
                    }
                    break
                }
            }
        }
    }

    ; ---- 7) Timeout ----
    if TargetTimeoutMs > 0 && TargetBiomeStartedTick > 0 && (A_TickCount - TargetBiomeStartedTick >= TargetTimeoutMs)
        return "WORLD_RESET"

    return "WAITING"
}

; Snapshot of every currently-visible chat line, with a count of how
; many times each normalized text appears. Counts (not just presence)
; are what let us detect a *new* instance of a message whose text is
; already in the visible chat from an earlier cycle.
CaptureChatBaseline()
{
    global ChatOCR_X, ChatOCR_Y, ChatOCR_WIDTH, ChatOCR_HEIGHT
    baseline := Map()
    chatLines := []

    Loop 2
    {
        try
        {
            result := OCR.FromRect(ChatOCR_X, ChatOCR_Y, ChatOCR_WIDTH, ChatOCR_HEIGHT, {lang: "en-US"})
            chatLines := ExtractChatLines(result)
            if chatLines.Length > 0
                break
        }
        catch
        {
        }
        Sleep(150)
    }

    for line in chatLines
    {
        if !line.isGame
            continue
        n := NormalizeLine(line.text)
        if (n = "")
            continue
        baseline[n] := baseline.Has(n) ? baseline[n] + 1 : 1
    }
    return baseline
}

; Resolves which boss (from a given biome's boss list) a chat spawn line
; refers to. Returns the bossObj, or "" if none of the biome's bosses
; appear in the line, or if the line is an ore spawn.
ResolveSpawnedBossName(line, biomeDef)
{
    global OreSpawnNames

    if !IsObject(biomeDef)
        return ""

    lower := StrLower(line)

    ; Rule out ore spawns first - they share the "has spawned" phrasing.
    for _, oreName in OreSpawnNames
        if InStr(lower, oreName)
            return ""

    ; Now try each boss in this biome's list, longest keyword first so
    ; "old dragon" matches before a hypothetical "dragon".
    best := ""
    bestLen := 0
    for bossObj in biomeDef.bosses
    {
        for kw in bossObj.keywords
        {
            if (StrLen(kw) > bestLen && InStr(lower, kw))
            {
                best := bossObj
                bestLen := StrLen(kw)
            }
        }
    }

    return best
}

; When a boss spawn line appears but no biome message, try to figure out
; what to do. Preference order:
;   1) If any biome containing this boss is GOOD -> treat as good
;   2) Otherwise, if any containing biome is BAD -> treat as bad
;   3) Otherwise, no action.
ResolveBossWithoutBiome(lineText)
{
    global BiomeDefs, BiomeGood, BiomeBad, OreSpawnNames

    lower := StrLower(lineText)
    for oreName in OreSpawnNames
        if InStr(lower, oreName)
            return ""

    bestBossObj := ""
    bestBiomeDef := ""
    bestLen := 0

    for def in BiomeDefs
    {
        for bossObj in def.bosses
        {
            for kw in bossObj.keywords
            {
                if (StrLen(kw) > bestLen && InStr(lower, kw))
                {
                    bestBossObj := bossObj
                    bestBiomeDef := def
                    bestLen := StrLen(kw)
                }
            }
        }
    }

    if (bestBossObj = "")
        return ""

    biomeDef := bestBiomeDef
    bossObj  := bestBossObj

    ; Decide the action from the containing biome's status. If the boss
    ; has an explicit leave flag, that takes priority.
    action := ""
    if (bossObj.HasProp("leave") && bossObj.leave)
        action := "bad"
    else if BiomeGood.Has(biomeDef.id) && BiomeGood[biomeDef.id]
        action := "good"
    else if BiomeBad.Has(biomeDef.id) && BiomeBad[biomeDef.id]
        action := "bad"

    if (action = "")
        return ""

    return { action: action, biomeDef: biomeDef, bossObj: bossObj, bossName: bossObj.name }
}

; General-purpose line normalization for baseline comparison.
; Lowercases, collapses whitespace, strips leading/trailing punctuation.
; Unlike NormalizeSpawnLine this works for ANY line, not just spawns.
NormalizeLine(line)
{
    s := Trim(StrLower(line))
    if (s = "")
        return ""
    s := RegExReplace(s, "\s+", " ")
    s := RegExReplace(s, "^[^a-z0-9]+", "")
    s := RegExReplace(s, "[^a-z0-9]+$", "")
    return s
}

; Returns true if the game's Play button is visible at the captured
; coordinate. Samples a small cluster of pixels around the captured point
; so minor misalignments don't matter.
;
; The Play button is a distinctive bright green - much more reliable
; than OCR'ing text that also appears on the loading screen.
IsPlayButtonVisible()
{
    global PlayButtonX, PlayButtonY
    if (PlayButtonX <= 0 || PlayButtonY <= 0)
        return false

    ; Wider sample grid so we don't miss the button if the capture is
    ; slightly off or the scaling differs between RDPs.
    points := [
        [PlayButtonX,      PlayButtonY    ],
        [PlayButtonX - 25, PlayButtonY    ],
        [PlayButtonX + 25, PlayButtonY    ],
        [PlayButtonX - 12, PlayButtonY    ],
        [PlayButtonX + 12, PlayButtonY    ],
        [PlayButtonX,      PlayButtonY - 10],
        [PlayButtonX,      PlayButtonY + 10],
        [PlayButtonX - 20, PlayButtonY - 5],
        [PlayButtonX + 20, PlayButtonY - 5],
        [PlayButtonX - 20, PlayButtonY + 5],
        [PlayButtonX + 20, PlayButtonY + 5]
    ]

    greenCount := 0
    for pt in points
    {
        c := PixelGetColor(pt[1], pt[2], "RGB")
        r := (c >> 16) & 0xFF
        g := (c >> 8)  & 0xFF
        b :=  c        & 0xFF

        ; Looser green check: green channel clearly dominant, mid-to-light.
        if (g > 130 && g > r + 10 && g > b + 10)
            greenCount += 1
    }

    ; Require 3+ green samples to declare visible. The Play button is
    ; big enough that even on a misaligned RDP, 3 of 11 should be green.
    return (greenCount >= 3)
}

GetBossBarRect()
{
    try
    {
        hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        if hwnd
        {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)
            return {
                x: wx + Round(ww * 0.25),
                y: wy + Round(wh * 0.66),
                w: Round(ww * 0.50),
                h: Round(wh * 0.24)
            }
        }
    }
    catch
    {
    }

    return {
        x: Round(A_ScreenWidth * 0.25),
        y: Round(A_ScreenHeight * 0.66),
        w: Round(A_ScreenWidth * 0.50),
        h: Round(A_ScreenHeight * 0.24)
    }
}

; ============================================================
; ORENGA PRIORITY DETECTION
;
; Orenga is a roaming boss that is NOT announced in chat - the only
; way to detect it is via the boss health bar at the bottom of the
; screen. Because it's extremely rare and highly desirable, we check
; for it on every loop iteration BEFORE any biome or boss decision.
;
; On detection: ping Discord and pause the macro so a bad-biome rejoin
; can't yank us out of the server before the player responds.
; ============================================================
; ============================================================
; ORENGA PIXEL COLOR CHECK
;
; Orenga's HP bar is a distinctive orange (#E17814, RGB 225 120 20).
; No other boss in the game uses that exact color, so we can scan a
; few horizontal lines inside the boss-bar region and look for it.
;
; This runs as a second signal on top of the OCR name check, in case
; the stylized font confuses OCR on a specific render.
; ============================================================

IsOrengaBarVisible()
{
    targetR := 225
    targetG := 120
    targetB := 20
    tol := 35       ; per-channel tolerance, covers antialiasing + D3D variance

    bossRect := GetBossBarRect()

    ; The bar sits a little below the boss name text. From the region
    ; returned by GetBossBarRect, the bar is roughly 45-65% down.
    ; We scan 5 horizontal lines in that range and take any hit.
    xStart := bossRect.x + Round(bossRect.w * 0.30)
    xEnd   := bossRect.x + Round(bossRect.w * 0.70)

    Loop 5
    {
        yFrac := 0.45 + (A_Index - 1) * (0.20 / 4)
        y := bossRect.y + Round(bossRect.h * yFrac)

        matches := 0
        samples := 0
        x := xStart
        while (x <= xEnd)
        {
            c := PixelGetColor(x, y, "RGB")
            r := (c >> 16) & 0xFF
            g := (c >> 8)  & 0xFF
            b :=  c        & 0xFF

            ; Skip near-black so chat shadow / letterboxing doesn't count.
            if !(r < 30 && g < 30 && b < 30)
            {
                samples += 1
                if (Abs(r - targetR) <= tol
                &&  Abs(g - targetG) <= tol
                &&  Abs(b - targetB) <= tol)
                    matches += 1
            }
            x += 6
        }

        ; Bar fills left to right. 30% orange on a line is a clear hit
        ; even if the boss is heavily damaged.
        if (samples >= 8 && matches / samples > 0.30)
            return true
    }

    return false
}

CheckForOrenga(force := false)
{
    global OrengaLastDetectTick, OrengaDetectCooldownMs, OrengaKeywords

    ; Rate limit: OCR is fast but not free. 5x/second is plenty.
    if !force && (A_TickCount - OrengaLastDetectTick < OrengaDetectCooldownMs)
        return false
    OrengaLastDetectTick := A_TickCount

    ; --- 1) OCR the boss-name text ---
    try
    {
        bossRect := GetBossBarRect()
        result := OCR.FromRect(bossRect.x, bossRect.y, bossRect.w, bossRect.h, {lang: "en-US"})
        if (result.Text != "")
        {
            low := StrLower(result.Text)
            for kw in OrengaKeywords
                if InStr(low, kw)
                    return true
        }
    }
    catch
    {
    }

    ; --- 2) Fall back to the orange bar color ---
    ; Catches cases where OCR mangled the name beyond recognition.
    if IsOrengaBarVisible()
        return true

    return false
}

HandleOrengaFound()
{
    global MacroPaused, OrengaAlertActive, PauseButton, MacroMode

    ; Always ensure paused, even on repeat calls.
    MacroPaused := true
    try PauseButton.Text := "RESUME"

    ; Only fire the Discord ping + status change once per spawn.
    if OrengaAlertActive
        return

    OrengaAlertActive := true

    NotifyOrenga()

    UpdateStatus("ORENGA FOUND!", "Paused - check Discord")
    UpdateOCRResult(
        "🚨 ORENGA DETECTED 🚨`n"
        . "The script has paused so a rejoin cannot lose it.`n"
        . "Discord ping sent - get to this server.`n"
        . "Press F6 (or RESUME) when ready to continue."
    )
}

NotifyOrenga()
{
    global DiscordWebhookURL, PrivateServerLink
    global SecondaryWebhookURL, SecondaryEnabled
    global OrengaRoleID, LastBossNotifyTick

    msg :=
        "🚨🚨 **ORENGA HAS SPAWNED!** 🚨🚨`n"
        . "Priority alert - script paused, get in now.`n"

    link := Trim(PrivateServerLink)
    if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        msg .= "`n" . link

    ; Primary server
    if (Trim(DiscordWebhookURL) != "" && DiscordWebhookURL != "PASTE_NEW_DISCORD_WEBHOOK_HERE")
        try SendDiscordWebhook(DiscordWebhookURL, msg, OrengaRoleID)

    ; Secondary server (if enabled)
    if SecondaryEnabled
    {
        secURL := Trim(SecondaryWebhookURL)
        if (secURL != "" && secURL != "PASTE_SECONDARY_WEBHOOK_HERE")
            try SendDiscordWebhook(secURL, msg, "")
    }

    ; Stamp the standard boss cooldown so the normal boss-bar path
    ; doesn't fire a second ping for the same spawn.
    LastBossNotifyTick["Orenga"] := A_TickCount
}

; ============================================================
; WAIT WHILE PAUSED
; ============================================================

WaitWhilePaused()
{
    global MacroRunning
    global MacroPaused

    while MacroPaused
    {
        if !MacroRunning
            return false

        Sleep(100)
    }

    return MacroRunning
}

; ============================================================
; REJOIN ROBLOX
; ============================================================

ActivateRoblox()
{
    try
    {
        hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        if hwnd
        {
            WinActivate("ahk_id " . hwnd)
            ; Verify it actually became the foreground window instead of
            ; assuming WinActivate worked - Windows can silently refuse
            ; to hand over focus (foreground lock), which previously left
            ; the browser active while we thought Roblox was.
            if WinWaitActive("ahk_id " . hwnd, , 0.5)
                return true
        }
    }
    catch
    {
    }
    return false
}

ClickJoinButton(browserHwnd)
{
    global JoinButtonX, JoinButtonY, JoinButtonRelX, JoinButtonRelY
    try
    {
        if JoinButtonRelX >= 0 && JoinButtonRelY >= 0
        {
            WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
            Click(bx + JoinButtonRelX, by + JoinButtonRelY, 1, "Left")
        }
        else
            Click(JoinButtonX, JoinButtonY, 1, "Left")
        return true
    }
    catch
    {
        return false
    }
}

; One-shot manual hop: close Roblox, activate the join browser window,
; click Join, wait for Roblox to launch. No scanning, no state changes -
; this is purely the mechanical half of a hop, for when the user wants
; to hop by hand or the macro is doing something else.
ManualHop(*)
{
    SetTimer(AntiAfkTick, 0)
    StopAutoAttack()
    global MacroRunning

    if MacroRunning
    {
        UpdateStatus("MANUAL HOP", "Macro is running - stop it first")
        UpdateOCRResult("Stop the current macro before running a manual hop.")
        return
    }

    UpdateStatus("MANUAL HOP", "Closing Roblox...")

    ; 1) Close Roblox if it's open.
    hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if hwnd
    {
        try WinClose("ahk_id " . hwnd)
        catch
        {
        }

        closeDeadline := A_TickCount + 3000
        while WinExist("ahk_exe RobloxPlayerBeta.exe") && A_TickCount < closeDeadline
            Sleep(50)
    }

    ; 2) Activate the join browser window.
    browserHwnd := FindJoinWindow()
    if !browserHwnd
    {
        UpdateStatus("MANUAL HOP FAILED", "Join window not found")
        UpdateOCRResult("Manual hop: could not find the join browser window. Set it via Tools > Capture Join Window.")
        return
    }

    try
    {
        WinActivate("ahk_id " . browserHwnd)
        if !WinWaitActive("ahk_id " . browserHwnd, , 1.0)
        {
            UpdateStatus("MANUAL HOP FAILED", "Browser did not activate")
            return
        }
    }
    catch
    {
        UpdateStatus("MANUAL HOP FAILED", "Cannot activate browser")
        return
    }

    ; 3) Optional safe click (same as RejoinRoblox).
    global SafeClickConfigured, SafeClickRelX, SafeClickRelY
    WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
    if SafeClickConfigured && SafeClickRelX >= 0 && SafeClickRelY >= 0
        Click(bx + SafeClickRelX, by + SafeClickRelY, 1, "Left")

    ; 4) Click Join.
    if !ClickJoinButton(browserHwnd)
    {
        UpdateStatus("MANUAL HOP FAILED", "Join click failed")
        return
    }

    UpdateStatus("MANUAL HOP", "Waiting for Roblox to launch...")

    ; 5) Wait for Roblox to launch, retrying the join click if needed.
    appeared := false
    Loop 3
    {
        launchDeadline := A_TickCount + RobloxLaunchTimeout
        while A_TickCount < launchDeadline
        {
            if WinExist("ahk_exe RobloxPlayerBeta.exe")
            {
                appeared := true
                break 2
            }
            Sleep(50)
        }
        UpdateStatus("MANUAL HOP", "Retrying join click...")
        ClickJoinButton(browserHwnd)
        Sleep(2000)
    }

    if !appeared
    {
        UpdateStatus("MANUAL HOP FAILED", "Roblox did not launch after 3 attempts")
        return
    }

    try WinActivate("ahk_exe RobloxPlayerBeta.exe")
    catch
    {
    }
    WinWaitActive("ahk_exe RobloxPlayerBeta.exe", , 2.0)

    ; Force fullscreen (matches RejoinRoblox's behaviour).
    robloxHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if robloxHwnd
    {
        MonitorGet(MonitorGetPrimary(), &monLeft, &monTop, &monRight, &monBottom)
        screenW := monRight - monLeft
        screenH := monBottom - monTop
        Loop 2
        {
            WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . robloxHwnd)
            if (rw >= screenW - 5 && rh >= screenH - 5)
                break
            try WinActivate("ahk_id " . robloxHwnd)
            Send("{F11}")
            Sleep(600)
        }
    }

    ; Pixel-based Play button detection (matches RejoinRoblox).
    SetTimer(AntiAfkTick, 5000)
    playFound   := false

    ; ---- Phase 1: wait for the green Play button (with error recovery) ----
    phase1Deadline := A_TickCount + RobloxLaunchTimeout
    lastErrorCheck := A_TickCount
    errorRetries   := 0

    while (A_TickCount < phase1Deadline)
    {
        ; Error screen detection every ~3 seconds.
        if (A_TickCount - lastErrorCheck > 3000)
        {
            lastErrorCheck := A_TickCount

            if CheckRobloxErrorScreen()
            {
                errorRetries += 1
                if (errorRetries > 3)
                {
                    UpdateStatus("REJOIN FAILED", "Too many errors")
                    UpdateOCRResult("Roblox errored out 3 times in a row. Giving up.")
                    NotifyError("Rejoin failed 3 times in a row - Roblox keeps showing an error screen. "
                              . "Likely cause: private server code expired/changed, or account lost access. "
                              . "Check the server ID in the GUI.")
                    return false
                }
                UpdateStatus("ROBLOX ERROR", "Force-closing, retry " . errorRetries . "/3")
                UpdateOCRResult("Roblox error screen detected. Force-closing Roblox and re-clicking Join (attempt "
                              . errorRetries . " of 3)...")

                ForceCloseRoblox()
                Sleep(1500)

                browserHwnd2 := FindJoinWindow()
                if browserHwnd2
                {
                    try
                    {
                        WinActivate("ahk_id " . browserHwnd2)
                        Sleep(300)
                        ClickJoinButton(browserHwnd2)
                    }
                }

                phase1Deadline := A_TickCount + RobloxLaunchTimeout
                continue
            }
        }

        if IsPlayButtonVisible()
        {
            playFound := true
            break
        }

        UpdateOCRResult("Waiting for Play button... ("
                      . Round((phase1Deadline - A_TickCount) / 1000) . "s left)")
        Sleep(150)
    }

    if !playFound
    {
        UpdateOCRResult("Play button never appeared within "
                      . Round(RobloxLaunchTimeout / 1000) . "s. Giving up.")
        NotifyError("Play button never appeared after "
                  . Round(RobloxLaunchTimeout / 1000) . " seconds. "
                  . "Roblox may be stuck loading, or the server is unavailable.")
        return false
    }

    ; ---- Phase 2: click the Play button. ----
    UpdateOCRResult("Play button visible - clicking...")
    ActivateRoblox()
    Sleep(120)

    MouseMove(PlayButtonX, PlayButtonY, 0)
    Sleep(120)
    MouseMove(PlayButtonX + 1, PlayButtonY + 1, 0)
    Sleep(60)
    Click("Left")

    ; ---- Phase 3: wait for the button to disappear. ----
    disappearDeadline := A_TickCount + 6000
    while (A_TickCount < disappearDeadline)
    {
        if !IsPlayButtonVisible()
            break
        Sleep(100)
    }

    ; ---- Phase 4: grace period for the world to render. ----
    Sleep(2500)

    FocusRobloxChat()
    UpdateStatus("MANUAL HOP DONE", "In world")
    UpdateOCRResult("Manual hop complete.")
    return true
}

ToggleAutoAttack(*)
{
    global AutoAttackEnabled, AutoAttackIntervalMs

    AutoAttackEnabled := !AutoAttackEnabled

    if AutoAttackEnabled
    {
        ; Focus Roblox first so clicks land in the game.
        if ActivateRoblox()
        {
            SetTimer(DoAutoAttackTick, AutoAttackIntervalMs)
            UpdateStatus("AUTO-ATTACK", "On")
            UpdateOCRResult("Auto-attack ENABLED. Spamming left click every " . AutoAttackIntervalMs . " ms. Press Ctrl+Shift+A to stop.")
        }
        else
        {
            AutoAttackEnabled := false
            UpdateOCRResult("Auto-attack could not start - Roblox is not the active window.")
        }
    }
    else
    {
        SetTimer(DoAutoAttackTick, 0)
        UpdateStatus("AUTO-ATTACK", "Off")
        UpdateOCRResult("Auto-attack DISABLED.")
    }
}

DoAutoAttackTick()
{
    global AutoAttackEnabled
    if !AutoAttackEnabled
    {
        SetTimer(DoAutoAttackTick, 0)
        return
    }
    ; Click wherever the cursor is (leave it in a safe attack zone).
    Click("Left")
}

RejoinRoblox()
{   
    SetTimer(WatchdogTick, 0)
    SetTimer(AntiAfkTick, 0)
    StopAutoAttack()
    global MacroRunning, MacroMode
    global JoinButtonX, JoinButtonY, JoinButtonRelX, JoinButtonRelY
    global SafeClickX, SafeClickY, SafeClickRelX, SafeClickRelY, SafeClickConfigured
    global RobloxLaunchTimeout

    ; Priority safety: refuse to rejoin while Orenga is on the boss bar.
    ; Use force := true to bypass the OCR rate limit - we want a real
    ; check right here, right now.
    if CheckForOrenga(true)
    {
        HandleOrengaFound()
        return false
    }

    if !MacroRunning
        return false

    UpdateStatus("REJOINING", "Server hop")

    ; ---- Fast path: Ctrl+R the browser tab that has the join page. ----
    ; This is much quicker than closing Roblox, re-activating the browser,
    ; clicking Join, and waiting for launch. If the browser tab can't be
    ; found or the refresh doesn't produce a Roblox launch, we fall
    ; through to the click-Join path below (Roblox is already closed by
    ; the time TryCtrlRRejoin returns false).
    if TryNavigateAndJoin()
    {
        try WinActivate("ahk_exe RobloxPlayerBeta.exe")
        catch
        {
        }
        WinWaitActive("ahk_exe RobloxPlayerBeta.exe", , 1.0)
        Sleep(2000)

        ; Force fullscreen on whichever monitor was selected.
        robloxHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        if robloxHwnd
        {
            mon := GetMonitorBounds()
            Loop 2
            {
                WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . robloxHwnd)
                if (rw >= mon.w - 5 && rh >= mon.h - 5)
                    break
                try WinActivate("ahk_id " . robloxHwnd)
                Send("{F11}")
                Sleep(600)
            }
        }

        ; Same Play-button logic as the click path.
        SetTimer(AntiAfkTick, 5000)
        playFound := false
        phase1Deadline := A_TickCount + RobloxLaunchTimeout
        while (A_TickCount < phase1Deadline)
        {
            if !MacroRunning
                return false
            if MacroPaused
            {
                Sleep(200)
                continue
            }
            if IsPlayButtonVisible()
            {
                playFound := true
                break
            }
            UpdateOCRResult("URL rejoin - waiting for Play button... ("
                          . Round((phase1Deadline - A_TickCount) / 1000) . "s left)")
            Sleep(150)
        }

        if playFound
        {
            UpdateOCRResult("Play button visible - clicking...")
            ActivateRoblox()
            Sleep(120)
            MouseMove(PlayButtonX, PlayButtonY, 0)
            Sleep(120)
            MouseMove(PlayButtonX + 1, PlayButtonY + 1, 0)
            Sleep(60)
            Click("Left")

            disappearDeadline := A_TickCount + 6000
            while (A_TickCount < disappearDeadline)
            {
                if !MacroRunning
                    return false
                if !IsPlayButtonVisible()
                    break
                Sleep(100)
            }

            Sleep(2500)
            FocusRobloxChat()
            UpdateStatus("RUNNING", MacroMode)
            UpdateOCRResult("Rejoined via URL - in world.")
            return true
        }

        ; Refresh happened but Play never showed. Fall through to the
        ; click-Join path. Roblox is already closed at this point.
        UpdateOCRResult("URL rejoin didn't reach Play screen - trying click-Join...")
    }

    ; 2) Activate the captured browser window.
    browserHwnd := FindJoinWindow()
    if !browserHwnd
    {
        UpdateStatus("REJOIN FAILED", "Join window not found")
        return false
    }

    try
    {
        WinActivate("ahk_id " . browserHwnd)
        if !WinWaitActive("ahk_id " . browserHwnd, , 0.35)
        {
            UpdateStatus("REJOIN FAILED", "Browser did not activate")
            return false
        }
    }
    catch
    {
        UpdateStatus("REJOIN FAILED", "Cannot activate browser")
        return false
    }

    if !MacroRunning
        return false

    ; 3) Safe click - ONLY if you've actually captured one with "SET SAFE
    ;    CLICK". This step exists solely to dismiss an optional Roblox
    ;    loading overlay if it's on screen. If it's not configured, skip it
    ;    entirely - guessing a coordinate risks clicking real page content
    ;    (e.g. the Roblox logo/home link), which navigates the tab away
    ;    from the join page and breaks the rejoin.
    WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
    if SafeClickConfigured && SafeClickRelX >= 0 && SafeClickRelY >= 0
        Click(bx + SafeClickRelX, by + SafeClickRelY, 1, "Left")

    if !MacroRunning
        return false

    ; 4) Immediately click Join. No artificial delay and no second click.
    if !ClickJoinButton(browserHwnd)
    {
        UpdateStatus("REJOIN FAILED", "Join click failed")
        return false
    }

    ; 5) Poll for Roblox. Retry the Join click up to 3 times total if the
    ; game doesn't appear within the timeout - RDP launches frequently
    ; need a second click to actually fire.
    appeared := false
    Loop 3
    {
        launchDeadline := A_TickCount + RobloxLaunchTimeout
        while MacroRunning && A_TickCount < launchDeadline
        {
            if WinExist("ahk_exe RobloxPlayerBeta.exe")
            {
                appeared := true
                break 2
            }
            Sleep(40)
        }

        if !MacroRunning
            return false

        ; Timeout: click Join again before giving up.
        UpdateStatus("REJOINING", "Retrying join click...")
        ClickJoinButton(browserHwnd)
        Sleep(2000)
    }

    if !appeared
    {
        UpdateStatus("REJOIN FAILED", "Roblox did not launch after 3 attempts")
        return false
    }

    try WinActivate("ahk_exe RobloxPlayerBeta.exe")
    catch
    {
    }

    WinWaitActive("ahk_exe RobloxPlayerBeta.exe", , 1.0)

    ; Give Roblox a moment to finish opening before checking its window
    ; size.
    Sleep(1200)

    ; Force fullscreen every time. Roblox sometimes opens as a small,
    ; windowed square instead of covering the screen, which throws off
    ; every OCR coordinate. This checks the actual window size against
    ; the monitor and sends F11 (up to twice, matching what you already
    ; do manually) until it actually covers the screen.
    robloxHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if robloxHwnd
    {
        mon := GetMonitorBounds()

        Loop 2
        {
            WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . robloxHwnd)
            if (rw >= mon.w - 5 && rh >= mon.h - 5)
                break

            try WinActivate("ahk_id " . robloxHwnd)
            Send("{F11}")
            Sleep(600)
        }
    }

        ; Pixel-based Play button detection.
    ;
    ; Flow:
    ;   1) Wait for the green Play button to appear (pixel check).
    ;   2) Click it.
    ;   3) Wait for the green button to disappear (game transitioning).
    ;   4) Short grace period for the world to become interactive.
    ;   5) Hand back control.
    ;
    ; Every step checks MacroRunning and MacroPaused so pause/stop work.

    SetTimer(AntiAfkTick, 5000)
    playFound   := false
    playClicked := false

    ; ---- Phase 1: wait for the green Play button. ----
    ; Also periodically checks for Roblox's error screen ("This
    ; experience has ended..."). On error, force-closes Roblox, clicks
    ; Join again, and restarts the wait.
    phase1Deadline := A_TickCount + RobloxLaunchTimeout
    lastErrorCheck := A_TickCount
    errorRetries   := 0

    while (A_TickCount < phase1Deadline)
    {
        if !MacroRunning
            return false

        if MacroPaused
        {
            Sleep(200)
            continue
        }

        ; Error screen detection every ~3 seconds.
        if (A_TickCount - lastErrorCheck > 3000)
        {
            lastErrorCheck := A_TickCount

            if CheckRobloxErrorScreen()
            {
                errorRetries += 1
                if (errorRetries > 3)
                {
                    UpdateStatus("REJOIN FAILED", "Too many errors")
                    UpdateOCRResult("Roblox errored out 3 times in a row. Giving up.")
                    NotifyError("Rejoin failed 3 times in a row - Roblox keeps showing an error screen. "
                              . "Likely cause: private server code expired/changed, or account lost access. "
                              . "Check the server ID in the GUI.")
                    return false
                }

                UpdateStatus("ROBLOX ERROR", "Force-closing, retry " . errorRetries . "/3")
                UpdateOCRResult("Roblox error screen detected. Force-closing Roblox and re-clicking Join (attempt "
                              . errorRetries . " of 3)...")

                ForceCloseRoblox()
                Sleep(1500)

                ; Re-activate the join browser window and click Join to relaunch.
                browserHwnd2 := FindJoinWindow()
                if browserHwnd2
                {
                    try
                    {
                        WinActivate("ahk_id " . browserHwnd2)
                        Sleep(300)
                        ClickJoinButton(browserHwnd2)
                    }
                }

                ; Reset the deadline so we get a fresh full timeout after
                ; the retry.
                phase1Deadline := A_TickCount + RobloxLaunchTimeout
                UpdateStatus("REJOINING", "Server hop")
                continue
            }
        }

        if IsPlayButtonVisible()
        {
            playFound := true
            break
        }

        UpdateOCRResult("URL rejoin - waiting for Play button... ("
                        . Round((phase1Deadline - A_TickCount) / 1000) . "s left)")
        Sleep(150)
    }

    if !playFound
    {
        UpdateOCRResult("Play button never appeared within "
                      . Round(RobloxLaunchTimeout / 1000) . "s. Giving up.")
        NotifyError("Play button never appeared after "
                  . Round(RobloxLaunchTimeout / 1000) . " seconds. "
                  . "Roblox may be stuck loading, or the server is unavailable.")
        return false
    }

    ; ---- Phase 2: click the Play button. ----
    UpdateOCRResult("Play button visible - clicking...")
    ActivateRoblox()
    Sleep(120)

    MouseMove(PlayButtonX, PlayButtonY, 0)
    Sleep(120)
    MouseMove(PlayButtonX + 1, PlayButtonY + 1, 0)
    Sleep(60)
    Click("Left")
    playClicked := true

    ; ---- Phase 3: wait for the button to disappear. ----
    ; Up to 6 seconds. If Roblox shows a brief mid-transition loading
    ; screen, we still see the button on top, so this catches that too.
    disappearDeadline := A_TickCount + 6000
    while (A_TickCount < disappearDeadline)
    {
        if !MacroRunning
            return false
        if !IsPlayButtonVisible()
            break
        Sleep(100)
    }

    ; ---- Phase 4: grace period. ----
    Sleep(1500)

    FocusRobloxChat()
    UpdateStatus("RUNNING", MacroMode)
    UpdateOCRResult("Rejoined successfully - in world.")
    return true
}

; ============================================================
; CTRL+R REJOIN
;
; Instead of closing Roblox and re-clicking Join, we refresh the
; browser tab that has the private server link. Roblox's join page
; reloads and re-triggers the launch automatically.
;
; Falls back to the close-and-click flow if:
;   - Roblox is still running after the refresh (launch failed)
;   - The browser window can't be found
; ============================================================

; ============================================================
; FAST REJOIN VIA URL NAVIGATION
;
; Instead of relying on a browser tab that's already on the private
; server page, we focus the browser, jump the URL bar, type the
; private server link, and press Enter. This works no matter what the
; browser was showing before, as long as the browser is running.
;
; Then we wait for Roblox to launch, same as the click-Join path.
; Falls back to click-Join if anything goes wrong.
; ============================================================

; ============================================================
; FAST REJOIN VIA URL LAUNCH
;
; Approach borrowed from MrToaster's script:
;   1) Close Roblox.
;   2) If a browser window with "Roblox" in its title exists,
;      activate it and Ctrl+R it.
;   3) Otherwise, Run the URL - Windows routes it to the default
;      browser and the private server page loads.
;   4) Wait for Roblox to appear.
;
; Then the caller clicks Play, same as the click-Join path.
; ============================================================

TryNavigateAndJoin()
{
    global MacroRunning, RobloxLaunchTimeout, PrivateServerLink
    global JoinWindowExe

    link := Trim(PrivateServerLink)
    if (link = "" || link = "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        return false

    ; ---- 1) Close Roblox ----
    hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if hwnd
    {
        try WinClose("ahk_id " . hwnd)
        catch
        {
        }
        closeDeadline := A_TickCount + 2500
        while MacroRunning && WinExist("ahk_exe RobloxPlayerBeta.exe") && A_TickCount < closeDeadline
            Sleep(20)
    }

    if !MacroRunning
        return false

    ; ---- 2) Look for an existing Roblox browser tab and Ctrl+R it ----
    refreshed := false
    try
    {
        hwnds := WinGetList("ahk_exe " . JoinWindowExe)
        for hwnd in hwnds
        {
            title := ""
            try title := WinGetTitle("ahk_id " . hwnd)
            if (title != "" && InStr(StrLower(title), "roblox"))
            {
                WinActivate("ahk_id " . hwnd)
                Sleep(300)
                Send("^r")
                refreshed := true
                break
            }
        }
    }
    catch
    {
    }

    ; ---- 3) If no Roblox tab found, Run the URL fresh ----
    ; The URL may or may not launch Roblox directly depending on its
    ; format. Share links usually land on a page with a Play button;
    ; game-instances links may auto-launch. Either way, we wait below.
    if !refreshed
    {
        try Run(link)
        catch
            return false
    }

    ; ---- 4) Wait for Roblox to launch ----
    launchDeadline := A_TickCount + RobloxLaunchTimeout
    while MacroRunning && A_TickCount < launchDeadline
    {
        if WinExist("ahk_exe RobloxPlayerBeta.exe")
            break
        Sleep(40)
    }

    if !MacroRunning
        return false

    return WinExist("ahk_exe RobloxPlayerBeta.exe")
}

GetMonitorBounds(idx := 0)
{
    if (idx = 0)
    {
        global SelectedMonitor
        idx := SelectedMonitor
    }
    MonitorGet(idx, &left, &top, &right, &bottom)
    return { x: left, y: top, w: right - left, h: bottom - top }
}

LoadMonitorSelection()
{
    global SelectedMonitor, ConfigFile

    if FileExist(ConfigFile)
    {
        try
        {
            v := IniRead(ConfigFile, "Display", "Monitor", "1")
            SelectedMonitor := Integer(v)
        }
    }

    maxMon := MonitorGetCount()
    if (SelectedMonitor < 1 || SelectedMonitor > maxMon)
        SelectedMonitor := 1
}

StartAutoAttack(sequenceName := "default")
{
    global AttackSequences, ActiveSequenceName, ActiveSequenceCommands
    global ActiveSequenceIndex, AttackTickWaitUntil
    global AutoAttackActive, AutoAttackStartedTick
    global AttackHoldX, AttackHoldY, AttackHoldConfigured

    if AutoAttackActive
        return

    if !AttackSequences.Has(sequenceName)
        sequenceName := "default"
    if !AttackSequences.Has(sequenceName)
    {
        UpdateOCRResult("Auto-attack: no sequence named '" . sequenceName . "' and no default.")
        return
    }

    if !ActivateRoblox()
    {
        UpdateOCRResult("Auto-attack: could not focus Roblox.")
        return
    }

    Sleep(200)

    ; CRITICAL: explicitly close any open chat input. If "FocusRobloxChat"
    ; or "KeepRobloxChatFocused" was pressed earlier, the input may still
    ; be open and would swallow the sequence's ability keys.
    Send("{Escape}")
    Sleep(150)
    Send("{Escape}")
    Sleep(150)

    ; Click the safe attack point to lock keyboard focus onto the game
    ; world. Uses mouse_event (SendInput's click is silently swallowed
    ; by Roblox's DirectX input handler).
    if AttackHoldConfigured
    {
        MouseMove(AttackHoldX, AttackHoldY, 0)
        Sleep(120)
        DllCall("mouse_event", "UInt", 0x0002, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep(80)
        DllCall("mouse_event", "UInt", 0x0004, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep(250)
    }

    ActiveSequenceName     := sequenceName
    ActiveSequenceCommands := AttackSequences[sequenceName]
    ActiveSequenceIndex    := 1
    AttackTickWaitUntil    := 0

    AutoAttackActive := true
    AutoAttackStartedTick := A_TickCount

    SetTimer(AttackSequenceTick, 20)
    UpdateOCRResult("Auto-attack started: '" . sequenceName . "'")
}

StopAutoAttack()
{
    global AutoAttackActive, ActiveSequenceCommands

    if !AutoAttackActive
        return

    AutoAttackActive := false
    SetTimer(AttackSequenceTick, 0)

    ; Release any held LMB as a safety net.
    DllCall("mouse_event", "UInt", 0x0004, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)

    UpdateOCRResult("Auto-attack stopped.")
}

AttackSequenceTick()
{
    global AutoAttackActive, ActiveSequenceCommands
    global ActiveSequenceIndex, AttackTickWaitUntil
    global AttackMinGapMs

    if !AutoAttackActive
    {
        SetTimer(AttackSequenceTick, 0)
        return
    }
    if (ActiveSequenceCommands.Length = 0)
        return
    if (A_TickCount < AttackTickWaitUntil)
        return

    cmd := ActiveSequenceCommands[ActiveSequenceIndex]

    switch cmd.type
    {
        case "click":
            ; Use mouse_event for the click too - SendInput's instantaneous
            ; down+up gets swallowed by Roblox on some accounts.
            MouseMove(cmd.x, cmd.y, 0)
            Sleep(30)
            DllCall("mouse_event", "UInt", 0x0002, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)  ; LEFTDOWN
            Sleep(50)
            DllCall("mouse_event", "UInt", 0x0004, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)  ; LEFTUP
            Sleep(30)

        case "hold":
            MouseMove(cmd.x, cmd.y, 0)
            Sleep(50)
            DllCall("mouse_event", "UInt", 0x0002, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)

        case "release":
            DllCall("mouse_event", "UInt", 0x0004, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)

        case "move":
            MouseMove(cmd.x, cmd.y, 0)

        case "send":
            Send(cmd.key)

        case "sleep":
            AttackTickWaitUntil := A_TickCount + cmd.ms
    }

    ; Enforce a global minimum gap between commands so nothing fires
    ; back-to-back and gets swallowed. 60ms is the sweet spot I've found.
    if (cmd.type != "sleep" && A_TickCount < AttackTickWaitUntil)
        AttackTickWaitUntil := A_TickCount + 60
    else if (cmd.type != "sleep")
        AttackTickWaitUntil := A_TickCount + 60

    ActiveSequenceIndex += 1
    if (ActiveSequenceIndex > ActiveSequenceCommands.Length)
        ActiveSequenceIndex := 1
}

; Forcefully close Roblox. Uses the two-step Alt+F4 dance:
;   1) Alt+F4 on the game window (returns to Roblox app homepage)
;   2) If still alive, Alt+F4 again (closes the app entirely)
;   3) If STILL alive, taskkill as the final fallback
ForceCloseRoblox()
{
    global MacroRunning

    if WinExist("ahk_exe RobloxPlayerBeta.exe")
    {
        ; Try clicking the "Leave" button on modal error dialogs first.
        ; This is a best-effort - if it fails, taskkill below handles it.
        try
        {
            hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
            WinActivate("ahk_id " . hwnd)
            Sleep(200)

            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)

            ; The Leave button is centered horizontally, ~78% down.
            leaveX := wx + Round(ww * 0.50)
            leaveY := wy + Round(wh * 0.78)

            MouseMove(leaveX, leaveY, 0)
            Sleep(100)
            Click("Left")
            Sleep(500)
        }
        catch
        {
        }

        ; Then check if Roblox is gone; if not, force kill.
        if WinExist("ahk_exe RobloxPlayerBeta.exe")
        {
            try Run("taskkill /F /IM RobloxPlayerBeta.exe", , "Hide")
            Sleep(1500)
        }
    }

    return !WinExist("ahk_exe RobloxPlayerBeta.exe")
}

FindJoinWindow()
{
    global JoinWindowExe, JoinWindowTitle
    try
    {
        if JoinWindowTitle != ""
        {
            hwnd := WinExist(JoinWindowTitle . " ahk_exe " . JoinWindowExe)
            if hwnd
                return hwnd
        }
        return WinExist("ahk_exe " . JoinWindowExe)
    }
    catch
    {
        return 0
    }
}

CaptureJoinWindow(*)
{
    global MainGui
    global JoinWindowExe, JoinWindowTitle

    MsgBox(
        "Click OK, then switch to the browser window containing the Roblox Join page.`n`n"
        . "The script will capture the active browser window automatically.",
        "Capture Join Window",
        "Iconi"
    )

    try
    {
        WinWaitNotActive("ahk_id " . MainGui.Hwnd, , 10)
    }
    catch
    {
    }

    Sleep(300)
    active := WinGetID("A")
    if !active
        return

    try
    {
        JoinWindowExe := WinGetProcessName("ahk_id " . active)
        JoinWindowTitle := WinGetTitle("ahk_id " . active)
        UpdateJoinSettingsText()
        UpdateOCRResult("Join window captured.`n" . JoinWindowExe . "`n" . JoinWindowTitle)
    }
    catch Error as err
    {
        UpdateOCRResult("Could not capture join window: " . err.Message)
    }
    SaveJoinSettings()
}

CaptureJoinButton(*)
{
    global JoinButtonX, JoinButtonY, JoinButtonRelX, JoinButtonRelY, JoinWindowExe, JoinWindowTitle

    MsgBox(
        "Click OK, then click the Roblox Join button once.`n`n"
        . "The script will save that screen coordinate.",
        "Set Join Button",
        "Iconi"
    )

    KeyWait("LButton")
    Loop
    {
        if GetKeyState("LButton", "P")
            break
        Sleep(20)
    }

    MouseGetPos(&JoinButtonX, &JoinButtonY)
    browserHwnd := FindJoinWindow()
    if browserHwnd
    {
        try
        {
            WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
            JoinButtonRelX := JoinButtonX - bx
            JoinButtonRelY := JoinButtonY - by
        }
        catch
        {
            JoinButtonRelX := -1
            JoinButtonRelY := -1
        }
    }
    KeyWait("LButton")
    UpdateJoinSettingsText()
    UpdateOCRResult("Join button captured: X=" . JoinButtonX . " Y=" . JoinButtonY)
    SaveJoinSettings()
}

CaptureSafeClick(*)
{
    global MainGui, SafeClickX, SafeClickY, SafeClickConfigured, SafeClickRelX, SafeClickRelY

    MsgBox(
        "Click OK, then click a harmless area of the Roblox Join webpage.`n`n"
        . "Pick a spot that will never activate a button or link.`n"
        . "This click is used to dismiss the optional 'Roblox is loading' overlay before Join.",
        "Set Safe Browser Click",
        "Iconi"
    )

    try
        WinWaitNotActive("ahk_id " . MainGui.Hwnd, , 10)

    Sleep(200)
    MouseGetPos(&SafeClickX, &SafeClickY)
    browserHwnd := WinGetID("A")
    try
    {
        WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
        SafeClickRelX := SafeClickX - bx
        SafeClickRelY := SafeClickY - by
    }
    catch
    {
        SafeClickRelX := -1
        SafeClickRelY := -1
    }
    SafeClickConfigured := true
    UpdateJoinSettingsText()
    UpdateOCRResult("Safe browser click captured: X=" . SafeClickX . " Y=" . SafeClickY)
    SaveJoinSettings()
    SetTimer(AntiAfkTick, 5000)
}

CaptureAttackHold(*)
{
    global MainGui, AttackHoldX, AttackHoldY, AttackHoldConfigured

    MsgBox(
        "Click OK, then CLICK ONCE at a safe spot in the game world.`n`n"
        . "This is where the cursor will sit while auto-swinging.`n"
        . "Pick somewhere that won't click on UI or move your character.",
        "Set Attack Hold Point",
        "Iconi"
    )

    ; Wait for user to actually click somewhere.
    KeyWait("LButton")
    Loop
    {
        if GetKeyState("LButton", "P")
            break
        Sleep(20)
    }

    MouseGetPos(&AttackHoldX, &AttackHoldY)
    KeyWait("LButton")

    AttackHoldConfigured := true
    SaveAttackSettings()
    UpdateOCRResult("Attack hold point captured: X=" . AttackHoldX . " Y=" . AttackHoldY)
}

CapturePlayButton(*)
{
    global MainGui, PlayButtonX, PlayButtonY, PlayButtonConfigured

    MsgBox(
        "Click OK, then CLICK ONCE on the PLAY button on the game's menu screen.`n`n"
        . "The script will capture that coordinate.",
        "Set Play Button",
        "Iconi"
    )

    ; Wait for user to actually click the Play button.
    KeyWait("LButton")
    Loop
    {
        if GetKeyState("LButton", "P")
            break
        Sleep(20)
    }

    MouseGetPos(&PlayButtonX, &PlayButtonY)
    KeyWait("LButton")

    PlayButtonConfigured := true
    SaveAttackSettings()
    UpdateOCRResult("Play button captured: X=" . PlayButtonX . " Y=" . PlayButtonY)
}

SaveAttackSettings()
{
    global ConfigFile, AttackHoldX, AttackHoldY, AttackHoldConfigured
    global PlayButtonX, PlayButtonY, PlayButtonConfigured

    try
    {
        IniWrite(AttackHoldConfigured ? "1" : "0", ConfigFile, "Attack", "HoldConfigured")
        IniWrite(AttackHoldX, ConfigFile, "Attack", "HoldX")
        IniWrite(AttackHoldY, ConfigFile, "Attack", "HoldY")
        IniWrite(PlayButtonConfigured ? "1" : "0", ConfigFile, "Attack", "PlayConfigured")
        IniWrite(PlayButtonX, ConfigFile, "Attack", "PlayX")
        IniWrite(PlayButtonY, ConfigFile, "Attack", "PlayY")
    }
}

LoadAttackSettings()
{
    global ConfigFile, AttackHoldX, AttackHoldY, AttackHoldConfigured
    global PlayButtonX, PlayButtonY, PlayButtonConfigured

    if !FileExist(ConfigFile)
        return

    try
    {
        v := IniRead(ConfigFile, "Attack", "HoldConfigured", "0")
        AttackHoldConfigured := (v = "1")
    }
    try
    {
        v := IniRead(ConfigFile, "Attack", "HoldX", "")
        if (v != "")
            AttackHoldX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Attack", "HoldY", "")
        if (v != "")
            AttackHoldY := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Attack", "PlayConfigured", "0")
        PlayButtonConfigured := (v = "1")
    }
    try
    {
        v := IniRead(ConfigFile, "Attack", "PlayX", "")
        if (v != "")
            PlayButtonX := Integer(v)
    }
    try
    {
        v := IniRead(ConfigFile, "Attack", "PlayY", "")
        if (v != "")
            PlayButtonY := Integer(v)
    }
}

LoadAttackSequences()
{
    global AttackSequencesFile, AttackSequences

    AttackSequences := Map()

    ; Seed default if the file doesn't exist yet.
    if !FileExist(AttackSequencesFile)
    {
        try
        {
            FileAppend(
                "; Attack sequence file.`n"
                . "; Each [SectionName] starts a new sequence.`n"
                . "; See the GUI editor for a full command list.`n"
                . "`n"
                . "[default]`n"
                . "click 961 713`n"
                . "sleep 800`n",
                AttackSequencesFile)
        }
        AttackSequences["default"] := [
            { type: "click", x: 961, y: 713 },
            { type: "sleep", ms: 800 }
        ]
        return
    }

    ; Read file.
    content := ""
    try content := FileRead(AttackSequencesFile)
    catch
        return

    currentName := ""
    currentCmds := []

    for rawLine in StrSplit(content, "`n", "`r")
    {
        line := Trim(rawLine)

        ; Blank line or comment: skip.
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue

        ; Section header.
        if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]")
        {
            ; Commit previous section.
            if (currentName != "")
                AttackSequences[currentName] := currentCmds

            currentName := Trim(SubStr(line, 2, StrLen(line) - 2))
            currentCmds := []
            continue
        }

        if (currentName = "")
            continue

        ; Parse command line.
        cmd := ParseAttackCommand(line)
        if IsObject(cmd)
            currentCmds.Push(cmd)
    }

    ; Commit last section.
    if (currentName != "")
        AttackSequences[currentName] := currentCmds

    ; Guarantee a default exists.
    if !AttackSequences.Has("default")
        AttackSequences["default"] := [
            { type: "click", x: 961, y: 713 },
            { type: "sleep", ms: 800 }
        ]
}

ParseAttackCommand(line)
{
    parts := StrSplit(line, " ")
    if (parts.Length < 1)
        return ""

    verb := StrLower(Trim(parts[1]))

    switch verb
    {
        case "click", "hold", "move":
            if (parts.Length < 3)
                return ""
            x := 0, y := 0
            try x := Integer(Trim(parts[2]))
            catch
                return ""
            try y := Integer(Trim(parts[3]))
            catch
                return ""
            return { type: verb, x: x, y: y }

        case "send":
            if (parts.Length < 2)
                return ""
            key := ""
            Loop parts.Length - 1
                key .= (A_Index = 1 ? "" : " ") . parts[A_Index + 1]
            return { type: "send", key: key }

        case "equip":
            if (parts.Length < 2)
                return ""
            slot := Trim(parts[2])
            return { type: "send", key: slot }

        case "sleep", "wait":
            if (parts.Length < 2)
                return ""
            ms := 0
            try ms := Integer(Trim(parts[2]))
            catch
                return ""
            return { type: "sleep", ms: ms }

        case "release":
            return { type: "release" }
    }

    return ""
}

SaveAttackSequencesFromGui(text)
{
    global AttackSequencesFile
    try FileDelete(AttackSequencesFile)
    try FileAppend(text, AttackSequencesFile)
    LoadAttackSequences()
}

; ============================================================
; ALT JOINER
;
; Fast alt-switching: saves usernames, joins with one click.
; Requires a captured "username field" coordinate (Tools > Alt Joiner >
; Capture Username Field) and a captured Join button (already captured
; via Tools > Capture Join Click).
; ============================================================

LoadAlts()
{
    global AltNames, ConfigFile
    AltNames := []
    if !FileExist(ConfigFile)
        return
    i := 1
    Loop
    {
        v := ""
        try v := IniRead(ConfigFile, "Alts", "Alt" . i, "")
        catch
            break
        if (v = "")
            break
        AltNames.Push(v)
        i += 1
    }
}

SaveAlts()
{
    global AltNames, ConfigFile
    Loop 200
    {
        try IniDelete(ConfigFile, "Alts", "Alt" . A_Index)
        catch
        {
        }
    }
    for i, name in AltNames
    {
        try IniWrite(name, ConfigFile, "Alts", "Alt" . i)
    }
}

CaptureUsernameField(*)
{
    global UsernameFieldX, UsernameFieldY, UsernameFieldConfigured
    global UsernameFieldRelX, UsernameFieldRelY

    MsgBox(
        "Click OK, then click the USERNAME FIELD in your Roblox Account Manager."
        . "`n(the box where you'd normally type the alt's username).",
        "Capture Username Field", "Iconi")

    KeyWait("LButton")
    Loop
    {
        if GetKeyState("LButton", "P")
            break
        Sleep(20)
    }

    MouseGetPos(&UsernameFieldX, &UsernameFieldY)

    browserHwnd := FindJoinWindow()
    if browserHwnd
    {
        try
        {
            WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
            UsernameFieldRelX := UsernameFieldX - bx
            UsernameFieldRelY := UsernameFieldY - by
        }
        catch
        {
            UsernameFieldRelX := -1
            UsernameFieldRelY := -1
        }
    }
    KeyWait("LButton")
    UsernameFieldConfigured := true
    SaveJoinSettings()
    UpdateOCRResult("Username field captured: X=" . UsernameFieldX . " Y=" . UsernameFieldY)
}

CaptureFollowButton(*)
{
    global FollowButtonX, FollowButtonY, FollowButtonRelX, FollowButtonRelY, FollowButtonConfigured

    MsgBox(
        "Click OK, then click the FOLLOW button in your Roblox Account Manager.`n`n"
        . "The script will save that screen coordinate.",
        "Set Follow Button", "Iconi")

    KeyWait("LButton")
    Loop
    {
        if GetKeyState("LButton", "P")
            break
        Sleep(20)
    }

    MouseGetPos(&FollowButtonX, &FollowButtonY)
    browserHwnd := FindJoinWindow()
    if browserHwnd
    {
        try
        {
            WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . browserHwnd)
            FollowButtonRelX := FollowButtonX - bx
            FollowButtonRelY := FollowButtonY - by
        }
        catch
        {
            FollowButtonRelX := -1
            FollowButtonRelY := -1
        }
    }
    KeyWait("LButton")
    FollowButtonConfigured := true
    SaveJoinSettings()
    UpdateOCRResult("Follow button captured: X=" . FollowButtonX . " Y=" . FollowButtonY)
}

GetListViewSelectedRow(lv)
{
    ; LVM_GETNEXTITEM = 0x100C, start from -1, LVNI_SELECTED = 0x0002
    idx := SendMessage(0x100C, -1, 0x0002, lv.Hwnd)
    if (idx = -1 || idx = "")
        return 0
    return idx + 1
}

ClearListViewSelection(lv)
{
    static LVM_SETITEMSTATE := 0x102B
    static LVIS_SELECTED    := 0x0002
    static LVIS_FOCUSED     := 0x0001

    ; LVITEM struct: state at offset 12, stateMask at offset 16
    buf := Buffer(64, 0)
    NumPut("Int",  -1, buf, 4)                       ; iItem = -1 (all items)
    NumPut("UInt",  0, buf, 12)                      ; state = 0 (clear)
    NumPut("UInt", LVIS_SELECTED | LVIS_FOCUSED, buf, 16)
    SendMessage(LVM_SETITEMSTATE, 0, buf.Ptr, lv.Hwnd)
}

AddAltFromEdit(newEdit, lv, *)
{
    global AltNames
    name := Trim(newEdit.Text)
    if (name = "")
        return
    AltNames.Push(name)
    SaveAlts()
    newEdit.Text := ""
    RefreshAltList(lv)
}

FollowAlt(username)
{
    global UsernameFieldRelX, UsernameFieldRelY, UsernameFieldConfigured
    global FollowButtonRelX, FollowButtonRelY, FollowButtonConfigured

    if !UsernameFieldConfigured || UsernameFieldRelX < 0 || UsernameFieldRelY < 0
    {
        UpdateOCRResult("Alt Joiner: username field not captured.")
        return false
    }
    if !FollowButtonConfigured || FollowButtonRelX < 0 || FollowButtonRelY < 0
    {
        UpdateOCRResult("Alt Joiner: Follow button not captured.")
        return false
    }

    hwnd := FindJoinWindow()
    if !hwnd
    {
        UpdateOCRResult("Alt Joiner: join window not found.")
        return false
    }

    try
    {
        WinActivate("ahk_id " . hwnd)
        if !WinWaitActive("ahk_id " . hwnd, , 1.5)
            return false
    }
    catch
        return false

    Sleep(250)
    WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . hwnd)

    fieldX := bx + UsernameFieldRelX
    fieldY := by + UsernameFieldRelY

    ; 1) Click into the field to focus it.
    Click(fieldX, fieldY, 1, "Left")
    Sleep(350)

    ; 2) Select-all then delete, so the field is empty first.
    Send("^a")
    Sleep(100)
    Send("{Delete}")
    Sleep(100)

    ; 3) Type the username one character at a time. RAM's field rejects
    ;    ControlSetText / WM_SETTEXT / fast keystrokes; only per-key
    ;    input at human speed gets through its per-keystroke validation.
    for ch in StrSplit(username)
    {
        Send(ch)
        Sleep(100)
    }

    ; 4) Give RAM a moment to run its lookup before we click Follow.
    Sleep(30)

    ; 5) Click Follow.
    Click(bx + FollowButtonRelX, by + FollowButtonRelY, 1, "Left")

    UpdateOCRResult("Alt Joiner: followed '" . username . "'.")
    return true
}

FollowSelectedAlt(lv)
{
    global AltNames
    row := GetListViewSelectedRow(lv)
    if (row < 1 || row > AltNames.Length)
        return
    FollowAlt(AltNames[row])
}

ShowAltJoiner(*)
{
    global AltNames

    LoadAlts()

    altGui := Gui("+AlwaysOnTop -MaximizeBox", "Alt Joiner")
    altGui.BackColor := "20242A"
    altGui.SetFont("s9 cFFFFFF", "Segoe UI")

    altGui.AddText("x14 y12 w440 h20", "Double-click an alt to Follow it (which rejoins its own server):")

    lv := altGui.AddListView(
        "x14 y38 w440 h300 Grid -Multi cFFFFFF Background20242A",
        ["#", "Username"])
    lv.SetFont("s9 cFFFFFF", "Segoe UI")
    lv.ModifyCol(1, 40)
    lv.ModifyCol(2, 380)

    RefreshAltList(lv)

    ; Double-click = Follow. This is the primary action.
    lv.OnEvent("DoubleClick", (*) => FollowSelectedAlt(lv))

    altGui.AddText("x14 y348 w60 h22", "New alt:")
    newEdit := altGui.AddEdit("x78 y345 w210 h26")
    addBtn    := altGui.AddButton("x294 y344 w80 h28", "Add")
    removeBtn := altGui.AddButton("x380 y344 w74 h28", "Remove")

    capBtn     := altGui.AddButton("x14 y382 w200 h30", "Capture Username Field")
    capFllBtn  := altGui.AddButton("x220 y382 w120 h30", "Capture Follow Click")
    capWinBtn  := altGui.AddButton("x346 y382 w108 h30", "Capture Window")

    addBtn.OnEvent("Click", AddAltFromEdit.Bind(newEdit, lv))
    removeBtn.OnEvent("Click", (*) => RemoveSelectedAlt(lv))

    capBtn.OnEvent("Click",    (*) => CaptureUsernameField())
    capFllBtn.OnEvent("Click", (*) => CaptureFollowButton())
    capWinBtn.OnEvent("Click", (*) => CaptureJoinWindow())

    altGui.Show("w470 h430")
}

RefreshAltList(lv)
{
    global AltNames
    lv.Delete()
    for i, name in AltNames
        lv.Add(, i, name)
}

RemoveSelectedAlt(lv)
{
    global AltNames
    row := GetListViewSelectedRow(lv)
    if (row < 1 || row > AltNames.Length)
    {
        MsgBox("Select an alt to remove first.", "Alt Joiner", "Iconi")
        return
    }
    AltNames.RemoveAt(row)
    SaveAlts()
    RefreshAltList(lv)
}

UpdateJoinSettingsText()
{
    global JoinSettingsText, JoinWindowExe, JoinWindowTitle
    global JoinButtonX, JoinButtonY
    global JoinButtonRelX, JoinButtonRelY, SafeClickX, SafeClickY, SafeClickRelX, SafeClickRelY, SafeClickConfigured
    if !IsObject(JoinSettingsText)
        return

    label := JoinWindowExe
    if JoinWindowTitle != ""
        label .= " | " . JoinWindowTitle
    JoinSettingsText.Text :=
        "Window: " . label
        . " | Join: " . (JoinButtonRelX >= 0 ? "rel " . JoinButtonRelX . "," . JoinButtonRelY : JoinButtonX . "," . JoinButtonY)
        . " | safe: " . (SafeClickConfigured ? (SafeClickRelX >= 0 ? "rel " . SafeClickRelX . "," . SafeClickRelY : SafeClickX . "," . SafeClickY) : "NOT SET")
    SaveJoinSettings()
}

ResumeAfterBoss(*)
{
    global MacroRunning, MacroPaused, TargetBiomeActive
    global TargetBiomeKeyword, TargetBiomeName, TargetBiomeStartedTick, TargetChatBaseline
    global MacroMode
    global PostResumeGraceMs

    if !MacroRunning
    {
        UpdateOCRResult("Macro is not running. Start a hop mode first.")
        return
    }

    TargetBiomeActive := false
    TargetBiomeKeyword := ""
    TargetBiomeName := ""
    TargetBiomeStartedTick := 0
    TargetChatBaseline := Map()

    if !ActivateRoblox()
    {
        UpdateStatus("WAITING FOR ROBLOX", "Resume when joined")
        UpdateOCRResult("Boss was handled. Rejoin Roblox on this computer, then press the Resume hotkey/button.")
        return
    }

    ; Clear the Roblox chat log so no stale boss-spawn/biome-arrival/defeat
    ; text is left on screen to immediately re-trigger a false detection
    ; the moment scanning resumes. This is what actually makes auto-resume
    ; reliable - without it, the old messages are still visible and get
    ; re-read as if they just happened.
    ClearRobloxChat()

    FocusRobloxChat()
    UpdateStatus("RUNNING", MacroMode)
    UpdateOCRResult("Resumed after wanted boss. Chat cleared, giving the screen a moment to settle before scanning again.")

    ; Small grace period as a second layer of safety in case the boss
    ; health bar (a sprite, not chat text - "/clear" doesn't touch it)
    ; takes a moment to visually disappear after the real kill.
    Sleep(PostResumeGraceMs)
    UpdateOCRResult("Resumed after wanted boss. Returning to biome hopping.")
}

; Opens Roblox chat, clears any text already in the box, then sends
; "/clear" to wipe the visible chat log.
;
; Key insight: "/clear" is only a command if "/" is the FIRST character
; in an otherwise-empty box. If any stray character (like a leftover "/"
; from KeepRobloxChatFocused) is in the box, Roblox treats the whole
; line as a literal message - which is why we used to see "/clear/"
; appearing in the chat log instead of the chat being cleared.
;
; So: force the input closed first, then type the full command fresh.
ClearRobloxChat()
{
    if !ActivateRoblox()
        return false

    Sleep(80)

    ; Close any currently-open chat input. This puts us in a known state:
    ; input is closed, box is empty. Escape is Roblox chat's standard
    ; "close the input" key.
    Send("{Escape}")
    Sleep(150)

    ; Type the command as one literal string. Roblox sees the leading "/"
    ; and opens the chat in command mode with a fresh, empty input.
    SendText("/clear")
    Sleep(150)
    Send("{Enter}")
    Sleep(400)

    ; If for any reason the input is still open with content after Enter,
    ; Escape again so we don't leave a stray character behind for the
    ; next OCR pass to read.
    Send("{Escape}")
    Sleep(80)

    return true
}

; ============================================================
; PAUSE / RESUME
; ============================================================

TogglePause(*)
{
    global MacroRunning
    global MacroPaused
    global MacroMode
    global PauseButton
    global OrengaAlertActive

    ; Always allow toggling, even if the macro isn't running.
    ; This lets you clear an Orenga alert that was triggered while
    ; sitting idle, without having to restart the whole script.
    MacroPaused := !MacroPaused

    if MacroPaused
    {
        StopAutoAttack()
        try PauseButton.Text := "RESUME"
        UpdateStatus("PAUSED", MacroRunning ? MacroMode : "None")
    }
    else
    {
        ; Clearing the pause also clears the Orenga alert flag so a fresh
        ; spawn can fire a fresh ping later.
        OrengaAlertActive := false

        try PauseButton.Text := "PAUSE"
        if MacroRunning
            UpdateStatus("RUNNING", MacroMode)
        else
            UpdateStatus("IDLE", "None")
    }
}

; ============================================================
; STOP
; ============================================================

StopMacro(*)
{
    SetTimer(WatchdogTick, 0)
    SetTimer(AntiAfkTick, 0)
    StopAutoAttack()
    global MacroRunning, MacroPaused, MacroMode
    global TargetBiomeActive, TargetBiomeKeyword, TargetBiomeName
    global TargetBiomeStartedTick, TargetChatBaseline
    global BadBiomeSeenCount, BadBiomeSeenId
    global OrengaAlertActive
    global PauseButton

    MacroRunning := false
    MacroPaused := false
    MacroMode := ""
    TargetBiomeActive := false
    TargetBiomeKeyword := ""
    TargetBiomeName := ""
    TargetBiomeStartedTick := 0
    TargetChatBaseline := Map()
    BadBiomeSeenCount := 0
    BadBiomeSeenId := ""

    PauseButton.Text := "PAUSE"
    UpdateStatus("STOPPED", "None")
}

; ============================================================
; STATUS DISPLAY
; ============================================================

UpdateStatus(status, mode)
{
    global StatusText
    global ModeText
    global MacroMode

    if !IsObject(StatusText)
        return

    ; For biome-related statuses the second argument carries the biome
    ; name. Show it on the second line. For all other statuses the
    ; second argument is the macro mode, shown as "Mode: X".
    if ((status = "TARGET BIOME" || status = "BAD BIOME") && mode != "")
    {
        StatusText.Text := status
        ModeText.Text := mode
    }
    else
    {
        StatusText.Text := status
        ModeText.Text := "Mode: " . mode
    }

    switch status
    {
        case "RUNNING":
            StatusText.SetFont("c55D6BE")
        case "PAUSED":
            StatusText.SetFont("cF2C94C")
        case "CALIBRATING":
            StatusText.SetFont("cF2C94C")
        case "STOPPED", "REJOIN FAILED", "TARGET TIMEOUT":
            StatusText.SetFont("cEB5757")
        case "TARGET BIOME", "BOSS FOUND - STAYING", "REJOINING":
            StatusText.SetFont("cF2C94C")
        case "ALREADY RUNNING":
            StatusText.SetFont("cF2C94C")
        default:
            StatusText.SetFont("c55D6BE")
    }
}

; ============================================================
; OCR RESULT
; ============================================================

UpdateOCRResult(text)
{
    global OCRResultEdit

    if !IsObject(OCRResultEdit)
        return

    OCRResultEdit.Value := text
}

; ============================================================
; OCR REGION DISPLAY
; ============================================================

UpdateRegionDisplay()
{
    global RegionText
    global OCR_X
    global OCR_Y
    global OCR_WIDTH
    global OCR_HEIGHT
    global OCR_Calibrated

    label := OCR_Calibrated ? "Calibrated" : "Default"

    RegionText.Text :=
        "Current OCR Region:`n"
        . "X=" . OCR_X
        . "  Y=" . OCR_Y
        . "  Width=" . OCR_WIDTH
        . "  Height=" . OCR_HEIGHT
        . "  (" . label . ")"
}

; ============================================================
; CALIBRATE OCR
; ============================================================
;
; The GUI button starts calibration.
;
; 1. Screen dims.
; 2. Click and hold anywhere.
; 3. Drag.
; 4. Release.
; 5. Coordinates are saved.
; 6. Existing macro resumes if it was running.
;
; ============================================================

CalibrateOCR(*)
{
    global Calibrating
    global CalibrationStarted
    global CalibrationOverlay
    global CalibrationInfo
    global CalibrationInstruction
    global SelectionTop
    global SelectionBottom
    global SelectionLeft
    global SelectionRight
    global SelectionFill
    global MacroRunning
    global MacroPaused

    if Calibrating
        return

    ; Pause running macro automatically.
    if MacroRunning && !MacroPaused
        MacroPaused := true

    Calibrating := true
    CalibrationStarted := false

    UpdateStatus(
        "CALIBRATING",
        MacroRunning ? MacroMode : "None"
    )

    ; Full-screen dimmer. It is layered + transparent so it
    ; does not prevent the physical mouse from being read.
    CalibrationOverlay := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x20",
        "OCR Calibration Overlay"
    )
    CalibrationOverlay.BackColor := "000000"
    CalibrationOverlay.Show(
        "NA x0 y0 w" . A_ScreenWidth . " h" . A_ScreenHeight
    )
    WinSetTransparent(150, CalibrationOverlay)

    ; One translucent fill plus four bright borders makes the
    ; selection much easier to see than four tiny border windows.
    SelectionFill := CreateSelectionFill()
    SelectionTop := CreateSelectionBorder()
    SelectionBottom := CreateSelectionBorder()
    SelectionLeft := CreateSelectionBorder()
    SelectionRight := CreateSelectionBorder()

    ; Floating instructions. It is deliberately placed away from
    ; the center and is hidden as soon as the user starts dragging.
    CalibrationInfo := Gui(
        "+AlwaysOnTop +Caption -MinimizeBox -MaximizeBox",
        "OCR Calibration"
    )
    CalibrationInfo.BackColor := "20242A"
    CalibrationInfo.SetFont("s10 cFFFFFF Bold", "Segoe UI")
    CalibrationInfo.AddText("x16 y10 w488 h22", "OCR CALIBRATION")

    CalibrationInfo.SetFont("s9 cC8D0DA", "Segoe UI")
    CalibrationInstruction := CalibrationInfo.AddText(
        "x16 y37 w488 h42",
        "Release the mouse button first, then click and drag a box around the biome text."
    )

    cancelButton := CalibrationInfo.AddButton(
        "x16 y86 w488 h34",
        "CANCEL CALIBRATION"
    )
    cancelButton.OnEvent("Click", CancelCalibration)

    infoX := Max(15, (A_ScreenWidth - 520) // 2)
    infoY := Max(15, A_ScreenHeight - 185)

    CalibrationInfo.Show(
        "x" . infoX . " y" . infoY . " w520 h135"
    )

    ; IMPORTANT:
    ; The Calibrate button's own mouse click is still physically held
    ; when this function is called. Wait for that click to be released
    ; before allowing calibration to begin, otherwise the button click
    ; itself becomes the selection's starting point.
    KeyWait("LButton")

    if !Calibrating
        return

    SetTimer(UpdateCalibration, 10)
}


; ============================================================
; CALIBRATION UPDATE
; ============================================================

UpdateCalibration()
{
    global Calibrating
    global CalibrationStarted
    global CalibrationStartX
    global CalibrationStartY
    global CalibrationInstruction
    global CalibrationInfo
    global CalibrationOverlay
    global SelectionTop
    global SelectionBottom
    global SelectionLeft
    global SelectionRight

    if !Calibrating
    {
        SetTimer(
            UpdateCalibration,
            0
        )
        return
    }

    ; --------------------------------------------------------
    ; Wait for mouse button to be pressed.
    ; --------------------------------------------------------

    if !CalibrationStarted
    {
        if GetKeyState("LButton", "P")
        {
            MouseGetPos(
                &CalibrationStartX,
                &CalibrationStartY
            )

            CalibrationStarted := true

            ; Hide the floating instructions while dragging so they
            ; can never cover the area being selected.
            try CalibrationInfo.Hide()

            CalibrationInstruction.Text :=
                "Selection started.`n"
                . "Drag to the opposite corner and release."
        }

        return
    }

    ; --------------------------------------------------------
    ; Current cursor position.
    ; --------------------------------------------------------

    MouseGetPos(
        &currentX,
        &currentY
    )

    x := Min(
        CalibrationStartX,
        currentX
    )

    y := Min(
        CalibrationStartY,
        currentY
    )

    width := Abs(
        currentX - CalibrationStartX
    )

    height := Abs(
        currentY - CalibrationStartY
    )

    if width < 1
        width := 1

    if height < 1
        height := 1

    UpdateSelectionFill(
        SelectionFill,
        x,
        y,
        width,
        height
    )

    UpdateSelectionBorders(
        SelectionTop,
        SelectionBottom,
        SelectionLeft,
        SelectionRight,
        x,
        y,
        width,
        height,
        3
    )

    CalibrationInstruction.Text :=
        "X: " . x
        . "    Y: " . y
        . "    Width: " . width
        . "    Height: " . height
        . "`n`nRelease the mouse to confirm."

    ; --------------------------------------------------------
    ; Mouse released = save.
    ; --------------------------------------------------------

    if !GetKeyState("LButton", "P")
    {
        FinalizeCalibration(
            x,
            y,
            width,
            height
        )
    }
}

; ============================================================
; FINALIZE CALIBRATION
; ============================================================

FinalizeCalibration(x, y, width, height)
{
    global Calibrating
    global CalibrationStarted
    global MacroRunning
    global MacroPaused
    global OCR_X
    global OCR_Y
    global OCR_WIDTH
    global OCR_HEIGHT
    global OCR_Calibrated

    if !Calibrating
        return

    if (width < 5 || height < 5)
    {
        CancelCalibration()

        MsgBox(
            "The selected area is too small. Please calibrate again.",
            "OCR Calibration",
            "Icon!"
        )

        return
    }

    OCR_X := x
    OCR_Y := y
    OCR_WIDTH := width
    OCR_HEIGHT := height
    OCR_Calibrated := true

    FinishCalibrationUI()

    Calibrating := false
    CalibrationStarted := false

    ; Resume macro if it was paused for calibration.
    if MacroRunning
        MacroPaused := false

    UpdateRegionDisplay()

    if MacroRunning
        UpdateStatus("RUNNING", MacroMode)
    else
        UpdateStatus("IDLE", "None")

    MsgBox(
        "OCR region calibrated successfully.`n`n"
        . "X: " . OCR_X . "`n"
        . "Y: " . OCR_Y . "`n"
        . "Width: " . OCR_WIDTH . "`n"
        . "Height: " . OCR_HEIGHT,
        "OCR Calibration Complete",
        "Iconi"
    )
}

; ============================================================
; CANCEL CALIBRATION
; ============================================================

CancelCalibration(*)
{
    global Calibrating
    global CalibrationStarted
    global MacroRunning
    global MacroPaused

    if !Calibrating
        return

    FinishCalibrationUI()

    Calibrating := false
    CalibrationStarted := false

    ; Resume the macro if calibration temporarily paused it.
    if MacroRunning
        MacroPaused := false

    if MacroRunning
        UpdateStatus("RUNNING", MacroMode)
    else
        UpdateStatus("IDLE", "None")
}

; ============================================================
; DESTROY CALIBRATION UI
; ============================================================

FinishCalibrationUI()
{
    global CalibrationOverlay
    global CalibrationInfo
    global CalibrationInstruction
    global SelectionTop
    global SelectionBottom
    global SelectionLeft
    global SelectionRight
    global SelectionFill

    SetTimer(
        UpdateCalibration,
        0
    )

    try CalibrationOverlay.Destroy()
    try CalibrationInfo.Destroy()
    try SelectionTop.Destroy()
    try SelectionBottom.Destroy()
    try SelectionLeft.Destroy()
    try SelectionRight.Destroy()
    try SelectionFill.Destroy()

    CalibrationOverlay := 0
    CalibrationInfo := 0
    CalibrationInstruction := 0
    SelectionTop := 0
    SelectionBottom := 0
    SelectionLeft := 0
    SelectionRight := 0
}

; ============================================================
; SELECTION FILL
; ============================================================

CreateSelectionFill()
{
    fill := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x20"
    )

    fill.BackColor := "00BFFF"
    fill.Show("NA x0 y0 w1 h1")
    WinSetTransparent(45, fill)

    return fill
}

UpdateSelectionFill(fill, x, y, width, height)
{
    try
        fill.Show(
            "NA x" . x
            . " y" . y
            . " w" . width
            . " h" . height
        )
}

; ============================================================
; SELECTION BORDER
; ============================================================

CreateSelectionBorder()
{
    border := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x20"
    )

    border.BackColor := "00D9FF"
    border.Show("NA x0 y0 w1 h1")
    WinSetTransparent(235, border)

    return border
}

; ============================================================
; UPDATE SELECTION BORDER
; ============================================================

UpdateSelectionBorders(
    top,
    bottom,
    left,
    right,
    x,
    y,
    width,
    height,
    thickness
)
{
    top.Show(
        "NA x" . x
        . " y" . y
        . " w" . width
        . " h" . thickness
    )

    bottom.Show(
        "NA x" . x
        . " y" . (y + height - thickness)
        . " w" . width
        . " h" . thickness
    )

    left.Show(
        "NA x" . x
        . " y" . y
        . " w" . thickness
        . " h" . height
    )

    right.Show(
        "NA x" . (x + width - thickness)
        . " y" . y
        . " w" . thickness
        . " h" . height
    )
}

; ============================================================
; RESET OCR
; ============================================================

ResetOCR(*)
{
    global OCR_X
    global OCR_Y
    global OCR_WIDTH
    global OCR_HEIGHT
    global OCR_Calibrated

    OCR_X := 12
    OCR_Y := 67
    OCR_WIDTH := 461
    OCR_HEIGHT := 285
    OCR_Calibrated := false

    UpdateRegionDisplay()
    UpdateOCRResult(
        "OCR region reset to the original default."
    )

    TrayTip(
        "Biome Hopper",
        "OCR reset to X=12, Y=67, W=461, H=285.",
        2
    )
}

; ============================================================
; TEST OCR
; ============================================================

TestOCR(*)
{
    global OCR_X
    global OCR_Y
    global OCR_WIDTH
    global OCR_HEIGHT

    try
    {
        result := OCR.FromRect(
            OCR_X,
            OCR_Y,
            OCR_WIDTH,
            OCR_HEIGHT,
            {lang: "en-US"}
        )

        if result.Text = ""
        {
            UpdateOCRResult(
                "No text was detected in the selected region."
            )

            MsgBox(
                "OCR completed, but no text was detected.",
                "Test OCR",
                "Icon!"
            )

            return
        }

        UpdateOCRResult(result.Text)

        MsgBox(
            "OCR result:`n`n" . result.Text,
            "Test OCR",
            "Iconi"
        )
    }
    catch Error as err
    {
        UpdateOCRResult(
            "OCR error: " . err.Message
        )

        MsgBox(
            "OCR failed:`n`n" . err.Message,
            "Test OCR",
            "Icon!"
        )
    }
}

; Fires immediately when a wanted BIOME appears in chat, before the boss
; itself has spawned. HandleDetectedBoss() still fires separately later
; once the actual boss is found - this is an earlier, additional ping.
SendBiomeArrivalNotification(biomeKeyword, def)
{
    global PrivateServerLink, LastBiomeNotifyTick, BiomeNotifyCooldownMs

    ; Biomes without a role ID configured don't need arrival pings -
    ; this avoids spamming Discord with "The world has returned to normal"
    ; every few minutes.
    if !IsObject(def) || Trim(def.roleID) = ""
        return

    ; Cooldown: skip if we've pinged about this biome recently.
    nowTick := A_TickCount
    if LastBiomeNotifyTick.Has(def.id)
    {
        if (nowTick - LastBiomeNotifyTick[def.id] < BiomeNotifyCooldownMs)
            return
    }
    LastBiomeNotifyTick[def.id] := nowTick

    if Trim(def.roleID) = ""
        return

    biomeName := def ? def.biomeName : biomeKeyword

    message :=
        "🌟 **Target Biome Arrived: " . biomeName . "**`n"
        . "🔎 Watching for the boss to spawn...`n"
        . "⚠️ Triggered by: **" . biomeKeyword . "**"

    link := Trim(PrivateServerLink)
    if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        message .= "`n" . link

    sent := BroadcastDiscordNotification(message, def ? def.roleID : "", "", biomeKeyword)
    global CommunityAutoStage
    if CommunityAutoStage
        StageCommunityBiomePing(def)

    if sent
        UpdateOCRResult("✅ " . biomeName . " - biome-arrival ping sent.")
}

; Sends a boss-spawn notification. `def` is the biome, `bossObj` is the
; specific boss. If bossObj.notify is false, this is a no-op.
HandleDetectedBoss(biomeDef, bossObj, detectionMethod)
{
    global PrivateServerLink, LastHandledBiomeDef, LastHandledBossObj
    global LastBossNotifyTick, BiomeNotifyCooldownMs

    if !IsObject(bossObj)
        return false

    LastHandledBiomeDef := biomeDef
    LastHandledBossObj  := bossObj

    if !bossObj.notify
        return false

    ; Cooldown per boss
    nowTick := A_TickCount
    if LastBossNotifyTick.Has(bossObj.name)
    {
        if (nowTick - LastBossNotifyTick[bossObj.name] < BiomeNotifyCooldownMs)
            return false
    }
    LastBossNotifyTick[bossObj.name] := nowTick

    bossName := bossObj.name
    roleID   := bossObj.roleID

    notification :=
        "🚨 **" . bossName . " has spawned!**`n"
        . "🌎 **Biome:** " . biomeDef.biomeName . "`n"
        . "🔎 **Detected via:** " . detectionMethod

    link := Trim(PrivateServerLink)
    if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        notification .= "`n" . link
    else
        notification .= "`n⚠️ No private server link configured - set it in the Discord Notifications panel."

    if (roleID = "")
        notification .= "`n⚠️ No role ID configured for this boss."

    sent := BroadcastDiscordNotification(notification, roleID, bossName, biomeDef.id)
    ; Also stage the community message on the clipboard so you can
    ; paste it into the official CRCW Discord without retyping.
    global CommunityAutoStage
    if CommunityAutoStage
        StageCommunityBossPing(bossObj)

    if sent
    {
        UpdateOCRResult(notification . "`n`n✅ Discord notification sent. Staying in biome.")
        UpdateOCRResult("✅ " . bossName . " / " . biomeDef.biomeName . " - notification sent.")
    }
    else
    {
        UpdateOCRResult(notification . "`n`n❌ Discord notification FAILED.")
    }

    return sent
}

DetectOreSpawns(lines)
{
    global OreByKeyword, OreNotifyEnabled, LastOreNotifyTick, BiomeNotifyCooldownMs

    for line in lines
    {
        if !line.isGame
            continue

        low := StrLower(line.text)
        if !InStr(low, "has spawned")
            continue
        if !InStr(low, "in the mines")
            continue

        for kw, oreDef in OreByKeyword
        {
            if !InStr(low, kw)
                continue

            if !OreNotifyEnabled.Has(oreDef.id) || !OreNotifyEnabled[oreDef.id]
                continue

            nowTick := A_TickCount
            if LastOreNotifyTick.Has(oreDef.id)
            {
                if (nowTick - LastOreNotifyTick[oreDef.id] < BiomeNotifyCooldownMs)
                    continue
            }
            LastOreNotifyTick[oreDef.id] := nowTick

            HandleOreDetected(oreDef)
            return   ; one ore per pass
        }
    }
}

HandleOreDetected(oreDef)
{
    global PrivateServerLink, DiscordWebhookURL

    UpdateOCRResult("⛏️ Ore detected: " . oreDef.name)

    if (Trim(DiscordWebhookURL) = ""
    ||  DiscordWebhookURL = "PASTE_NEW_DISCORD_WEBHOOK_HERE")
        return

    msg := "⛏️ **" . oreDef.name . "** has spawned in the mines!"

    link := Trim(PrivateServerLink)
    if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        msg .= "`n" . link

    try SendDiscordWebhook(DiscordWebhookURL, msg, oreDef.roleID)
}

ShowOreSelector(*)
{
    global OreDefs, OreNotifyEnabled, OreSelectorGui

    if IsObject(OreSelectorGui)
    {
        try
        {
            OreSelectorGui.Show()
            WinActivate("ahk_id " . OreSelectorGui.Hwnd)
            return
        }
        catch
            OreSelectorGui := 0
    }

    g := Gui("+AlwaysOnTop -MaximizeBox +Resize", "Select Ores to Notify")
    g.BackColor := "FFFFFF"

    g.SetFont("s10 c000000", "Segoe UI")
    g.AddText("x14 y12 w400 h22", "Tick the ores you want Discord pings for:")

    g.SetFont("s9 c000000", "Segoe UI")
    lv := g.AddListView(
        "x14 y42 w400 h420 Grid -Multi Checked",
        ["Ore"])
    lv.SetFont("s9 c000000", "Segoe UI")
    lv.ModifyCol(1, 380)

   ForceClassicListViewTheme(lv)    

    for def in OreDefs
    {
        checked := OreNotifyEnabled.Has(def.id) && OreNotifyEnabled[def.id]
        lv.Add(checked ? "Check" : "", def.name)
    }

    lv.OnEvent("ItemCheck", (ctrl, rowNum, checked) => SetTimer(ApplyOreCheck.Bind(lv, rowNum, checked), -1))

    ApplyOreCheck(lv, rowNum, checked)
    {
        global OreDefs, OreNotifyEnabled

        if (rowNum < 1 || rowNum > OreDefs.Length)
            return

        def := OreDefs[rowNum]
        OreNotifyEnabled[def.id] := checked
        SaveOreChoice(def.id, checked ? "notify" : "ignore")
    }

    g.SetFont("s9 c000000", "Segoe UI")
    g.AddButton("x14 y476 w180 h32", "Mark Selected NOTIFY").OnEvent("Click",
        (*) => SetSelectedOreStatus(lv, true))
    g.AddButton("x204 y476 w100 h32", "IGNORE").OnEvent("Click",
        (*) => SetSelectedOreStatus(lv, false))
    g.AddButton("x314 y476 w100 h32", "Close").OnEvent("Click",
        (*) => CloseOreSelector())

    g.OnEvent("Close", (*) => CloseOreSelector())
    g.OnEvent("Escape", (*) => CloseOreSelector())

    OreSelectorGui := g
    g.Show("w430 h530")
}

OnOreCheck(lv, rowNum, checked)
{
    global OreDefs, OreNotifyEnabled

    if (rowNum < 1 || rowNum > OreDefs.Length)
        return

    def := OreDefs[rowNum]
    OreNotifyEnabled[def.id] := checked
    SaveOreChoice(def.id, checked ? "notify" : "ignore")
}

SetSelectedOreStatus(lv, notify)
{
    global OreDefs, OreNotifyEnabled

    row := 0
    Loop
    {
        row := SendMessage(0x100C, row, 0x0002, lv.Hwnd)
        if (row = -1 || row = "")
            break
        realRow := row + 1
        if (realRow < 1 || realRow > OreDefs.Length)
            continue
        def := OreDefs[realRow]
        OreNotifyEnabled[def.id] := notify
        SaveOreChoice(def.id, notify ? "notify" : "ignore")
        lv.Modify(realRow, (notify ? "Check" : "-Check") . " -Select -Focus")
    }
}

CloseOreSelector()
{
    global OreSelectorGui
    if IsObject(OreSelectorGui)
    {
        try OreSelectorGui.Destroy()
        catch
        {
        }
        OreSelectorGui := 0
    }
}

; ============================================================
; DISCORD
; ============================================================
; Kept as a thin wrapper around SendDiscordBossNotificationTo so the
; existing TEST PING button keeps working.
SendDiscordBossNotification(bossName, biomeName, messageText, roleID := "")
{
    global DiscordWebhookURL
    return SendDiscordBossNotificationTo(DiscordWebhookURL, messageText, roleID, "Primary")
}

NotifyError(errorText)
{
    global DiscordWebhookURL, PrivateServerLink

    ; Don't ping if the webhook isn't configured yet.
    if (Trim(DiscordWebhookURL) = ""
    ||  DiscordWebhookURL = "PASTE_NEW_DISCORD_WEBHOOK_HERE")
        return

    msg := "⚠️ **BIOME HOPPER ALERT** ⚠️`n`n" . errorText

    ; Add the private server link so you can manually check/join if needed
    link := Trim(PrivateServerLink)
    if (link != "" && link != "PASTE_YOUR_PRIVATE_SERVER_LINK_HERE")
        msg .= "`n`n" . link

    try SendDiscordWebhook(DiscordWebhookURL, msg, "")
}

; Sends one notification to every enabled destination. `def` carries the
; role ID for the primary server; the secondary server still uses its own
; maps for its own role IDs.
; primaryRoleID is the role to ping on the primary server. For a biome
; arrival this is the biome's roleID; for a boss spawn it's the boss's.
BroadcastDiscordNotification(messageText, primaryRoleID, bossKey, biomeKeyword)
{
    global DiscordWebhookURL
    global SecondaryWebhookURL, SecondaryEnabled, SecondaryRoleMap, SecondaryBossRoleMap

    anySent := false

    if SendDiscordBossNotificationTo(DiscordWebhookURL, messageText, primaryRoleID, "Primary")
        anySent := true

    if SecondaryEnabled
    {
        secondaryUrl := Trim(SecondaryWebhookURL)
        if (secondaryUrl != "" && secondaryUrl != "PASTE_SECONDARY_WEBHOOK_HERE")
        {
            secondaryRoleID := ResolveRoleID(SecondaryRoleMap, SecondaryBossRoleMap, bossKey, biomeKeyword)
            if SendDiscordBossNotificationTo(secondaryUrl, messageText, secondaryRoleID, "Secondary")
                anySent := true
        }
    }

    return anySent
}

; Still used for the secondary server, which has its own role-ID maps.
ResolveRoleID(roleMap, bossRoleMap, bossKey, biomeKeyword)
{
    if (bossKey != "" && bossRoleMap.Has(bossKey))
        return bossRoleMap[bossKey]
    if (biomeKeyword != "" && roleMap.Has(biomeKeyword))
        return roleMap[biomeKeyword]
    return ""
}

SendDiscordBossNotificationTo(url, messageText, roleID, label)
{
    url := Trim(url)

    if (url = "" || url = "PASTE_NEW_DISCORD_WEBHOOK_HERE" || url = "PASTE_SECONDARY_WEBHOOK_HERE")
    {
        UpdateOCRResult("❌ " . label . " NOT SENT: webhook URL is not configured.")
        return false
    }

    ; Catch the common mistake of pasting a channel link, invite link, or
    ; some other URL instead of the actual webhook URL. This fails fast
    ; with a clear message instead of a confusing HTTP error later.
    if !(InStr(url, "discord.com/api/webhooks/") || InStr(url, "discordapp.com/api/webhooks/"))
    {
        UpdateOCRResult("❌ " . label . " NOT SENT: that URL doesn't look like a Discord webhook link (should contain /api/webhooks/).")
        return false
    }

    return SendDiscordWebhook(
        url,
        messageText,
        roleID
    )
}

SendDiscordWebhook(url, text, roleID := "")
{
    try
    {
        ; If a role ID is supplied, ensure the actual Discord role mention is
        ; present. This also makes direct tests of SendDiscordWebhook() work
        ; when the caller passes only the numeric role ID.
        if roleID != "" && !InStr(text, "<@&" . roleID . ">")
            text := "<@&" . roleID . "> " . text

        ; Escape characters required by JSON.
        cleanText := StrReplace(text, "\", "\\")
        cleanText := StrReplace(cleanText, '"', '\"')
        cleanText := StrReplace(cleanText, "`r", "")
        cleanText := StrReplace(cleanText, "`n", "\n")
        cleanText := StrReplace(cleanText, "`t", "\t")

        allowedRolesJSON := "[]"
        if roleID != ""
            allowedRolesJSON := '["' . roleID . '"]'

        payload :=
            '{"content":"' . cleanText . '",'
            . '"allowed_mentions":{"roles":' . allowedRolesJSON . '}}'

        ; --------------------------------------------------------
        ; CRITICAL FIX: send the payload as real UTF-8 bytes.
        ;
        ; WinHttpRequest.Send() converts a plain AHK string body using the
        ; Windows SYSTEM CODEPAGE, not UTF-8. Because these messages contain
        ; emoji (🚨 🌎 🔎 etc.), that silently corrupts the JSON on most
        ; Windows installs, and Discord either rejects it (HTTP 400) or the
        ; request effectively goes nowhere. Routing the text through an
        ; ADODB.Stream forces a correct UTF-8 byte body every time,
        ; regardless of the system locale.
        ; --------------------------------------------------------
        stream := ComObject("ADODB.Stream")
        stream.Type := 2            ; text
        stream.Charset := "utf-8"
        stream.Open()
        stream.WriteText(payload)
        stream.Position := 0
        stream.Type := 1            ; binary
        stream.Position := 3        ; skip the UTF-8 BOM ADODB writes
        utf8Body := stream.Read()
        stream.Close()

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", url, false)

        ; Force TLS 1.2. On some Windows/WinHTTP configurations the default
        ; negotiated protocol is older than what Discord's servers accept,
        ; which fails the connection before it even gets to send data.
        try whr.Option[9] := 0x00000800  ; WinHttpRequestOption_SecureProtocols = TLS 1.2

        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.Send(utf8Body)

        if (whr.Status < 200 || whr.Status >= 300)
        {
            UpdateOCRResult(
                "❌ HTTP " . whr.Status . " from Discord.`n"
                . whr.ResponseText
            )
            return false
        }

        return true
    }
    catch Error as err
    {
        UpdateOCRResult("❌ ERROR: " . err.Message)
        return false
    }
}

ApplyHotkeys()
{
    global PauseHotkey, StopHotkey, ExitHotkey, StartTrueHotkey, StartModifiedHotkey
    static oldPause := "", oldStop := "", oldExit := "", oldTrue := "", oldModified := ""

    ; Unregister old hotkeys. Use the documented two-argument Off form and
    ; isolate failures so one bad entry cannot break every other control.
    SafeDisableHotkey(oldPause)
    SafeDisableHotkey(oldStop)
    SafeDisableHotkey(oldExit)
    SafeDisableHotkey(oldTrue)
    SafeDisableHotkey(oldModified)

    errors := ""
    errors .= SafeEnableHotkey(PauseHotkey, TogglePause, "Pause")
    errors .= SafeEnableHotkey(StopHotkey, StopMacro, "Stop")
    errors .= SafeEnableHotkey(ExitHotkey, ExitProgram, "Exit")
    errors .= SafeEnableHotkey(StartTrueHotkey, StartTrue, "True Hop")
    errors .= SafeEnableHotkey(StartModifiedHotkey, ManualHop, "Manual Hop")

    oldPause := PauseHotkey
    oldStop := StopHotkey
    oldExit := ExitHotkey
    oldTrue := StartTrueHotkey
    oldModified := StartModifiedHotkey

    if errors != ""
        throw Error("Invalid hotkey setting(s):`n" . errors)
}

SafeDisableHotkey(keyName)
{
    if Trim(keyName) = ""
        return
    try
        Hotkey(keyName, "Off")
    catch
    {
        ; Ignore stale/invalid previous values. New values are validated below.
    }
}

SafeEnableHotkey(keyName, callback, label)
{
    keyName := Trim(keyName)
    if keyName = ""
        return label . ": blank`n"

    try
    {
        Hotkey(keyName, callback, "On")
        return ""
    }
    catch Error as err
    {
        return label . " (" . keyName . "): " . err.Message . "`n"
    }
}

; ============================================================
; EXIT
; ============================================================

ExitProgram(*)
{
    SetTimer(WatchdogTick, 0)
    SetTimer(AntiAfkTick, 0)
    StopAutoAttack()
    global MacroRunning
    global MacroPaused
    global TargetBiomeActive

    MacroRunning := false
    MacroPaused := false

    try FinishCalibrationUI()

    ExitApp()
}

; OTHER LOL

InjectChatLine(text, durationMs := 3000)
{
    global InjectedLines
    InjectedLines.Push({ text: text, expiresAtTick: A_TickCount + durationMs })
}

ForceResume()
{
    global TargetBiomeActive, TargetBiomeDef, TargetBiomeKeyword, TargetBiomeName
    global TargetPingedBosses, TargetBiomeStartedTick, TargetChatBaseline, MacroMode

    if !TargetBiomeActive
    {
        UpdateOCRResult("Force Resume: not currently in a target biome.")
        return
    }

    TargetBiomeActive      := false
    TargetBiomeKeyword     := ""
    TargetBiomeName        := ""
    TargetBiomeDef         := ""
    TargetPingedBosses     := Map()
    TargetBiomeStartedTick := 0
    TargetChatBaseline     := Map()

    ClearRobloxChat()
    UpdateStatus("RUNNING", MacroMode)
    UpdateOCRResult("Force Resume: target biome cleared, resuming scan.")
}

; ============================================================
; LUCK CALCULATOR
;
; Two independent rows: LOOT (items) and BIOME (spawn chance).
; Each row has its own base 1/N and its own multiplier.
; Multipliers persist to INI.
; ============================================================

ShowLuckCalculator(*)
{
    global LuckCalcGui, ConfigFile

    if IsObject(LuckCalcGui)
    {
        try
        {
            LuckCalcGui.Show()
            WinActivate("ahk_id " . LuckCalcGui.Hwnd)
            return
        }
        catch
            LuckCalcGui := 0
    }

    lootLuckDefault  := "1.5"
    biomeLuckDefault := "1.25"
    try
    {
        v := IniRead(ConfigFile, "Luck", "LootLuck", "")
        if (Trim(v) != "")
            lootLuckDefault := v
    }
    try
    {
        v := IniRead(ConfigFile, "Luck", "BiomeLuck", "")
        if (Trim(v) != "")
            biomeLuckDefault := v
    }

    g := Gui("+AlwaysOnTop -MaximizeBox", "Luck Calculator")
    g.BackColor := "20242A"

    g.SetFont("s10 cFFFFFF Bold", "Segoe UI")
    g.AddText("x14 y12 w440 h20", "LOOT (items)")
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x14 y38 w90 h20", "Base 1/N:")
    g.AddText("x116 y38 w100 h20", "Loot Luck:")
    g.AddText("x240 y38 w220 h20", "Result")
    g.SetFont("s10 c000000", "Segoe UI")
    lootBaseEdit  := g.AddEdit("x14 y60 w90 h28", "25")
    lootLuckEdit  := g.AddEdit("x116 y60 w100 h28", lootLuckDefault)
    g.SetFont("s11 c55D6BE Bold", "Segoe UI")
    lootResult := g.AddText("x240 y62 w220 h26", "")

    g.SetFont("s10 cFFFFFF Bold", "Segoe UI")
    g.AddText("x14 y110 w440 h20", "BIOME (spawn chance)")
    g.SetFont("s9 cFFFFFF", "Segoe UI")
    g.AddText("x14 y136 w90 h20", "Base 1/N:")
    g.AddText("x116 y136 w100 h20", "Biome Luck:")
    g.AddText("x240 y136 w220 h20", "Result")
    g.SetFont("s10 c000000", "Segoe UI")
    biomeBaseEdit := g.AddEdit("x14 y158 w90 h28", "25")
    biomeLuckEdit := g.AddEdit("x116 y158 w100 h28", biomeLuckDefault)
    g.SetFont("s11 c55D6BE Bold", "Segoe UI")
    biomeResult := g.AddText("x240 y160 w220 h26", "")

    g.SetFont("s8 c9AA4B2", "Segoe UI")
    g.AddText("x14 y200 w440 h40",
        "Base 1/N is the denominator (25 for 1/25). Both luck values"
        . " are saved to disk when you close the window or copy.")

    g.SetFont("s9 cFFFFFF", "Segoe UI")
    copyBtn  := g.AddButton("x14 y250 w210 h30", "Copy Results")
    closeBtn := g.AddButton("x234 y250 w220 h30", "Close")

    update := (*) => UpdateLuckResults(lootBaseEdit, lootLuckEdit, lootResult,
                                       biomeBaseEdit, biomeLuckEdit, biomeResult)
    lootBaseEdit.OnEvent("Change", update)
    lootLuckEdit.OnEvent("Change", update)
    biomeBaseEdit.OnEvent("Change", update)
    biomeLuckEdit.OnEvent("Change", update)

    copyBtn.OnEvent("Click", LuckCopyResults.Bind(lootLuckEdit, biomeLuckEdit, lootResult, biomeResult))
    closeBtn.OnEvent("Click", LuckSaveAndClose.Bind(lootLuckEdit, biomeLuckEdit))
    g.OnEvent("Close",  LuckSaveAndClose.Bind(lootLuckEdit, biomeLuckEdit))
    g.OnEvent("Escape", LuckSaveAndClose.Bind(lootLuckEdit, biomeLuckEdit))

    LuckCalcGui := g
    update()
    g.Show("w470 h300")
}

CloseLuckCalculator()
{
    global LuckCalcGui
    if IsObject(LuckCalcGui)
    {
        try LuckCalcGui.Destroy()
        catch
        {
        }
        LuckCalcGui := 0
    }
}

UpdateLuckResults(lootBaseEdit, lootLuckEdit, lootResult,
                  biomeBaseEdit, biomeLuckEdit, biomeResult)
{
    lootResult.Text  := ComputeLuckString(lootBaseEdit, lootLuckEdit)
    biomeResult.Text := ComputeLuckString(biomeBaseEdit, biomeLuckEdit)
}

ComputeLuckString(baseEdit, luckEdit)
{
    baseN := 0
    try baseN := Round(Float(Trim(baseEdit.Text)))
    catch
        baseN := 0

    if (baseN < 1)
        return "1/?  (---%)"

    luck := 1.0
    try luck := Float(Trim(luckEdit.Text))
    catch
        luck := 1.0
    if (luck <= 0)
        luck := 1.0

    newN := Round(baseN / luck)
    if (newN < 1)
        newN := 1

    newPct := 100.0 / newN
    return "1/" . newN . "   (" . Format("{:.5f}", newPct) . "%)"
}

LuckCopyResults(lootLuckEdit, biomeLuckEdit, lootResult, biomeResult, *)
{
    global ConfigFile
    A_Clipboard := "LOOT:  " . lootResult.Text . "`nBIOME: " . biomeResult.Text
    try {
        IniWrite(Trim(lootLuckEdit.Text), ConfigFile, "Luck", "LootLuck")
    }
    try {
        IniWrite(Trim(biomeLuckEdit.Text), ConfigFile, "Luck", "BiomeLuck")
    }
}

LuckSaveAndClose(lootLuckEdit, biomeLuckEdit, *)
{
    global ConfigFile
    try {
        IniWrite(Trim(lootLuckEdit.Text), ConfigFile, "Luck", "LootLuck")
    }
    try {
        IniWrite(Trim(biomeLuckEdit.Text), ConfigFile, "Luck", "BiomeLuck")
    }
    CloseLuckCalculator()
}

ShowSimulator(*)
{
    global BiomeDefs

    sim := Gui("+AlwaysOnTop -MaximizeBox", "Simulate Events (Debug)")
    sim.BackColor := "20242A"
    sim.SetFont("s9 cFFFFFF", "Segoe UI")

    sim.AddText("x14 y12 w420 h20", "Choose a biome:")
    sim.SetFont("s9 c000000", "Segoe UI")

    names := []
    for def in BiomeDefs
    {
        bossList := ""
        for bossObj in def.bosses
        {
            if (bossList != "")
                bossList .= ", "
            bossList .= bossObj.name
            if bossObj.notify
                bossList .= "*"
        }
        if (bossList = "")
            bossList := "no bosses"
        names.Push(def.biomeName . "   [" . bossList . "]")
    }

    biomeDDL := sim.AddDropDownList("x14 y35 w420", names)
    biomeDDL.Choose(1)

    sim.SetFont("s9 cFFFFFF", "Segoe UI")

    sim.AddText("x14 y68 w420 h20", "Choose a boss from that biome (ignored for Biome Arrives / Ends):")
    sim.SetFont("s9 c000000", "Segoe UI")
    bossDDL := sim.AddDropDownList("x14 y90 w420", ["(auto)"])
    bossDDL.Choose(1)

    ; Repopulate boss dropdown when the biome changes.
    biomeDDL.OnEvent("Change", (*) => PopulateBossDDL(biomeDDL, bossDDL))

    sim.SetFont("s9 cFFFFFF", "Segoe UI")
    sim.AddButton("x14 y128 w128 h32", "Biome Arrives").OnEvent("Click",
        (*) => SimInject("biome", biomeDDL, bossDDL))
    sim.AddButton("x148 y128 w128 h32", "Boss Spawns").OnEvent("Click",
        (*) => SimInject("boss", biomeDDL, bossDDL))
    sim.AddButton("x282 y128 w152 h32", "Biome Ends").OnEvent("Click",
        (*) => SimInject("ends", biomeDDL, bossDDL))

    sim.AddButton("x14 y172 w420 h32", "World Returned To Normal").OnEvent("Click",
        (*) => InjectChatLine("The world has returned to normal.", 2500))

    ; Community staging test buttons.
    sim.AddButton("x14 y216 w203 h32", "Stage CRCW: Boss").OnEvent("Click",
        (*) => SimStageCommunity("boss", biomeDDL, bossDDL))
    sim.AddButton("x220 y216 w214 h32", "Stage CRCW: Biome").OnEvent("Click",
        (*) => SimStageCommunity("biome", biomeDDL, bossDDL))

    sim.SetFont("s8 c9AA4B2", "Segoe UI")
    sim.AddText("x14 y258 w420 h50",
        "A * next to a boss name means it will ping when it spawns. "
        . "Only biomes currently marked GOOD will be detected.")

    sim.Show("w450 h330")
}

SimStageCommunity(kind, biomeDDL, bossDDL)
{
    global BiomeDefs

    sel := biomeDDL.Text
    matchDef := ""
    for def in BiomeDefs
    {
        if InStr(sel, def.biomeName)
        {
            matchDef := def
            break
        }
    }
    if (matchDef = "")
        return

    if (kind = "biome")
    {
        StageCommunityBiomePing(matchDef)
        return
    }

    ; Boss.
    chosenName := StrReplace(bossDDL.Text, " *", "")
    targetBoss := ""
    if (chosenName != "" && chosenName != "(auto)")
    {
        for bossObj in matchDef.bosses
            if (bossObj.name = chosenName)
            {
                targetBoss := bossObj
                break
            }
    }
    if (targetBoss = "")
    {
        if (matchDef.bosses.Length > 0)
            targetBoss := matchDef.bosses[1]
        else
        {
            UpdateOCRResult("No bosses defined for this biome.")
            return
        }
    }
    StageCommunityBossPing(targetBoss)
}

PopulateBossDDL(biomeDDL, bossDDL)
{
    global BiomeDefs

    sel := biomeDDL.Text
    items := ["(auto)"]
    for def in BiomeDefs
    {
        if InStr(sel, def.biomeName)
        {
            for bossObj in def.bosses
                items.Push(bossObj.name . (bossObj.notify ? " *" : ""))
            break
        }
    }

    bossDDL.Delete()
    bossDDL.Add(items)
    bossDDL.Choose(1)
}

SimInject(kind, biomeDDL, bossDDL)
{
    global BiomeDefs

    sel := biomeDDL.Text
    matchDef := ""
    for def in BiomeDefs
    {
        if InStr(sel, def.biomeName)
        {
            matchDef := def
            break
        }
    }
    if (matchDef = "")
        return

    switch kind
    {
        case "biome":
            InjectChatLine(matchDef.biomeName, 2500)
        case "ends":
            InjectChatLine("The world has returned to normal.", 2500)
        case "boss":
            chosenName := StrReplace(bossDDL.Text, " *", "")
            targetBoss := ""
            if (chosenName != "" && chosenName != "(auto)")
            {
                for bossObj in matchDef.bosses
                    if (bossObj.name = chosenName)
                    {
                        targetBoss := bossObj
                        break
                    }
            }
            if (targetBoss = "")
            {
                if (matchDef.bosses.Length > 0)
                    targetBoss := matchDef.bosses[1]
                else
                {
                    InjectChatLine("Some random boss has spawned!", 2500)
                    return
                }
            }
            InjectChatLine(targetBoss.name . " has spawned!", 2500)
    }
}

ShowBiomeSelector(*)
{
    global BiomeDefs, BiomeGood, BiomeBad, BiomeSelectorGui

    if IsObject(BiomeSelectorGui)
    {
        try
        {
            BiomeSelectorGui.Show()
            WinActivate("ahk_id " . BiomeSelectorGui.Hwnd)
            return
        }
        catch
            BiomeSelectorGui := 0
    }

    sel := Gui("+AlwaysOnTop -MaximizeBox +Resize", "Select Biomes / Bosses")
    sel.BackColor := "FFFFFF"

    sel.SetFont("s10 c000000", "Segoe UI")
    sel.AddText("x14 y12 w700 h22",
        "Click a row to cycle GOOD -> BAD -> IGNORED. Select multiple rows and use the buttons below for bulk changes.")

    sel.SetFont("s9 c000000", "Segoe UI")
    lv := sel.AddListView(
        "x14 y42 w700 h470 Grid Multi",
        ["Biome / Boss", "Status"])
    lv.SetFont("s9 c000000", "Segoe UI")
    lv.ModifyCol(1, 540)
    lv.ModifyCol(2, 130)

    RebuildBiomeList(lv)
    lv.OnEvent("Click", OnBiomeRowClick)

    sel.SetFont("s9 c000000", "Segoe UI")
    sel.AddButton("x14 y524 w150 h32", "Mark Selected GOOD").OnEvent("Click",
        (*) => SetSelectedStatus(lv, "good"))
    sel.AddButton("x170 y524 w150 h32", "Mark Selected BAD").OnEvent("Click",
        (*) => SetSelectedStatus(lv, "bad"))
    sel.AddButton("x326 y524 w170 h32", "Mark Selected IGNORED").OnEvent("Click",
        (*) => SetSelectedStatus(lv, "ignored"))
    sel.AddButton("x502 y524 w110 h32", "Reset Defaults").OnEvent("Click",
        (*) => ResetBiomeChoices(lv))
    sel.AddButton("x618 y524 w96 h32", "Close").OnEvent("Click",
        (*) => CloseBiomeSelector())

    sel.OnEvent("Close",  (*) => CloseBiomeSelector())
    sel.OnEvent("Escape", (*) => CloseBiomeSelector())

    BiomeSelectorGui := sel
    sel.Show("w730 h570")
}

OnBiomeRowClick(lv, rowNum, *)
{
    global BiomeDefs, BiomeGood, BiomeBad

    if (rowNum < 1 || rowNum > BiomeDefs.Length)
        return

    def := BiomeDefs[rowNum]

    if BiomeGood[def.id]
    {
        BiomeGood[def.id] := false
        BiomeBad[def.id]  := true
        SaveBiomeChoice(def.id, "bad")
    }
    else if BiomeBad[def.id]
    {
        BiomeGood[def.id] := false
        BiomeBad[def.id]  := false
        SaveBiomeChoice(def.id, "ignored")
    }
    else
    {
        BiomeGood[def.id] := true
        BiomeBad[def.id]  := false
        SaveBiomeChoice(def.id, "good")
    }

    ; Destroy and re-create all rows. This clears any selection state
    ; Windows was tracking, which is what causes the invisible-text bug.
    RebuildBiomeList(lv)
}

SetSelectedStatus(lv, status)
{
    global BiomeDefs, BiomeGood, BiomeBad

    selectedRows := []
    startIndex := -1
    Loop
    {
        startIndex := SendMessage(0x100C, startIndex, 0x0002, lv.Hwnd)
        if (startIndex = -1 || startIndex = "")
            break
        selectedRows.Push(startIndex + 1)
    }

    if (selectedRows.Length = 0)
    {
        MsgBox("Select one or more rows first, then click a status button.",
               "Biome Selector", "Iconi")
        return
    }

    for row in selectedRows
    {
        if (row < 1 || row > BiomeDefs.Length)
            continue
        def := BiomeDefs[row]

        switch status
        {
            case "good":
                BiomeGood[def.id] := true
                BiomeBad[def.id]  := false
            case "bad":
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := true
            case "ignored":
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := false
        }

        SaveBiomeChoice(def.id, status)
    }

    RebuildBiomeList(lv)
}

ResetBiomeChoices(lv)
{
    global BiomeDefs, BiomeGood, BiomeBad

    for i, def in BiomeDefs
    {
        dflt := "bad"
        if def.HasProp("defaultStatus")
            dflt := def.defaultStatus
        else if (def.HasProp("defaultGood") && def.defaultGood)
            dflt := "good"

        switch dflt
        {
            case "good":
                BiomeGood[def.id] := true
                BiomeBad[def.id]  := false
                SaveBiomeChoice(def.id, "good")
            case "ignored":
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := false
                SaveBiomeChoice(def.id, "ignored")
            default:
                BiomeGood[def.id] := false
                BiomeBad[def.id]  := true
                SaveBiomeChoice(def.id, "bad")
        }
    }

    RebuildBiomeList(lv)
}

ApplyBiomeCheck(lv, rowNum, checked)
{
    global BiomeDefs, BiomeGood, BiomeBad

    if (rowNum < 1 || rowNum > BiomeDefs.Length)
        return

    def := BiomeDefs[rowNum]

    if checked
    {
        BiomeGood[def.id] := true
        BiomeBad[def.id]  := false
        lv.Modify(rowNum, "", "", "GOOD")
        SaveBiomeChoice(def.id, "good")
    }
    else
    {
        BiomeGood[def.id] := false
        BiomeBad[def.id]  := true
        lv.Modify(rowNum, "", "", "BAD")
        SaveBiomeChoice(def.id, "bad")
    }
}

CloseBiomeSelector()
{
    global BiomeSelectorGui
    if IsObject(BiomeSelectorGui)
    {
        try BiomeSelectorGui.Destroy()
        catch
        {
        }
        BiomeSelectorGui := 0
    }
}

CheckRobloxErrorScreen()
{
    try
    {
        hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        if !hwnd
            return false

        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)

        ; Two scan regions:
        ;   1. Bottom strip: "server became unavailable" / "experience has ended"
        ;   2. Center box:   "Join Error 524" / "you do not have permission"
        ;                    / "you have been kicked" / "Disconnected"
        regions := [
            { x: wx + Round(ww * 0.10), y: wy + wh - 130,
              w: Round(ww * 0.80), h: 120 },
            { x: wx + Round(ww * 0.20), y: wy + Round(wh * 0.25),
              w: Round(ww * 0.60), h: Round(wh * 0.50) }
        ]

        errorPhrases := [
            "unexpected error", "system error",
            "server became unavailable", "experience has ended",
            "join error", "error code",
            "you do not have permission",
            "you have been kicked",
            "you have been disconnected",
            "cannot join", "server is full",
            "failed to join", "lost connection",
            "this experience is currently unavailable"
        ]

        for rect in regions
        {
            result := OCR.FromRect(rect.x, rect.y, rect.w, rect.h, {lang: "en-US"})
            if (result.Text = "")
                continue

            low := StrLower(result.Text)
            for phrase in errorPhrases
                if InStr(low, phrase)
                    return true
        }
    }
    catch
    {
    }
    return false
}

^!t::ProbeOCRLines()   ; Ctrl+Alt+T
^!r::ForceResume()   ; Ctrl+Alt+R
; Ctrl+Shift+1..4 all trigger a manual hop. Useful when you're driving
; multiple RDP sessions: focus the session, press its number, it hops.
Loop 4
{
    try Hotkey("^+" . A_Index, ManualHop, "On")
    catch
    {
    }
}

; Fires on a repeating timer while the macro runs. Tiny mouse jiggle +
; harmless click to keep Roblox from disconnecting for inactivity.
; Suppressed while auto-attack is active (the LMB is already held and
; clicking would release it).
AntiAfkTick()
{
    global AntiAfkEnabled, AntiAfkIntervalMs, LastAntiAfkTick
    global AntiAfkJigglePixels, AntiAfkLastDir
    global AutoAttackActive
    global MacroRunning

    if !AntiAfkEnabled
        return
    if !MacroRunning
        return
    if AutoAttackActive
        return

    if (A_TickCount - LastAntiAfkTick < AntiAfkIntervalMs)
        return

    ; Only jiggle if Roblox is actually focused. Otherwise the jiggle
    ; would land on whatever window the user is working in.
    if !WinActive("ahk_exe RobloxPlayerBeta.exe")
    {
        LastAntiAfkTick := A_TickCount
        return
    }

    ; Save current cursor position so we can return to it.
    MouseGetPos(&origX, &origY)

    ; Move a few pixels in alternating directions, then back.
    dx := AntiAfkJigglePixels * AntiAfkLastDir
    MouseMove(origX + dx, origY, 1)
    Sleep(60)
    MouseMove(origX, origY, 1)
    Sleep(60)

    ; Send a harmless keystroke that Roblox won't act on as a real input.
    ; Shift alone doesn't toggle anything in-game but resets the idle timer.
    Send("{Ctrl}")

    AntiAfkLastDir := -AntiAfkLastDir
    LastAntiAfkTick := A_TickCount
}

ToggleAutoAttackManual()
{
    global AutoAttackActive, TargetBiomeDef

    if AutoAttackActive
    {
        StopAutoAttack()
        UpdateOCRResult("Auto-attack manually stopped.")
        return
    }

    ; Pick sequence based on current biome if we're in one
    seqName := "default"
    if IsObject(TargetBiomeDef) && TargetBiomeDef.HasProp("attackSequence")
        seqName := TargetBiomeDef.attackSequence

    StartAutoAttack(seqName)
    UpdateOCRResult("Auto-attack manually started: '" . seqName . "'")
}

WatchdogTick()
{
    global MacroRunning, WatchdogLastStatus
    global WatchdogLastStatusChangeTick, WatchdogAlertSent
    global StatusText

    if !MacroRunning
        return
    if !IsObject(StatusText)
        return

    currentStatus := ""
    try currentStatus := Trim(StatusText.Text)

    if (currentStatus = "")
        return

    ; First observation or a fresh transition - reset the clock.
    if (currentStatus != WatchdogLastStatus)
    {
        WatchdogLastStatus := currentStatus
        WatchdogLastStatusChangeTick := A_TickCount
        WatchdogAlertSent := false
        return
    }

    stuckMs := A_TickCount - WatchdogLastStatusChangeTick

    ; REJOINING should never last more than 3 minutes. Anything else
    ; lasting more than 15 minutes is also a softlock.
    threshold := (currentStatus = "REJOINING" || currentStatus = "LAUNCHING ROBLOX"
               || currentStatus = "ROBLOX ERROR") ? 180000 : 900000

    if (stuckMs >= threshold && !WatchdogAlertSent)
    {
        WatchdogAlertSent := true
        NotifyError("Script has been in status **" . currentStatus . "** for "
                  . Round(stuckMs / 60000, 1) . " minutes. "
                  . "This usually means the macro is softlocked and needs a manual check.")
    }
}

^!z::StageLastBoss()    ; Ctrl+Alt+z - stage last boss for CRCW
^!w::StageLastBiome()   ; Ctrl+Alt+W - stage last biome for CRCW
^+a::ToggleAutoAttackManual()   ; Ctrl+Shift+A toggles AA on/off
^!o::TestOrengaAlert()   ; Ctrl+Alt+O — fires the Orenga alert as if detected

TestOrengaAlert()
{
    global OrengaAlertActive
    OrengaAlertActive := false
    HandleOrengaFound()
}

^!b::ShowBossBarOCR()   ; Ctrl+Alt+B — dump what the boss-bar OCR sees

ShowBossBarOCR()
{
    try
    {
        bossRect := GetBossBarRect()
        r := OCR.FromRect(bossRect.x, bossRect.y, bossRect.w, bossRect.h, {lang: "en-US"})
        MsgBox(
            "Boss bar region:`n"
            . "x=" . bossRect.x . "  y=" . bossRect.y . "`n"
            . "w=" . bossRect.w . "  h=" . bossRect.h . "`n`n"
            . "OCR text:`n[" . r.Text . "]",
            "Boss Bar OCR"
        )
    }
    catch Error as err
    {
        MsgBox("Failed: " . err.Message, "Boss Bar OCR")
    }
}