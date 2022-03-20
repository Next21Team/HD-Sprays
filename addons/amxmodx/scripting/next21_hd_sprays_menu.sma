#include <amxmodx>
#include <hdsprays>

new const PLUGIN[] =	"HD Sprays Simple Menu"
new const AUTHOR[] =	"1.0"
new const VERSION[] =	"Psycrow"

new const CHAT_TAG[] = "^4[HD Sprays]"

new g_iMenu

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_dictionary("next21_hd_sprays.txt")
	register_dictionary("common.txt")

	create_sprays_menu()

	register_clcmd("say /spray", "show_sprays_menu")
	register_clcmd("say_team /spray", "show_sprays_menu")
	register_clcmd("hd_spray", "show_sprays_menu")
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

		ArrayPushCell(aAvailableSprays, i)
	}

	new iAvailableSpraysNum = ArraySize(aAvailableSprays)
	if (!iAvailableSpraysNum)
		iSprayId = NULL_SPRAY_ID
	else
		iSprayId = ArrayGetCell(aAvailableSprays, random(iAvailableSpraysNum))
}

public show_sprays_menu(iPlayer)
{
	if (!is_user_connected(iPlayer))
		return PLUGIN_HANDLED

	menu_display(iPlayer, g_iMenu)
	return PLUGIN_HANDLED
}

public sprays_menu_handler(iPlayer, iMenu, iItem)
{
	if (iItem == MENU_EXIT)
		return PLUGIN_HANDLED

	new szSprayId[6], szSprayName[SPRAY_NAME_LEN], iAccess
	menu_item_getinfo(iMenu, iItem, iAccess, szSprayId,
		charsmax(szSprayId), szSprayName, charsmax(szSprayName))

	if (~get_user_flags(iPlayer) & iAccess)
	{
		client_print(iPlayer, print_center, "%L", iPlayer, "SPRAY_ACCESS")
		menu_display(iPlayer, iMenu, iItem / 7)
		return PLUGIN_HANDLED
	}

	new iSprayId = str_to_num(szSprayId)
	set_user_spray(iPlayer, iSprayId)

	switch (iSprayId)
	{
		case NULL_SPRAY_ID: client_print_color(iPlayer, print_team_default,
			"%s %L", CHAT_TAG, iPlayer, "SPRAY_SET_REMOVE")
		case RANDOM_SPRAY_ID: client_print_color(iPlayer, print_team_default,
			"%s %L", CHAT_TAG, iPlayer, "SPRAY_SET_RANDOM")
		default: client_print_color(iPlayer, print_team_default,
			"%s %L", CHAT_TAG, iPlayer, "SPRAY_SET", szSprayName)
	}

	menu_display(iPlayer, iMenu, iItem / 7)
	return PLUGIN_HANDLED
}

create_sprays_menu()
{
	g_iMenu = menu_create(fmt("%L", LANG_PLAYER, "SPRAY_MENU_TITLE"), "sprays_menu_handler")

	menu_additem(g_iMenu, fmt("%L", LANG_PLAYER, "SPRAY_MENU_REMOVE"), fmt("%d", NULL_SPRAY_ID))
	menu_additem(g_iMenu, fmt("%L", LANG_PLAYER, "SPRAY_MENU_RANDOM"), fmt("%d", RANDOM_SPRAY_ID))

	new Array:aSprays
	new iSpraysNum = get_sprays(aSprays)

	for (new i, eSprayData[SPRAY_DATA]; i < iSpraysNum; i++)
	{
		ArrayGetArray(aSprays, i, eSprayData)

		// You can use other spray options to format the menu item
		menu_additem(g_iMenu, eSprayData[SPRAY_NAME], fmt("%d", i), eSprayData[SPRAY_ACCESS])
	}

	menu_setprop(g_iMenu, MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "BACK"))
	menu_setprop(g_iMenu, MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "MORE"))
	menu_setprop(g_iMenu, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "EXIT"))
}
