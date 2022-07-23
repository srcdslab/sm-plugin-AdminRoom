/**
 * This is the include file for AdminRoom
 * To check that AdminRoom is installed and running, verify that the "AdminRoom" library exists
 */

#if defined _AdminRoom_included
	#endinput
#endif
#define _AdminRoom_included

#include "CAdminRoom.inc"

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
