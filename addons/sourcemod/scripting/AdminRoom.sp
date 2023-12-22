#include <sourcemod>
#include <sdktools>
#include <regex>
#include <multicolors>
#include <outputinfo>
#include <AdminRoom>
#include <utilshelper.inc>

#pragma semicolon 1
#pragma newdecls required

#define TAG_COLOR "{green}[SM]{default}"
#define POSITIVE(%1) ((%1) < 0 ? 0 - (%1) : (%1))
#define STEP 4.0
#define RADIUSSIZE 40.0

int menuSelected[MAXPLAYERS+1] = { 0, ... };
Menu menuHandle[MAXPLAYERS+1] = { null, ... };

// anti-stuck
bool isStuck[MAXPLAYERS+1] = { false, ... };
int StuckCheck[MAXPLAYERS+1] = {0, ...};
float Ground_Velocity[3] = {0.0, 0.0, -300.0};

float g_fPlayerOrigin[MAXPLAYERS+1][3];
ArrayList g_cAdminRoomLocationsDetected = null;
ArrayList g_aAutoDetect = null;

CAdminRoom g_AdminRoom = null;

bool g_bLateLoad = false;

public Plugin myinfo =
{
	name = "Admin Room",
	author = "IT-KILLER, BotoX, maxime1907, .Rushaway",
	description = "Teleport to admin rooms and change stages.",
	version = "2.1.1",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   g_bLateLoad = late;
   return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_adminroom_reloadcfg", Command_ReloadConfig, ADMFLAG_CONFIG, "Reload both map and keyword configs");
	RegAdminCmd("sm_adminroom", Command_AdminRoom, ADMFLAG_BAN, "Teleport anyone to the admin room");
	RegAdminCmd("sm_stage", Command_Stage, ADMFLAG_BAN, "Change the map stage");

	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
}

public void EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		OnClientDisconnect(client);
	}
	DetectAdminRoomLocations();
}

public void OnMapStart()
{
	LoadMapConfig();
	LoadConfig();

	if (g_bLateLoad)
	{
		EventRoundStart(null, "", true);
		g_bLateLoad = false;
	}
}

public void OnClientDisconnect(int client)
{
	g_fPlayerOrigin[client][0] = 0.0;
	g_fPlayerOrigin[client][1] = 0.0;
	g_fPlayerOrigin[client][2] = 0.0;
	menuSelected[client] = 0;
	isStuck[client] = false;
	StuckCheck[client] = false;
	menuHandle[client] = null; 
}

public Action Command_ReloadConfig(int client, int argc)
{
	g_bLateLoad = true;
	OnMapStart();

	CReplyToCommand(client, "%s AdminRoom configs reloaded.", TAG_COLOR);
	LogAction(client, -1, "[AdminRoom] %L Reloaded the configs files.", client);
	return Plugin_Handled;
}

public Action Command_Stage(int client, int argc)
{
	ArrayList cStages;
	g_AdminRoom.GetStages(cStages);

	if (!g_AdminRoom.bEnabled)
	{
		CReplyToCommand(client, "%s The current map is not supported.", TAG_COLOR);
		return Plugin_Handled;
	}

	if (!cStages || cStages.Length <= 0)
	{
		CReplyToCommand(client, "%s The current map either does not have stages or is incorrectly configured.", TAG_COLOR);
		return Plugin_Handled;
	}

	if (argc < 1)
	{
		CReplyToCommand(client, "%s Available stages :", TAG_COLOR);

		for (int i = 0; i < cStages.Length; i++)
		{
			CStage cStage = cStages.Get(i);

			char sTriggers[128] = "";

			ArrayList cTriggers;
			if (cStage.GetTriggers(cTriggers))
			{
				for (int y = 0; y < cTriggers.Length; y++)
				{
					CTrigger cTrigger = cTriggers.Get(y);

					char sTrigger[32];
					cTrigger.GetValue(sTrigger, sizeof(sTrigger));
	
					if (y + 1 < cTriggers.Length)
						StrCat(sTrigger, sizeof(sTrigger), ", ");

					StrCat(sTriggers, sizeof(sTriggers), sTrigger);
				}
			}
			char sName[64];
			cStage.GetName(sName, sizeof(sName));

			CReplyToCommand(client, "{olive}%s : {default}%s", sName, sTriggers);
		}

		return Plugin_Handled;
	}

	char sArg[64];
	GetCmdArgString(sArg, sizeof(sArg));

	for (int i = 0; i < cStages.Length; i++)
	{
		CStage cStage = cStages.Get(i);

		bool bFound = false;

		ArrayList cTriggers;
		if (cStage.GetTriggers(cTriggers))
		{
			for (int y = 0; y < cTriggers.Length; y++)
			{
				CTrigger cTrigger = cTriggers.Get(y);

				char sTrigger[32];
				cTrigger.GetValue(sTrigger, sizeof(sTrigger));

				if (StrEqual(sArg, sTrigger, true))
				{
					bFound = true;
					break;
				}
			}
		}

		if(!bFound)
			continue;

		char sName[64];
		cStage.GetName(sName, sizeof(sName));

		CReplyToCommand(client, "%s Triggering \"{olive}%s{default}\".", TAG_COLOR, sName);

		ArrayList cActions;
		if (cStage.GetActions(cActions))
		{
			for (int y = 0; y < cActions.Length; y++)
			{
				CAction cAction = cActions.Get(y);

				char sIdentifier[64];
				cAction.GetIdentifier(sIdentifier, sizeof(sIdentifier));

				char sEvent[64];
				cAction.GetEvent(sEvent, sizeof(sEvent));

				CReplyToCommand(client, "%s Firing \"{olive}%s{default}\".", TAG_COLOR, sIdentifier);

				int entity = INVALID_ENT_REFERENCE;
				while((entity = FindEntityByTargetname(entity, sIdentifier, "*")) != INVALID_ENT_REFERENCE)
				{
					AcceptEntityInput(entity, sEvent, client, client);
				}
			}
		}

		if (client > 0)
			CShowActivity2(client, "{green}[SM] {olive}", "{default}Changed the stage to {green}%s{default}.", sName);
		else
			ShowActivity2(client, "[SM] ", "Changed the stage to %s.", sName);

		LogAction(client, -1, "\"%L\" changed the stage to \"%s\".", client, sName);

		return Plugin_Handled;
	}

	CReplyToCommand(client, "%s Invalid stage %s", TAG_COLOR, sArg);
	return Plugin_Handled;
}

public Action Command_AdminRoom(int client, int argc)
{
	if (!client)
	{
		CReplyToCommand(client, "%s Console cannot be teleported.", TAG_COLOR);
		return Plugin_Handled;
	}

	if(argc > 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_adminroom [#userid|name]");
		return Plugin_Handled;
	}

	char sArgs[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	if(argc == 1)
		GetCmdArg(1, sArgs, sizeof(sArgs));
	else
		strcopy(sArgs, sizeof(sArgs), "@me");

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	if(iTargetCount <= 1)
	{
		for(int i = 0; i < iTargetCount; i++)
		{
			ArrayList cAdminRoomLocations;
			if ((g_AdminRoom.GetAdminRoomLocations(cAdminRoomLocations) && cAdminRoomLocations.Length > 0) || g_cAdminRoomLocationsDetected.Length > 0)
			{
				Menu_AdminRoom(iTargets[i]);
				CReplyToCommand(client, "%s AdminRoom Menu has been sent to {olive}%N{default}.", TAG_COLOR, iTargets);
				LogAction(client, client, "\"%L\" printed the AdminRoom Menu to \"%L\".", client, iTargets);
			}
			else
				CReplyToCommand(client, "%s Unable to detect any admin room.", TAG_COLOR);
		}
	}
	else
		CReplyToCommand(client, "%s Only one target can be reached.", TAG_COLOR);

	return Plugin_Handled;
}

void Menu_AdminRoom(int client)
{
	Menu menu = new Menu(MenuHandler_AdminRoom, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DrawItem);

	menuHandle[client] = menu;

	menu.SetTitle("Admin Room");
	menu.AddItem("-1", "Get out (saved position)");

	ArrayList cAdminRoomLocations;
	if (g_AdminRoom.GetAdminRoomLocations(cAdminRoomLocations) && cAdminRoomLocations.Length)
	{
		for (int i = 0; i < cAdminRoomLocations.Length; i++)
		{
			CAdminRoomLocation cAdminRoomLocation = cAdminRoomLocations.Get(i);

			char sName[32];
			cAdminRoomLocation.GetName(sName, sizeof(sName));

			char sIndex[32];
			IntToString(i, sIndex, sizeof(sIndex));

			menu.AddItem(sIndex, sName);
		}
	}
	else
	{
		for (int i = 0; i < g_cAdminRoomLocationsDetected.Length; i++)
		{
			CAdminRoomLocation cAdminRoomLocation = g_cAdminRoomLocationsDetected.Get(i);

			char sName[32];
			cAdminRoomLocation.GetName(sName, sizeof(sName));

			char sIndex[32];
			IntToString(i, sIndex, sizeof(sIndex));

			menu.AddItem(sIndex, sName);
		}
	}

	menu.Display(client, 20);
}

public int MenuHandler_AdminRoom(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			menuSelected[param1] = 0;
		}
		case MenuAction_End:
		{
			if (param1 != MenuEnd_Selected)
			{
				delete(menu);
			}
		}
		case MenuAction_Select:
		{
			if (menuHandle[param1] != menu)
			{
				delete menu;
				return 0;
			}

			char option[32];
			menu.GetItem(param2, option, sizeof(option));
			menuSelected[param1] = param2;

			int target = StringToInt(option);

			if (target == -1)
			{
				GetOut(param1);
			}
			else
			{
				CAdminRoomLocation cAdminRoomLocation;

				ArrayList cAdminRoomLocations;
				if (g_AdminRoom.GetAdminRoomLocations(cAdminRoomLocations) && cAdminRoomLocations.Length)
					cAdminRoomLocation = cAdminRoomLocations.Get(target);
				else
					cAdminRoomLocation = g_cAdminRoomLocationsDetected.Get(target);

				GoToEntity(param1, cAdminRoomLocation);
			}
			menu.DisplayAt(param1, GetMenuSelectionPosition(), 20);
			return 0;
		}
		case MenuAction_DrawItem:
		{
			int style;
			char option[32];
			menu.GetItem(param2, option, sizeof(option), style);
			if(param2 == 0 && g_fPlayerOrigin[param1][0] == 0.0 && g_fPlayerOrigin[param1][1] == 0.0 && g_fPlayerOrigin[param1][2] == 0.0)
			{
				return ITEMDRAW_DISABLED;
			} 
			else if(menuSelected[param1] == param2)
			{
				return ITEMDRAW_DISABLED;
			} 
			return style;
		}
	}
	return 0;
}

stock void InitAdminRoom()
{
	if (g_cAdminRoomLocationsDetected != null)
	{
		for (int i = 0; i < g_cAdminRoomLocationsDetected.Length; i++)
		{
			CAdminRoomLocation cAdminRoomLocation = g_cAdminRoomLocationsDetected.Get(i);
			delete cAdminRoomLocation;
		}
		delete g_cAdminRoomLocationsDetected;
	}
	g_cAdminRoomLocationsDetected = new ArrayList();

	if (g_AdminRoom != null)
	{
		ArrayList cAdminRoomLocations;
		if (g_AdminRoom.GetAdminRoomLocations(cAdminRoomLocations))
		{
			for (int i = 0; i < cAdminRoomLocations.Length; i++)
			{
				CAdminRoomLocation cAdminRoomLocation = cAdminRoomLocations.Get(i);
				delete cAdminRoomLocation;
			}
			delete cAdminRoomLocations;
		}

		ArrayList cStages;
		if (g_AdminRoom.GetStages(cStages))
		{
			for (int i = 0; i < cStages.Length; i++)
			{
				CStage cStage = cStages.Get(i);

				ArrayList cTriggers;
				if (cStage.GetTriggers(cTriggers))
				{
					for (int y = 0; y < cTriggers.Length; y++)
					{
						CTrigger cTrigger = cTriggers.Get(y);
						delete cTrigger;
					}
					delete cTriggers;
				}
				ArrayList cActions;
				if (cStage.GetActions(cActions))
				{
					for (int y = 0; y < cActions.Length; y++)
					{
						CAction cAction = cActions.Get(y);
						delete cAction;
					}
					delete cActions;
				}
				delete cStage;
			}
			delete cStages;
		}
		delete g_AdminRoom;
	}
	g_AdminRoom = new CAdminRoom();
}

stock void LoadConfig()
{
	if (g_aAutoDetect != null)
		delete g_aAutoDetect;

	g_aAutoDetect = new ArrayList();

	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/adminroom/adminroom.cfg");

	if (!FileExists(sConfigFile))
	{
		LogError("Missing config file %s", sConfigFile);
		return;
	}

	KeyValues kvConfig = new KeyValues("AutoDetect");

	if (!kvConfig.ImportFromFile(sConfigFile))
	{
		delete kvConfig;
		return;
	}
	kvConfig.Rewind();

	if (!kvConfig.GotoFirstSubKey(false))
	{
		delete kvConfig;
		return;
	}

	do
	{
		char sAutoDetectWord[32];
		kvConfig.GetString("name", sAutoDetectWord, sizeof(sAutoDetectWord), "");

		g_aAutoDetect.PushString(sAutoDetectWord);
	}
	while(kvConfig.GotoNextKey(false));

	delete kvConfig;
}

stock void LoadMapConfig()
{
	InitAdminRoom();

	char sMapName[PLATFORM_MAX_PATH], sMapNameLowercase[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));
	strcopy(sMapNameLowercase, sizeof(sMapNameLowercase), sMapName);
	StringToLowerCase(sMapNameLowercase);

	char sConfigFile[PLATFORM_MAX_PATH], sConfigFile_override[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/adminroom/maps/%s.cfg", sMapName);
	BuildPath(Path_SM, sConfigFile_override, sizeof(sConfigFile_override), "configs/adminroom/maps/%s_override.cfg", sMapName);

	KeyValues kvConfig = new KeyValues("AdminRoom");

	if (!FileExists(sConfigFile_override))
		BuildPath(Path_SM, sConfigFile_override, sizeof(sConfigFile_override), "configs/adminroom/maps/%s_override.cfg", sMapNameLowercase);

	if (FileExists(sConfigFile_override))
	{
		if(!kvConfig.ImportFromFile(sConfigFile_override))
		{
			LogMessage("Unable to load config override: \"%s\"", sConfigFile_override);
			delete kvConfig;
			return;
		}
		else LogMessage("Loaded override mapconfig: \"%s\"", sConfigFile_override);
	}
	else
	{
		if (!FileExists(sConfigFile))
			BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/adminroom/maps/%s.cfg", sMapNameLowercase);

		if(!kvConfig.ImportFromFile(sConfigFile))
		{
			LogMessage("Unable to load config: \"%s\"", sConfigFile);
			delete kvConfig;
			return;
		}
		else LogMessage("Loaded mapconfig: \"%s\"", sConfigFile);
	}

	kvConfig.Rewind();

	g_AdminRoom.bEnabled = true;

	LoadMapAdminRoomLocations(kvConfig);

	LoadMapStages(kvConfig);

	delete kvConfig;
}

stock void LoadMapAdminRoomLocations(KeyValues kvConfig)
{
	if (!kvConfig.JumpToKey("adminrooms", false) || !kvConfig.GotoFirstSubKey(false))
		return;

	do
	{
		char sName[64];
		kvConfig.GetString("name", sName, sizeof(sName), "MISSING_NAME");

		char sOrigin[64];
		kvConfig.GetString("origin", sOrigin, sizeof(sOrigin), "MISSING_ORIGIN");

		if (sOrigin[0])
		{
			char sOrigins[3][16];
			ExplodeString(sOrigin, " ", sOrigins, sizeof(sOrigins), sizeof(sOrigins[]));

			float fOrigin[3];
			fOrigin[0] = StringToFloat(sOrigins[0]);
			fOrigin[1] = StringToFloat(sOrigins[1]);
			fOrigin[2] = StringToFloat(sOrigins[2]);

			CAdminRoomLocation cAdminRoomLocation = new CAdminRoomLocation();
			cAdminRoomLocation.SetName(sName);
			cAdminRoomLocation.SetOrigin(fOrigin);

			g_AdminRoom.AddAdminRoomLocation(cAdminRoomLocation);
		}
	}
	while(kvConfig.GotoNextKey(false));

	kvConfig.Rewind();
}

stock void LoadMapStages(KeyValues kvConfig)
{
	if (!kvConfig.JumpToKey("stages", false) || !kvConfig.GotoFirstSubKey(false))
		return;

	do
	{
		char sSection[32];
		kvConfig.GetSectionName(sSection, sizeof(sSection));

		char sName[64];
		kvConfig.GetString("name", sName, sizeof(sName), "MISSING_NAME");

		CStage cStage = new CStage();
		cStage.SetName(sName);

		if (!kvConfig.JumpToKey("triggers", false))
		{
			kvConfig.GoBack(); // "stages"
			kvConfig.GoBack(); // "GotoFirstSubKey"

			LogError("Config error in stage \"%s\"(\"%s\"), missing \"triggers\" block.", sSection, sName);
			continue;
		}

		if (!kvConfig.GotoFirstSubKey(false))
		{
			kvConfig.GoBack(); // "stages"
			kvConfig.GoBack(); // "GotoFirstSubKey"
			kvConfig.GoBack(); // "triggers"

			LogError("Config error in stage \"%s\"(\"%s\"), empty \"triggers\" block.", sSection, sName);
			continue;
		}

		do
		{
			CTrigger cTrigger = new CTrigger();

			char sTrigger[64];
			kvConfig.GetString(NULL_STRING, sTrigger, sizeof(sTrigger));

			cTrigger.SetKey("");
			cTrigger.SetValue(sTrigger);

			cStage.AddTrigger(cTrigger);

		} while(kvConfig.GotoNextKey(false));

		kvConfig.GoBack(); // "triggers"
		kvConfig.GoBack(); // "GotoFirstSubKey"

		if (!kvConfig.JumpToKey("actions", false))
		{
			kvConfig.GoBack(); // "stages"
			kvConfig.GoBack(); // "GotoFirstSubKey"

			LogError("Config error in stage \"%s\"(\"%s\"), missing \"actions\" block.", sSection, sName);
			continue;
		}

		if (!kvConfig.GotoFirstSubKey(false))
		{
			kvConfig.GoBack(); // "stages"
			kvConfig.GoBack(); // "GotoFirstSubKey"
			kvConfig.GoBack(); // "actions"

			LogError("Config error in stage \"%s\"(\"%s\"), empty \"actions\" block.", sSection, sName);
			continue;
		}

		do
		{
			CAction cAction = new CAction();

			char sAction[256];
			kvConfig.GetString(NULL_STRING, sAction, sizeof(sAction));

			int iDelim = FindCharInString(sAction, ':');
			if(iDelim == -1)
			{
				char sActionSection[32];
				kvConfig.GetSectionName(sActionSection, sizeof(sActionSection));

				kvConfig.GoBack(); // "actions"
				kvConfig.GoBack(); // "GotoFirstSubKey"
				kvConfig.GoBack(); // "stages"
				kvConfig.GoBack(); // "GotoFirstSubKey"

				LogError("Config error in stage \"%s\"(\"%s\"), action \"%s\" missing delim ':'.", sSection, sName, sActionSection);
				continue;
			}

			sAction[iDelim++] = 0;

			cAction.SetKey("");
			cAction.SetIdentifier(sAction);
			cAction.SetEvent(sAction[iDelim]);
	
			cStage.AddAction(cAction);

		} while(kvConfig.GotoNextKey(false));

		kvConfig.GoBack(); // "actions"
		kvConfig.GoBack(); // "GotoFirstSubKey"

		g_AdminRoom.AddStage(cStage);

	} while(kvConfig.GotoNextKey(false));

	kvConfig.Rewind();
}

stock void DetectAdminRoomLocations()
{
	int entity = -1, entityNear = -1;
	bool loop;
	float entityPosition[3], entityPositionNear[3];
	float distance = 0.0;

	entity = -1;
	while((entity = FindEntityByClassname(entity, "func_button")) != -1)
	{
		if (!logicalButtonMatch(entity))
			continue;

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityPosition);
		loop = true;
		entityNear = -1;

		while ((entityNear = FindEntityByClassname(entityNear, "func_button")) != -1 && loop)
		{
			if (entity != entityNear && logicalButtonMatch(entityNear))
			{
				GetEntPropVector(entityNear, Prop_Send, "m_vecOrigin", entityPositionNear);
				distance = GetVectorDistance(entityPosition, entityPositionNear, false);
				if (distance < 500.00)
				{
					if (POSITIVE(entityPosition[0] - entityPositionNear[0]) < 40.00
					|| POSITIVE(entityPosition[1] - entityPositionNear[1]) < 40.00
					|| POSITIVE(entityPosition[2] - entityPositionNear[2]) < 40.00)
					{
						if (!IsValidEntity(entity) || !entity)
							continue;

						CAdminRoomLocation cAdminRoomLocation = new CAdminRoomLocation();

						char sName[64];
						GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

						char sFinalName[32];
						if (!sName[0])
							FormatEx(sFinalName, sizeof(sFinalName), "Button %d", g_cAdminRoomLocationsDetected.Length + 1);
						else
							FormatEx(sFinalName, sizeof(sFinalName), "%s", sName);

						cAdminRoomLocation.SetName(sFinalName);

						float fOrigin[3];
						GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
						cAdminRoomLocation.SetOrigin(fOrigin);

						g_cAdminRoomLocationsDetected.Push(cAdminRoomLocation);

						loop = false;
					}
				}
			}
		}
	}

	if (g_cAdminRoomLocationsDetected != null && g_cAdminRoomLocationsDetected.Length > 0)
	{
		// SortCustom1D(g_ArrayEntity, dArraySize, OrderByLocation);
	}
}

stock bool logicalButtonMatch(int entity)
{
	char buffer[100];
	
	GetEntPropString(entity, Prop_Data, "m_iParent", buffer, 5);

	if(strlen(buffer))
	{
		// BAD MATCH
		return false;
	}

	GetEntPropString(entity, Prop_Data, "m_iName", buffer, 50);
	if(strlen(buffer))
	{
		for(int i = 0; i < g_aAutoDetect.Length; i++)
		{
			char sAutoDetectWord[32];
			g_aAutoDetect.GetString(i, sAutoDetectWord, sizeof(sAutoDetectWord));

			if(StrContains(buffer, sAutoDetectWord, false) !=-1)
			{
				// NICE MATCH
				return true;
			}
		}
	}

	int count = GetOutputCount( entity, "m_OnPressed" );
	for( int output = 0; output < count; output++ )
	{
		GetOutputParameter( entity, "m_OnPressed", output, buffer, 100);

		if(!startWith(buffer, "say")) continue;

		for(int i = 0; i < g_aAutoDetect.Length; i++)
		{
			char sAutoDetectWord[32];
			g_aAutoDetect.GetString(i, sAutoDetectWord, sizeof(sAutoDetectWord));

			if(StrContains(buffer, sAutoDetectWord, false) != -1)
			{
				// NICE MATCH
				return true;
			}
		}
	}

	// NO MATCH
	return false;
}

stock int OrderByLocation(int index1, int index2, const int[] array, Handle hndl)
{
	float position[3];

	GetEntPropVector(index1, Prop_Send, "m_vecOrigin", position);
	float A = position[0] + position[1] + position[2];

	GetEntPropVector(index2, Prop_Send, "m_vecOrigin", position);
	float B = position[0] + position[1] + position[2];

	return FloatCompare(A, B);
}

stock bool startWith(const char[] str, const char[] substr, bool caseSensitive = false)
{
	char pattern[125];
	FormatEx(pattern, 125, "%s^\\s*(%s)", caseSensitive ? "" : "(?i)", substr);
	Regex sw_regex = CompileRegex(pattern);
	int result = MatchRegex(sw_regex, str);
	CloseHandle(sw_regex);
	return result > 0;
}

stock void GoToEntity(int client, CAdminRoomLocation cAdminRoomLocation)
{
	float currentPlayerPosition[3];
	GetClientAbsOrigin(client, currentPlayerPosition);

	char sAdminRoomLocationName[32];
	cAdminRoomLocation.GetName(sAdminRoomLocationName, sizeof(sAdminRoomLocationName));

	float entityposition[3];
	cAdminRoomLocation.GetOrigin(entityposition);

	g_fPlayerOrigin[client] = currentPlayerPosition;

	TeleportEntity(client, entityposition, NULL_VECTOR, NULL_VECTOR);

	CShowActivity2(client, "{green}[SM] {olive}", "{default}has been teleported to the adminroom.");

	LogAction(client, -1, "\"%L\" teleported himself to the adminroom.", client);

	CreateTimer(0.2, Timer_StuckFix, client, TIMER_FLAG_NO_MAPCHANGE);
}

stock void GetOut(int client)
{
	if (g_fPlayerOrigin[client][0] == 0.0 && g_fPlayerOrigin[client][1] == 0.0 && g_fPlayerOrigin[client][2] == 0.0)
	{
		CPrintToChat(client, "%s Could not teleport you because your position was not saved.", TAG_COLOR);
		return;
	}

	TeleportEntity(client, g_fPlayerOrigin[client], NULL_VECTOR, NULL_VECTOR);
	CPrintToChat(client, "%s You have left the admin room.", TAG_COLOR);
	LogAction(client, -1, "\"%L\" teleported himself OUT of the adminroom.", client);
}

/*
======================================================================================================
	The anti-stuck code below is taken from: https://forums.alliedmods.net/showthread.php?t=243151
	Credit to Erreur 500 @ alliedmods
======================================================================================================
*/

public Action Timer_StuckFix(Handle timer, any client)
{
	StuckCheck[client] = 0;
	StartStuckDetection(client);
	FixPlayerPosition(client);
	return Plugin_Handled;
}

stock void StartStuckDetection(int client)
{
	isStuck[client] = false;
	isStuck[client] = CheckIfPlayerIsStuck(client); 
}

stock bool CheckIfPlayerIsStuck(int client)
{
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceEntityFilterSolid);
	return TR_DidHit();
}

public bool TraceEntityFilterSolid(int entity, int contentsMask) 
{
	return entity > MaxClients;
}

stock void FixPlayerPosition(int client)
{
	if(isStuck[client])
	{
		float pos_Z = 0.1;
		
		while(pos_Z <= RADIUSSIZE && !TryFixPosition(client, 10.0, pos_Z))
		{	
			pos_Z = -pos_Z;
			if(pos_Z > 0.0)
			{
				pos_Z += STEP;
			}
		}
	}
	else 
	{
		Handle trace = INVALID_HANDLE;
		float vecOrigin[3];
		float vecAngle[3];
		
		GetClientAbsOrigin(client, vecOrigin);
		vecAngle[0] = 90.0;
		trace = TR_TraceRayFilterEx(vecOrigin, vecAngle, MASK_SOLID, RayType_Infinite, TraceEntityFilterSolid);		
		if(!TR_DidHit(trace)) 
		{
			CloseHandle(trace);
			return;
		}
		
		TR_GetEndPosition(vecOrigin, trace);
		CloseHandle(trace);
		vecOrigin[2] += 10.0;
		TeleportEntity(client, vecOrigin, NULL_VECTOR, Ground_Velocity); 
		
		if(StuckCheck[client] < 7)
		{
			StartStuckDetection(client);
		}
	}
}

bool TryFixPosition(int client, float Radius, float pos_Z)
{
	float DegreeAngle;
	float vecPosition[3];
	float vecOrigin[3];
	float vecAngle[3];
	
	GetClientAbsOrigin(client, vecOrigin);
	GetClientEyeAngles(client, vecAngle);
	vecPosition[2] = vecOrigin[2] + pos_Z;

	DegreeAngle = -180.0;
	while(DegreeAngle < 180.0)
	{
		vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180);
		vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180);
		
		TeleportEntity(client, vecPosition, vecAngle, Ground_Velocity);
		if(!CheckIfPlayerIsStuck(client))
		{
			return true;
		}
		DegreeAngle += 10.0;
	}
	
	TeleportEntity(client, vecOrigin, vecAngle, Ground_Velocity);
	
	if(Radius <= RADIUSSIZE)
	{
		return TryFixPosition(client, Radius + STEP, pos_Z);
	}
	return false;
}

int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname="*")
{
	if(sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if(strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}

	return INVALID_ENT_REFERENCE;
}
