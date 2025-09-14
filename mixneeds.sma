/* 
 * Plugin: Automix Chat Commands
 * AMXModX: 1.9.0+
 * Description:
 *   - /rates : show recommended rates to all in colored chat
 *   - /rtv   : players can vote to restart server if no admin is online
 *   - /rr /!rr : admin-only instant restart (sv_restart 1)
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define PLUGIN "Automix Chat Commands"
#define VERSION "1.0"
#define AUTHOR "B@IL&Vasu"

#define MIN_RTV_PERCENT 0.51 // 51%

new g_iRTVVotes[33];   // track who voted
new g_iTotalVotes;     // number of votes cast
new bool:g_bVoteInProgress;
new g_iMenuID;

// -------------------- PLUGIN INIT --------------------
public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    // Commands
    register_clcmd("say /rates", "cmdRates");
    register_clcmd("say_team /rates", "cmdRates");

    register_clcmd("say /rtv", "cmdRTV");
    register_clcmd("say_team /rtv", "cmdRTV");

    register_clcmd("say /rr", "cmdRR");
    register_clcmd("say !rr", "cmdRR");
    register_clcmd("say_team /rr", "cmdRR");
    register_clcmd("say_team !rr", "cmdRR");
}

// -------------------- /rates --------------------
public cmdRates(id) {
    client_print_color(0, print_team_default, "^4[RATES]^1 rate^3 100000^1 | cl_updaterate^3 100^1 | cl_cmdrate^3 105");
    return PLUGIN_HANDLED;
}

// -------------------- /rr (Admin only) --------------------
public cmdRR(id) {
    if(get_user_flags(id) & ADMIN_BAN) { // You can change flag if needed
        server_cmd("sv_restart 1");
    } else {
        client_print_color(id, print_team_default, "^4[INFO]^1 Only admin can use this command!");
    }
    return PLUGIN_HANDLED;
}

// -------------------- /rtv --------------------
public cmdRTV(id) {
    // If admin is online, block RTV
    if(is_user_admin(id)) {
        client_print_color(id, print_team_default, "^4[RTV]^1 Admin is present on the server, RTV is disabled.");
        return PLUGIN_HANDLED;
    }

    // Prevent multiple votes from same player
    if(g_iRTVVotes[id]) {
        client_print_color(id, print_team_default, "^4[RTV]^1 You already voted.");
        return PLUGIN_HANDLED;
    }

    g_iRTVVotes[id] = 1;
    g_iTotalVotes++;

    new iPlayers[32], iNum;
    get_players(iPlayers, iNum, "ch"); // count humans
    new required = floatround(iNum * MIN_RTV_PERCENT, floatround_ceil);

    client_print_color(0, print_team_default, "^4[RTV]^1 %n has voted to restart. (^3%d^1 / ^3%d^1 needed)", id, g_iTotalVotes, required);

    if(g_iTotalVotes >= required && !g_bVoteInProgress) {
        startVote();
    }

    return PLUGIN_HANDLED;
}

// -------------------- Start Vote --------------------
public startVote() {
    g_bVoteInProgress = true;
    g_iMenuID = menu_create("\yRestart the server?", "menuHandler");
    menu_additem(g_iMenuID, "Restart Server", "1");
    menu_additem(g_iMenuID, "Cancel Voting", "2");

    menu_setprop(g_iMenuID, MPROP_EXIT, MEXIT_NEVER);

    new iPlayers[32], iNum;
    get_players(iPlayers, iNum, "ch");

    for(new i=0; i<iNum; i++) {
        menu_display(iPlayers[i], g_iMenuID, 0);
    }

    client_print_color(0, print_team_default, "^4[RTV]^1 Voting started! Choose an option...");
    set_task(15.0, "endVote"); // 15 seconds to vote
}

// -------------------- Menu Handler --------------------
new g_iYes, g_iNo;

public menuHandler(id, menu, item) {
    if(item == MENU_EXIT) return PLUGIN_HANDLED;

    new info[3], name[64], access, callback;
    menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), callback);

    switch(str_to_num(info)) {
        case 1: g_iYes++;
        case 2: g_iNo++;
    }
    return PLUGIN_HANDLED;
}

// -------------------- End Vote --------------------
public endVote() {
    menu_destroy(g_iMenuID);
    g_bVoteInProgress = false;

    client_print_color(0, print_team_default, "^4[RTV]^1 Vote ended: ^3Restart^1: %d | ^3Cancel^1: %d", g_iYes, g_iNo);

    if(g_iYes > g_iNo) {
        announceRestart();
    } else if(g_iYes == g_iNo) {
        client_print_color(0, print_team_default, "^4[RTV]^1 The vote ended in a draw. No action taken.");
    } else {
        client_print_color(0, print_team_default, "^4[RTV]^1 Restart vote failed. Server continues.");
    }

    g_iTotalVotes = 0;
    arrayset(g_iRTVVotes, 0, sizeof(g_iRTVVotes));
    g_iYes = g_iNo = 0;
}

// -------------------- Announce + Restart --------------------
public announceRestart() {
    for(new i=5; i>0; i--) {
        set_task(float(6-i), "restartCountdown", i);
    }
    set_task(6.0, "doRestart");
}

public restartCountdown(i) {
    set_hudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 0.0, 3);
    show_hudmessage(0, "Server restarting in %d...", i);
}

public doRestart() {
    new map[32];
    get_mapname(map, charsmax(map));
    server_cmd("changelevel %s", map);
}
