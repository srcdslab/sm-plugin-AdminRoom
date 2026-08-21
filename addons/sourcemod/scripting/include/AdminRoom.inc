/**
 * This is the include file for AdminRoom
 * To check that AdminRoom is installed and running, verify that the "AdminRoom" library exists
 */

#if defined _AdminRoom_included
	#endinput
#endif
#define _AdminRoom_included

#include "CAdminRoom.inc"

/**
 * Called after AdminRoom successfully changes the current map's stage, whether the change was
 * requested by an admin, the server console, a stage vote winner, or another plugin through
 * AdminRoom_SetStage() / AdminRoom_SetStageByTrigger().
 *
 * @param index		Index of the new stage (see AdminRoom_GetStageName()).
 * @param name		Display name of the new stage.
 * @param client	Client that requested the change, or 0 if requested by the server.
 */
forward void AdminRoom_OnStageChanged(int index, const char[] name, int client);

/**
 * Returns whether the current map is configured and supported by AdminRoom.
 *
 * @return		True if the current map has an AdminRoom config loaded, false otherwise.
 */
native bool AdminRoom_IsEnabled();

/**
 * Returns the number of stages configured for the current map.
 *
 * @return		Number of stages, or 0 if the map has none configured.
 */
native int AdminRoom_GetStageCount();

/**
 * Retrieves the display name of a stage by index.
 *
 * @param index		Stage index, between 0 and AdminRoom_GetStageCount() - 1.
 * @param buffer	Buffer to store the stage name.
 * @param maxlen	Maximum length of the buffer.
 * @return		True on success, false if the index is out of range.
 */
native bool AdminRoom_GetStageName(int index, char[] buffer, int maxlen);

/**
 * Returns the index of the stage that is currently active.
 *
 * @return		Index of the current stage, or -1 if no stage has been set yet this map.
 */
native int AdminRoom_GetCurrentStage();

/**
 * Changes the current map's stage by index, firing its configured actions.
 * Fires AdminRoom_OnStageChanged() on success.
 *
 * @param index		Stage index to switch to.
 * @param client	Client to attribute the change to, or 0 for the server.
 * @return		True on success, false if the index is invalid or a required button is locked.
 */
native bool AdminRoom_SetStage(int index, int client=0);

/**
 * Changes the current map's stage by trigger keyword (same matching as the sm_stage command).
 * Fires AdminRoom_OnStageChanged() on success.
 *
 * @param trigger	Trigger keyword to match against the current map's configured stages.
 * @param client	Client to attribute the change to, or 0 for the server.
 * @return		True on success, false if no stage matches or a required button is locked.
 */
native bool AdminRoom_SetStageByTrigger(const char[] trigger, int client=0);

public SharedPlugin __pl_AdminRoom =
{
	name = "AdminRoom",
	file = "AdminRoom.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_AdminRoom_SetNTVOptional()
{
	MarkNativeAsOptional("AdminRoom_IsEnabled");
	MarkNativeAsOptional("AdminRoom_GetStageCount");
	MarkNativeAsOptional("AdminRoom_GetStageName");
	MarkNativeAsOptional("AdminRoom_GetCurrentStage");
	MarkNativeAsOptional("AdminRoom_SetStage");
	MarkNativeAsOptional("AdminRoom_SetStageByTrigger");
}
#endif
