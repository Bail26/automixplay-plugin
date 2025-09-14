//Supports ReHLDS/RegameDll Builds only

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

// Constants
#define HUD_REFRESH_INTERVAL 1.0
#define FULL_BANNER_HOLD     5.0
#define NEXT_STEP_DELAY      10.0
#define MAX_PLAYERS 32
#define TAG_A_STR "[A] "
#define TAG_B_STR "[B] "
#define TAG_DELAY 5.0
#define TASK_TAG_BASE 62000
#define MAX_RETRIES  12
#define VOTE_DURATION_SEC      8.0
#define CHANGE_DELAY_FULL_SEC  7.0   
#define CHANGE_DELAY_SH_SEC    7.0  
#define CAPTAIN_START_SEC     10.0   

// HUD
#define HUD_COUNTDOWN_INTERVAL 1.0

// TASK IDs
#define TASK_WAITING_HUD     1001
#define TASK_NEXT_STEP       1003
#define TASK_STATS_PAGE1   10021
#define TASK_STATS_PAGE2   10022
#define TASK_STATS_DONE    10023
#define TASK_SWAP_BASE  63000
#define TASK_MAPVOTE_END       2001
#define TASK_CHANGE_MAP        2002
#define TASK_HUD_COUNTDOWN     2003
#define TASK_START_CAPTAINS    2004
#define TASK_SH_COUNTDOWN     2005  
#define TASK_FH_EFFECTS_BASE   9100
#define TASK_SH_EFFECTS_BASE   9200
#define TASK_WAIT_2NDHALF      9301
#define TASK_ROUNDHUD_FADE     9401
#define TASK_FINAL_DHUD        9501
#define TASK_CAP_PICK_COUNTDOWN 3001
#define TASK_ROUND_RESTART      3002
#define TASK_SIDE_MENU          3003
#define TASK_TEAMSEL_START      3004
#define TASK_TEAMSEL_HUD        4001
#define TASK_TEAMSEL_GIVE_MENU  4002
#define TASK_TEAMSEL_FINALIZE   4003
#define TASK_FIRSTHALF_INIT     4004

// LIMITS
#define MAX_MAPS               64
#define MAX_NAME               64

#define SND_PHASE_BEEP          "buttons/blip1.wav"

// Countdown seconds
#define CAPTAIN_SELECT_COUNTDOWN 3
#define RESTART_DELAY_SEC        2.0
#define SIDE_MENU_DELAY_SEC      4.0
#define TEAMSEL_AFTER_SIDE_SEC   2.0
#define TEAMSEL_MENU_DELAY      2.0
#define TEAMSEL_FINISH_SHINE    2.0


// State
enum MatchStatus { MS_WAITING = 0, MS_FULL, MS_CAPTAINKNIFE, MS_TEAMSELECTION, MS_FIRSTHALFINITIAL, MS_FIRSTHALF, MS_HALFSWAP, MS_SECONDHALFINITIAL, MS_SECONDHALF }

new g_MatchStatus = MS_WAITING
new g_pCvarMinPlayers

new g_SwapTarget[33];     
new bool:g_SwapPending[33]; 

new bool:g_mapChanged = false
new MAP_CHANGE_FILE[PLATFORM_MAX_PATH]

new bool:g_SideChosen = false  

// Tracking toggles
new bool:g_StatsEnabled = false;  
new bool:g_StatsLocked  = true;    

// Per-player stats
new g_Kills[33];
new g_Deaths[33];
new g_HSKills[33];
new g_KnifeKills[33];
new g_HEKills[33];
new g_KnifedDeaths[33];     
new g_Plants[33];            
new g_SuccessPlants[33];    
new g_NameCache[33][32];
new g_LastPlanter = 0;

// Internals
new g_TagRetry[33];
new g_SHRemain = 0 

// STATE (Map Vote)
new bool:g_VoteActive = false
new g_VoteMenu = INVALID_HANDLE; 

new g_AllMaps[MAX_MAPS][MAX_NAME]
new g_AllMapCount = 0

new g_OptionMapIndex[MAX_MAPS]     
new g_OptionCount = 0

new g_VoteCount[MAX_MAPS]        
new bool:g_HasVoted[33]            
new g_SelectedMapIdx[33]          

new g_CountdownRemain = 0
enum CountdownType { CT_NONE = 0, CT_CAPTAINS, CT_CHANGEMAP }
new g_CountdownType = CT_NONE

enum VotePhase { VP_FULL = 1, VP_SECONDHALF }
new g_CurrentVotePhase = VP_FULL

new g_WinnerMap[MAX_NAME]


// STATE: Captains & flow flags
enum CaptainSlot { CAP_A = 0, CAP_B = 1 }

new g_CaptainPlayer[2] = {0, 0}     
new g_CaptainTeam[2]   = {CS_TEAM_UNASSIGNED, CS_TEAM_UNASSIGNED} 
new g_WinnerCapSlot     = -1        
new bool:g_JoinLocked   = false     
new g_CapCountdownRemain = 0

new CaptainSlot:g_CurrentPickerSlot;   
new bool:g_PickInProgress = false;     
new g_PickMenu = INVALID_HANDLE;     

// Score & round tracking 
new g_ScoreA = 0, g_ScoreB = 0;     
new g_HalfRound = 0;               
new g_TotalRounds = 0;               
new bool:g_ScoreLocked = true;     

// Which CS team currently maps to Team [A] and Team [B]
new CsTeams:g_TeamA_CS = CS_TEAM_T; 
new CsTeams:g_TeamB_CS = CS_TEAM_CT;  

new gCvarExecAutomix[64] = "clan.cfg";
new gCvarExecPub[64]     = "pub.cfg";
new gCvarExecKnife[64]  =   "knife.cfg"

// Round HUD animation state
new g_RoundHUDText[64];
new g_RoundHUDSteps = 0; 
new g_RoundHUDColorIdx = 0;

new g_GameDesc[128];
new bool:g_GameDescDirty = true;
new bool:g_MatchEnded = false;
new g_fwdGetGameDesc = -1;

new gCvarChatPrefix;
new g_ChatPrefix[32];

new g_LiveScrollTaskId = TASK_FINAL_DHUD; 
new g_LiveScrollSteps = 0;
new g_LiveScrollTotal = 0;
new Float:g_LiveScrollInterval = 0.12; 
new g_LiveScrollRightDelaySteps = 4; 
new g_LiveScrollText[64];

public plugin_init()
{
    register_plugin("Mixplay", "1.1", "B@IL&Vasu")

    g_pCvarMinPlayers = create_cvar("amx_minplayers", "10", FCVAR_NONE,"")
    gCvarChatPrefix = create_cvar("amx_prefix", "[Automix]", FCVAR_NONE, "");

    register_clcmd("jointeam", "Cmd_BlockJoinTeam")
    register_clcmd("chooseteam", "Cmd_BlockJoinTeam")
    register_clcmd("buy", "Cmd_BlockBuy")
    register_clcmd("buyequip", "Cmd_BlockBuy")
    register_clcmd("autobuy", "Cmd_BlockBuy")
    register_clcmd("rebuy", "Cmd_BlockBuy")

    register_clcmd("say /getmenu", "Cmd_GetMenu");
    register_clcmd("say_team /getmenu", "Cmd_GetMenu");
    register_clcmd("say /swap", "Cmd_SwapRequest");
    register_clcmd("say /score", "Cmd_ShowScore");
    register_clcmd("say_team /score", "Cmd_ShowScore");

    // Knife-only enforcement on spawn
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawnPost", 1)

    register_event("DeathMsg", "ev_DeathMsg", "a")

    register_logevent("LE_BombPlanted",   3, "2=Planted_The_Bomb");
    register_logevent("LE_BombExploded",  6, "3=Target_Bombed");
    register_logevent("LE_BombDefused",   3, "2=Bomb_Defused");

    register_event("HLTV", "EV_RoundStart", "a", "1=0", "2=0"); 

    register_event("SendAudio", "EV_TerWin", "a", "2=%!MRAD_terwin");
    register_event("SendAudio", "EV_CtWin",  "a", "2=%!MRAD_ctwin");

    g_fwdGetGameDesc = register_forward(FM_GetGameDescription, "Change");
    if (g_fwdGetGameDesc == -1)
    {
        log_amx("[AutoMix] FM_GetGameDescription forward NOT available; hostname fallback recommended.");
    }
    else
    {
        log_amx("[AutoMix] FM_GetGameDescription forward registered.");
    }

    g_GameDescDirty = true;
    UpdateGameDesc();
}

public plugin_cfg()
{
    new configsDir[PLATFORM_MAX_PATH]
    get_configsdir(configsDir, charsmax(configsDir))
    formatex(MAP_CHANGE_FILE, charsmax(MAP_CHANGE_FILE), "%s/mapchange_flag.ini", configsDir)

    get_pcvar_string(gCvarChatPrefix, g_ChatPrefix, charsmax(g_ChatPrefix));

    server_cmd("exec %s", gCvarExecPub);
    check_map_change_file()
    StartWaitingState()
}

public plugin_end()
{
    CancelAllMixTasks()
}

public plugin_precache()
{
    precache_sound(SND_PHASE_BEEP)
}


stock check_map_change_file()
{
    if (!file_exists(MAP_CHANGE_FILE))
    {
        // Create file with "0"
        new fp = fopen(MAP_CHANGE_FILE, "wt")
        if (!fp)
        {
            log_error(AMX_ERR_GENERAL, "%s Failed to create file: %s", g_ChatPrefix, MAP_CHANGE_FILE)
            g_mapChanged = false
            return
        }
        fputs(fp, "0")
        fclose(fp)
        g_mapChanged = false
        return
    }

    // Read existing file
    new fp = fopen(MAP_CHANGE_FILE, "rt")
    if (!fp)
    {
        log_error(AMX_ERR_GENERAL, "%s Failed to open file for reading: %s", g_ChatPrefix, MAP_CHANGE_FILE)
        g_mapChanged = false
        return
    }

    new line[16]
    fgets(fp, line, charsmax(line))
    fclose(fp)

    trim(line)

    if (equal(line, "1"))
    {
        g_mapChanged = true
        set_map_change_flag(0)
    }
    else
    {
        g_mapChanged = false
    }
}


stock set_map_change_flag(const value)
{
    if (MAP_CHANGE_FILE[0] == '^0')
    {
        log_error(AMX_ERR_GENERAL, "%s MAP_CHANGE_FILE not initialized yet.", g_ChatPrefix)
        return
    }

    new fp = fopen(MAP_CHANGE_FILE, "wt")
    if (!fp)
    {
        log_error(AMX_ERR_GENERAL, "%s Failed to open file for writing: %s", g_ChatPrefix, MAP_CHANGE_FILE)
        return
    }

    if (value == 1)
    {
        fputs(fp, "1")
    }
    else
    {
        fputs(fp, "0")
    }

    fclose(fp)
}

stock set_map_flag_changed()      { set_map_change_flag(1); }
stock set_map_flag_not_changed()  { set_map_change_flag(0); }


public client_putinserver(id)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) return;

    get_user_name(id, g_NameCache[id], charsmax(g_NameCache[]));

    if (g_MatchStatus == MS_FIRSTHALF || g_MatchStatus == MS_SECONDHALF
     || g_MatchStatus == MS_FIRSTHALFINITIAL || g_MatchStatus == MS_SECONDHALFINITIAL)
    {
        client_print_color(0, print_team_default,
            "^4%s^1 Player ^3%n^1 joined the match. Welcome to JKE Mix.", g_ChatPrefix, id)
        AutoAssignToSmallerTeam(id);
        StartJoinTagFlow(id);
        return
    }

    if (g_MatchStatus == MS_WAITING)
    {
        new playersNow = CountEligiblePlayers()
        new min = get_pcvar_num(g_pCvarMinPlayers)
        client_print_color(0, print_team_default,
            "^4%s^1 Player ^3%n^1 joined and is ready. ^4(%d/%d)", g_ChatPrefix, id, playersNow, min)

        EvaluateWaitingToFull()
    }
}

stock ClosePickMenuIfOpen()
{
    if (g_PickMenu != INVALID_HANDLE)
    {
        menu_destroy(g_PickMenu)
        g_PickMenu = INVALID_HANDLE
    }
    g_PickInProgress = false
}

public client_disconnected(id)
{
    if (g_MatchStatus > MS_FIRSTHALFINITIAL)
    {
        if (g_LastPlanter == id) g_LastPlanter = 0;

        remove_task(TASK_TAG_BASE + id);
        g_TagRetry[id] = 0;
    }
    
    if (g_MatchStatus == MS_WAITING)
    {
        EvaluateWaitingToFull()
      
    }

    // 2) Captain phases
    if (g_MatchStatus == MS_CAPTAINKNIFE || g_MatchStatus == MS_TEAMSELECTION)
    {
        new slot = GetCaptainSlot(id)
        if (slot == -1)
            return 

        if (ReassignCaptain(slot))
        {
            client_print_color(0, print_team_red,
                "^4%s^1 A captain left. Reassigned a new captain to ^3%s^1.", g_ChatPrefix, (g_CaptainTeam[slot] == CS_TEAM_T ? "T" : "CT"))

            if (g_MatchStatus == MS_CAPTAINKNIFE)
            {
                server_cmd("sv_restart 1")
                return
            }


            if (slot == g_WinnerCapSlot && !g_SideChosen)
            {
                if (task_exists(TASK_SIDE_MENU)) remove_task(TASK_SIDE_MENU)
                set_task(1.0, "Task_ShowSideMenu", TASK_SIDE_MENU)
                return
            }

            if (g_SideChosen && task_exists(TASK_TEAMSEL_START))
            {
                remove_task(TASK_TEAMSEL_START)
                set_task(1.0, "Task_BeginTeamSelection", TASK_TEAMSEL_START)

            }

            if (g_SideChosen && slot == g_CurrentPickerSlot)
            {

                ClosePickMenuIfOpen()

                if (task_exists(TASK_TEAMSEL_GIVE_MENU)) remove_task(TASK_TEAMSEL_GIVE_MENU)
                set_task(5.0, "Task_GivePickMenu", TASK_TEAMSEL_GIVE_MENU)
            }
        }
        else
        {
            client_print_color(0, print_team_red,
                "^4%s^1 Captain left but no Spectators available to replace. Waiting...", g_ChatPrefix)
        }
    }
}


stock StartWaitingState()
{
    g_MatchStatus = MS_WAITING

    MarkGameDescDirty(true)


    if (!task_exists(TASK_WAITING_HUD))
        set_task(HUD_REFRESH_INTERVAL, "Task_ShowWaitingHUD", TASK_WAITING_HUD, _, _, "b")

    EvaluateWaitingToFull()
}

stock StopWaitingHUD()
{
    if (task_exists(TASK_WAITING_HUD))
        remove_task(TASK_WAITING_HUD)
}

stock EvaluateWaitingToFull()
{
    if (g_MatchStatus != MS_WAITING) return

    new playersNow = CountEligiblePlayers()
    new min = get_pcvar_num(g_pCvarMinPlayers)

    if (playersNow >= min)
    {
        g_MatchStatus = MS_FULL
        StopWaitingHUD()

        ShowFullBanner()
        EmitFullSound()
        AnnounceNextStep()

        set_task(NEXT_STEP_DELAY, "Task_GoToNextPhase", TASK_NEXT_STEP)
    }
}

public Task_ShowWaitingHUD()
{
    if (g_MatchStatus != MS_WAITING) return

    new playersNow = CountEligiblePlayers()
    new min = get_pcvar_num(g_pCvarMinPlayers)

    set_dhudmessage(0, 160, 255, -1.0, 0.01, 0, 0.0, HUD_REFRESH_INTERVAL + 0.1, 0.0, 0.0)
    show_dhudmessage(0, "Status: WAITING")

    set_dhudmessage(255, 255, 255, -1.0, 0.06, 0, 0.0, HUD_REFRESH_INTERVAL + 0.1, 0.0, 0.0)
    show_dhudmessage(0, "Players Remaining to Start - %d/%d", playersNow, min)
}

stock ShowFullBanner()
{
    set_dhudmessage(0, 255, 128, -1.0, 0.08, 0, 0.0, FULL_BANNER_HOLD, 0.0, 0.0)
    show_dhudmessage(0, "Match will begin now")
}

stock AnnounceNextStep()
{
    if (!g_mapChanged)
        client_print_color(0, print_team_default,
            "^4%s^1 Map voting will start in ^3%d^1 seconds.", g_ChatPrefix, floatround(NEXT_STEP_DELAY))
    else
        client_print_color(0, print_team_default,
            "^4%s^1 Captain selection will start in ^3%d^1 seconds.", g_ChatPrefix, floatround(NEXT_STEP_DELAY))
}

stock EmitFullSound()
{
    client_cmd(0, "spk %s", SND_PHASE_BEEP);
}

public Task_GoToNextPhase()
{
    if (!g_mapChanged) StartMapVote();
    else BeginCaptainSelection();
}


// CLEANUP
stock CancelAllMixTasks()
{
    // ---- Waiting/Full flow ----
    if (task_exists(TASK_WAITING_HUD))     remove_task(TASK_WAITING_HUD)
    if (task_exists(TASK_NEXT_STEP))       remove_task(TASK_NEXT_STEP)

    // ---- MapVote: voting window & follow-ups ----
    if (task_exists(TASK_MAPVOTE_END))     remove_task(TASK_MAPVOTE_END)
    if (task_exists(TASK_HUD_COUNTDOWN))   remove_task(TASK_HUD_COUNTDOWN)
    if (task_exists(TASK_SH_COUNTDOWN))    remove_task(TASK_SH_COUNTDOWN)
    if (task_exists(TASK_CHANGE_MAP))      remove_task(TASK_CHANGE_MAP)
    if (task_exists(TASK_START_CAPTAINS))  remove_task(TASK_START_CAPTAINS)
    if (task_exists(TASK_ROUNDHUD_FADE)) remove_task(TASK_ROUNDHUD_FADE);


    // ---- Menu handle & voting state ----
    if (g_VoteMenu != INVALID_HANDLE)
    {
        menu_destroy(g_VoteMenu)
        g_VoteMenu = INVALID_HANDLE
    }
    g_VoteActive = false
    g_CountdownType = CT_NONE
    g_CountdownRemain = 0
    g_SHRemain = 0

    // Optional: clear vote tallies & per-player flags for safety
    arrayset(g_VoteCount, 0, sizeof g_VoteCount)
    for (new i = 1; i <= 32; i++)
    {
        g_HasVoted[i] = false
        g_SelectedMapIdx[i] = -1
    }
}

stock CountEligiblePlayers()
{
    new players[32], pnum
    get_players(players, pnum, "ch") 
    return pnum
}

stock StartMapVote()
{
    if (g_MatchStatus == MS_FULL)          g_CurrentVotePhase = VP_FULL
    else if (g_MatchStatus == MS_SECONDHALF) g_CurrentVotePhase = VP_SECONDHALF
    else
    {
        log_amx("%s StartMapVote() called in unsupported status (%d)", g_ChatPrefix, g_MatchStatus)
        return
    }

    if (g_VoteActive)
    {
        log_amx("%s StartMapVote() ignored; a vote is already active.", g_ChatPrefix)
        return
    }

    if (!LoadMapsIni())
    {
        client_print_color(0, print_team_red, "^4%s^1 maps.ini is empty or not found—cannot start map vote.", g_ChatPrefix)
        return
    }

    BuildMenuOptions()

    arrayset(g_VoteCount, 0, sizeof g_VoteCount)
    for (new i = 1; i <= 32; i++)
    {
        g_HasVoted[i] = false
        g_SelectedMapIdx[i] = -1
    }

    new title[128]
    if (g_CurrentVotePhase == VP_FULL)
        formatex(title, charsmax(title), "Vote for Match Map")
    else
        formatex(title, charsmax(title), "Vote for Next Map")

    if (g_VoteMenu != INVALID_HANDLE) menu_destroy(g_VoteMenu)
    g_VoteMenu = menu_create(title, "MapVote_Handler")

  
    for (new i = 0; i < g_OptionCount; i++)
    {
        new itemTxt[128], info[8]

        GetOptionText(i, itemTxt, charsmax(itemTxt))

        num_to_str(g_OptionMapIndex[i], info, charsmax(info))
        menu_additem(g_VoteMenu, itemTxt, info)
    }

    new players[32], pnum
    get_players(players, pnum, "ch") 
    for (new j = 0; j < pnum; j++)
    {
        menu_display(players[j], g_VoteMenu, 0)
    }


    g_VoteActive = true
    set_task(VOTE_DURATION_SEC, "Task_EndMapVote", TASK_MAPVOTE_END)
}

public MapVote_Handler(id, menu, item)
{
    if (!g_VoteActive) return PLUGIN_HANDLED

    if (item == MENU_EXIT) return PLUGIN_HANDLED


    new info[8], name[64], access, callback
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback)

    new mapIdx = str_to_num(info)
    if (mapIdx < 0 || mapIdx >= g_AllMapCount) return PLUGIN_HANDLED

    if (g_HasVoted[id]) return PLUGIN_HANDLED
    g_HasVoted[id] = true
    g_SelectedMapIdx[id] = mapIdx

 
    g_VoteCount[mapIdx]++

    client_print_color(0, print_team_default, "^4%s^1 ^3%n^1 voted for ^4%s", g_ChatPrefix, id, g_AllMaps[mapIdx])

    return PLUGIN_HANDLED
}

public Task_EndMapVote()
{
    if (!g_VoteActive) return
    g_VoteActive = false

    if (g_VoteMenu != INVALID_HANDLE)
    {
        menu_destroy(g_VoteMenu)
        g_VoteMenu = INVALID_HANDLE
    }

    DecideWinnerMap(g_WinnerMap, charsmax(g_WinnerMap))

    if (g_CurrentVotePhase == VP_FULL)
    {
        new cur[64]
        get_mapname(cur, charsmax(cur))

        if (equali(g_WinnerMap, cur))
        {

            client_print_color(0, print_team_default,
                "^4%s^1 Majority has decided to ^3play on the current map^1.", g_ChatPrefix)
            // DHUD + countdown 10s: "Captain selection will begin in X seconds"
            StartCountdownHUD(floatround(CAPTAIN_START_SEC), CT_CAPTAINS)

            // After 10s, start captains
            set_task(CAPTAIN_START_SEC, "Task_StartCaptains", TASK_START_CAPTAINS)
        }
        else
        {
            // Change to the selected map in 7 seconds
            client_print_color(0, print_team_default,
                "^4%s^1 Majority has decided to change map to ^3%s^1.", g_ChatPrefix, g_WinnerMap)
            client_print_color(0, print_team_default, "^4%s^1 Changing map in ^3%d^1 seconds.", g_ChatPrefix, floatround(CHANGE_DELAY_FULL_SEC))

            StartCountdownHUD(floatround(CHANGE_DELAY_FULL_SEC), CT_CHANGEMAP)

            // Persist that a change is happening, then changelevel
            set_task(CHANGE_DELAY_FULL_SEC, "Task_PerformChangelevel", TASK_CHANGE_MAP)
        }
    }
    else // VP_SECONDHALF
    {
        client_print_color(0, print_team_default,
            "^4%s^1 Next map decided: ^3%s^1.", g_ChatPrefix, g_WinnerMap)
        // 6s HUD countdown, change at 7s
        g_SHRemain = 6
        if (task_exists(TASK_SH_COUNTDOWN)) remove_task(TASK_SH_COUNTDOWN)
        set_task(1.0, "Task_ShowSecondHalfChangeCountdown", TASK_SH_COUNTDOWN, _, _, "b")

        set_task(CHANGE_DELAY_SH_SEC, "Task_PerformChangelevel", TASK_CHANGE_MAP)
    }
}

// Countdown HUDs
stock StartCountdownHUD(seconds, CountdownType:type)
{
    g_CountdownRemain = seconds
    g_CountdownType = type

    if (task_exists(TASK_HUD_COUNTDOWN))
        remove_task(TASK_HUD_COUNTDOWN)

    set_task(HUD_COUNTDOWN_INTERVAL, "Task_CountdownHUD", TASK_HUD_COUNTDOWN, _, _, "b")
}

public Task_CountdownHUD()
{
    if (g_CountdownRemain <= 0)
    {
        if (task_exists(TASK_HUD_COUNTDOWN))
            remove_task(TASK_HUD_COUNTDOWN)
        g_CountdownType = CT_NONE
        return
    }

    if (g_CountdownType == CT_CAPTAINS)
    {
        set_dhudmessage(0, 255, 128, -1.0, 0.08, 0, 0.0, HUD_COUNTDOWN_INTERVAL + 0.1, 0.0, 0.0)
        show_dhudmessage(0, "Captain selection will begin in %d seconds", g_CountdownRemain)
    }
    else if (g_CountdownType == CT_CHANGEMAP)
    {
        set_dhudmessage(0, 200, 255, -1.0, 0.08, 0, 0.0, HUD_COUNTDOWN_INTERVAL + 0.1, 0.0, 0.0)
        show_dhudmessage(0, "Changing map in %d seconds", g_CountdownRemain)
    }

    g_CountdownRemain--
}

// Special 6-second HUD for Second Half before changing
public Task_ShowSecondHalfChangeCountdown()
{
    if (g_SHRemain <= 0)
    {
        if (task_exists(TASK_SH_COUNTDOWN)) remove_task(TASK_SH_COUNTDOWN)
        g_SHRemain = 0
        return
    }

    set_dhudmessage(255, 255, 255, -1.0, 0.10, 0, 0.0, 1.1, 0.0, 0.0)
    show_dhudmessage(0, "Changing map in %d seconds", g_SHRemain)

    g_SHRemain--
}

public Task_PerformChangelevel()
{
    set_map_flag_changed()

    server_cmd("changelevel %s", g_WinnerMap)
}

public Task_StartCaptains()
{
    BeginCaptainSelection();
}

stock bool:LoadMapsIni()
{
    g_AllMapCount = 0

    new confDir[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH]
    get_configsdir(confDir, charsmax(confDir))
    formatex(path, charsmax(path), "%s/maps.ini", confDir)

    if (!file_exists(path))
        return false

    new fp = fopen(path, "rt")
    if (!fp) return false

    new line[128]
    while (!feof(fp) && g_AllMapCount < MAX_MAPS)
    {
        fgets(fp, line, charsmax(line))
        trim(line)

        if (!line[0])           continue
        if (line[0] == ';')     continue
        if (line[0] == '/')     
        {
            if (line[1] == '/') continue
        }

        if (!isalpha(line[0]) && line[0] != 'd' && line[0] != 'a' && line[0] != 'c')
            continue

        copy(g_AllMaps[g_AllMapCount++], MAX_NAME-1, line)
    }
    fclose(fp)

    return g_AllMapCount > 0
}

stock BuildMenuOptions()
{
    g_OptionCount = 0

    new cur[64]
    get_mapname(cur, charsmax(cur))

    if (g_CurrentVotePhase == VP_FULL)
    {
        new idx = FindOrAddMap(cur)
        g_OptionMapIndex[g_OptionCount++] = idx

        for (new i = 0; i < g_AllMapCount; i++)
        {
            if (equali(g_AllMaps[i], cur)) continue
            g_OptionMapIndex[g_OptionCount++] = i
        }
    }
    else
    {
        for (new i = 0; i < g_AllMapCount; i++)
        {
            if (equali(g_AllMaps[i], cur)) continue
            g_OptionMapIndex[g_OptionCount++] = i
        }
    }
}

stock GetOptionText(optIndex, buffer[], len)
{
    new allIdx = g_OptionMapIndex[optIndex]
    new cur[64]
    get_mapname(cur, charsmax(cur))

    if (g_CurrentVotePhase == VP_FULL && equali(g_AllMaps[allIdx], cur))
        formatex(buffer, len, "%s \r[Extend]", g_AllMaps[allIdx])
    else
        formatex(buffer, len, "%s", g_AllMaps[allIdx])
}

stock FindOrAddMap(const name[])
{
    for (new i = 0; i < g_AllMapCount; i++)
    {
        if (equali(g_AllMaps[i], name))
            return i
    }
    if (g_AllMapCount < MAX_MAPS)
    {
        copy(g_AllMaps[g_AllMapCount], MAX_NAME-1, name)
        return g_AllMapCount++
    }
    return 0
}

stock DecideWinnerMap(outName[], outLen)
{
    new bestVotes = -1
    new winners[MAX_MAPS], wCount = 0

    for (new i = 0; i < g_OptionCount; i++)
    {
        new mapIdx = g_OptionMapIndex[i]
        new v = g_VoteCount[mapIdx]

        if (v > bestVotes)
        {
            bestVotes = v
            wCount = 0
            winners[wCount++] = mapIdx
        }
        else if (v == bestVotes)
        {
            winners[wCount++] = mapIdx
        }
    }

    new finalIdx
    if (bestVotes <= 0)
    {
        finalIdx = g_OptionMapIndex[random(g_OptionCount)]
    }
    else if (wCount == 1)
    {
        finalIdx = winners[0]
    }
    else
    {
        finalIdx = winners[random(wCount)]
    }

    copy(outName, outLen, g_AllMaps[finalIdx])
}

public BeginCaptainSelection()
{
    g_SideChosen = false;
    client_cmd(0, "spk ^"%s^"", SND_PHASE_BEEP)

    new players[32], pnum;
    get_players(players, pnum, "ch");

    for (new i = 0; i < pnum; i++)
    {
        new id = players[i];
        if (!is_user_connected(id)) continue;

        if (is_user_alive(id)) {
            user_silentkill(id);         
        }

        cs_set_user_team(id, CS_TEAM_SPECTATOR);
        set_task(0.1, "MakeFreeLook", id);
    }

    client_print_color(0, print_team_default,
        "^4%s^1 Captain selection is starting. Everyone moved to ^3Spectators^1.", g_ChatPrefix)

    // Lock joins from now until match end
    g_JoinLocked = true

    // Calm 3s DHUD countdown before picking captains
    g_CapCountdownRemain = CAPTAIN_SELECT_COUNTDOWN
    if (task_exists(TASK_CAP_PICK_COUNTDOWN)) remove_task(TASK_CAP_PICK_COUNTDOWN)
    set_task(1.0, "Task_CaptainSelectCountdown", TASK_CAP_PICK_COUNTDOWN, _, _, "b")
}

public MakeFreeLook(id)
{
    if (!is_user_connected(id)) return;

    set_pev(id, pev_iuser1, OBS_ROAMING); // 3
    set_pev(id, pev_iuser2, 0);
    set_pev(id, pev_iuser3, 0);
    engclient_cmd(id, "specmode", "3");
}

public Task_CaptainSelectCountdown()
{
    if (g_CapCountdownRemain <= 0)
    {
        remove_task(TASK_CAP_PICK_COUNTDOWN)
        PickRandomCaptainsOrRetry()
        return
    }

    set_dhudmessage(0, 160, 255, -1.0, 0.08, 0, 0.0, 1.1, 0.0, 0.0)
    show_dhudmessage(0, "Selecting captains in %d...", g_CapCountdownRemain)
    g_CapCountdownRemain--
}

stock PickRandomCaptainsOrRetry()
{
    new specs[32], scount
    get_players(specs, scount, "ch")
    // keep only spectators
    new pool[32], pnum = 0
    for (new i = 0; i < scount; i++)
    {
        new id = specs[i]
        if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
            pool[pnum++] = id
    }

    if (pnum < 2)
    {
        client_print_color(0, print_team_red,
            "^4%s^1 Not enough players in Spectator to pick captains. Waiting...", g_ChatPrefix)
        // Retry in 2s
        set_task(2.0, "Task_CaptainSelectCountdown", TASK_CAP_PICK_COUNTDOWN, _, _, "b")
        g_CapCountdownRemain = 2
        return
    }

    // pick two distinct
    new a = random(pnum)
    new capA = pool[a]
    pool[a] = pool[pnum - 1]; pnum--
    new b = random(pnum)
    new capB = pool[b]

    // randomize which one goes CT/T
    if (random_num(0, 1) == 0)
    {
        AssignCaptain(CAP_A, capA, CS_TEAM_CT)
        AssignCaptain(CAP_B, capB, CS_TEAM_T)
    }
    else
    {
        AssignCaptain(CAP_A, capA, CS_TEAM_T)
        AssignCaptain(CAP_B, capB, CS_TEAM_CT)
    }

    // Announce captains
    client_print_color(0, print_team_default,
        "^4%s^1 Captains selected: ^3%n^1 and ^3%n^1.", g_ChatPrefix, g_CaptainPlayer[CAP_A], g_CaptainPlayer[CAP_B])

    // Small pause 
    if (task_exists(TASK_ROUND_RESTART)) remove_task(TASK_ROUND_RESTART)
    set_task(RESTART_DELAY_SEC, "Task_DoRestart", TASK_ROUND_RESTART)

    server_cmd("exec %s", gCvarExecKnife);
}

stock AssignCaptain(CaptainSlot:slot, id, CsTeams:team)
{
    g_CaptainPlayer[slot] = id
    g_CaptainTeam[slot]   = team
    cs_set_user_team(id, team)
}

// sv_restart and enter the KNIFE phase
public Task_DoRestart()
{
    server_cmd("sv_restart 1")
    g_MatchStatus = MS_CAPTAINKNIFE

    MarkGameDescDirty(true)

    set_dhudmessage(0, 255, 128, -1.0, 0.08, 0, 0.0, 3.0, 0.0, 0.0)
    show_dhudmessage(0, "Knife round for SIDE selection — GO!")
    client_print_color(0, print_team_default,
        "^4%s^1 Knife round started. Captains fight to choose side!", g_ChatPrefix)
}

public OnPlayerSpawnPost(id)
{
    if (!is_user_alive(id)) return

    if (g_MatchStatus == MS_CAPTAINKNIFE)
    {
        if (IsCaptain(id))
        {
            strip_user_weapons(id)
            give_item(id, "weapon_knife")
        }
    }

    if (g_MatchStatus == MS_TEAMSELECTION)
    {
        user_silentkill(id)
        return;
    }
}

public Cmd_BlockBuy(id)
{
    if (g_MatchStatus == MS_CAPTAINKNIFE || g_MatchStatus == MS_TEAMSELECTION)
    {
        if (IsCaptain(id))
        {
            client_print_color(id, print_team_default,
                "^4%s^1 Buying is disabled during captain phases.", g_ChatPrefix)
            return PLUGIN_HANDLED
        }
    }
    return PLUGIN_CONTINUE
}

public Cmd_BlockJoinTeam(id)
{
    if (!g_JoinLocked) return PLUGIN_CONTINUE

    client_print_color(id, print_team_default,
        "^4%s^1 Team joining is locked during match setup. Please wait.", g_ChatPrefix)
    return PLUGIN_HANDLED
}

public ev_DeathMsg()
{
    new killer = read_data(1)
    new victim = read_data(2)
    new hs     = read_data(3);
    new weapon[16]; read_data(4, weapon, charsmax(weapon))

    if (g_StatsEnabled && !g_StatsLocked)
    {
        if (is_user_connected(killer)) get_user_name(killer, g_NameCache[killer], charsmax(g_NameCache[]));
        if (is_user_connected(victim)) get_user_name(victim, g_NameCache[victim], charsmax(g_NameCache[]));

        if (killer && killer != victim && is_user_connected(killer))
        {
            g_Kills[killer]++;

            if (hs) g_HSKills[killer]++;

            if (equali(weapon, "knife"))      g_KnifeKills[killer]++;
            else if (equali(weapon, "grenade")) g_HEKills[killer]++;
        }

        if (is_user_connected(victim))
        {
            g_Deaths[victim]++;
            if (equali(weapon, "knife")) g_KnifedDeaths[victim]++;
        }
    }

    if (g_MatchStatus != MS_CAPTAINKNIFE) return

    if (!equali(weapon, "knife")) return // only knife decides

    if (IsCaptain(killer) && IsCaptain(victim))
    {
        g_WinnerCapSlot = (g_CaptainPlayer[CAP_A] == killer) ? CAP_A : CAP_B

        // Announce
        set_dhudmessage(0, 255, 128, -1.0, 0.08, 0, 0.0, 4.0, 0.0, 0.0)
        show_dhudmessage(0, "%n wins the knife round!", g_ChatPrefix, killer)

        client_print_color(0, print_team_default,
            "^4%s^1 ^3%n^1 wins the knife round!", g_ChatPrefix, killer)

        g_MatchStatus = MS_TEAMSELECTION
        g_SideChosen = false; 

         MarkGameDescDirty(true)

        if (task_exists(TASK_SIDE_MENU)) remove_task(TASK_SIDE_MENU)
        set_task(SIDE_MENU_DELAY_SEC, "Task_ShowSideMenu", TASK_SIDE_MENU)
    }
}

public Task_ShowSideMenu()
{
    if (g_WinnerCapSlot != CAP_A && g_WinnerCapSlot != CAP_B)
        return

    new winnerId = g_CaptainPlayer[g_WinnerCapSlot]
    if (!is_user_connected(winnerId))
        return  

    new m = menu_create("Choose starting SIDE", "SideMenu_Handler")
    menu_additem(m, "Terrorist", "1")
    menu_additem(m, "Counter-Terrorist", "2")
    menu_display(winnerId, m, 0)
}


public SideMenu_Handler(id, menu, item)
{
    if (item == MENU_EXIT) { menu_destroy(menu); return PLUGIN_HANDLED; }

    new info[8], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);
    menu_destroy(menu);

    new choice = str_to_num(info); // 1 = T, 2 = CT
    new CsTeams:desired = (choice == 1) ? CS_TEAM_T : CS_TEAM_CT;

    new winnerId = g_CaptainPlayer[g_WinnerCapSlot];
    if (!is_user_connected(winnerId)) return PLUGIN_HANDLED;

    new CsTeams:curTeam = cs_get_user_team(winnerId);
    if (curTeam == desired)
    {
        client_print_color(0, print_team_default,
            "^4%s^1 ^3%n^1 chose to stay on ^3%s^1.", g_ChatPrefix, winnerId, (desired == CS_TEAM_T ? "T" : "CT"));

        g_SideChosen = true; // side locked
        if (task_exists(TASK_TEAMSEL_START)) remove_task(TASK_TEAMSEL_START);
        set_task(TEAMSEL_AFTER_SIDE_SEC, "Task_BeginTeamSelection", TASK_TEAMSEL_START);
    }
    else
    {
        // swap captains
        SwapCaptainSides(desired);
        client_print_color(0, print_team_default,
            "^4%s^1 Sides swapped. ^3%n^1 now ^3%s^1.", g_ChatPrefix, winnerId, (desired == CS_TEAM_T ? "T" : "CT"));

        // small buffer then proceed
        g_SideChosen = true; // side locked after swap too
        if (task_exists(TASK_TEAMSEL_START)) remove_task(TASK_TEAMSEL_START);
        set_task(TEAMSEL_AFTER_SIDE_SEC, "Task_BeginTeamSelection", TASK_TEAMSEL_START);
    }

    return PLUGIN_HANDLED;
}


stock SwapCaptainSides(CsTeams:winnerDesired)
{
    new CaptainSlot:otherSlot = (g_WinnerCapSlot == CAP_A) ? CAP_B : CAP_A;

    new winId = g_CaptainPlayer[g_WinnerCapSlot];
    new loseId = g_CaptainPlayer[otherSlot];

    new CsTeams:loserTeam = (winnerDesired == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;

    cs_set_user_team(winId, winnerDesired);
    cs_set_user_team(loseId, loserTeam);

    g_CaptainTeam[g_WinnerCapSlot] = winnerDesired;
    g_CaptainTeam[otherSlot]       = loserTeam;
}

stock bool:ReassignCaptain(CaptainSlot:slot)
{
    new specs[32], scount
    get_players(specs, scount, "ch")

    new pool[32], pnum = 0
    for (new i = 0; i < scount; i++)
    {
        new id = specs[i]
        if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
            pool[pnum++] = id
    }

    if (pnum <= 0) return false

    new pick = pool[random(pnum)]
    g_CaptainPlayer[slot] = pick
    cs_set_user_team(pick, g_CaptainTeam[slot])
    return true
}

// Helpers
stock bool:IsCaptain(id)
{
    return (id == g_CaptainPlayer[CAP_A] || id == g_CaptainPlayer[CAP_B])
}

stock GetCaptainSlot(id)
{
    if (id == g_CaptainPlayer[CAP_A]) return CAP_A
    if (id == g_CaptainPlayer[CAP_B]) return CAP_B
    return -1
}

public Task_BeginTeamSelection()
{
    if (!g_SideChosen) return; 

    server_cmd("sv_restart 1");

    ForceAllDead();

    if (task_exists(TASK_TEAMSEL_HUD)) remove_task(TASK_TEAMSEL_HUD);
    set_task(1.0, "Task_DrawTeamSelHUD", TASK_TEAMSEL_HUD, _, _, "b");

    g_CurrentPickerSlot = g_WinnerCapSlot;

    if (task_exists(TASK_TEAMSEL_GIVE_MENU)) remove_task(TASK_TEAMSEL_GIVE_MENU);
    set_task(TEAMSEL_MENU_DELAY, "Task_GivePickMenu", TASK_TEAMSEL_GIVE_MENU);
}

public Task_DrawTeamSelHUD()
{
    if (g_MatchStatus != MS_TEAMSELECTION)
    {
        remove_task(TASK_TEAMSEL_HUD);
        return;
    }

    new left[512], right[512];
    BuildTeamSelColumns(left, charsmax(left), right, charsmax(right));

    // Left column (T or CT depending on captain’s team)
    set_hudmessage(
        255, 64, 64,   
        0.20, 0.25,    
        0,             
        6.0, 6.0,      
        0.1, 0.1       
    );
    show_hudmessage(0, "%s", left);

    // Right column (blue for CT captain name line)
    set_hudmessage(
        64, 128, 255,  
        0.60, 0.25,   
        0,
        6.0, 6.0,
        0.1, 0.1
    );
    show_hudmessage(0, "%s", right);
}


stock BuildTeamSelColumns(left[], llen, right[], rlen)
{
    new capT = -1, capCT = -1;
    if (g_CaptainTeam[CAP_A] == CS_TEAM_T) capT = g_CaptainPlayer[CAP_A];
    if (g_CaptainTeam[CAP_A] == CS_TEAM_CT) capCT = g_CaptainPlayer[CAP_A];
    if (g_CaptainTeam[CAP_B] == CS_TEAM_T) capT = g_CaptainPlayer[CAP_B];
    if (g_CaptainTeam[CAP_B] == CS_TEAM_CT) capCT = g_CaptainPlayer[CAP_B];

    new capTName[32], capCTName[32];
    if (capT > 0) get_user_name(capT, capTName, charsmax(capTName)); else copy(capTName, charsmax(capTName), "T Captain");
    if (capCT > 0) get_user_name(capCT, capCTName, charsmax(capCTName)); else copy(capCTName, charsmax(capCTName), "CT Captain");

    new tRoster[384]; BuildRosterForTeam(CS_TEAM_T, tRoster, charsmax(tRoster), capT);
    new ctRoster[384]; BuildRosterForTeam(CS_TEAM_CT, ctRoster, charsmax(ctRoster), capCT);

    formatex(left, llen,  "Captain: %s^n^n%s", capTName, tRoster);
    formatex(right, rlen, "Captain: %s^n^n%s", capCTName, ctRoster);
}

stock BuildRosterForTeam(CsTeams:team, out[], outlen, capId)
{
    out[0] = '^0';
    new players[32], pnum; get_players(players, pnum, "ch");
    new line[64];

    for (new i = 0; i < pnum; i++)
    {
        new id = players[i];
        if (cs_get_user_team(id) != team) continue;
        if (id == capId) continue; 

        new name[32]; get_user_name(id, name, charsmax(name));
        formatex(line, charsmax(line), "%s^n", name);
        add(out, outlen, line);
    }
}

// Give the pick menu to the captain whose turn it is
public Task_GivePickMenu()
{
    if (g_MatchStatus != MS_TEAMSELECTION) return;

    new specs[32], scount;
    GetHumanSpecList(specs, scount);

    if (scount <= 0)
    {
        FinishTeamsAndStart();
        return;
    }

    new picker = g_CaptainPlayer[g_CurrentPickerSlot];

    if (!is_user_connected(picker))
    {
        set_task(4.0, "Task_GivePickMenu", TASK_TEAMSEL_GIVE_MENU);
        return;
    }

    if (g_PickMenu != INVALID_HANDLE) menu_destroy(g_PickMenu);
    g_PickMenu = menu_create("Pick your teammate", "PickMenu_Handler");

    new specs2[32], scount2; GetHumanSpecList(specs2, scount2);
    if (scount2 <= 0) { menu_destroy(g_PickMenu); FinishTeamsAndStart(); return; }

    for (new i = 0; i < scount2; i++)
    {
        new id = specs2[i];
        new name[32]; get_user_name(id, name, charsmax(name));
        new info[8]; num_to_str(id, info, charsmax(info));
        menu_additem(g_PickMenu, name, info);
    }

    g_PickInProgress = true;
    menu_display(picker, g_PickMenu, 0);
}

public PickMenu_Handler(id, menu, item)
{
    if (menu != g_PickMenu) { if (menu != INVALID_HANDLE) menu_destroy(menu); return PLUGIN_HANDLED; }
    if (item == MENU_EXIT)  { menu_destroy(g_PickMenu); g_PickMenu = INVALID_HANDLE; g_PickInProgress = false; return PLUGIN_HANDLED; }

    if (id != g_CaptainPlayer[g_CurrentPickerSlot])
    {
        // Not your turn
        client_print_color(id, print_team_default, "^4%s^1 It is not your turn.", g_ChatPrefix);
        menu_destroy(g_PickMenu); g_PickMenu = INVALID_HANDLE; g_PickInProgress = false;
        return PLUGIN_HANDLED;
    }

    new info[8], name_buf[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name_buf, charsmax(name_buf), callback);
    menu_destroy(g_PickMenu); g_PickMenu = INVALID_HANDLE; g_PickInProgress = false;

    new pickId = str_to_num(info);
    if (!is_user_connected(pickId) || cs_get_user_team(pickId) != CS_TEAM_SPECTATOR)
    {
        set_task(0.8, "Task_GivePickMenu", TASK_TEAMSEL_GIVE_MENU);
        return PLUGIN_HANDLED;
    }

    cs_set_user_team(pickId, g_CaptainTeam[g_CurrentPickerSlot]);
    if (is_user_alive(pickId)) user_kill(pickId, 1);

    // Announce selection
    client_print_color(0, print_team_default,
        "^4%s^1 ^3%n^1 selected ^3%n^1.", g_ChatPrefix, id, pickId);

    // If no specs left now, finish
    if (CountHumanSpecs() == 0)
    {
        FinishTeamsAndStart();
        return PLUGIN_HANDLED;
    }

    g_CurrentPickerSlot = DecideNextPicker(g_CurrentPickerSlot);

    if (task_exists(TASK_TEAMSEL_GIVE_MENU)) remove_task(TASK_TEAMSEL_GIVE_MENU);
    set_task(TEAMSEL_MENU_DELAY, "Task_GivePickMenu", TASK_TEAMSEL_GIVE_MENU);

    return PLUGIN_HANDLED;
}

stock CaptainSlot:DecideNextPicker(CaptainSlot:lastPicker)
{
    new aTeam = g_CaptainTeam[CAP_A], bTeam = g_CaptainTeam[CAP_B];
    new aCnt = CountNonCaptainPlayers(aTeam, g_CaptainPlayer[CAP_A]);
    new bCnt = CountNonCaptainPlayers(bTeam, g_CaptainPlayer[CAP_B]);

    if (aCnt - bCnt > 1) return CAP_B;
    if (bCnt - aCnt > 1) return CAP_A;

    return (lastPicker == CAP_A) ? CAP_B : CAP_A;
}

stock CountNonCaptainPlayers(CsTeams:team, capId)
{
    new players[32], pnum; get_players(players, pnum, "ch");
    new cnt = 0;
    for (new i = 0; i < pnum; i++)
    {
        new id = players[i];
        if (cs_get_user_team(id) != team) continue;
        if (id == capId) continue;
        cnt++;
    }
    return cnt;
}

stock CountHumanSpecs()
{
    new specs[32], sc; GetHumanSpecList(specs, sc);
    return sc;
}

stock GetHumanSpecList(out[], &count)
{
    new p[32], n;
    get_players(p, n, "c");

    count = 0;
    for (new i = 0; i < n; i++)
    {
        new id = p[i];

        if (!is_user_connected(id)) continue;

        #if defined PLUGIN_has_is_user_bot
        if (is_user_bot(id)) continue; 
        #endif

        new team = cs_get_user_team(id);
        if (team == CS_TEAM_SPECTATOR || team == 0)
        {
            out[count++] = id;
        }
    }
}

stock ForceAllDead()
{
    new p[32], n; get_players(p, n, "ch");
    for (new i = 0; i < n; i++)
    {
        new id = p[i];
        if (is_user_alive(id)) user_kill(id, 1);
    }
}

stock FinishTeamsAndStart()
{
    set_task(TEAMSEL_FINISH_SHINE, "Task_AfterShine", TASK_TEAMSEL_FINALIZE);
}

public Task_AfterShine()
{

    if (task_exists(TASK_TEAMSEL_HUD)) remove_task(TASK_TEAMSEL_HUD);

    server_cmd("sv_restart 1");

    set_dhudmessage(0, 255, 128, -1.0, 0.10, 0, 0.0, 2.5, 0.0, 0.0);
    show_dhudmessage(0, "All teams set, match will begin now");

    if (task_exists(TASK_FIRSTHALF_INIT)) remove_task(TASK_FIRSTHALF_INIT);
    set_task(3.0, "FirstHalfInitial", TASK_FIRSTHALF_INIT);

}

public FirstHalfInitial()
{
    g_MatchStatus  = MS_FIRSTHALFINITIAL;

    MarkGameDescDirty(true)
    server_cmd("exec %s", gCvarExecAutomix);
    ApplyHalfTagsForAll();

    // Reset state for first half
    g_ScoreLocked   = true;   // lock 
    g_HalfRound     = 0;
    g_TotalRounds   = 0;
    g_TeamA_CS      = CS_TEAM_T;
    g_TeamB_CS      = CS_TEAM_CT;

    FirstHalf_IntroEffects();

    set_task(3.7, "FirstHalf_GoLive");
}

public Cmd_GetMenu(id)
{
    if (g_MatchStatus != MS_TEAMSELECTION) return PLUGIN_CONTINUE;

    if (id == g_CaptainPlayer[g_CurrentPickerSlot])
    {
        if (task_exists(TASK_TEAMSEL_GIVE_MENU)) remove_task(TASK_TEAMSEL_GIVE_MENU);
        set_task(0.2, "Task_GivePickMenu", TASK_TEAMSEL_GIVE_MENU);
    }
    else
    {
        client_print_color(id, print_team_default,
            "^4%s^1 It's not your turn. Ask the other captain to use ^3/getmenu^1.", g_ChatPrefix);
    }
    return PLUGIN_HANDLED;
}


// FIRST HALF 
stock FirstHalf_IntroEffects()
{
    FirstHalf_BannerStep(0, "First half is about to start");
    FirstHalf_BannerStep(1, "First half is about to start");
    FirstHalf_BannerStep(2, "First half is about to start");

    set_task(0.2, "FX_Beep", TASK_FH_EFFECTS_BASE+1);
    set_task(0.3, "FX_Restart", TASK_FH_EFFECTS_BASE+2); // sv_restart 1
    set_task(1.6, "FX_Beep", TASK_FH_EFFECTS_BASE+3);
    set_task(1.7, "FX_Restart", TASK_FH_EFFECTS_BASE+4);
}

stock FirstHalf_BannerStep(step, const text[])
{
    new Float:y = 0.10 + floatmul(float(step), 0.05);
    set_task(floatmul(float(step), 0.3), "Task_ShowBannerFH", TASK_FH_EFFECTS_BASE+10+step, text, strlen(text)+1);
}

public Task_ShowBannerFH(const text[])
{
    static callCount = 0;
    new Float:y = 0.10 + floatmul(float(callCount), 0.05);
    if (callCount >= 2) callCount = 0; else callCount++;

    set_dhudmessage(255, 220, 160, -1.0, y, 0, 0.0, 1.2, 0.0, 0.0);
    show_dhudmessage(0, text);
}

public FX_Beep()     { client_cmd(0, "spk %s", SND_PHASE_BEEP); }
public FX_Restart()  { server_cmd("sv_restart 1"); }

public FirstHalf_GoLive()
{

    g_MatchStatus  = MS_FIRSTHALF;
    g_ScoreLocked = false; 
    Stats_BeginFirstHalf()
    MarkGameDescDirty(true)

    client_print_color(0, print_team_default, "^4%s^1 It's ^3LIVE LIVE LIVE^1 — ^3GOGOGOGOGO^1!", g_ChatPrefix);

    // First round index
    g_HalfRound   = 1;
    g_TotalRounds = 1;


    ShowRoundStartHUD();
    StartLiveScroll(4.0)
}

public EV_RoundStart()
{
    if (g_MatchStatus != MS_FIRSTHALF && g_MatchStatus != MS_SECONDHALF) return;

    g_ScoreLocked = false;
    g_LastPlanter = 0;

    // Increment round counters
    if (g_MatchStatus == MS_FIRSTHALF)
    {
        if (g_HalfRound < 15)
        {
            if (g_TotalRounds > 0) { g_HalfRound++; g_TotalRounds++; }
        }
        // Last-round warning for first half
        if (g_HalfRound == 15)
        {
            client_print_color(0, print_team_default, "^4%s^1 ^3Last round of First Half^1!", g_ChatPrefix);
            set_dhudmessage(255, 180, 180, -1.0, 0.12, 0, 0.0, 3.0, 0.0, 0.0);
            show_dhudmessage(0, "Last round of First Half");
        }
    }
    else if((g_MatchStatus == MS_SECONDHALF))
    {
        if (g_HalfRound < 15)
        {
            if (g_TotalRounds > 15) { g_HalfRound++; g_TotalRounds++; }
        }
        // Last round of the map (round 30 overall)
        if (g_HalfRound == 15)
        {
            client_print_color(0, print_team_default, "^4%s^1 ^3Last round of the map^1!", g_ChatPrefix);
            set_dhudmessage(255, 255, 180, -1.0, 0.12, 0, 0.0, 3.0, 0.0, 0.0);
            show_dhudmessage(0, "Last round of the map");
        }
    }

    // Round-start scoreboard
    ShowRoundStartHUD();

    AnnounceLeaderChat();

    ShowRoundNumberHUD();
}

// Detect T win
public EV_TerWin()
{
    OnRoundWinner(CS_TEAM_T);
}

// Detect CT win
public EV_CtWin()
{
    OnRoundWinner(CS_TEAM_CT);
}

stock OnRoundWinner(CsTeams:winnerCS)
{
    
    if (g_ScoreLocked) return; 
    if (g_MatchStatus != MS_FIRSTHALF && g_MatchStatus != MS_SECONDHALF) return;

    MarkGameDescDirty(true)

    if (winnerCS == g_TeamA_CS) g_ScoreA++;
    else if (winnerCS == g_TeamB_CS) g_ScoreB++;

    g_ScoreLocked = true;

    MarkGameDescDirty(true)

    if (g_MatchStatus == MS_FIRSTHALF && g_HalfRound >= 15)
    {
        // lock & go halftime
        Stats_LockAtHalftime()
        BeginHalftimeSwap();
        return;
    }

    if (g_MatchStatus == MS_SECONDHALF)
    {
        if (g_ScoreA >= 16 || g_ScoreB >= 16)
        {
            EndMatchDeclareWinner();
            return;
        }

        if ((g_ScoreA + g_ScoreB) >= 30)
        {
            EndMatchDeclareWinner();
            return;
        }
    }
}

stock ShowRoundStartHUD()
{
    new line[96];
    formatex(line, charsmax(line), "Team [A] - %02d  ||  Team [B] - %02d", g_ScoreA, g_ScoreB);

    set_dhudmessage(200, 230, 255, -1.0, 0.11, 0, 0.0, 4.0, 0.0, 0.0);
    show_dhudmessage(0, line);

    client_print_color(0, print_team_default, "^4%s^1 Team ^3[A]^1 - ^3%02d^1  ||  Team ^3[B]^1 - ^3%02d^1.", g_ChatPrefix, g_ScoreA, g_ScoreB);

    if (g_MatchStatus == MS_SECONDHALF)
    {
        new needA = 16 - g_ScoreA;
        new needB = 16 - g_ScoreB;
        if (needA < 0) needA = 0;
        if (needB < 0) needB = 0;

        if (needA > 0)
            client_print_color(0, print_team_default, "^4%s^1 Team ^3[A]^1 needs ^3%d^1 round%s to win.", g_ChatPrefix, needA, (needA == 1 ? "" : "s"));
        if (needB > 0)
            client_print_color(0, print_team_default, "^4%s^1 Team ^3[B]^1 needs ^3%d^1 round%s to comeback.", g_ChatPrefix, needB, (needB == 1 ? "" : "s"));
    }
}

stock AnnounceLeaderChat()
{
    if (g_ScoreA > g_ScoreB)
        client_print_color(0, print_team_default, "^4%s^1 Team ^3[A]^1 is leading.", g_ChatPrefix);
    else if (g_ScoreB > g_ScoreA)
        client_print_color(0, print_team_default, "^4%s^1 Team ^3[B]^1 is leading.", g_ChatPrefix);
    else
        client_print_color(0, print_team_default, "^4%s^1 Scores are tied.", g_ChatPrefix);
}


// HALFTIME SWAP
stock BeginHalftimeSwap()
{
    if (g_MatchStatus != MS_FIRSTHALF) return;

    g_MatchStatus = MS_HALFSWAP;

    g_ScoreLocked = true;      // keep locked until we go live

    MarkGameDescDirty(true)

    client_print_color(0, print_team_default, "^4%s^1 First half is over. Swapping teams for second half...", g_ChatPrefix);
    set_dhudmessage(255, 255, 180, -1.0, 0.12, 0, 0.0, 5.0, 0.0, 0.0);
    show_dhudmessage(0, "First half is over^nSwapping teams for second half...");

    SwapAllPlayersTeams();

    g_TeamA_CS = CS_TEAM_CT;
    g_TeamB_CS = CS_TEAM_T;

    set_task(2.0, "Task_SecondHalfInit");
}

public Task_SecondHalfInit()
{
    g_MatchStatus  = MS_SECONDHALFINITIAL;
    
    g_HalfRound   = 0;        

    MarkGameDescDirty(true)

    SecondHalf_IntroEffects();

    ApplyHalfTagsForAll();

    remove_task(TASK_WAIT_2NDHALF);
    set_task(1.0, "SecondHalf_WaitForPlayers", TASK_WAIT_2NDHALF, "", 0, "b");
}

stock SecondHalf_IntroEffects()
{
    SecondHalf_BannerStep(0, "Second half starting soon");
    SecondHalf_BannerStep(1, "Second half starting soon");
    SecondHalf_BannerStep(2, "Second half starting soon");

    set_task(0.2, "FX_Beep", TASK_SH_EFFECTS_BASE+1);
    set_task(0.3, "FX_Restart", TASK_SH_EFFECTS_BASE+2);
    set_task(1.6, "FX_Beep", TASK_SH_EFFECTS_BASE+3);
    set_task(1.7, "FX_Restart", TASK_SH_EFFECTS_BASE+4);
}

stock SecondHalf_BannerStep(step, const text[])
{
    new Float:y = 0.10 + floatmul(float(step), 0.05);
    set_task(floatmul(float(step), 0.3), "Task_ShowBannerSH", TASK_SH_EFFECTS_BASE+10+step, text, strlen(text)+1);
}
public Task_ShowBannerSH(const text[])
{
    static callCount = 0;
    new Float:y = 0.10 + floatmul(float(callCount), 0.05);
    if (callCount >= 2) callCount = 0; else callCount++;

    set_dhudmessage(200, 255, 200, -1.0, y, 0, 0.0, 1.2, 0.0, 0.0);
    show_dhudmessage(0, text);
}

public SecondHalf_WaitForPlayers()
{
    if (g_MatchStatus != MS_SECONDHALFINITIAL) { remove_task(TASK_WAIT_2NDHALF); return; }

    new need = get_pcvar_num(g_pCvarMinPlayers);
    if (need < 0) need = 0;

    new players[32], pnum, humans = 0;
    get_players(players, pnum, "bch");
    for (new i = 0; i < pnum; i++)
    {
        new tm = _:cs_get_user_team(players[i]);
        if (tm == CS_TEAM_T || tm == CS_TEAM_CT) humans++;
    }

    if (humans >= need && need > 0)
    {
        remove_task(TASK_WAIT_2NDHALF);
        SecondHalf_GoLive();
        return;
    }

    new diff = (need > humans) ? (need - humans) : 0;
    new msg[96];
    formatex(msg, charsmax(msg), "Waiting for %d player%s before starting second half", diff, (diff == 1 ? "" : "s"));
    set_dhudmessage(255, 255, 180, -1.0, 0.12, 0, 0.0, 1.0, 0.0, 0.0);
    show_dhudmessage(0, msg);
}

stock SecondHalf_GoLive()
{
    if (g_MatchStatus != MS_SECONDHALFINITIAL) return;

    g_MatchStatus  = MS_SECONDHALF;
    g_ScoreLocked = false;  
    g_HalfRound   = 1;
    g_TotalRounds = 16;
    Stats_UnlockSecondHalf()

    MarkGameDescDirty(true)

    client_print_color(0, print_team_default, "^4%s^1 Second half is ^3LIVE^1!", g_ChatPrefix);
    ShowRoundStartHUD();

    StartLiveScroll(4.0)
}

// MATCH END
stock EndMatchDeclareWinner()
{
    // Figure winner/draw
    new msg[128];
    if (g_ScoreA > g_ScoreB)
    {
        formatex(msg, charsmax(msg), "Team [A] Wins!  %02d - %02d", g_ScoreA, g_ScoreB);
        client_print_color(0, print_team_default, "^4%s^1 ^3Team [A]^1 wins! ^3%02d^1-^3%02d^1.",g_ChatPrefix,  g_ScoreA, g_ScoreB);
    }
    else if (g_ScoreB > g_ScoreA)
    {
        formatex(msg, charsmax(msg), "Team [B] Wins!  %02d - %02d", g_ScoreB, g_ScoreA);
        client_print_color(0, print_team_default, "^4%s^1 ^3Team [B]^1 wins! ^3%02d^1-^3%02d^1.",g_ChatPrefix, g_ScoreB, g_ScoreA);
    }
    else
    {
        formatex(msg, charsmax(msg), "Match Draw  %02d - %02d", g_ScoreA, g_ScoreB);
        client_print_color(0, print_team_default, "^4%s^1 Match is a ^3DRAW^1 — ^3%02d^1-^3%02d^1.",g_ChatPrefix,  g_ScoreA, g_ScoreB);
    }

    set_dhudmessage(255, 255, 180, -1.0, 0.12, 0, 0.0, 10.0, 0.0, 0.0);
    show_dhudmessage(0, msg);

    set_task(1.0, "FX_Restart");
    set_task(1.1, "FX_Beep");
    server_cmd("exec %s", gCvarExecPub);

    StripAllTagsForAll();

    g_MatchEnded = true;
    MarkGameDescDirty(true);

    set_task(1.0, "Task_ShowMatchStats");
}


// UTILITIES: swap, tags, reapply, etc.
stock SwapAllPlayersTeams()
{
    new players[32], pnum; get_players(players, pnum, "bch");
    for (new i = 0; i < pnum; i++)
    {
        new id = players[i];
        new CsTeams:tm = cs_get_user_team(id);
        if (tm == CS_TEAM_T)       cs_set_user_team(id, CS_TEAM_CT);
        else if (tm == CS_TEAM_CT) cs_set_user_team(id, CS_TEAM_T);
    }
}

stock AutoAssignToSmallerTeam(id)
{
    // Count T vs CT
    new players[32], pnum; get_players(players, pnum, "bch");
    new t=0, ct=0;
    for (new i = 0; i < pnum; i++)
    {
        new tm = _:cs_get_user_team(players[i]);
        if (tm == CS_TEAM_T) t++;
        else if (tm == CS_TEAM_CT) ct++;
    }
    if (t <= ct) cs_set_user_team(id, CS_TEAM_T);
    else         cs_set_user_team(id, CS_TEAM_CT);
}

stock Stats_BeginFirstHalf()
{
    Stats_Reset();
    g_StatsLocked  = false;
    g_StatsEnabled = true;
}

stock Stats_LockAtHalftime()
{
    g_StatsLocked = true; 
}

stock Stats_UnlockSecondHalf()
{
    if (!g_StatsEnabled) g_StatsEnabled = true;
    g_StatsLocked = false;
}

public Task_StatsFlowDone()
{
    StartMapVote()
    Stats_Reset();
}

public LE_BombPlanted()
{
    if (!g_StatsEnabled || g_StatsLocked) return;

    new planter = FindCurrentPlanter();
    if (planter > 0)
    {
        g_Plants[planter]++;
        g_LastPlanter = planter;
        get_user_name(planter, g_NameCache[planter], charsmax(g_NameCache[]));
    }
}

public LE_BombExploded()
{
    if (!g_StatsEnabled || g_StatsLocked) return;

    if (g_LastPlanter && is_user_connected(g_LastPlanter))
    {
        g_SuccessPlants[g_LastPlanter]++;
    }
    g_LastPlanter = 0;
}

public LE_BombDefused()
{
    g_LastPlanter = 0;
}

// STATS DISPLAY
public Task_ShowStatsPage1()
{
    new mvp = FindMVP();

    new mk = FindTopIndex(g_Kills);
    new mhs = FindTopIndex(g_HSKills);

    new line[192], n1[32], n2[32], n3[32];
    GetDisplayName(mvp, n1, charsmax(n1));
    GetDisplayName(mk,  n2, charsmax(n2));
    GetDisplayName(mhs, n3, charsmax(n3));

    formatex(line, charsmax(line),
        "MATCH STATS (1/2)^nMVP: %s  (Kills: %d, HS: %d, Deaths: %d)^nMost Kills: %s  (%d)^nMost Headshots: %s  (%d)",
        n1, g_Kills[mvp], g_HSKills[mvp], g_Deaths[mvp],
        n2, g_Kills[mk],
        n3, g_HSKills[mhs]);

    set_hudmessage(200, 255, 200, -1.0, 0.4, 0, 0.0, 5.0, 0.0, 0.0);
    show_hudmessage(0, line);

}

public Task_ShowStatsPage2()
{
    new mkf = FindTopIndex(g_KnifeKills);
    new mhe = FindTopIndex(g_HEKills);
    new mknifed = FindTopIndex(g_KnifedDeaths);
    new mplant = FindTopIndex(g_SuccessPlants);
    new mbot  = FindBottomIndex(g_Kills); // least kills

    new line[224], a[32], b[32], c[32], d[32], e[32];
    GetDisplayName(mkf, a, charsmax(a));
    GetDisplayName(mhe, b, charsmax(b));
    GetDisplayName(mknifed, c, charsmax(c));
    GetDisplayName(mplant, d, charsmax(d));
    GetDisplayName(mbot, e, charsmax(e));

    formatex(line, charsmax(line),
        "MATCH STATS (2/2)^nKnife Master: %s  (%d)^nHE Grenadier: %s  (%d)^nMost Knifed: %s  (%d)^nSuccessful Plants: %s  (%d)^nBot of the Match: %s  (Kills: %d)",
        a, g_KnifeKills[mkf],
        b, g_HEKills[mhe],
        c, g_KnifedDeaths[mknifed],
        d, g_SuccessPlants[mplant],
        e, g_Kills[mbot]);

    set_hudmessage(255, 220, 180, -1.0, 0.4, 0, 0.0, 5.0, 0.0, 0.0);
    show_hudmessage(0, line);
}

// HELPERS — winners, names, reset
stock GetDisplayName(id, out[], len)
{
    if (id > 0 && id <= MAX_PLAYERS)
    {
        if (g_NameCache[id][0]) copy(out, len, g_NameCache[id]);
        else if (is_user_connected(id)) get_user_name(id, out, len);
        else copy(out, len, "—");
    }
    else copy(out, len, "—");
}

stock FindTopIndex(const arr[])
{
    new best = 0, bestv = -99999;
    for (new i = 1; i <= MAX_PLAYERS; i++)
    {
        if (arr[i] > bestv) { bestv = arr[i]; best = i; }
    }
    //return best ? best : 1; // fallback to 1
    return best; //return 0 when not found
}

stock FindBottomIndex(const arr[])
{
    new worst = 0, worstv = 99999, initialized = 0;
    for (new i = 1; i <= MAX_PLAYERS; i++)
    {
        if (!g_NameCache[i][0] && !arr[i] && !g_Deaths[i] && !g_HSKills[i]) continue;

        if (!initialized || arr[i] < worstv) { worstv = arr[i]; worst = i; initialized = 1; }
    }
    return initialized ? worst : 1;
}

stock FindMVP()
{
    new idx = 0;
    new bestKills = -1, bestHS = -1, bestDeaths = 99999;

    for (new i = 1; i <= MAX_PLAYERS; i++)
    {
        if (!g_NameCache[i][0] && !g_Kills[i] && !g_Deaths[i]) continue;

        if (g_Kills[i] > bestKills
            || (g_Kills[i] == bestKills && g_HSKills[i] > bestHS)
            || (g_Kills[i] == bestKills && g_HSKills[i] == bestHS && g_Deaths[i] < bestDeaths))
        {
            bestKills  = g_Kills[i];
            bestHS     = g_HSKills[i];
            bestDeaths = g_Deaths[i];
            idx = i;
        }
    }
    return idx ? idx : FindTopIndex(g_Kills);
}

stock FindCurrentPlanter()
{
    new players[32], pnum; get_players(players, pnum, "bch");
    new candidate = 0;

    for (new i = 0; i < pnum; i++)
    {
        new id = players[i];
        if (cs_get_user_team(id) != CS_TEAM_T) continue;

        if (user_has_weapon(id, CSW_C4)) {
            candidate = id;
            break;
        }
    }

    if (!candidate)
    {
        for (new i = 0; i < pnum; i++)
        {
            new id = players[i];
            if (cs_get_user_team(id) == CS_TEAM_T) { candidate = id; break; }
        }
    }
    return candidate;
}

stock Stats_Reset()
{
    if(g_MatchStatus  != MS_FIRSTHALF)
    {
        g_StatsEnabled = false;
        g_StatsLocked  = true;
        
    }

    g_LastPlanter  = 0;

    for (new i = 1; i <= MAX_PLAYERS; i++)
    {
        g_Kills[i] = g_Deaths[i] = g_HSKills[i] = 0;
        g_KnifeKills[i] = g_HEKills[i] = 0;
        g_KnifedDeaths[i] = 0;
        g_Plants[i] = g_SuccessPlants[i] = 0;
        g_NameCache[i][0] = 0;
    }

    g_MatchEnded = false;
    MarkGameDescDirty(true);
}

public FW_ClientUserInfoChanged(id, buffer)
{
    if (!is_user_connected(id)) return FMRES_IGNORED;

    static newname[32];
    get_user_info(id, "name", newname, charsmax(newname));
    if (newname[0]) copy(g_NameCache[id], charsmax(g_NameCache[]), newname);

    return FMRES_IGNORED;
}

public Task_ShowMatchStats()
{
    g_StatsLocked = true;

    Task_ShowStatsPage1();
    set_task(5.0, "Task_ShowStatsPage2", TASK_STATS_PAGE2);
    set_task(10.0, "Task_StatsFlowDone", TASK_STATS_DONE);
}

public Cmd_SwapRequest(id) {
    if (!is_user_connected(id)) return PLUGIN_HANDLED;

    if (!(g_MatchStatus == MS_FIRSTHALFINITIAL || 
         (g_MatchStatus == MS_FIRSTHALF && g_HalfRound < 2))) {
        client_print_color(id, print_team_default, "^4%s^1 Swap requests not allowed now.", g_ChatPrefix);
        return PLUGIN_HANDLED;
    }

    // Already pending?
    if (g_SwapPending[id]) {
        client_print_color(id, print_team_default, "^4%s^1 You already have a pending swap.", g_ChatPrefix);
        return PLUGIN_HANDLED;
    }

    // Build menu of opponents
    new CsTeams:myTeam = cs_get_user_team(id);
    if (myTeam != CS_TEAM_T && myTeam != CS_TEAM_CT) {
        client_print_color(id, print_team_default, "^4%s^1 You must be in a team to swap.", g_ChatPrefix);
        return PLUGIN_HANDLED;
    }

    new title[64]; formatex(title, charsmax(title), "Swap with which opponent?");
    new menu = menu_create(title, "SwapMenu_Handler");

    new players[32], pnum;
    get_players(players, pnum, "ch"); 
    for (new i=0; i<pnum; i++) {
        new pid = players[i];
        if (pid == id) continue;
        if (cs_get_user_team(pid) != CS_TEAM_T && cs_get_user_team(pid) != CS_TEAM_CT) continue;
        if (cs_get_user_team(pid) == myTeam) continue; // same team 

        new name[32], info[8];
        get_user_name(pid, name, charsmax(name));
        num_to_str(pid, info, charsmax(info));
        menu_additem(menu, name, info);
    }

    if (menu_items(menu) == 0) {
        client_print_color(id, print_team_default, "^4%s^1 No opponents available to swap.", g_ChatPrefix);
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public SwapMenu_Handler(id, menu, item) {
    if (item == MENU_EXIT || item == -1) return PLUGIN_HANDLED;

    new info[8], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
    new target = str_to_num(info);

    if (!is_user_connected(target)) {
        client_print_color(id, print_team_default, "^4%s^1 Target player left.", g_ChatPrefix);
        return PLUGIN_HANDLED;
    }

    g_SwapTarget[id]    = target;
    g_SwapPending[id]   = true;

    new reqName[32]; get_user_name(id, reqName, charsmax(reqName));
    new title[64]; formatex(title, charsmax(title), "Swap with %s?", reqName);

    new confMenu = menu_create(title, "SwapConfirm_Handler");
    menu_additem(confMenu, "Yes, swap", "1");
    menu_additem(confMenu, "No, stay", "0");

    menu_setprop(confMenu, MPROP_EXIT, MEXIT_NEVER); 
    menu_display(target, confMenu);

    return PLUGIN_HANDLED;
}

public SwapConfirm_Handler(id, menu, item) {
   
    new requester = 0;
    for (new i=1; i<=32; i++) {
        if (g_SwapTarget[i] == id && g_SwapPending[i]) {
            requester = i;
            break;
        }
    }
    if (!requester) return PLUGIN_HANDLED;

    if (item == -1) {
    
        SwapMenu_Redisplay(id, requester);
        return PLUGIN_HANDLED;
    }

    new info[8], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);

    if (equal(info, "1")) {
    
        DoSwapPlayers(requester, id);
    } else {
        client_print_color(requester, print_team_default, "^4%s^1 ^3%s^1 declined your swap request.", g_ChatPrefix, g_NameCache[id]);
        client_print_color(id, print_team_default, "^4%s^1 You declined the swap.",g_ChatPrefix);
    }

 
    g_SwapPending[requester] = false;
    g_SwapTarget[requester] = 0;

    return PLUGIN_HANDLED;
}

stock SwapMenu_Redisplay(target, requester) {
    if (!is_user_connected(target) || !is_user_connected(requester)) return;

    new reqName[32]; get_user_name(requester, reqName, charsmax(reqName));
    new title[64]; formatex(title, charsmax(title), "Swap with %s?", reqName);

    new confMenu = menu_create(title, "SwapConfirm_Handler");
    menu_additem(confMenu, "Yes, swap", "1");
    menu_additem(confMenu, "No, stay", "0");

    menu_setprop(confMenu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(target, confMenu);
}

stock DoSwapPlayers(id1, id2) {
    if (!is_user_connected(id1) || !is_user_connected(id2)) return;

    new CsTeams:t1 = cs_get_user_team(id1);
    new CsTeams:t2 = cs_get_user_team(id2);

    if (t1 == t2) return; // no sense

    cs_set_user_team(id1, t2);
    cs_set_user_team(id2, t1);

    set_task(0.2, "Task_ApplyHalfTag", TASK_SWAP_BASE + id1);
    set_task(0.2, "Task_ApplyHalfTag", TASK_SWAP_BASE + id2);

    new n1[32], n2[32];
    get_user_name(id1, n1, charsmax(n1));
    get_user_name(id2, n2, charsmax(n2));

    client_print_color(0, print_team_default, "^4%s^1 ^3%s^1 swapped teams with ^3%s^1.",g_ChatPrefix, n1, n2);
    client_print_color(0, print_team_default, "^4%s^1 Using ^3/swap, you can swap teams with anyone before Round 2 ends", g_ChatPrefix);
}

stock ApplyHalfTagForUser(id)
{
    if (!is_user_connected(id)) return;

    new bool:firstHalf = (g_MatchStatus == MS_FIRSTHALF || g_MatchStatus == MS_FIRSTHALFINITIAL);
    new CsTeams:tm = cs_get_user_team(id);

    if (tm == CS_TEAM_T)
    {
        StripThenSetTag(id, firstHalf ? TAG_A_STR : TAG_B_STR);
    }
    else if (tm == CS_TEAM_CT)
    {
        StripThenSetTag(id, firstHalf ? TAG_B_STR : TAG_A_STR);
    }
    else
    {
        StripThenSetTag(id, "");
    }
}

public Task_ApplyHalfTag(taskid)
{
    new id = taskid - TASK_SWAP_BASE;
    if (id < 1 || id > get_maxplayers()) return;
    if (!is_user_connected(id)) return;
    ApplyHalfTagForUser(id);
}


stock ApplyHalfTagsForAll()
{
    new bool:firstHalf = (g_MatchStatus == MS_FIRSTHALF || g_MatchStatus == MS_FIRSTHALFINITIAL);

    new maxp = get_maxplayers();
    for (new id = 1; id <= maxp; id++)
    {
        if (!is_user_connected(id)) continue;

        new CsTeams:tm = cs_get_user_team(id);

        if (tm == CS_TEAM_T)
        {
            StripThenSetTag(id, firstHalf ? TAG_A_STR : TAG_B_STR);
        }
        else if (tm == CS_TEAM_CT)
        {
            StripThenSetTag(id, firstHalf ? TAG_B_STR : TAG_A_STR);
        }
        else
        {
            StripThenSetTag(id, "");
        }
    }
}


stock StartJoinTagFlow(id)
{
    if (!is_user_connected(id)) return;
    g_TagRetry[id] = 0;
    remove_task(TASK_TAG_BASE + id);
    set_task(TAG_DELAY, "Task_AttemptJoinTag", TASK_TAG_BASE + id);
}

public Task_AttemptJoinTag(taskid)
{
    new id = taskid - TASK_TAG_BASE;
    if (id < 1 || id > 32 || !is_user_connected(id)) return;

    new CsTeams:tm = cs_get_user_team(id);
    if (tm != CS_TEAM_T && tm != CS_TEAM_CT)
    {
        if (++g_TagRetry[id] <= MAX_RETRIES)
            set_task(TAG_DELAY, "Task_AttemptJoinTag", TASK_TAG_BASE + id);
        return;
    }

    if (g_MatchStatus == MS_FIRSTHALFINITIAL || g_MatchStatus == MS_FIRSTHALF)
    {
        StripThenSetTag(id, (tm == CS_TEAM_T) ? TAG_A_STR : TAG_B_STR);
    }
    else if (g_MatchStatus == MS_SECONDHALFINITIAL || g_MatchStatus == MS_SECONDHALF)
    {
        StripThenSetTag(id, (tm == CS_TEAM_T) ? TAG_B_STR : TAG_A_STR);
    }
    else
    {
        StripThenSetTag(id, "");
    }
}

stock StripAllTagsForAll()
{
    new maxp = get_maxplayers();
    for (new id = 1; id <= maxp; id++)
    {
        if (!is_user_connected(id)) continue;
        StripThenSetTag(id, "");
    }
}

stock StripThenSetTag(id, const prefix[])
{
    if (!is_user_connected(id)) return;

    new name[64];
    get_user_name(id, name, charsmax(name));

    while (starts_with(name, TAG_A_STR) || starts_with(name, TAG_B_STR))
    {
        if (starts_with(name, TAG_A_STR)) strip_leading(name, TAG_A_STR);
        else                               strip_leading(name, TAG_B_STR);
    }

    if (prefix[0] && starts_with(name, prefix))
        return;

    const MAX_GAME_NAME = 31; 
    new baseAllowed = MAX_GAME_NAME - strlen(prefix);
    if (baseAllowed < 0) baseAllowed = 0;

    if (strlen(name) > baseAllowed)
        name[baseAllowed] = 0; // hard truncate

    new finalname[64];
    if (prefix[0])
        formatex(finalname, charsmax(finalname), "%s%s", prefix, name);
    else
        copy(finalname, charsmax(finalname), name);

    set_user_info(id, "name", finalname);
}

stock bool:starts_with(const s[], const pre[])
{
    return (equal(s, pre, strlen(pre)) != 0);
}

stock strip_leading(s[], const lead[])
{
    new L = strlen(lead), n = strlen(s);
    if (n >= L && equal(s, lead, L))
    {
        for (new i = 0; i <= n - L; i++)
            s[i] = s[i + L];
    }
}

stock ShowRoundNumberHUD()
{
    formatex(g_RoundHUDText, charsmax(g_RoundHUDText), "Round %02d", g_TotalRounds);

    g_RoundHUDSteps = 8;
    g_RoundHUDColorIdx = 0;

    if (task_exists(TASK_ROUNDHUD_FADE)) remove_task(TASK_ROUNDHUD_FADE);

    set_task(0.5, "Task_RoundHUDFade", TASK_ROUNDHUD_FADE, _, _, "b");
}

public Task_RoundHUDFade()
{
    if (g_RoundHUDSteps <= 0)
    {
        if (task_exists(TASK_ROUNDHUD_FADE)) remove_task(TASK_ROUNDHUD_FADE);
        g_RoundHUDSteps = 0;
        g_RoundHUDColorIdx = 0;
        g_RoundHUDText[0] = 0;
        return;
    }

    new r = 255, g = 255, b = 255;
    switch (g_RoundHUDColorIdx % 8)
    {
        case 0: { r = 255; g =   0; b =   0; }   // red
        case 1: { r = 255; g = 128; b =   0; }   // orange
        case 2: { r = 255; g = 255; b =   0; }   // yellow
        case 3: { r =   0; g = 255; b =   0; }   // green
        case 4: { r =   0; g = 200; b = 255; }   // cyan
        case 5: { r =   0; g =   0; b = 255; }   // blue
        case 6: { r = 150; g =   0; b = 255; }   // purple
        case 7: { r = 255; g =   0; b = 180; }   // magenta
    }

    set_dhudmessage(r, g, b, -1.0, 0.48, 0, 0.0, 0.6, 0.05, 0.05);

    show_dhudmessage(0, "%s", g_RoundHUDText);

    g_RoundHUDSteps--;
    g_RoundHUDColorIdx++;
}

stock MarkGameDescDirty(bool:rebuild = true)
{
    g_GameDescDirty = true;
    if (rebuild) UpdateGameDesc();
}

stock UpdateGameDesc()
{
    if (!g_GameDescDirty) return;

    new buf[128];

    if (g_MatchStatus == MS_WAITING)
    {
        copy(buf, charsmax(buf), "Waiting for players..");
    }
    // 2) Captain/Team selection
    else if (g_MatchStatus == MS_CAPTAINKNIFE || g_MatchStatus == MS_TEAMSELECTION)
    {
        copy(buf, charsmax(buf), "Team-Selection in progress");
    }
    // 3) FIRST or SECOND half -> show scores + round
    else if (g_MatchStatus == MS_FIRSTHALF || g_MatchStatus == MS_SECONDHALF ||
             g_MatchStatus == MS_FIRSTHALFINITIAL || g_MatchStatus == MS_SECONDHALFINITIAL)
    {
        if (g_MatchEnded || (g_MatchStatus == MS_SECONDHALF && (g_ScoreA >= 16 || g_ScoreB >= 16)))
        {
            formatex(buf, charsmax(buf), "Match Ends: A %02d - B %02d", g_ScoreA, g_ScoreB);
        }
        else
        {
            formatex(buf, charsmax(buf), "A %02d-%02d B | Rnd %02d", g_ScoreA, g_ScoreB, g_TotalRounds <= 0 ? 0 : g_TotalRounds);
        }
    }
    // 4) halftime swap state show short HT message
    else if (g_MatchStatus == MS_HALFSWAP)
    {
        formatex(buf, charsmax(buf), "Halftime swap", g_ScoreA, g_ScoreB);
    }
    // 5) fallback
    else
    {
        copy(buf, charsmax(buf), "Automix by B@IL");
    }

    copy(g_GameDesc, charsmax(g_GameDesc), buf);
    g_GameDescDirty = false;
}

public Change()
{
    if (g_GameDescDirty) UpdateGameDesc();

    forward_return(FMV_STRING, g_GameDesc);
    return FMRES_SUPERCEDE;
}

public Cmd_ShowScore(id)
{
    if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
        return PLUGIN_HANDLED;

    if (g_MatchStatus < MS_FIRSTHALFINITIAL)
    {
        client_print_color(id, print_team_default,
            "^4%s^3 Scores are not available yet. ^1Match has not started.", g_ChatPrefix);
        return PLUGIN_HANDLED;
    }

    ShowRoundStartHUD();   
    AnnounceLeaderChat();  

    return PLUGIN_HANDLED;
}

stock StartLiveScroll(Float:duration)
{
    if (duration <= 0.0) duration = 4.0;

    copy(g_LiveScrollText, charsmax(g_LiveScrollText), "LIVE LIVE LIVE LIVE LIVE");

    new Float:interval = g_LiveScrollInterval;

    g_LiveScrollTotal = floatround(duration / interval, floatround_ceil);
    g_LiveScrollSteps = g_LiveScrollTotal;

    g_LiveScrollRightDelaySteps = floatmax(2, floatround(0.4 / interval));

    if (task_exists(g_LiveScrollTaskId)) remove_task(g_LiveScrollTaskId);
    set_task(interval, "Task_LiveScrollTick", g_LiveScrollTaskId, _, _, "b");
}

public Task_LiveScrollTick()
{
    if (g_LiveScrollSteps <= 0)
    {
        if (task_exists(g_LiveScrollTaskId)) remove_task(g_LiveScrollTaskId);
        g_LiveScrollSteps = 0;
        g_LiveScrollTotal = 0;
        g_LiveScrollText[0] = 0;
        return;
    }

    new Float:startY = -0.12;
    new Float:targetY = 0.42;

    new elapsed = g_LiveScrollTotal - g_LiveScrollSteps;
    new Float:progress = (g_LiveScrollTotal > 0) ? floatdiv(elapsed, g_LiveScrollTotal) : 1.0;
    if (progress > 1.0) progress = 1.0;

    new Float:eased = 1.0 - (1.0 - progress) * (1.0 - progress);
    new Float:deltaY = targetY - startY;
    new Float:curY = startY + eased * deltaY;

    new lr = 255, lg = 40, lb = 40;   // left color
    new rr = 200, rg = 200, rb = 0;   // right color

    set_dhudmessage(lr, lg, lb, 0.08, curY, 0, 0.0, g_LiveScrollInterval * 1.1, 0.02, 0.08);
    show_dhudmessage(0, "%s", g_LiveScrollText);

    if (elapsed >= g_LiveScrollRightDelaySteps)
    {
        new Float:rightY = curY + 0.02;
        set_dhudmessage(rr, rg, rb, 0.78, rightY, 0, 0.0, g_LiveScrollInterval * 1.1, 0.02, 0.08);
        show_dhudmessage(0, "%s", g_LiveScrollText);
    }

    if (elapsed == 0)
    {
        new sndcmd[64];
        formatex(sndcmd, charsmax(sndcmd), "spk %s", SND_PHASE_BEEP);
        client_cmd(0, sndcmd);
    }

    g_LiveScrollSteps--;
}