#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <hdsprays>
#include <aes_v>

new const PLUGIN[] = "HD Sprays AES Menu"
new const VERSION[] = "1.0"
new const AUTHOR[] = "Psycrow"

new const CHAT_TAG[] = "^4[HD Sprays] "

new Array:g_aPlayerSprays[MAX_PLAYERS + 1]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_dictionary("next21_hd_sprays.txt")
	register_dictionary("common.txt")

	register_clcmd("say /spray", "sprays_menu_cmd")
	register_clcmd("say_team /spray", "sprays_menu_cmd")
	register_clcmd("hd_spray", "sprays_menu_cmd")

	arrayset(g_aPlayerSprays, Invalid_Array, sizeof g_aPlayerSprays)
}

public plugin_cfg()
{
	sqlite_init()
}

public client_authorized(iPlayer)
{
	if (g_aPlayerSprays[iPlayer] == Invalid_Array)
		g_aPlayerSprays[iPlayer] = ArrayCreate()

	load_player_sprays(iPlayer)
}

public client_disconnected(iPlayer)
{
	ArrayDestroy(g_aPlayerSprays[iPlayer])
	g_aPlayerSprays[iPlayer] = Invalid_Array
}

public client_set_spray(const iPlayer, &iSprayId, &bool:bSave)
{
	if (!is_valid_spray(iSprayId))
		return PLUGIN_CONTINUE

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	// If the selected spray is not available to the player, then remove it
	if (~get_user_flags(iPlayer) & eSprayData[SPRAY_ACCESS])
		iSprayId = NULL_SPRAY_ID

	return PLUGIN_CONTINUE
}

public client_get_random_spray(const iPlayer, &iSprayId)
{
	new Array:aSprays
	new iSpraysNum = get_sprays(aSprays)
	new Array:aAvailableSprays = ArrayCreate()

	for (new i, eSprayData[SPRAY_DATA]; i < iSpraysNum; i++)
	{
		ArrayGetArray(aSprays, i, eSprayData)
		if (~get_user_flags(iPlayer) & eSprayData[SPRAY_ACCESS])
			continue

		if (eSprayData[SPRAY_COST] > 0 && !has_player_spray(iPlayer, i))
			continue

		ArrayPushCell(aAvailableSprays, i)
	}

	new iAvailableSpraysNum = ArraySize(aAvailableSprays)
	if (!iAvailableSpraysNum)
		iSprayId = NULL_SPRAY_ID
	else
		iSprayId = ArrayGetCell(aAvailableSprays, random(iAvailableSpraysNum))
}

public sprays_menu_cmd(iPlayer)
{
	show_sprays_menu(iPlayer)
	return PLUGIN_HANDLED
}

show_sprays_menu(iPlayer, iPage=0)
{
	if (!is_user_connected(iPlayer))
		return

	new iMenu = menu_create(fmt("%L", iPlayer, "SPRAY_PT_MENU_TITLE", aes_get_player_bonus(iPlayer)),
		"sprays_menu_handler")

	menu_additem(iMenu, fmt("%L", iPlayer, "SPRAY_MENU_REMOVE"), fmt("%d", NULL_SPRAY_ID))
	menu_additem(iMenu, fmt("%L", iPlayer, "SPRAY_MENU_RANDOM"), fmt("%d", RANDOM_SPRAY_ID))

	new Array:aSprays
	new iSpraysNum = get_sprays(aSprays)

	static szItemName[48]
	for (new i, eSprayData[SPRAY_DATA]; i < iSpraysNum; i++)
	{
		ArrayGetArray(aSprays, i, eSprayData)
		formatex(szItemName, charsmax(szItemName), "\w%s", eSprayData[SPRAY_NAME])

		if (eSprayData[SPRAY_COST] > 0 && !has_player_spray(iPlayer, i))
			format(szItemName, charsmax(szItemName), "\r[%d pt.] %s", eSprayData[SPRAY_COST], szItemName)

		menu_additem(iMenu, szItemName, fmt("%d", i), eSprayData[SPRAY_ACCESS])
	}

	menu_setprop(iMenu, MPROP_BACKNAME, fmt("%L", iPlayer, "BACK"))
	menu_setprop(iMenu, MPROP_NEXTNAME, fmt("%L", iPlayer, "MORE"))
	menu_setprop(iMenu, MPROP_EXITNAME, fmt("%L", iPlayer, "EXIT"))
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)

	menu_display(iPlayer, iMenu, iPage)
}

public sprays_menu_handler(iPlayer, iMenu, iItem)
{
	if (iItem == MENU_EXIT)
	{
		menu_destroy(iMenu)
		return PLUGIN_HANDLED
	}

	new szSprayId[6], szSprayName[SPRAY_NAME_LEN], iAccess
	menu_item_getinfo(iMenu, iItem, iAccess, szSprayId,
		charsmax(szSprayId), szSprayName, charsmax(szSprayName))

	menu_destroy(iMenu)

	if (~get_user_flags(iPlayer) & iAccess)
	{
		client_print(iPlayer, print_center, "%L", iPlayer, "SPRAY_ACCESS")
		show_sprays_menu(iPlayer, iItem / 7)
		return PLUGIN_HANDLED
	}

	new iSprayId = str_to_num(szSprayId)

	if (iSprayId == RANDOM_SPRAY_ID)
	{
		if (get_player_sprays_num(iPlayer) == 0)
		{
			client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_NO_SPRAYS")
			show_sprays_menu(iPlayer)
			return PLUGIN_HANDLED
		}

		set_user_spray(iPlayer, RANDOM_SPRAY_ID)
		client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_SET_RANDOM")
		return PLUGIN_HANDLED
	}

	if (iSprayId == NULL_SPRAY_ID)
	{
		set_user_spray(iPlayer, NULL_SPRAY_ID)
		client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_SET_REMOVE")
		return PLUGIN_HANDLED
	}

	set_preview_spray(iPlayer, iSprayId)

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	if (eSprayData[SPRAY_COST] > 0 && !has_player_spray(iPlayer, iSprayId))
	{
		new iCost = eSprayData[SPRAY_COST]
		new iBuyAcceptMenu = menu_create(
			fmt("%L", iPlayer, "SPRAY_BUY_MENU_TITLE", eSprayData[SPRAY_NAME], iCost),
			"buy_spray_accept_handler")
		menu_additem(iBuyAcceptMenu, fmt("%L", iPlayer, "YES"), fmt("%d", iSprayId))
		menu_additem(iBuyAcceptMenu, fmt("%L", iPlayer, "NO"))
		menu_setprop(iBuyAcceptMenu, MPROP_EXIT, MEXIT_NEVER)
		menu_display(iPlayer, iBuyAcceptMenu)
	}
	else
	{
		new iSelectAcceptMenu = menu_create(
			fmt("%L", iPlayer, "SPRAY_CHOOSE_MENU_TITLE", eSprayData[SPRAY_NAME]),
			"select_spray_accept_handler")
		menu_additem(iSelectAcceptMenu, fmt("%L", iPlayer, "SPRAY_MENU_CHOOSE"), fmt("%d", iSprayId))
		if (eSprayData[SPRAY_COST] > 0)
			menu_additem(iSelectAcceptMenu, fmt("%L", iPlayer, "SPRAY_MENU_SELL"))
		menu_setprop(iSelectAcceptMenu, MPROP_EXITNAME, fmt("%L", iPlayer, "BACK"))
		menu_setprop(iSelectAcceptMenu, MPROP_EXIT, MEXIT_ALL)
		menu_display(iPlayer, iSelectAcceptMenu)
	}

	return PLUGIN_HANDLED
}

public buy_spray_accept_handler(iPlayer, iMenu, iItem)
{
	new iAccess, szSprayId[6]
	menu_item_getinfo(iMenu, 0, iAccess, szSprayId, charsmax(szSprayId))
	menu_destroy(iMenu)
	new iSprayId = str_to_num(szSprayId)
	new iPage = (iSprayId - RANDOM_SPRAY_ID) / 7

	clear_preview_spray(iPlayer)

	if (iItem == MENU_EXIT)
		return PLUGIN_HANDLED

	if (iItem != 0)
	{
		show_sprays_menu(iPlayer, iPage)
		return PLUGIN_HANDLED
	}

	new iPlayerPoints = aes_get_player_bonus(iPlayer)
	if (iPlayerPoints == -1)
	{
		show_sprays_menu(iPlayer, iPage)
		return PLUGIN_HANDLED
	}

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	iPlayerPoints -= eSprayData[SPRAY_COST]

	if (iPlayerPoints < 0)
	{
		client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_NOT_ENOUGH_PT", -iPlayerPoints)
		show_sprays_menu(iPlayer, iPage)
		return PLUGIN_HANDLED
	}

	sqlite_insert_player_spray(iPlayer, iSprayId)
	return PLUGIN_HANDLED
}

public select_spray_accept_handler(iPlayer, iMenu, iItem)
{
	new iAccess, szSprayId[6]
	menu_item_getinfo(iMenu, 0, iAccess, szSprayId, charsmax(szSprayId))
	menu_destroy(iMenu)
	new iSprayId = str_to_num(szSprayId)
	new iPage = (iSprayId - RANDOM_SPRAY_ID) / 7

	if (iItem == MENU_EXIT)
	{
		clear_preview_spray(iPlayer)
		show_sprays_menu(iPlayer, iPage)
		return PLUGIN_HANDLED
	}

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	if (iItem == 1)
	{
		new iSellAcceptMenu = menu_create(
			fmt("%L", iPlayer, "SPRAY_SELL_MENU_TITLE", eSprayData[SPRAY_NAME], eSprayData[SPRAY_COST] / 2),
			"sell_spray_accept_handler")
		menu_additem(iSellAcceptMenu, fmt("%L", iPlayer, "YES"), fmt("%d", iSprayId))
		menu_additem(iSellAcceptMenu, fmt("%L", iPlayer, "NO"))
		menu_setprop(iSellAcceptMenu, MPROP_EXIT, MEXIT_NEVER)
		menu_display(iPlayer, iSellAcceptMenu)
		return PLUGIN_HANDLED
	}

	clear_preview_spray(iPlayer)
	set_user_spray(iPlayer, iSprayId)
	client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_SET", eSprayData[SPRAY_NAME])

	return PLUGIN_HANDLED
}

public sell_spray_accept_handler(iPlayer, iMenu, iItem)
{
	new iAccess, szSprayId[6]
	menu_item_getinfo(iMenu, 0, iAccess, szSprayId, charsmax(szSprayId))
	menu_destroy(iMenu)
	new iSprayId = str_to_num(szSprayId)
	new iPage = (iSprayId - RANDOM_SPRAY_ID) / 7

	clear_preview_spray(iPlayer)

	if (iItem == MENU_EXIT)
		return PLUGIN_HANDLED

	if (iItem != 0)
	{
		show_sprays_menu(iPlayer, iPage)
		return PLUGIN_HANDLED
	}

	if (aes_get_player_bonus(iPlayer) == -1)
	{
		show_sprays_menu(iPlayer, iPage)
		return PLUGIN_HANDLED
	}

	sqlite_delete_player_spray(iPlayer, iSprayId)
	return PLUGIN_HANDLED
}

load_player_sprays(iPlayer)
{
	new Array:aPlayerSprays = g_aPlayerSprays[iPlayer]
	if (aPlayerSprays == Invalid_Array)
		return

	ArrayClear(aPlayerSprays)

	new Array:aSprays
	new iSpraysNum = get_sprays(aSprays)

	for (new i, eSprayData[SPRAY_DATA]; i < iSpraysNum; i++)
	{
		ArrayGetArray(aSprays, i, eSprayData)
		if (~get_user_flags(iPlayer) & eSprayData[SPRAY_ACCESS])
			continue

		if (eSprayData[SPRAY_COST] == 0)
			ArrayPushCell(aPlayerSprays, i)
	}

	sqlite_get_player_sprays(iPlayer)
}

get_player_sprays_num(iPlayer)
{
	new Array:aPlayerSprays = g_aPlayerSprays[iPlayer]
	if (aPlayerSprays == Invalid_Array)
		return 0

	return ArraySize(aPlayerSprays)
}

bool:has_player_spray(iPlayer, iSprayId)
{
	new Array:aPlayerSprays = g_aPlayerSprays[iPlayer]
	if (aPlayerSprays == Invalid_Array)
		return false

	return ArrayFindValue(aPlayerSprays, iSprayId) > -1
}

add_player_spray(iPlayer, iSprayId)
{
	new Array:aPlayerSprays = g_aPlayerSprays[iPlayer]
	if (aPlayerSprays == Invalid_Array)
		return

	ArrayPushCell(aPlayerSprays, iSprayId)
}

remove_player_spray(iPlayer, iSprayId)
{
	new Array:aPlayerSprays = g_aPlayerSprays[iPlayer]
	if (aPlayerSprays == Invalid_Array)
		return

	ArrayDeleteItem(aPlayerSprays, iSprayId)
}

// ****** SQL DB ******
new const DB_NAME[] = "next21_sprays_sql.db"

enum
{
	SQL_CREATE_TABLE_HANDLE,
	SQL_GET_PLAYER_SPRAYS_HANDLE,
	SQL_INSERT_PLAYER_SPRAY_HANDLE,
	SQL_DELETE_PLAYER_SPRAY_HANDLE
}

new Handle:g_hSQLTuple, g_szQuery[512]

new const SQL_REQ_CREATE_TABLE[] =
"CREATE TABLE IF NOT EXISTS sprays ( \
    steamid TEXT, \
    name TEXT, \
    PRIMARY KEY (steamid, name) \
);"

new const SQL_REQ_GET_PLAYER_SPRAYS[] =
"SELECT name \
FROM sprays \
WHERE steamid = '%s';"

new const SQL_REQ_INSERT_PLAYER_SPRAY[] =
"INSERT INTO sprays (steamid, name) \
VALUES ('%s', '%s');"

new const SQL_REQ_DELETE_PLAYER_SPRAY[] =
"DELETE FROM sprays \
WHERE steamid = '%s' AND name = '%s';"

sqlite_init()
{
	new szDataDir[32], szDBFile[64]
	get_datadir(szDataDir, charsmax(szDataDir))
	formatex(szDBFile, charsmax(szDBFile), "%s/%s", szDataDir, DB_NAME)

	SQL_SetAffinity("sqlite")

	if (!file_exists(szDBFile))
	{
		new iFile = fopen(szDBFile, "w")
		if (!iFile)
			set_fail_state("File %s not found and can't be created", szDBFile)
		fclose(iFile)
	}

	g_hSQLTuple = SQL_MakeDbTuple("", "", "", szDBFile, 0)

	new iData[2]
	iData[1] = SQL_CREATE_TABLE_HANDLE
	SQL_ThreadQuery(g_hSQLTuple, "sql_query_handle", SQL_REQ_CREATE_TABLE, iData, sizeof iData)
}

sqlite_get_player_sprays(iPlayer)
{
	new szAuthId[32]
	get_user_authid(iPlayer, szAuthId, charsmax(szAuthId))

	new iData[3]
	formatex(g_szQuery, charsmax(g_szQuery), SQL_REQ_GET_PLAYER_SPRAYS, szAuthId)
	iData[1] = SQL_GET_PLAYER_SPRAYS_HANDLE
	iData[2] = iPlayer
	SQL_ThreadQuery(g_hSQLTuple, "sql_query_handle", g_szQuery, iData, sizeof iData)
}

sqlite_insert_player_spray(iPlayer, iSprayId)
{
	new iData[4]

	new szAuthId[32]
	get_user_authid(iPlayer, szAuthId, charsmax(szAuthId))

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	formatex(g_szQuery, charsmax(g_szQuery), SQL_REQ_INSERT_PLAYER_SPRAY, szAuthId, eSprayData[SPRAY_NAME])
	iData[1] = SQL_INSERT_PLAYER_SPRAY_HANDLE
	iData[2] = iPlayer
	iData[3] = iSprayId
	SQL_ThreadQuery(g_hSQLTuple, "sql_query_handle", g_szQuery, iData, sizeof iData)
}

sqlite_delete_player_spray(iPlayer, iSprayId)
{
	new iData[4]

	new szAuthId[32]
	get_user_authid(iPlayer, szAuthId, charsmax(szAuthId))

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	formatex(g_szQuery, charsmax(g_szQuery), SQL_REQ_DELETE_PLAYER_SPRAY, szAuthId, eSprayData[SPRAY_NAME])
	iData[1] = SQL_DELETE_PLAYER_SPRAY_HANDLE
	iData[2] = iPlayer
	iData[3] = iSprayId
	SQL_ThreadQuery(g_hSQLTuple, "sql_query_handle", g_szQuery, iData, sizeof iData)
}

public sql_query_handle(iFailstate, Handle:hQuery, szError[], iErrorNum, iData[], iSize)
{
	switch (iData[1])
	{
		case SQL_CREATE_TABLE_HANDLE:
		{
			if (iFailstate != TQUERY_SUCCESS)
				log_amx("SQL: create table handle state error: %s", szError)
		}
		case SQL_GET_PLAYER_SPRAYS_HANDLE:
		{
			if (iFailstate != TQUERY_SUCCESS)
			{
				log_amx("SQL: select player sprays error: %s", szError)
				return
			}

			new iPlayer = iData[2]
			static szSprayName[SPRAY_NAME_LEN]

			while (SQL_MoreResults(hQuery))
			{
				SQL_ReadResult(hQuery, 0, szSprayName, charsmax(szSprayName))
				SQL_NextRow(hQuery)

				new iSprayId = find_spray_by_name(szSprayName)
				if (iSprayId != NULL_SPRAY_ID)
					add_player_spray(iPlayer, iSprayId)
			}
		}
		case SQL_INSERT_PLAYER_SPRAY_HANDLE:
		{
			if (iFailstate != TQUERY_SUCCESS)
			{
				log_amx("SQL: insert player spray error: %s", szError)
				return
			}

			new iPlayer = iData[2]
			new iSprayId = iData[3]

			new iPlayerPoints = aes_get_player_bonus(iPlayer)
			if (iPlayerPoints == -1)
				return

			new eSprayData[SPRAY_DATA]
			get_spray_data(iSprayId, eSprayData)

			iPlayerPoints = max(iPlayerPoints - eSprayData[SPRAY_COST], 0)
			aes_set_player_bonus(iPlayer, iPlayerPoints, false)
			add_player_spray(iPlayer, iSprayId)
			set_user_spray(iPlayer, iSprayId)
			client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_BOUGHT", eSprayData[SPRAY_NAME])
		}
		case SQL_DELETE_PLAYER_SPRAY_HANDLE:
		{
			if (iFailstate != TQUERY_SUCCESS)
			{
				log_amx("SQL: delete player spray error: %s", szError)
				return
			}

			new iPlayer = iData[2]
			new iSprayId = iData[3]

			new iPlayerPoints = aes_get_player_bonus(iPlayer)
			if (iPlayerPoints == -1)
				return

			new eSprayData[SPRAY_DATA]
			get_spray_data(iSprayId, eSprayData)

			iPlayerPoints += eSprayData[SPRAY_COST] / 2
			aes_set_player_bonus(iPlayer, iPlayerPoints, false)
			remove_player_spray(iPlayer, iSprayId)
			if (get_user_spray(iPlayer) == iSprayId)
				set_user_spray(iPlayer, NULL_SPRAY_ID)
			client_print_color(iPlayer, print_team_default, "%s%L", CHAT_TAG, iPlayer, "SPRAY_SOLD", eSprayData[SPRAY_NAME])

			show_sprays_menu(iPlayer, (iSprayId - RANDOM_SPRAY_ID) / 7)
		}
	}
}
