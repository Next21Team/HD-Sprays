#if defined _hdsprays_const_included
	#endinput
#endif
#define _hdsprays_const_included

#define NULL_SPRAY_ID			-1
#define RANDOM_SPRAY_ID			-2

#define var_sprayid			var_iuser2
#define var_spawntime		var_fuser2

#define SPRAY_NAME_LEN 			64


enum SprayType
{
    SPRAY_TYPE_STATIC,
    SPRAY_TYPE_ANIMATE
}

enum SprayFormat
{
    SPRAY_FMT_MDL,
    SPRAY_FMT_SPR
}

enum _:SPRAY_DATA
{
    SPRAY_MODEL[SPRAY_NAME_LEN],
    SPRAY_NAME[SPRAY_NAME_LEN],
    SprayType:SPRAY_TYPE,
    SprayFormat:SPRAY_FORMAT,
    SPRAY_BODY,
    SPRAY_SKIN,
    Float:SPRAY_WIDTH,
    Float:SPRAY_HEIGHT,
    Float:SPRAY_SCALE,
    Float:SPRAY_FRAMERATE,
    SPRAY_FRAMES_NUM,
    SPRAY_COST,
    SPRAY_ACCESS
}
