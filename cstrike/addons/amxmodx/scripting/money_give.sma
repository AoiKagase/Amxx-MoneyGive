/*
-=MONEY-GIVE=- 

Each player can be Money Give to other players.

================================================ 

-=VERSIONS=- 

Releaseed(Time in JP)	Version 	comment 
------------------------------------------------ 
2005.01.29		1.02		main release 
2005.01.29		1.03		Rename
2005.03.11		1.04		Can donate to the immunity.
							Bot was stopped in the reverse.
2006.03.15		1.05		Any bugfix
2020.03.20		2.00		Rewriten New menu system.
							change cvars and cmds.
================================================ 

-=INSTALLATION=- 

Compile and install plugin. (configs/plugins.ini) 
================================================ 

-=USAGE=- 

Client command: say /mg or /mgive or /donate or /money
	- show money give menu.
	  select player => select money value. give to other player.

Server Cvars: 
	- amx_mgive		 			// enable this plugin. 0 = off, 1 = on.
	- amx_mgive_acs 			// Menu access level. 0 = all, 1 = admin only.
	- amx_mgive_max 			// A limit of amount of money to have. default $16000
	- amx_mgive_menu_enemies	// menu display in enemies. 0 = off, 1 = on.
	- amx_mgive_menu_bots		// menu display in bots. 0 = off, 1 = on.
	- amx_mgive_bots_action		// The bot gives money to those who have the least money. 0 = off, 1 = on.
								// (Happens when bot kill someone and exceed your maximum money.)
	- amx_mgive_bank			// Save player money in the bank.
================================================ 

-=SpecialThanks=-
Idea	Mr.Kaseijin
Tester	Mr.Kaseijin
		orutiga
		justice

================================================
*/
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <nvault>

#pragma semicolon 1
/*=====================================*/
/*  VERSION CHECK				       */
/*=====================================*/
#if AMXX_VERSION_NUM < 190
	#assert "AMX Mod X v1.9.0 or greater library required!"
#endif

/*=====================================*/
/*  MACRO AREA					       */
/*=====================================*/
//
// String Data.
//
// AUTHOR NAME +ARUKARI- => SandStriker => Aoi.Kagase
#define AUTHOR 						"Aoi.Kagase"
#define PLUGIN 						"MONEY-GIVE"
#define VERSION 					"2.03"

#define CHAT_TAG 					"[MONEY-GIVE]"
#define CVAR_TAG					"amx_mgive"
#define NVAULT_NAME					"mgive"

// ADMIN LEVEL
#define ADMIN_ACCESSLEVEL			ADMIN_LEVEL_H
#define MAX_CVAR_LENGTH				64

//====================================================
// ENUM AREA
//====================================================
//
// CVAR SETTINGS
//
enum CVAR_SETTING
{
	CVAR_ENABLE             = 0,    // Plugin Enable.
	CVAR_ACCESS_LEVEL       ,   	// Access level for 0 = ADMIN or 1 = ALL.
	CVAR_MAX_MONEY			,		// Max have money. default:$16000
	CVAR_ENEMIES			,		// Menu display in Enemiy team.
	CVAR_BOTS_MENU			,		// Bots in menu. 0 = none, 1 = admin, 2 = all.
	CVAR_BOTS_ACTION		,		// Bots give money action.
	CVAR_MONEY_LIST[MAX_CVAR_LENGTH],		// Money list.
	CVAR_BANK				,		// Bank system.	
}

new const CHAT_CMD[][] 		= {
	"/money",
	"/donate",
	"/mgive",
	"/mg"
};

new g_cvar[CVAR_SETTING];
new Array:gMoneyValues;
new g_nv_handle;
/*=====================================*/
/*  STOCK FUNCTIONS				       */
/*=====================================*/
//
// Get User Team Name
//
stock cs_get_user_team_name(id)
{
	new team[3];
	// Witch your team?
	switch(CsTeams:cs_get_user_team(id))
	{
		case CS_TEAM_CT: 
			team = "CT";
		case CS_TEAM_T : 
			team = "T";
		default:
			team = "";
	}
	return team;
}

//
// IS User in Team ?
//
stock bool:is_user_in_team(id)
{
	return strlen(cs_get_user_team_name(id)) > 0;
}

public plugin_init() 
{ 
	register_plugin(PLUGIN, VERSION, AUTHOR); 

	register_clcmd("say", 		"say_mg");
	register_clcmd("say_team",	"say_mg");

	// CVar settings.
	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_enable"), 		"1"), 		g_cvar[CVAR_ENABLE]);		// 0 = off, 1 = on.
	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_acs"), 			"0"), 		g_cvar[CVAR_ACCESS_LEVEL]);	// 0 = all, 1 = admin

	if (!cvar_exists("mp_maxmoney"))
	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_max"), 			"16000"), 	g_cvar[CVAR_MAX_MONEY]);	// Max have money. 
	else // Use ReGameDLL
	bind_pcvar_num(get_cvar_pointer("mp_maxmoney"), 								g_cvar[CVAR_MAX_MONEY]);	// Max have money. 

	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_enemies"),		"0"),		g_cvar[CVAR_ENEMIES]);		// Enemies in menu. 
	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_bots_menu"),		"0"),		g_cvar[CVAR_BOTS_MENU]);	// Bots in menu. 
	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_bots_action"),	"0"),		g_cvar[CVAR_BOTS_ACTION]);	// Bots in action. 

	bind_pcvar_string(create_cvar(fmt("%s%s", CVAR_TAG, "_money_list"),	"100,500,1000,5000,10000,15000"), g_cvar[CVAR_MONEY_LIST], charsmax(g_cvar[CVAR_MONEY_LIST])); 

	bind_pcvar_num(create_cvar(fmt("%s%s", CVAR_TAG, "_bank"),	"1"),				g_cvar[CVAR_BANK]);			// Bank system.

	// Bots Action
	register_event_ex("DeathMsg", "bots_action", RegisterEvent_Global);
	g_nv_handle 	  			= nvault_open(NVAULT_NAME);

	init_money_list();

	return PLUGIN_CONTINUE;
} 

//====================================================
// Destruction.
//====================================================
public plugin_end() 
{ 
	ArrayDestroy(gMoneyValues);
	nvault_close(g_nv_handle);
}

//====================================================
// Init Money List.
//====================================================
init_money_list()
{
	gMoneyValues = ArrayCreate(1);
	new cvar_money[MAX_CVAR_LENGTH];
	formatex(cvar_money, charsmax(cvar_money), "%s%s", g_cvar[CVAR_MONEY_LIST], ",");

	new i = 0;
	new iPos = 0;
	new szMoney[6];
	while((i = split_string(cvar_money[iPos += i], ",", szMoney, charsmax(szMoney))) != -1)
	{
		ArrayPushCell(gMoneyValues, str_to_num(szMoney));
	}	
}

public client_authorized(id)
{
	if (!g_cvar[CVAR_BANK])
		return PLUGIN_CONTINUE;

	new authid[MAX_AUTHID_LENGTH], temp[7], timestamp;
	get_user_authid(id, authid, charsmax(authid));

	if (nvault_lookup(g_nv_handle, authid, temp, charsmax(temp), timestamp))
		cs_set_user_money(id, str_to_num(temp), 0);

	return PLUGIN_CONTINUE;
}

public client_disconnected(id)
{
	new authid[MAX_AUTHID_LENGTH];
	get_user_authid(id, authid, charsmax(authid));

	nvault_set(g_nv_handle, authid, fmt("%d", cs_get_user_money(id)));
}
//====================================================
// Main menu.
//====================================================
public mg_player_menu(id) 
{
	if (!check_admin(id))
		return PLUGIN_HANDLED;

	if (!check_in_team(id))
		return PLUGIN_HANDLED;

	// Create a variable to hold the menu
	new menu = menu_create("Money-Give Menu:", "mg_player_menu_handler");

	// We will need to create some variables so we can loop through all the players
	new players[MAX_PLAYERS], pnum, tempid;

	// Some variables to hold information about the players
	new szName[32], szUserId[32], szMenu[32], szListFlags[3];
	//new int:money;

	// Fill players with available players
	// Optional list of filtering flags:
	// "a" - do not include dead clients		x
	// "b" - do not include alive clients		x
	// "c" - do not include bots				O
	// "d" - do not include human clients		x
	// "e" - match with team					O
	// "f" - match with part of name			x
	// "g" - match case insensitive				x
	// "h" - do not include HLTV proxies		O
	// "i" - include connecting clients			x
	const SIZE = 3;
	new len = 0;
	// display in bots
	if (g_cvar[CVAR_BOTS_MENU] == 0)
	{
		len += formatex(szListFlags[len], SIZE - len, "c");
	}
	// display in enemies.
	if (g_cvar[CVAR_ENEMIES] == 0) 
	{
		len += formatex(szListFlags[len], SIZE - len, "e");
	}
	// don't include HLTV proxies
	len += formatex(szListFlags[len], SIZE - len, "h");

	// Get Players
	get_players( players, pnum, szListFlags, cs_get_user_team_name(id));

	//Start looping through all players
	for ( new i; i<pnum; i++ )
	{
		//Save a tempid so we do not re-index
		tempid = players[i];
		if (tempid == id)
			continue;
		//Get the players name and userid as strings
		get_user_name(tempid, szName, charsmax(szName));
		//We will use the data parameter to send the userid, so we can identify which player was selected in the handler
		formatex(szUserId,	charsmax(szUserId), "%d", get_user_userid(tempid));
		formatex(szMenu,	charsmax(szMenu), 	"%s^t^t\y[$%6d]", szName, cs_get_user_money(tempid));

		//Add the item for this player
		menu_additem(menu, szMenu, szUserId, 0);
	}

	//We now have all players in the menu, lets display the menu
	menu_display( id, menu, 0 );
	return PLUGIN_HANDLED;
}

//====================================================
// Main menu handler.
//====================================================
public mg_player_menu_handler(id, menu, item)
{
	//Do a check to see if they exited because menu_item_getinfo ( see below ) will give an error if the item is MENU_EXIT
	if (item == MENU_EXIT)
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}

	//now lets create some variables that will give us information about the menu and the item that was pressed/chosen
	new szData[6], szName[64];
	new _access, item_callback;
	//heres the function that will give us that information ( since it doesnt magicaly appear )
	menu_item_getinfo( menu, item, _access, szData, charsmax(szData), szName, charsmax(szName), item_callback);

	//Get the userid of the player that was selected
	new userid = str_to_num(szData);

	//Try to retrieve player index from its userid
	new player = find_player("k", userid); // flag "k" : find player from userid

	//If player == 0, this means that the player's userid cannot be found
	//If the player is still alive ( we had retrieved alive players when formating the menu but some players may have died before id could select an item from the menu )
	if (player && is_user_connected(player))
		mg_money_menu(id, player);

	menu_destroy(menu);
	return PLUGIN_HANDLED;	
}

//====================================================
// Sub menu.
//====================================================
public mg_money_menu(id, player)
{
	new menu = menu_create("Choose Money Value.:", "mg_money_menu_handler");
	new i;
	new szValue[16];
	new szPlayer[3];
	num_to_str(player, szPlayer, charsmax(szPlayer));
	new money;
	for(i = 0;i < ArraySize(gMoneyValues); i++)
	{
		money = ArrayGetCell(gMoneyValues, i);
		formatex(szValue, charsmax(szValue), "^t$%6d", money);
		menu_additem(menu, szValue,	szPlayer, 0);
	}
	menu_display(id, menu, 0);
}

//====================================================
// Sub menu handler.
//====================================================
public mg_money_menu_handler(id, menu, item)
{
	new acces, player, callback, s_tempid[2], s_itemname[64];
	menu_item_getinfo(menu, item, acces, s_tempid, 2, s_itemname, 63, callback);

	player = str_to_num(s_tempid);

	switch(item)
	{
		case MENU_EXIT:
			if (is_user_connected(id))
				mg_player_menu(id);
		default:
		{
			new int:giveMoney = int:ArrayGetCell(gMoneyValues, item);
			TransferMoney(id, player, giveMoney);
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

//====================================================
// Chat command.
//====================================================
public say_mg(id)
{
	if(!g_cvar[CVAR_ENABLE])
		return PLUGIN_CONTINUE;

	if (!check_admin(id))
		return PLUGIN_CONTINUE;

	new said[32];
	new param[32];
	new szMessage[charsmax( said ) + charsmax( param ) + 2];
	
	read_argv(1, szMessage, charsmax(szMessage)); 
	argbreak(szMessage, said, charsmax(param), param, charsmax(param)); 
	
	for(new i = 0; i < sizeof(CHAT_CMD); i++)
	{
		if (equali(said, CHAT_CMD[i]))
		{
			trim(param);
			if (equali(param, ""))
				mg_player_menu(id);
			else
				CmdMoneyTransfer(id, param);
			break;
		}
	}


	if (containi(said, "give")	!= -1 
	||	containi(said, "money")	!= -1)
	{
		client_print_color(id, print_chat, "^4%s ^1/mg or /mgive is show money give menu", CHAT_TAG);
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
}

//====================================================
// Check Logic.
//====================================================
bool:check_admin(id)
{
	if (g_cvar[CVAR_ACCESS_LEVEL])
		return bool:(get_user_flags(id) & ADMIN_ACCESSLEVEL);

	return true;
}

bool:check_in_team(id)
{
	if (g_cvar[CVAR_ENEMIES])
		return is_user_in_team(id);

	return true;
}

//====================================================
// Bots Action.
//====================================================
public bots_action(id)
{
	new killer = read_data(1); // The killer data
	// new victim = read_data(2); // The victim data
	
	if (is_user_connected(killer) && is_user_bot(killer))
	{	
		new int:maxMoney = int:g_cvar[CVAR_MAX_MONEY];
		new int:tgtMoney = maxMoney;
		new int:botMoney = int:cs_get_user_money(killer);

		new players[MAX_PLAYERS], pnum, target;
		new int:temp;
		const int:botGive = int:500;
		if (botMoney >= maxMoney)
		{
			get_players(players, pnum, "ceh", cs_get_user_team_name(killer));

			if (pnum <= 0)
				return PLUGIN_CONTINUE;

			// get minimun money have player.
			for(new i = 0; i < pnum; i++)
			{
				temp = int:cs_get_user_money(players[i]);
				if (tgtMoney > temp)
				{
					tgtMoney = temp;
					target	 = players[i];
				}
			}

			TransferMoney(killer, target, botGive);
		}
	}
	return PLUGIN_CONTINUE;
}

//====================================================
// Chat Command.
//====================================================
CmdMoneyTransfer(id, param[])
{
	// check param[] is none.
	if (!param[0])
	{
		client_print_color(id, print_team_default, "%s Usage: '^4/mg^1 <target> <money>'", CHAT_TAG);
		return PLUGIN_CONTINUE;
	}
 
	new target[MAX_NAME_LENGTH], money[32];
	argbreak(param, target, charsmax(target), money, charsmax(money));

	new player;
	if (GetSingleTargetPlayer(id, target, player))
	{
		new int:value = int:str_to_num(money);
		TransferMoney(id, player, value);
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
} 

//====================================================
// Get Target Player.
//====================================================
GetSingleTargetPlayer(id, target[MAX_NAME_LENGTH], &player)
{
	player = cmd_target(id, target, 0);
	if (player > 0)
		return true;

	return false;
}

//====================================================
// Transfer Money.
//====================================================
TransferMoney(from, to, int:value, bool:fromBot = false)
{
	new int:mMoney	= int:g_cvar[CVAR_MAX_MONEY];	// MAX
	new int:fMoney 	= int:cs_get_user_money(from);				// From
	new int:tMoney 	= int:cs_get_user_money(to);				// To

	// don't enough!
	if (!fromBot)
	if (fMoney < value) 
	{
		client_print_color(from, print_chat, "^3%s You don't have enough money to gaving!", CHAT_TAG);
		return PLUGIN_HANDLED;
	}

	// his max have money.
	if (mMoney < tMoney + value)
	{
		fMoney -= (mMoney - tMoney);
		tMoney  = mMoney;
	}
	// give.
	else
	{
		fMoney -= value;
		tMoney += value;
	}

	cs_set_user_money	(from, 	fMoney);
	cs_set_user_money	(to,	tMoney);

	if (!fromBot)
	client_print_color	(from,	print_chat, "^4%s ^1$%d was give to ^3^"%n^".", 	CHAT_TAG, value, to);

	client_print_color	(to,	print_chat, "^4%s ^1$%d was give from ^3^"%n^".", 	CHAT_TAG, value, from);	

	return PLUGIN_CONTINUE;

}