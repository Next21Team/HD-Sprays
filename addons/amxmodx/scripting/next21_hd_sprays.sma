#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>
#include <reapi>
#include <time>
#include <nvault>
#include <xs>
#include <hdsprays_const>

new const PLUGIN[] =	"HD Sprays"
new const AUTHOR[] =	"1.4"
new const VERSION[] =	"Polarhigh & Psycrow"

#define play_spray_sound(%1)		emit_sound(%1, CHAN_AUTO, "player/sprayer.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
#define is_valid_spray(%1)			(0<=%1<g_iTotalSprays)

#define PRESS_DELAY				0.2	// delay for using the IMPULSE_SPRAY
#define VAULT_DAYS 				30 // duration of storage of the selected spray by the player

#define IMPULSE_SPRAY           201

#define STATUS_TEXT_MAXLEN      64
#define STATUS_TEXT_DELAY       0.1

new const SPRAYS_PATH[] = "models/next21_sprays"
new const NVAULT_DB[] = "next21_spray"
new const CLASSNAME_BASE[] = "info_target"

new const CLASSNAME_SPRAY[] = "next21_spray"
new const CLASSNAME_PREVIEW_SPRAY[] = "next21_preview_spray"

#define WALL_CHECKER_DEBUG_LEVEL 	0

#define ADD_UNITS			2.0
#define USABLE_DIST			128.0	// maximum spray distance

new const USER_ERR_STR[] = "User %d not connected"
new const SPRAY_ID_ERR_STR[] = "Invalid spray id (%d)"

new const BLOCKED_SURFACE_CLSSNAMES[][] = {
    "func_conveyor",
    "func_door",
    "func_pendulum",
    "func_plat",
    "func_rot_button",
    "func_rotating",
    "func_train",
    "func_tracktrain",
    "func_breakable"
}

enum _:CVAR_LIST
{
    bool:CVAR_LIGHT,
    Float:CVAR_SPRAY_LIFETIME,
    Float:CVAR_SPRAY_DELAY,
    CVAR_MAX_SPRAYS,
    bool:CVAR_CLIENT_DECAL,
    bool:CVAR_MOVABLE_SURFACE,
    bool:CVAR_INTERSECTS,
    bool:CVAR_SHOW_OWNER,
    bool:CVAR_ROUND_CLEANUP
}

enum _:THINK_PARAMS
{
    SprayFormat:TP_FORMAT,
    TP_FRAMES_NUM
}

new
    Array:g_aSprays, Trie:g_trieSprayMap,
    g_iTotalSprays, g_iSpraysNow,
    g_iPlayerSpray[MAX_PLAYERS + 1],
    g_szStatusText[MAX_PLAYERS + 1][STATUS_TEXT_MAXLEN],
    g_iPlayerShowOwnerSprayEnt[MAX_PLAYERS + 1],
    g_iPlayerPreviewSprayEnt[MAX_PLAYERS + 1],
    g_pCvars[CVAR_LIST],
    g_msgStatusText,
    g_fwdSetUserSpray, g_fwdGetRandomSpray,
    g_fwdCreateSprayPre, g_fwdCreateSprayPost,
    Trie:g_trieBlockedSurfClassNames,
    g_iVaultSprays

#if WALL_CHECKER_DEBUG_LEVEL > 0
new g_iBeamSprite
#endif

public plugin_cfg()
{
    g_iVaultSprays = nvault_open(NVAULT_DB)

    if (g_iVaultSprays == INVALID_HANDLE)
        set_fail_state("Error opening nVault!")

    nvault_prune(g_iVaultSprays, 0, get_systime() - (SECONDS_IN_DAY * VAULT_DAYS))
}

public plugin_natives()
{
    register_native("get_sprays", "native_get_sprays")
    register_native("get_spraysnum", "native_get_spraysnum")

    register_native("get_spray_data", "native_get_spray_data")
    register_native("is_valid_spray", "native_is_valid_spray")

    register_native("get_user_spray", "native_get_user_spray")
    register_native("set_user_spray", "native_set_user_spray")

    register_native("create_spray", "native_create_spray")
    register_native("remove_spray", "native_remove_spray")

    register_native("set_preview_spray", "native_set_preview_spray")
    register_native("clear_preview_spray", "native_clear_preview_spray")
}

public plugin_precache()
{
    new szCfgDir[32], szSpraysFile[64]
    get_configsdir(szCfgDir, charsmax(szCfgDir))

    formatex(szSpraysFile, charsmax(szSpraysFile), "%s/sprays.ini", szCfgDir)

    g_aSprays = ArrayCreate(SPRAY_DATA)
    g_trieSprayMap = TrieCreate()

    if (load_sprays(szSpraysFile))
        server_print("[%s] Loaded %d sprays from %s", PLUGIN, g_iTotalSprays, szSpraysFile)
    else
        server_print("[%s] Failed load %s", PLUGIN, szSpraysFile)

    new Trie:triePrecached = TrieCreate()
    for (new i, szModelPath[256], eSprayData[SPRAY_DATA]; i < g_iTotalSprays; i++)
    {
        ArrayGetArray(g_aSprays, i, eSprayData)
        formatex(szModelPath, charsmax(szModelPath), "%s/%s", SPRAYS_PATH, eSprayData[SPRAY_MODEL])

        if (TrieKeyExists(triePrecached, szModelPath))
            continue

        precache_model(szModelPath)
        TrieSetCell(triePrecached, szModelPath, 1)
    }
    TrieDestroy(triePrecached)

    #if WALL_CHECKER_DEBUG_LEVEL > 0
    g_iBeamSprite = precache_model("sprites/laserbeam.spr");
    #endif
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_dictionary("next21_hd_sprays.txt")

    g_msgStatusText = get_user_msgid("StatusText")

    RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink_Post", true);
    RegisterHookChain(RG_CBasePlayer_ImpulseCommands, "CBasePlayer_ImpulseCommands_Pre", false)
    RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", true)

    register_message(g_msgStatusText, "OnMessageStatusText")

    bind_pcvar_num(register_cvar("hd_spray_light", "0"), g_pCvars[CVAR_LIGHT])
    bind_pcvar_float(register_cvar("hd_spray_lifetime", "200.0"), g_pCvars[CVAR_SPRAY_LIFETIME])
    bind_pcvar_num(register_cvar("hd_max_sprays", "32"), g_pCvars[CVAR_MAX_SPRAYS])
    bind_pcvar_float(get_cvar_pointer("decalfrequency"), g_pCvars[CVAR_SPRAY_DELAY])
    bind_pcvar_num(register_cvar("hd_spray_client_decal", "1"), g_pCvars[CVAR_CLIENT_DECAL])
    bind_pcvar_num(register_cvar("hd_spray_movable_surface", "0"), g_pCvars[CVAR_MOVABLE_SURFACE])
    bind_pcvar_num(register_cvar("hd_spray_intersects", "1"), g_pCvars[CVAR_INTERSECTS])
    bind_pcvar_num(register_cvar("hd_spray_show_owner", "1"), g_pCvars[CVAR_SHOW_OWNER])
    bind_pcvar_num(register_cvar("hd_spray_round_cleanup", "0"), g_pCvars[CVAR_ROUND_CLEANUP])

    g_trieBlockedSurfClassNames = TrieCreate()
    for (new i; i < sizeof BLOCKED_SURFACE_CLSSNAMES; i++)
        TrieSetCell(g_trieBlockedSurfClassNames, BLOCKED_SURFACE_CLSSNAMES[i], 1)

    g_fwdSetUserSpray = CreateMultiForward("client_set_spray",
        ET_STOP, FP_CELL, FP_VAL_BYREF, FP_VAL_BYREF)

    g_fwdGetRandomSpray = CreateMultiForward("client_get_random_spray",
        ET_IGNORE, FP_CELL, FP_VAL_BYREF)

    g_fwdCreateSprayPre = CreateMultiForward("client_create_spray_pre",
        ET_STOP, FP_CELL)

    g_fwdCreateSprayPost = CreateMultiForward("client_create_spray_post",
        ET_IGNORE, FP_CELL, FP_CELL)
}

public plugin_end()
{
    nvault_close(g_iVaultSprays)
}

public client_authorized(iPlayer)
{
    g_iPlayerSpray[iPlayer] = NULL_SPRAY_ID
    g_iPlayerShowOwnerSprayEnt[iPlayer] = NULLENT
    g_iPlayerPreviewSprayEnt[iPlayer] = NULLENT

    new szKey[24], szValue[SPRAY_NAME_LEN], iTimestamp
    get_user_authid(iPlayer, szKey, charsmax(szKey))

    if (nvault_lookup(g_iVaultSprays, szKey, szValue, charsmax(szValue), iTimestamp))
    {
        new iSprayId = NULL_SPRAY_ID
        TrieGetCell(g_trieSprayMap, szValue, iSprayId)
        set_player_spray(iPlayer, iSprayId, false)
    }
}

public client_disconnected(iPlayer)
{
    clear_preview_spray(iPlayer)
}

public CBasePlayer_PreThink_Post(iPlayer)
{
    new iPreviewSprayEnt = g_iPlayerPreviewSprayEnt[iPlayer]

    if (is_nullent(iPreviewSprayEnt))
        return HC_CONTINUE

    new Float:vOrigin[3], Float:vAngles[3]
    get_entvar(iPlayer, var_origin, vOrigin)
    get_entvar(iPlayer, var_angles, vAngles)

    if (engfunc(EngFunc_PointContents, vOrigin) == CONTENTS_EMPTY)
    {
        vOrigin[0] += floatcos(vAngles[1], degrees) * 100.0
        vOrigin[1] += floatsin(vAngles[1], degrees) * 100.0
        vOrigin[2] += 15.0

        vAngles[1] += 180.0

        set_entvar(iPreviewSprayEnt, var_origin, vOrigin)
        set_entvar(iPreviewSprayEnt, var_angles, vAngles)
    }

    return HC_CONTINUE
}

public CBasePlayer_ImpulseCommands_Pre(iPlayer)
{
    if (g_pCvars[CVAR_SHOW_OWNER])
        show_spray_owner(iPlayer)

    if (get_entvar(iPlayer, var_impulse) != IMPULSE_SPRAY)
        return HC_CONTINUE

    new iImpulse = 0
    new Float:fGameTime = get_gametime()
    static Float:fPressTimeout[MAX_PLAYERS + 1]

    if (fPressTimeout[iPlayer] > fGameTime)
        goto skip

    fPressTimeout[iPlayer] = get_gametime() + PRESS_DELAY

    if (get_member(iPlayer, m_flNextDecalTime) > fGameTime)
        goto skip

    new iSprayId = g_iPlayerSpray[iPlayer]
    if (iSprayId == RANDOM_SPRAY_ID)
        iSprayId = get_random_player_spray(iPlayer)

    if (!is_valid_spray(iSprayId))
    {
        iImpulse = g_pCvars[CVAR_CLIENT_DECAL] ? IMPULSE_SPRAY: 0
        goto skip
    }

    create_spray(iPlayer, iSprayId)

    skip:
    set_entvar(iPlayer, var_impulse, iImpulse)
    return HC_CONTINUE
}

public CSGameRules_CleanUpMap_Post()
{
    if (g_pCvars[CVAR_ROUND_CLEANUP])
    {
        new iSprayEnt
        while ((iSprayEnt = rg_find_ent_by_class(iSprayEnt, CLASSNAME_SPRAY)))
            erase_spray(iSprayEnt)
    }
}

public OnMessageStatusText(iMsgId, iMsgDest, iMsgEnt)
{
    if (iMsgEnt)
        get_msg_arg_string(2, g_szStatusText[iMsgEnt], STATUS_TEXT_MAXLEN - 1)
}

create_spray(iPlayer, iSprayId)
{
    if (!is_user_alive(iPlayer))
        return NULLENT

    if (!is_valid_spray(iSprayId))
        return NULLENT

    new iForwardReturn = PLUGIN_CONTINUE
    ExecuteForward(g_fwdCreateSprayPre, iForwardReturn, iPlayer)
    if (iForwardReturn == PLUGIN_HANDLED)
        return NULLENT

    new eSprayData[SPRAY_DATA]
    ArrayGetArray(g_aSprays, iSprayId, eSprayData)

    new Float:vOrigin[3], Float:vAngles[3], Float:vNormal[3]
    if (!get_corrected_origin(iPlayer, vOrigin, eSprayData[SPRAY_WIDTH], eSprayData[SPRAY_HEIGHT], vNormal))
        return NULLENT

    if (eSprayData[SPRAY_FORMAT] == SPRAY_FMT_SPR)
    {
        vNormal[0] = -vNormal[0]
        vNormal[1] = -vNormal[1]
    }

    vector_to_angle(vNormal, vAngles)

    new Float:vForward[3], Float:vRight[3], Float:vUp[3]
    angle_vector(vAngles, ANGLEVECTOR_FORWARD, vForward)
    angle_vector(vAngles, ANGLEVECTOR_RIGHT, vRight)
    angle_vector(vAngles, ANGLEVECTOR_UP, vUp)

    xs_vec_mul_scalar(vForward, ADD_UNITS, vForward)
    xs_vec_mul_scalar(vRight, eSprayData[SPRAY_WIDTH] / 2.0, vRight)
    xs_vec_mul_scalar(vUp, eSprayData[SPRAY_HEIGHT] / 2.0, vUp)

    new Float:vCornerLeft[3], Float:vCornerRight[3]
    xs_vec_add(vForward, vRight, vCornerRight)
    xs_vec_add(vCornerRight, vUp, vCornerRight)
    xs_vec_neg(vCornerRight, vCornerLeft)

    new Float:vMins[3], Float:vMaxs[3]
    for (new i; i < 3; i++)
    {
        if (vCornerRight[i] > vCornerLeft[i])
        {
            vMaxs[i] = vCornerRight[i]
            vMins[i] = vCornerLeft[i]
        }
        else
        {
            vMaxs[i] = vCornerLeft[i]
            vMins[i] = vCornerRight[i]
        }
    }

    if (g_pCvars[CVAR_INTERSECTS] && get_spray_on_bounds(vOrigin, vMins, vMaxs) != NULLENT)
        return NULLENT

    if (vAngles[0] == 90.0 || vAngles[0] == 270.0)
    {
        new Float:vPlayerAngles[3]
        get_entvar(iPlayer, var_v_angle, vPlayerAngles)
        if (eSprayData[SPRAY_FORMAT] == SPRAY_FMT_SPR)
            vAngles[1] = vPlayerAngles[1]
        else
            vAngles[1] = vPlayerAngles[1] - 180.0
    }

    new iSprayEnt = spawn_spray_ent(eSprayData)
    if (is_nullent(iSprayEnt))
        return NULLENT

    engfunc(EngFunc_SetSize, iSprayEnt, vMins, vMaxs)
    set_entvar(iSprayEnt, var_origin, vOrigin)
    set_entvar(iSprayEnt, var_angles, vAngles)
    set_entvar(iSprayEnt, var_owner, iPlayer)
    set_entvar(iSprayEnt, var_classname, CLASSNAME_SPRAY)
    set_entvar(iSprayEnt, var_netname, fmt("%n", iPlayer))
    set_entvar(iSprayEnt, var_sprayid, iSprayId)

    if (g_pCvars[CVAR_LIGHT])
        set_entvar(iSprayEnt, var_effects, EF_DIMLIGHT)

    if (g_iSpraysNow >= g_pCvars[CVAR_MAX_SPRAYS])
    {
        new iOldestSprayEnt = find_oldest_spray()
        if (iOldestSprayEnt != NULLENT && iOldestSprayEnt != iSprayEnt)
            erase_spray(iOldestSprayEnt)
    }

    new Float:fLifeTime = g_pCvars[CVAR_SPRAY_LIFETIME]
    if (fLifeTime > 0.0)
        set_task(fLifeTime, "erase_spray", iSprayEnt)

    set_member(iPlayer, m_flNextDecalTime, get_gametime() + g_pCvars[CVAR_SPRAY_DELAY])
    play_spray_sound(iPlayer)

    g_iSpraysNow++
    ExecuteForward(g_fwdCreateSprayPost, iForwardReturn, iPlayer, iSprayEnt)
    return iSprayEnt
}

public erase_spray(iSprayEnt)
{
    remove_task(iSprayEnt)
    if (iSprayEnt && FClassnameIs(iSprayEnt, CLASSNAME_SPRAY))
    {
        set_entvar(iSprayEnt, var_flags, FL_KILLME)
        g_iSpraysNow--
    }
}

public spray_think(iSprayEnt, aParams[THINK_PARAMS])
{
    new Float:fFrameRate = get_entvar(iSprayEnt, var_framerate)

    if (aParams[TP_FORMAT] == SPRAY_FMT_MDL)
    {
        new iNextFrame = (get_entvar(iSprayEnt, var_body) + 1) % aParams[TP_FRAMES_NUM]
        set_entvar(iSprayEnt, var_body, iNextFrame)
        set_entvar(iSprayEnt, var_skin, iNextFrame)
    }
    else
    {
        new iNextFrame = (floatround(get_entvar(iSprayEnt, var_frame)) + 1) % aParams[TP_FRAMES_NUM]
        set_entvar(iSprayEnt, var_frame, iNextFrame + 0.0)
    }

    set_entvar(iSprayEnt, var_nextthink, get_gametime() + (1.0 / fFrameRate))
}

spawn_spray_ent(eSprayData[SPRAY_DATA])
{
    new iSprayEnt = rg_create_entity(CLASSNAME_BASE, true)
    if (is_nullent(iSprayEnt))
        return NULLENT

    static szModelPath[256]
    formatex(szModelPath, charsmax(szModelPath), "%s/%s", SPRAYS_PATH, eSprayData[SPRAY_MODEL])
    engfunc(EngFunc_SetModel, iSprayEnt, szModelPath)

    new Float:fGameTime = get_gametime()

    set_entvar(iSprayEnt, var_solid, SOLID_NOT)
    set_entvar(iSprayEnt, var_movetype, MOVETYPE_FLY)
    set_entvar(iSprayEnt, var_rendermode, kRenderNormal)
    set_entvar(iSprayEnt, var_scale, eSprayData[SPRAY_SCALE])
    set_entvar(iSprayEnt, var_frame, 0)
    set_entvar(iSprayEnt, var_framerate, eSprayData[SPRAY_FRAMERATE])
    set_entvar(iSprayEnt, var_animtime, fGameTime)
    set_entvar(iSprayEnt, var_spawntime, fGameTime)

    switch (eSprayData[SPRAY_TYPE])
    {
        case SPRAY_TYPE_STATIC:
        {
            if (eSprayData[SPRAY_FORMAT] == SPRAY_FMT_MDL)
            {
                set_entvar(iSprayEnt, var_body, eSprayData[SPRAY_BODY])
                set_entvar(iSprayEnt, var_skin, eSprayData[SPRAY_SKIN])
            }
            else
            {
                set_entvar(iSprayEnt, var_frame, eSprayData[SPRAY_BODY] + 0.0)
            }
        }
        case SPRAY_TYPE_ANIMATE:
        {
            set_entvar(iSprayEnt, var_body, 0)
            set_entvar(iSprayEnt, var_skin, 0)
            set_entvar(iSprayEnt, var_frame, 0.0)
            set_entvar(iSprayEnt, var_nextthink, fGameTime + (1.0 / eSprayData[SPRAY_FRAMERATE]))

            new aParams[THINK_PARAMS]
            aParams[TP_FORMAT] = eSprayData[SPRAY_FORMAT]
            aParams[TP_FRAMES_NUM] = eSprayData[SPRAY_FRAMES_NUM]
            SetThink(iSprayEnt, "spray_think", aParams, THINK_PARAMS)
        }
    }

    return iSprayEnt
}

find_oldest_spray()
{
    new iSprayEnt = NULLENT
    new Float:fOldestTime = get_gametime()

    new iEnt, Float:fSpawnTime
    while ((iEnt = rg_find_ent_by_class(iEnt, CLASSNAME_SPRAY)))
    {
        fSpawnTime = get_entvar(iEnt, var_spawntime)
        if (fSpawnTime < fOldestTime)
        {
            iSprayEnt = iEnt
            fOldestTime = fSpawnTime
        }
    }

    return iSprayEnt
}

set_player_spray(iPlayer, iSprayId, bool:bSave)
{
    if (!is_valid_spray(iSprayId) && iSprayId != RANDOM_SPRAY_ID)
        iSprayId = NULL_SPRAY_ID

    new iForwardReturn = PLUGIN_CONTINUE
    ExecuteForward(g_fwdSetUserSpray, iForwardReturn, iPlayer, iSprayId, bSave)
    if (iForwardReturn == PLUGIN_HANDLED)
        return g_iPlayerSpray[iPlayer]

    g_iPlayerSpray[iPlayer] = iSprayId

    if (bSave)
    {
        new szKey[24]
        get_user_authid(iPlayer, szKey, charsmax(szKey))

        switch (iSprayId)
        {
            case NULL_SPRAY_ID: nvault_remove(g_iVaultSprays, szKey)
            case RANDOM_SPRAY_ID: nvault_set(g_iVaultSprays, szKey, fmt("@%d", RANDOM_SPRAY_ID))
            default:
            {
                new eSprayData[SPRAY_DATA]
                ArrayGetArray(g_aSprays, iSprayId, eSprayData)
                nvault_set(g_iVaultSprays, szKey, eSprayData[SPRAY_NAME])
            }
        }
    }

    return iSprayId
}

create_preview_spray(iPlayer, iSprayId)
{
    if (!is_user_connected(iPlayer))
        return NULLENT

    if (!is_valid_spray(iSprayId))
        return NULLENT

    new eSprayData[SPRAY_DATA]
    ArrayGetArray(g_aSprays, iSprayId, eSprayData)

    new iPreviewSprayEnt = spawn_spray_ent(eSprayData)
    if (is_nullent(iPreviewSprayEnt))
        return NULLENT

    new iEffects = EF_OWNER_VISIBILITY | EF_FORCEVISIBILITY
    if (g_pCvars[CVAR_LIGHT])
        iEffects |= EF_DIMLIGHT

    set_entvar(iPreviewSprayEnt, var_movetype, MOVETYPE_NOCLIP)
    set_entvar(iPreviewSprayEnt, var_owner, iPlayer)
    set_entvar(iPreviewSprayEnt, var_classname, CLASSNAME_PREVIEW_SPRAY)
    set_entvar(iPreviewSprayEnt, var_effects, iEffects)

    return iPreviewSprayEnt
}

set_preview_spray(iPlayer, iSprayId)
{
    new iPreviewSprayEnt = create_preview_spray(iPlayer, iSprayId)
    if (!is_nullent(iPreviewSprayEnt))
    {
        clear_preview_spray(iPlayer)
        g_iPlayerPreviewSprayEnt[iPlayer] = iPreviewSprayEnt
    }
    return iPreviewSprayEnt
}

clear_preview_spray(iPlayer)
{
    new iPreviewSprayEnt = g_iPlayerPreviewSprayEnt[iPlayer]
    if (!is_nullent(iPreviewSprayEnt))
    {
        set_entvar(iPreviewSprayEnt, var_flags, FL_KILLME)
        g_iPlayerPreviewSprayEnt[iPlayer] = NULLENT
    }
}

get_random_player_spray(iPlayer)
{
    new iForwardReturn, iSprayId = random(g_iTotalSprays)
    ExecuteForward(g_fwdGetRandomSpray, iForwardReturn, iPlayer, iSprayId)
    return iSprayId
}

bool:get_corrected_origin(iPlayer, Float:vOutPointFSet[3], Float:fWidth, Float:fHeight, Float:vOrigWallNormal[3])
{
    new Float:vWallNormal[3]
    get_wall_normal(iPlayer, vWallNormal)
    xs_vec_copy(vWallNormal, vOrigWallNormal)

    new Float:vWallAngles[3]
    vector_to_angle(vWallNormal, vWallAngles)

    new Float:vUpNormal[3], Float:vRightNormal[3]
    angle_vector(vWallAngles, ANGLEVECTOR_UP, vUpNormal)
    angle_vector(vWallAngles, ANGLEVECTOR_RIGHT, vRightNormal)

    new Float:vAimOrigin[3], iHit
    if (!get_trace_hit_data(iPlayer, USABLE_DIST, vAimOrigin, iHit))
        return false

    if (iHit > 0 && !g_pCvars[CVAR_MOVABLE_SURFACE])
    {
        static szHitEntClassName[16]
        get_entvar(iHit, var_classname, szHitEntClassName, charsmax(szHitEntClassName))
        if (TrieKeyExists(g_trieBlockedSurfClassNames, szHitEntClassName))
            return false
    }

    xs_vec_copy(vAimOrigin, vOutPointFSet)

    new Float:vAddUnits[3]
    xs_vec_mul_scalar(vOrigWallNormal, ADD_UNITS, vAddUnits)
    xs_vec_add(vAddUnits, vAimOrigin, vAimOrigin)

    vUpNormal[2] = -vUpNormal[2]

    new Float:vUpLeftPoint[3], Float:vUpRightPoint[3],
        Float:vDownLeftPoint[3], Float:vDownRightPoint[3]
    xs_vec_mul_scalar(vUpNormal, fHeight/2, vUpNormal)
    xs_vec_mul_scalar(vRightNormal, fWidth/2, vRightNormal)

    //1
    xs_vec_add(vUpNormal, vRightNormal, vUpRightPoint)
    xs_vec_add(vUpRightPoint, vAimOrigin, vUpRightPoint)

    //2
    xs_vec_neg(vRightNormal, vRightNormal)
    xs_vec_add(vUpNormal, vRightNormal, vUpLeftPoint)
    xs_vec_add(vUpLeftPoint, vAimOrigin, vUpLeftPoint)

    //3
    xs_vec_neg(vUpNormal, vUpNormal)
    xs_vec_add(vUpNormal, vRightNormal, vDownLeftPoint)
    xs_vec_add(vDownLeftPoint, vAimOrigin, vDownLeftPoint)

    //4
    xs_vec_neg(vRightNormal, vRightNormal)
    xs_vec_add(vUpNormal, vRightNormal, vDownRightPoint)
    xs_vec_add(vDownRightPoint, vAimOrigin, vDownRightPoint)

    xs_vec_neg(vWallNormal, vWallNormal)

    new bool:isUpRightPoint, bool:isUpLeftPoint, bool:isDownLeftPoint, bool:isDownRightPoint
    isUpRightPoint = trace_to_wall(vUpRightPoint, vWallNormal)
    isUpLeftPoint = trace_to_wall(vUpLeftPoint, vWallNormal)
    isDownLeftPoint = trace_to_wall(vDownLeftPoint, vWallNormal)
    isDownRightPoint = trace_to_wall(vDownRightPoint, vWallNormal)

    if (!isUpRightPoint || !isUpLeftPoint || !isDownLeftPoint || !isDownRightPoint)
        return false

    #if WALL_CHECKER_DEBUG_LEVEL > 0
    create_rectangle(vUpRightPoint, vUpLeftPoint, vDownLeftPoint, vDownRightPoint, 'g', 50)
    #endif

    angle_vector(vWallAngles, ANGLEVECTOR_UP, vUpNormal)
    angle_vector(vWallAngles, ANGLEVECTOR_RIGHT, vRightNormal)

    vUpNormal[2] = -vUpNormal[2]

    xs_vec_mul_scalar(vRightNormal, fWidth/2, vRightNormal)
    xs_vec_mul_scalar(vUpNormal, fHeight/2, vUpNormal)

    new Float:vTmpVec[3]
    xs_vec_add(vDownLeftPoint, vRightNormal, vTmpVec)
    xs_vec_add(vTmpVec, vUpNormal, vOutPointFSet)

    return true
}

bool:load_sprays(const szSpraysFile[])
{
    g_iTotalSprays = 0
    ArrayClear(g_aSprays)
    TrieClear(g_trieSprayMap)

    TrieSetCell(g_trieSprayMap, fmt("@%d", NULL_SPRAY_ID), NULL_SPRAY_ID)
    TrieSetCell(g_trieSprayMap, fmt("@%d", RANDOM_SPRAY_ID), RANDOM_SPRAY_ID)

    if (!file_exists(szSpraysFile))
        return false

    new szLineData[256], szModelPath[256],
        iFile = fopen(szSpraysFile, "rt"),
        szSprayName[SPRAY_NAME_LEN], szSprayModel[SPRAY_NAME_LEN],
        szSprayType[2], szSprayBody[8], szSpraySkin[8],
        szSprayFrameRate[16], szSprayWidth[16], szSprayHeight[16],
        szSprayScale[16], szSprayCost[16], szSprayAccess[32],
        eSprayData[SPRAY_DATA]

    while (iFile && !feof(iFile))
    {
        fgets(iFile, szLineData, charsmax(szLineData))
        if (szLineData[0] == ';')
            continue

        new iArgsNum = parse(szLineData, szSprayName, charsmax(szSprayName),
            szSprayModel, charsmax(szSprayModel),
            szSprayType, charsmax(szSprayType),
            szSprayBody, charsmax(szSprayBody),
            szSpraySkin, charsmax(szSpraySkin),
            szSprayFrameRate, charsmax(szSprayFrameRate),
            szSprayWidth, charsmax(szSprayWidth),
            szSprayHeight, charsmax(szSprayHeight),
            szSprayScale, charsmax(szSprayScale),
            szSprayCost, charsmax(szSprayCost),
            szSprayAccess, charsmax(szSprayAccess))

        if (iArgsNum < 11)
            continue

        formatex(szModelPath, charsmax(szModelPath), "%s/%s", SPRAYS_PATH, szSprayModel)

        if (!file_exists(szModelPath))
        {
            server_print("[%s] Failed to precache %s", PLUGIN, szModelPath)
            continue
        }

        copy(eSprayData[SPRAY_NAME], SPRAY_NAME_LEN - 1, szSprayName)
        copy(eSprayData[SPRAY_MODEL], SPRAY_NAME_LEN - 1, szSprayModel)

        switch (szSprayType[0])
        {
            case 'n': eSprayData[SPRAY_TYPE] = SPRAY_TYPE_STATIC
            case 'a': eSprayData[SPRAY_TYPE] = SPRAY_TYPE_ANIMATE
        }

        new SprayFormat:iSprayFormat, iSprayFramesNum
        parse_spray_file(szModelPath, iSprayFormat, iSprayFramesNum)

        eSprayData[SPRAY_BODY] = str_to_num(szSprayBody)
        eSprayData[SPRAY_SKIN] = str_to_num(szSpraySkin)
        eSprayData[SPRAY_WIDTH] = floatmax(1.0, str_to_float(szSprayWidth))
        eSprayData[SPRAY_HEIGHT] = floatmax(1.0, str_to_float(szSprayHeight))
        eSprayData[SPRAY_SCALE] = floatmax(0.000001, str_to_float(szSprayScale))
        eSprayData[SPRAY_FRAMERATE] = floatmax(0.000001, str_to_float(szSprayFrameRate))
        eSprayData[SPRAY_COST] = str_to_num(szSprayCost)
        eSprayData[SPRAY_ACCESS] = read_flags(szSprayAccess)
        eSprayData[SPRAY_FORMAT] = iSprayFormat
        eSprayData[SPRAY_FRAMES_NUM] = iSprayFramesNum

        ArrayPushArray(g_aSprays, eSprayData)
        TrieSetCell(g_trieSprayMap, szSprayName, g_iTotalSprays)
        g_iTotalSprays++
    }

    if (iFile)
        fclose(iFile)

    return true
}

parse_spray_file(const szModelPath[], &SprayFormat:iFormat, &iFramesNum)
{
    new szHeader[5]
    new fd = fopen(szModelPath, "rb")
    fread_blocks(fd, szHeader, 4, BLOCK_CHAR)

    if (equal(szHeader, "IDST"))
    {
        iFramesNum = 0

        new iBodyPartsNum, iBodyPartsOffset
        fseek(fd, 204, SEEK_SET)
        fread(fd, iBodyPartsNum, BLOCK_INT)
        fread(fd, iBodyPartsOffset, BLOCK_INT)

        fseek(fd, iBodyPartsOffset, SEEK_SET)
        for (new i, iBodiesNum; i < iBodyPartsNum; i++)
        {
            fseek(fd, 64, SEEK_CUR)
            fread(fd, iBodiesNum, BLOCK_INT)
            fseek(fd, 8, SEEK_CUR)

            if (iBodiesNum > iFramesNum)
                iFramesNum = iBodiesNum
        }

        iFormat = SPRAY_FMT_MDL
    }
    else if (equal(szHeader, "IDSP"))
    {
        fseek(fd, 28, SEEK_SET)
        fread(fd, iFramesNum, BLOCK_INT)
        iFormat = SPRAY_FMT_SPR
    }

    fclose(fd)
}

bool:get_trace_hit_data(iPlayer, Float:fDist, Float:vOrigin[3], &iHit)
{
    new Float:vSrc[3], Float:vViewOfs[3]
    get_entvar(iPlayer, var_origin, vSrc)
    get_entvar(iPlayer, var_view_ofs, vViewOfs)
    xs_vec_add(vSrc, vViewOfs, vSrc)

    new Float:vEnd[3]
    get_entvar(iPlayer, var_v_angle, vEnd)
    engfunc(EngFunc_MakeVectors, vEnd)
    global_get(glb_v_forward, vEnd)
    xs_vec_mul_scalar(vEnd, fDist, vEnd)
    xs_vec_add(vSrc, vEnd, vEnd)

    new pTrace = create_tr2()
    engfunc(EngFunc_TraceLine, vSrc, vEnd, DONT_IGNORE_MONSTERS, iPlayer, pTrace)

    new Float:fFraction
    get_tr2(pTrace, TR_flFraction, fFraction)
    if (fFraction >= 1.0)
    {
        free_tr2(pTrace)
        return false
    }

    get_tr2(pTrace, TR_vecEndPos, vOrigin)
    iHit = get_tr2(pTrace, TR_pHit)

    free_tr2(pTrace)
    return true
}

get_wall_normal(iPlayer, Float:vNormal[3])
{
    new Float:vOrigin[3]
    get_entvar(iPlayer, var_origin, vOrigin)

    new Float:vAngles[3]
    get_entvar(iPlayer, var_v_angle, vAngles)
    angle_vector(vAngles, ANGLEVECTOR_FORWARD, vAngles)
    xs_vec_mul_scalar(vAngles, 9999.0, vAngles)

    new Float:vEndPos[3]
    xs_vec_add(vAngles, vOrigin, vEndPos)

    new pTrace = create_tr2()
    engfunc(EngFunc_TraceLine, vOrigin, vEndPos, IGNORE_MISSILE | IGNORE_MONSTERS | IGNORE_GLASS, iPlayer, pTrace)

    get_tr2(pTrace, TR_vecPlaneNormal, vNormal)
    free_tr2(pTrace)
}

bool:trace_to_wall(Float:vOrigin[3], Float:vDir[3])
{
    new Float:vOrigin2[3]
    xs_vec_mul_scalar(vDir, ADD_UNITS, vOrigin2)
    xs_vec_add(vOrigin2, vOrigin, vOrigin2)
    xs_vec_add(vOrigin2, vDir, vOrigin2)

    new pTrace = create_tr2()
    engfunc(EngFunc_TraceLine, vOrigin, vOrigin2, IGNORE_MISSILE | IGNORE_MONSTERS | IGNORE_GLASS, 0, pTrace)

    new Float:fFrac
    get_tr2(pTrace, TR_flFraction, fFrac)

    free_tr2(pTrace)
    return fFrac != 1.0
}

show_spray_owner(iPlayer)
{
    static Float:fGameTime, Float:fNextTime[MAX_PLAYERS + 1]
    fGameTime = get_gametime()
    if (fGameTime < fNextTime[iPlayer])
        return
    fNextTime[iPlayer] = fGameTime + STATUS_TEXT_DELAY

    new iSprayEnt = trace_to_spray(iPlayer, USABLE_DIST)
    if (g_iPlayerShowOwnerSprayEnt[iPlayer] != iSprayEnt)
    {
        static szText[STATUS_TEXT_MAXLEN]
        if (iSprayEnt != NULLENT)
        {
            static szPlayerName[32]
            get_entvar(iSprayEnt, var_netname, szPlayerName, charsmax(szPlayerName))
            formatex(szText, charsmax(szText), "%L", iPlayer, "SPRAY_STATUS_TEXT", szPlayerName)
        }
        else
            copy(szText, charsmax(szText), g_szStatusText[iPlayer])

        message_begin(MSG_ONE, g_msgStatusText, .player=iPlayer)
        write_byte(0)
        write_string(szText)
        message_end()

        g_iPlayerShowOwnerSprayEnt[iPlayer] = iSprayEnt
    }
}

trace_to_spray(iPlayer, Float:fDistance)
{
    static Float:vSrc[3], Float:vEnd[3], Float:vViewOfs[3]

    new pTrace = create_tr2()
    get_entvar(iPlayer, var_origin, vSrc)
    get_entvar(iPlayer, var_view_ofs, vViewOfs)
    xs_vec_add(vSrc, vViewOfs, vSrc)

    get_entvar(iPlayer, var_v_angle, vEnd)
    engfunc(EngFunc_MakeVectors, vEnd)
    global_get(glb_v_forward, vEnd)

    xs_vec_mul_scalar(vEnd, fDistance, vEnd)
    xs_vec_add(vSrc, vEnd, vEnd)

    engfunc(EngFunc_TraceLine, vSrc, vEnd, DONT_IGNORE_MONSTERS, iPlayer, pTrace)

    new Float:fFraction
    get_tr2(pTrace, TR_flFraction, fFraction)
    if (fFraction >= 1.0)
    {
        free_tr2(pTrace)
        return NULLENT
    }

    get_tr2(pTrace, TR_vecEndPos, vEnd)
    free_tr2(pTrace)

    return get_spray_on_origin(vEnd)
}

get_spray_on_origin(Float:vOrigin[3])
{
    static Float:vAbsMin[3], Float:vAbsMax[3]

    new iSprayEnt
    while ((iSprayEnt = rg_find_ent_by_class(iSprayEnt, CLASSNAME_SPRAY)))
    {
        get_entvar(iSprayEnt, var_absmin, vAbsMin)
        get_entvar(iSprayEnt, var_absmax, vAbsMax)

        if (vAbsMin[0] <= vOrigin[0] <= vAbsMax[0] &&
            vAbsMin[1] <= vOrigin[1] <= vAbsMax[1] &&
            vAbsMin[2] <= vOrigin[2] <= vAbsMax[2])
            return iSprayEnt
    }

    return NULLENT
}

get_spray_on_bounds(Float:vOrigin[3], Float:vMins[3], Float:vMaxs[3])
{
    static Float:vAbsMin[3], Float:vAbsMax[3],
        Float:vBoundsMin[3], Float:vBoundsMax[3]

    xs_vec_add(vOrigin, vMins, vBoundsMin)
    xs_vec_add(vOrigin, vMaxs, vBoundsMax)

    new iSprayEnt
    while ((iSprayEnt = rg_find_ent_by_class(iSprayEnt, CLASSNAME_SPRAY)))
    {
        get_entvar(iSprayEnt, var_absmin, vAbsMin)
        get_entvar(iSprayEnt, var_absmax, vAbsMax)

        if (vAbsMin[0] > vBoundsMax[0] ||
            vAbsMin[1] > vBoundsMax[1] ||
            vAbsMin[2] > vBoundsMax[2] ||
            vAbsMax[0] < vBoundsMin[0] ||
            vAbsMax[1] < vBoundsMin[1] ||
            vAbsMax[2] < vBoundsMin[2])
            continue

        return iSprayEnt
    }

    return NULLENT
}

#if WALL_CHECKER_DEBUG_LEVEL > 0
create_rectangle(Float:vUpRightPoint[3], Float:vUpLeftPoint[3], Float:vDownLeftPoint[3], Float:vDownRightPoint[3], cColor, iLifetime)
{
    new r, g, b
    switch (cColor)
    {
        case 'r': r = 255
        case 'g': g = 255
        case 'b': b = 255
    }

    set_sprite(vUpRightPoint, vUpLeftPoint, r, g, b, iLifetime)
    set_sprite(vUpLeftPoint, vDownLeftPoint, r, g, b, iLifetime)
    set_sprite(vDownLeftPoint, vDownRightPoint, r, g, b, iLifetime)
    set_sprite(vDownRightPoint, vUpRightPoint, r, g, b, iLifetime)
}

set_sprite(Float:vOrigin[3], Float:vOrigin2[3], r, g, b, iLifetime)
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMPOINTS)
    engfunc(EngFunc_WriteCoord, vOrigin[0])
    engfunc(EngFunc_WriteCoord, vOrigin[1])
    engfunc(EngFunc_WriteCoord, vOrigin[2])
    engfunc(EngFunc_WriteCoord, vOrigin2[0])
    engfunc(EngFunc_WriteCoord, vOrigin2[1])
    engfunc(EngFunc_WriteCoord, vOrigin2[2])
    write_short(g_iBeamSprite)
    write_byte(0)
    write_byte(1)
    write_byte(iLifetime)
    write_byte(20)
    write_byte(0)
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(200)
    write_byte(0)
    message_end()
}
#endif

// Natives
public native_get_sprays(plugin_id, argc)
{
    set_param_byref(1, _:g_aSprays)
    return g_iTotalSprays
}

public native_get_spraysnum(plugin_id, argc)
{
    return g_iTotalSprays
}

public native_get_spray_data(plugin_id, argc)
{
    new iSprayId = get_param(1)
    if (!is_valid_spray(iSprayId))
        abort(AMX_ERR_NATIVE, SPRAY_ID_ERR_STR, iSprayId)

    new eSprayData[SPRAY_DATA]
    ArrayGetArray(g_aSprays, iSprayId, eSprayData)
    set_array(2, eSprayData, SPRAY_DATA)

    return true
}

public bool:native_is_valid_spray(plugin_id, argc)
{
    return is_valid_spray(get_param(1))
}

public native_get_user_spray(plugin_id, argc)
{
    new iPlayer = get_param(1)

    if (!is_user_connected(iPlayer))
        abort(AMX_ERR_NATIVE, USER_ERR_STR, iPlayer)

    return g_iPlayerSpray[iPlayer]
}

public native_set_user_spray(plugin_id, argc)
{
    new iPlayer = get_param(1)
    new iSprayId = get_param(2)
    new bool:bSave = bool:get_param(3)

    if (!is_user_connected(iPlayer))
        abort(AMX_ERR_NATIVE, USER_ERR_STR, iPlayer)

    return set_player_spray(iPlayer, iSprayId, bSave)
}

public native_create_spray(plugin_id, argc)
{
    new iPlayer = get_param(1)
    new iSprayId = get_param(2)

    if (!is_user_connected(iPlayer))
        abort(AMX_ERR_NATIVE, USER_ERR_STR, iPlayer)

    if (iSprayId == RANDOM_SPRAY_ID)
        iSprayId = get_random_player_spray(iPlayer)

    return create_spray(iPlayer, iSprayId)
}

public native_remove_spray(plugin_id, argc)
{
    erase_spray(get_param(1))
}

public native_set_preview_spray(plugin_id, argc)
{
    return set_preview_spray(get_param(1), get_param(2))
}

public native_clear_preview_spray(plugin_id, argc)
{
    clear_preview_spray(get_param(1))
}
