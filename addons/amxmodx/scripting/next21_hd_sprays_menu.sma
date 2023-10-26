#include <amxmodx>
#include <hdsprays>

new const PLUGIN[] =	"HD Sprays Simple Menu"
new const AUTHOR[] =	"1.0"
new const VERSION[] =	"Psycrow"

new const CHAT_TAG[] = "^4[HD Sprays]"

new g_iSprayMenu, g_iPreviewMenu

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_dictionary("next21_hd_sprays.txt")
	register_dictionary("common.txt")

	create_sprays_menu()
	create_preview_menu()

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

	new szMenuItem[64]

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "SPRAY_MENU_TITLE")
	menu_setprop(g_iSprayMenu, MPROP_TITLE, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "SPRAY_MENU_PREVIEW")
	menu_item_setname(g_iSprayMenu, 0, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "SPRAY_MENU_REMOVE")
	menu_item_setname(g_iSprayMenu, 1, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "SPRAY_MENU_RANDOM")
	menu_item_setname(g_iSprayMenu, 2, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "BACK")
	menu_setprop(g_iSprayMenu, MPROP_BACKNAME, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "MORE")
	menu_setprop(g_iSprayMenu, MPROP_NEXTNAME, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "EXIT")
	menu_setprop(g_iSprayMenu, MPROP_EXITNAME, szMenuItem)

	menu_display(iPlayer, g_iSprayMenu)
	return PLUGIN_HANDLED
}

show_preview_menu(iPlayer, iPage=0, iSprayId=0)
{
	if (!is_user_connected(iPlayer))
		return PLUGIN_HANDLED

	if (set_preview_spray(iPlayer, iSprayId) <= 0)
		return PLUGIN_HANDLED

	new eSprayData[SPRAY_DATA]
	get_spray_data(iSprayId, eSprayData)

	new szMenuItem[64]

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "SPRAY_PREVIEW_MENU_TITLE", eSprayData[SPRAY_NAME])
	menu_setprop(g_iPreviewMenu, MPROP_TITLE, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "BACK")
	menu_setprop(g_iPreviewMenu, MPROP_BACKNAME, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "MORE")
	menu_setprop(g_iPreviewMenu, MPROP_NEXTNAME, szMenuItem)

	formatex(szMenuItem, charsmax(szMenuItem), "%L", iPlayer, "EXIT")
	menu_setprop(g_iPreviewMenu, MPROP_EXITNAME, szMenuItem)

	menu_display(iPlayer, g_iPreviewMenu, iPage)
	return PLUGIN_HANDLED
}

public sprays_menu_handler(iPlayer, iMenu, iItem)
{
	if (iItem == MENU_EXIT)
		return PLUGIN_HANDLED

	if (iItem == 0)
	{
		show_preview_menu(iPlayer)
		return PLUGIN_HANDLED
	}

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

public preview_menu_handler(iPlayer, iMenu, iItem)
{
	if (iItem == MENU_EXIT)
	{
		clear_preview_spray(iPlayer)
		show_sprays_menu(iPlayer)
		return PLUGIN_HANDLED
	}

	new iSprayId, szSprayId[6]
	menu_item_getinfo(iMenu, iItem, .info=szSprayId, .infolen=charsmax(szSprayId))
	iSprayId = str_to_num(szSprayId)

	show_preview_menu(iPlayer, iItem / 7, iSprayId)
	return PLUGIN_HANDLED
}

public preview_menu_available(iPlayer, iMenu, iItem)
{
	return get_spraysnum() > 1 ? ITEM_ENABLED : ITEM_DISABLED
}

create_sprays_menu()
{
	g_iSprayMenu = menu_create("SPRAY_MENU_TITLE", "sprays_menu_handler")

	menu_additem(g_iSprayMenu, "SPRAY_MENU_PREVIEW", .callback=menu_makecallback("preview_menu_available"))
	menu_additem(g_iSprayMenu, "SPRAY_MENU_REMOVE", fmt("%d", NULL_SPRAY_ID))
	menu_additem(g_iSprayMenu, "SPRAY_MENU_RANDOM", fmt("%d", RANDOM_SPRAY_ID))

	new Array:aSprays
	new iSpraysNum = get_sprays(aSprays)

	for (new i, eSprayData[SPRAY_DATA]; i < iSpraysNum; i++)
	{
		ArrayGetArray(aSprays, i, eSprayData)

		// You can use other spray options to format the menu item
		menu_additem(g_iSprayMenu, eSprayData[SPRAY_NAME], fmt("%d", i), eSprayData[SPRAY_ACCESS])
	}
}

create_preview_menu()
{
	g_iPreviewMenu = menu_create("SPRAY_PREVIEW_MENU_TITLE", "preview_menu_handler")

	new Array:aSprays
	new iSpraysNum = get_sprays(aSprays)

	for (new i, eSprayData[SPRAY_DATA]; i < iSpraysNum; i++)
	{
		ArrayGetArray(aSprays, i, eSprayData)
		menu_additem(g_iPreviewMenu, eSprayData[SPRAY_NAME], fmt("%d", i))
	}
}
