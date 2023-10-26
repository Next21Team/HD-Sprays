#if defined _hdsprays_included
    #endinput
#endif
#define _hdsprays_included

#include <hdsprays_const>

/**
 * Called before changing the client's spray index.
 *
 * @param    iPlayer        Client index
 * @param    iSprayId       Spray index
 * @param    bSave          Save spray index to database
 *
 * @return                  Use PLUGIN_HANDLED if you want to disable change
 */
forward client_set_spray(const iPlayer, &iSprayId, &bool:bSave);

/**
 * Called before a random spray is selected before it is created.
 *
 * @param    iPlayer        Client index
 * @param    iSprayId       Spray index
 */
forward client_get_random_spray(const iPlayer, &iSprayId);

/**
 * Called before the player creates a spray.
 *
 * @param    iPlayer        Client index
 *
 * @return                  Use PLUGIN_HANDLED if you want to prevent spraying
 */
forward client_create_spray_pre(const iPlayer);

/**
 * Called after the player creates a spray.
 *
 * @param    iPlayer        Client index
 * @param    iSprayEnt      Spray entity index
 */
forward client_create_spray_post(const iPlayer, const iSprayEnt);

/**
* Get an array of loaded sprays.
*
* @param    aSprays         Spray array
*
* @return                   Number of sprays
*/
native get_sprays(&Array:aSprays);

/**
* Get number of sprays.
*
* @return                   Number of sprays
*/
native get_spraysnum();

/**
* Get spray data by spray index.
*
* @param    iSprayId        Spray index
* @param    eSprayData      Spray data
*
* @noreturn
*/
native get_spray_data(const iSprayId, eSprayData[SPRAY_DATA]);

/**
* Returns if the spray index is valid.
*
* @param    iSprayId        Spray index
*
* @note     Returns false when given a negative value, like RANDOM_SPRAY_ID
*
*
* @return                   true if spray index is valid
*/
native bool:is_valid_spray(const iSprayId);

/**
* Get the client's current spray index.
*
* @param    iPlayer         Client index
*
* @return                   Spray index
*/
native get_user_spray(const iPlayer);

/**
* Set the client's current spray index.
*
* @param    iPlayer         Client index
* @param    iSprayId        Spray index
* @param    bSave           Save spray index to database
*
* @return                   Actual spray index after function call
*/
native set_user_spray(const iPlayer, const iSprayId, bool:bSave=true);

/**
* Creates a spray in front of the player.
*
* @param    iPlayer         Client index
* @param    iSprayId        Spray index
*
* @return                   Spray entity index
*/
native create_spray(const iPlayer, const iSprayId);

/**
* Removes the spray entity.
*
* @param    iSprayEnt      Spray entity index
*
* @noreturn
*/
native remove_spray(const iSprayEnt);

/**
* Sets the preview spray to the client.
*
* @param    iPlayer         Client index
* @param    iSprayId        Spray index
*
* @return                   Spray entity index
*/
native set_preview_spray(const iPlayer, const iSprayId);

/**
* Cleans the preview spray to the client.
*
* @param    iPlayer      Client index
*
* @noreturn
*/
native clear_preview_spray(const iPlayer)
