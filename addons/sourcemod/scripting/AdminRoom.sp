#include <sourcemod>
#include <sdktools>
#include <cstrike>
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
int g_iCurrentStage = -1;
Handle g_hForwardOnStageChanged = null;

bool g_bLateLoad = false;

// Stage vote (merged from sm-plugin-PotcVote / sm-plugin-MakoVote)
bool g_bVoteFinished = true;
bool g_bVoteStartNextRound = false;
bool g_bIsRevote = false;
ArrayList g_cStageCooldown = null;  // int (0/1) per stage index, parallel to g_AdminRoom's stages
ArrayList g_cStagePlayed = null;    // int (0/1) per stage index, parallel to g_AdminRoom's stages
ArrayList g_cVoteStageOrder = null; // shuffled stage indices eligible for the current vote
Handle g_VoteMenu = null;
Handle g_hVoteCountdownTimer = null;

public Plugin myinfo =
{
	name = "Admin Room",
	author = "IT-KILLER, BotoX, maxime1907, .Rushaway",
	description = "Teleport to admin rooms, change stages, and vote to replay a stage.",
	version = "2.2.0",
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

	RegAdminCmd("sm_stagevote", Command_StageVote, ADMFLAG_CONVARS, "Start a vote to pick the next stage");
	RegAdminCmd("sm_potcvote", Command_StageVote, ADMFLAG_CONVARS, "Legacy alias for sm_stagevote (sm-plugin-PotcVote)");
	RegAdminCmd("sm_makovote", Command_StageVote, ADMFLAG_CONVARS, "Legacy alias for sm_stagevote (sm-plugin-MakoVote)");

	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);

	g_hForwardOnStageChanged = CreateGlobalForward("AdminRoom_OnStageChanged", ET_Ignore, Param_Cell, Param_String, Param_Cell);

	CreateNative("AdminRoom_IsEnabled", Native_AdminRoom_IsEnabled);
	CreateNative("AdminRoom_GetStageCount", Native_AdminRoom_GetStageCount);
	CreateNative("AdminRoom_GetStageName", Native_AdminRoom_GetStageName);
	CreateNative("AdminRoom_GetCurrentStage", Native_AdminRoom_GetCurrentStage);
	CreateNative("AdminRoom_SetStage", Native_AdminRoom_SetStage);
	CreateNative("AdminRoom_SetStageByTrigger", Native_AdminRoom_SetStageByTrigger);

	RegPluginLibrary("AdminRoom");
}

public void EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		OnClientDisconnect(client);
	}
	DetectAdminRoomLocations();

	if (g_bVoteStartNextRound)
	{
		g_bVoteStartNextRound = false;
		StartVoteCountdown();
	}
}

public void OnMapStart()
{
	LoadMapConfig();
	LoadConfig();

	ResetVoteState();

	if (g_bLateLoad)
	{
		EventRoundStart(null, "", true);
		g_bLateLoad = false;
	}
}

public void OnMapEnd()
{
	g_hVoteCountdownTimer = null;
	delete g_cVoteStageOrder;
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

	int index;
	if (!FindStageIndexByTrigger(sArg, index))
	{
		CReplyToCommand(client, "%s Invalid stage %s", TAG_COLOR, sArg);
		return Plugin_Handled;
	}

	ChangeStageByIndex(index, client);
	return Plugin_Handled;
}

// Finds the stage whose triggers contain sArg. Returns false (index untouched) if none match.
stock bool FindStageIndexByTrigger(const char[] sArg, int &index)
{
	ArrayList cStages;
	if (!g_AdminRoom.bEnabled || !g_AdminRoom.GetStages(cStages))
		return false;

	for (int i = 0; i < cStages.Length; i++)
	{
		CStage cStage = cStages.Get(i);

		ArrayList cTriggers;
		if (!cStage.GetTriggers(cTriggers))
			continue;

		for (int y = 0; y < cTriggers.Length; y++)
		{
			CTrigger cTrigger = cTriggers.Get(y);

			char sTrigger[32];
			cTrigger.GetValue(sTrigger, sizeof(sTrigger));

			if (strcmp(sArg, sTrigger, false) == 0)
			{
				index = i;
				return true;
			}
		}
	}

	return false;
}

// Fires every action (identifier:event) in cActions, as if the given client triggered them.
// Returns false without firing the remaining actions if a required func_button is locked.
stock bool FireActions(ArrayList cActions, int client, const char[] sContextName = "")
{
	if (!cActions)
		return true;

	for (int y = 0; y < cActions.Length; y++)
	{
		CAction cAction = cActions.Get(y);

		char sIdentifier[64];
		cAction.GetIdentifier(sIdentifier, sizeof(sIdentifier));

		char sEvent[64];
		cAction.GetEvent(sEvent, sizeof(sEvent));

		int entity = INVALID_ENT_REFERENCE;
		while((entity = FindEntityByTargetname(entity, sIdentifier, "*")) != INVALID_ENT_REFERENCE)
		{
			char sClassnameBuf[64];
			GetEdictClassname(entity, sClassnameBuf, sizeof(sClassnameBuf));
			if (strcmp(sClassnameBuf, "func_button", false) == 0)
			{
				int iOffset = FindDataMapInfo(entity, "m_bLocked");
				if (iOffset != -1 && GetEntData(entity, iOffset, 1))
				{
					// Handling client for plugins who change stages (to be able to debug it)
					if (client > 0)
						CReplyToCommand(client, "%s Can not set \"{olive}%s{default}\". Button (#%s) is locked.", TAG_COLOR, sContextName, sIdentifier);
					else
					{
						CPrintToChatAll("%s Can not set \"{olive}%s{default}\". Button (#%s) is locked.", TAG_COLOR, sContextName, sIdentifier);
						LogAction(client, -1, "\"%L\" tried to set \"%s\" but the button (#%s) is locked.", client, sContextName, sIdentifier);
					}

					return false;
				}
			}
			AcceptEntityInput(entity, sEvent, client, client);
		}
	}

	return true;
}

// Changes the current map's stage by index: fires its actions, tracks it as the current stage,
// announces the change and fires AdminRoom_OnStageChanged(). Shared by sm_stage, the stage vote
// and the AdminRoom_SetStage()/AdminRoom_SetStageByTrigger() natives.
stock bool ChangeStageByIndex(int index, int client)
{
	ArrayList cStages;
	if (!g_AdminRoom.bEnabled || !g_AdminRoom.GetStages(cStages) || index < 0 || index >= cStages.Length)
		return false;

	CStage cStage = cStages.Get(index);

	char sName[64];
	cStage.GetName(sName, sizeof(sName));

	ArrayList cActions;
	cStage.GetActions(cActions);

	if (!FireActions(cActions, client, sName))
		return false;

	g_iCurrentStage = index;

	if (client > 0)
		CShowActivity2(client, "{green}[SM] {olive}", "{default}Changed the stage to {green}%s{default}.", sName);
	else
		ShowActivity2(client, "[SM] ", "Changed the stage to %s.", sName);

	LogAction(client, -1, "\"%L\" changed the stage to \"%s\".", client, sName);

	Call_StartForward(g_hForwardOnStageChanged);
	Call_PushCell(index);
	Call_PushString(sName);
	Call_PushCell(client);
	Call_Finish();

	return true;
}

/*
======================================================================================================
	Stage vote: when all of a map's stages have been played, vote to pick one to play again.
	Merged from sm-plugin-PotcVote and sm-plugin-MakoVote, generalized to any map configured with
	AdminRoom stages instead of being hardcoded per map. Reachable through sm_stagevote (and the
	sm_potcvote / sm_makovote aliases, so existing maps' point_servercommand entities keep working
	unmodified) as well as any other plugin via AdminRoom_SetStage()/AdminRoom_SetStageByTrigger().
======================================================================================================
*/

public Action Command_StageVote(int client, int argc)
{
	CVoteConfig cVoteConfig;
	if (!g_AdminRoom.bEnabled || !g_AdminRoom.GetVoteConfig(cVoteConfig) || !cVoteConfig.bEnabled)
	{
		if (client > 0)
			CReplyToCommand(client, "%s Stage vote is not configured for this map.", TAG_COLOR);
		return Plugin_Handled;
	}

	if (!g_bVoteFinished)
	{
		if (client > 0)
			CReplyToCommand(client, "%s A stage vote is already in progress.", TAG_COLOR);
		return Plugin_Handled;
	}

	char sName[64];
	if (client == 0)
		strcopy(sName, sizeof(sName), "The server");
	else if (!GetClientName(client, sName, sizeof(sName)))
		FormatEx(sName, sizeof(sName), "Disconnected (uid:%d)", client);

	if (client != 0)
	{
		CPrintToChatAll("%s {cyan}%s{default} has initiated a stage vote (in %.0f seconds).", TAG_COLOR, sName, cVoteConfig.fDelay);
		TerminateVoteRound(cVoteConfig.fDelay);
	}

	Cmd_StartVote();

	return Plugin_Handled;
}

// Resets per-map vote bookkeeping. Called on every map start.
stock void ResetVoteState()
{
	g_bVoteFinished = true;
	g_bVoteStartNextRound = false;
	g_bIsRevote = false;

	delete g_hVoteCountdownTimer;
	delete g_cStageCooldown;
	delete g_cStagePlayed;
	delete g_cVoteStageOrder;

	ArrayList cStages;
	int iStageCount = g_AdminRoom.GetStages(cStages) ? cStages.Length : 0;

	g_cStageCooldown = new ArrayList();
	g_cStagePlayed = new ArrayList();
	for (int i = 0; i < iStageCount; i++)
	{
		g_cStageCooldown.Push(0);
		g_cStagePlayed.Push(0);
	}
}

void Cmd_StartVote()
{
	if (g_iCurrentStage > -1 && g_iCurrentStage < g_cStageCooldown.Length)
		g_cStageCooldown.Set(g_iCurrentStage, 1);

	CVoteConfig cVoteConfig;
	g_AdminRoom.GetVoteConfig(cVoteConfig);

	int iOnCooldown = 0;
	for (int i = 0; i < g_cStageCooldown.Length; i++)
		iOnCooldown += g_cStageCooldown.Get(i);

	if (iOnCooldown >= cVoteConfig.iCooldownMax)
	{
		for (int i = 0; i < g_cStageCooldown.Length; i++)
			g_cStageCooldown.Set(i, 0);
	}

	g_bVoteFinished = false;
	g_bIsRevote = false;
	GenerateVoteStageOrder();
	g_bVoteStartNextRound = true;
}

// Builds a shuffled list of votable stage indices for the upcoming vote menu.
void GenerateVoteStageOrder()
{
	delete g_cVoteStageOrder;
	g_cVoteStageOrder = new ArrayList();

	ArrayList cStages;
	if (!g_AdminRoom.GetStages(cStages))
		return;

	for (int i = 0; i < cStages.Length; i++)
	{
		CStage cStage = cStages.Get(i);
		if (cStage.bVotable)
			g_cVoteStageOrder.Push(i);
	}

	int iSize = g_cVoteStageOrder.Length;
	for (int i = 0; i < iSize; i++)
	{
		int iRandom = GetRandomInt(0, iSize - 1);
		int iTemp1 = g_cVoteStageOrder.Get(iRandom);
		int iTemp2 = g_cVoteStageOrder.Get(i);
		g_cVoteStageOrder.Set(i, iTemp1);
		g_cVoteStageOrder.Set(iRandom, iTemp2);
	}
}

// Called once the round that should carry the vote actually starts: rolls each eligible stage's
// "roll the dice" chance (generalized MakoVote RTD/ZM behavior), then either applies the winner
// directly or fires the map's configured vote-start actions and begins the countdown.
void StartVoteCountdown()
{
	if (TryRollRtdStage())
		return;

	CVoteConfig cVoteConfig;
	g_AdminRoom.GetVoteConfig(cVoteConfig);

	ArrayList cOnStartActions;
	if (cVoteConfig.GetOnStartActions(cOnStartActions))
		FireActions(cOnStartActions, 0);

	delete g_hVoteCountdownTimer;
	g_hVoteCountdownTimer = CreateTimer(1.0, Timer_VoteCountdown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

// Rolls the dice for every votable stage with iRtdPercent > 0 that hasn't been played yet and
// isn't on cooldown. Returns true (and applies the stage immediately, skipping the vote) on a hit.
bool TryRollRtdStage()
{
	ArrayList cStages;
	if (!g_AdminRoom.GetStages(cStages))
		return false;

	for (int i = 0; i < cStages.Length; i++)
	{
		CStage cStage = cStages.Get(i);

		if (cStage.iRtdPercent <= 0)
			continue;

		if (i < g_cStagePlayed.Length && g_cStagePlayed.Get(i))
			continue;

		if (i < g_cStageCooldown.Length && g_cStageCooldown.Get(i))
			continue;

		if (GetRandomInt(1, 100) > cStage.iRtdPercent)
			continue;

		char sName[64];
		cStage.GetName(sName, sizeof(sName));

		CPrintToChatAll("%s Rolling the dice... Result: {green}%s{default}!", TAG_COLOR, sName);

		if (i < g_cStagePlayed.Length)
			g_cStagePlayed.Set(i, 1);

		g_bVoteFinished = true;
		ChangeStageByIndex(i, 0);
		TerminateVoteRound(1.5);

		return true;
	}

	return false;
}

public Action Timer_VoteCountdown(Handle timer)
{
	CVoteConfig cVoteConfig;
	g_AdminRoom.GetVoteConfig(cVoteConfig);

	static int iCountdown = -1;
	if (iCountdown < 0)
		iCountdown = cVoteConfig.iCountdown;

	PrintCenterTextAll("[AdminRoom] Starting stage vote in %ds", iCountdown);

	if (iCountdown-- <= 0)
	{
		iCountdown = -1;
		g_hVoteCountdownTimer = null;
		InitiateStageVote();
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void InitiateStageVote()
{
	if (IsVoteInProgress())
	{
		delete g_hVoteCountdownTimer;
		g_hVoteCountdownTimer = CreateTimer(5.0, Timer_VoteCountdown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	ArrayList cStages;
	g_AdminRoom.GetStages(cStages);

	g_VoteMenu = CreateMenu(Handler_StageVoteMenu, MenuAction_End|MenuAction_Display|MenuAction_DisplayItem|MenuAction_VoteCancel);

	for (int i = 0; i < g_cVoteStageOrder.Length; i++)
	{
		int iStageIndex = g_cVoteStageOrder.Get(i);
		CStage cStage = cStages.Get(iStageIndex);

		char sName[64];
		cStage.GetName(sName, sizeof(sName));

		char sInfo[16];
		IntToString(iStageIndex, sInfo, sizeof(sInfo));

		bool bOnCooldown = view_as<bool>(g_cStageCooldown.Get(iStageIndex));

		AddMenuItem(g_VoteMenu, sInfo, sName, bOnCooldown ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	SetMenuOptionFlags(g_VoteMenu, MENU_NO_PAGINATION);
	SetMenuTitle(g_VoteMenu, "What stage to play next?");
	SetVoteResultCallback(g_VoteMenu, Handler_StageVoteFinished);
	VoteMenuToAll(g_VoteMenu, 15);
}

public int Handler_StageVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;

		if (param1 != -1)
		{
			g_bVoteFinished = true;
			TerminateVoteRound(1.5);
		}
	}
	return 0;
}

public void Handler_StageVoteFinished(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	CVoteConfig cVoteConfig;
	g_AdminRoom.GetVoteConfig(cVoteConfig);

	int iHighestVotes = item_info[0][VOTEINFO_ITEM_VOTES];
	int iRequiredVotes = RoundToCeil(float(num_votes) * float(cVoteConfig.iPercent) / 100.0);

	if (num_items > 1 && iHighestVotes < iRequiredVotes && !g_bIsRevote)
	{
		CPrintToChatAll("%s A revote is needed!", TAG_COLOR);

		char sFirst[16], sSecond[16];
		GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sFirst, sizeof(sFirst));
		GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], sSecond, sizeof(sSecond));

		delete g_cVoteStageOrder;
		g_cVoteStageOrder = new ArrayList();
		g_cVoteStageOrder.Push(StringToInt(sFirst));
		g_cVoteStageOrder.Push(StringToInt(sSecond));

		g_bIsRevote = true;

		delete g_hVoteCountdownTimer;
		g_hVoteCountdownTimer = CreateTimer(1.0, Timer_VoteCountdown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		return;
	}

	g_bIsRevote = false;
	FinishStageVote(menu, item_info);
}

void FinishStageVote(Handle menu, const int[][] item_info)
{
	g_bVoteFinished = true;

	char sIndex[16];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sIndex, sizeof(sIndex));
	int iWinnerStage = StringToInt(sIndex);

	ArrayList cStages;
	g_AdminRoom.GetStages(cStages);

	if (iWinnerStage < 0 || iWinnerStage >= cStages.Length)
		return;

	CStage cStage = cStages.Get(iWinnerStage);

	char sName[64];
	cStage.GetName(sName, sizeof(sName));

	CPrintToChatAll("%s Vote Finished! Moving to {green}%s{default}.", TAG_COLOR, sName);

	if (iWinnerStage < g_cStagePlayed.Length)
		g_cStagePlayed.Set(iWinnerStage, 1);

	ChangeStageByIndex(iWinnerStage, 0);
	TerminateVoteRound(1.5);
}

stock void TerminateVoteRound(float delay)
{
	CS_TerminateRound(delay, CSRoundEnd_Draw, false);

	// Fix the score - Round Draw gives 1 point to CT Team
	int score = GetTeamScore(CS_TEAM_CT);
	if (score > 0)
		SetTeamScore(CS_TEAM_CT, score - 1);
}

/*
======================================================================================================
	Public API (see include/AdminRoom.inc)
======================================================================================================
*/

public int Native_AdminRoom_IsEnabled(Handle plugin, int numParams)
{
	return g_AdminRoom.bEnabled;
}

public int Native_AdminRoom_GetStageCount(Handle plugin, int numParams)
{
	ArrayList cStages;
	if (!g_AdminRoom.GetStages(cStages))
		return 0;

	return cStages.Length;
}

public int Native_AdminRoom_GetStageName(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	int maxlen = GetNativeCell(3);

	ArrayList cStages;
	if (!g_AdminRoom.GetStages(cStages) || index < 0 || index >= cStages.Length || maxlen <= 0)
		return false;

	CStage cStage = cStages.Get(index);

	char[] sName = new char[maxlen];
	cStage.GetName(sName, maxlen);
	SetNativeString(2, sName, maxlen);

	return true;
}

public int Native_AdminRoom_GetCurrentStage(Handle plugin, int numParams)
{
	return g_iCurrentStage;
}

public int Native_AdminRoom_SetStage(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	int client = GetNativeCell(2);

	return ChangeStageByIndex(index, client);
}

public int Native_AdminRoom_SetStageByTrigger(Handle plugin, int numParams)
{
	int client = GetNativeCell(2);

	int len;
	GetNativeStringLength(1, len);
	char[] sTrigger = new char[len + 1];
	GetNativeString(1, sTrigger, len + 1);

	int index;
	if (!FindStageIndexByTrigger(sTrigger, index))
		return false;

	return ChangeStageByIndex(index, client);
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

		CVoteConfig cVoteConfig;
		if (g_AdminRoom.GetVoteConfig(cVoteConfig))
		{
			ArrayList cOnStartActions;
			if (cVoteConfig.GetOnStartActions(cOnStartActions))
			{
				for (int i = 0; i < cOnStartActions.Length; i++)
				{
					CAction cAction = cOnStartActions.Get(i);
					delete cAction;
				}
				delete cOnStartActions;
			}
			delete cVoteConfig;
		}

		delete g_AdminRoom;
	}
	g_AdminRoom = new CAdminRoom();
	g_iCurrentStage = -1;
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

	// Attempt to load the override config with default map name
	if (!FileExists(sConfigFile_override))
		BuildPath(Path_SM, sConfigFile_override, sizeof(sConfigFile_override), "configs/adminroom/maps/%s_override.cfg", sMapNameLowercase);

	// Attempt to load the override config with lowercase map name
	if (FileExists(sConfigFile_override))
	{
		if(!kvConfig.ImportFromFile(sConfigFile_override))
		{
			LogMessage("Unable to load config override: \"%s\"", sConfigFile_override);
			delete kvConfig;
			return;
		}

		LogMessage("Loaded override mapconfig: \"%s\"", sConfigFile_override);
	}
	else // No override config found, try to load the default config
	{
		// Attempt to load the default config with default map name
		if (!FileExists(sConfigFile))
			BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/adminroom/maps/%s.cfg", sMapNameLowercase);

		// Attempt to load the default config with lowercase map name
		if (FileExists(sConfigFile))
		{
			if(!kvConfig.ImportFromFile(sConfigFile))
			{
				LogMessage("Unable to load config: \"%s\"", sConfigFile);
				delete kvConfig;
				return;
			}

			LogMessage("Loaded mapconfig: \"%s\"", sConfigFile);
		}
	}

	kvConfig.Rewind();

	g_AdminRoom.bEnabled = true;

	LoadMapAdminRoomLocations(kvConfig);

	LoadMapStages(kvConfig);

	LoadMapVoteConfig(kvConfig);

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
		cStage.bVotable = (kvConfig.GetNum("votable", 1) != 0);
		cStage.iRtdPercent = kvConfig.GetNum("rtd_percent", 0);

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

// Optional "votes" block in the map config, enabling the stage vote for maps that opt in:
//
// "votes"
// {
//     "percent"    "60"   // percent of votes the winner needs to avoid a revote
//     "delay"      "3.0"  // seconds before the round ends when an admin starts a vote manually
//     "countdown"  "3"    // seconds shown to players before the vote menu opens
//     "cooldown"   "2"    // most-recently-played stages disabled in the menu before reset
//     "actions"            // fired once when a vote starts (same format as a stage's "actions")
//     {
//         "0"    "ambient_music:Kill"
//     }
// }
stock void LoadMapVoteConfig(KeyValues kvConfig)
{
	if (!kvConfig.JumpToKey("votes", false))
		return;

	CVoteConfig cVoteConfig;
	g_AdminRoom.GetVoteConfig(cVoteConfig);

	cVoteConfig.bEnabled = true;
	cVoteConfig.iPercent = kvConfig.GetNum("percent", 60);
	cVoteConfig.fDelay = kvConfig.GetFloat("delay", 3.0);
	cVoteConfig.iCountdown = kvConfig.GetNum("countdown", 3);
	cVoteConfig.iCooldownMax = kvConfig.GetNum("cooldown", 2);

	if (kvConfig.JumpToKey("actions", false) && kvConfig.GotoFirstSubKey(false))
	{
		do
		{
			char sAction[256];
			kvConfig.GetString(NULL_STRING, sAction, sizeof(sAction));

			int iDelim = FindCharInString(sAction, ':');
			if (iDelim == -1)
				continue;

			sAction[iDelim++] = 0;

			CAction cAction = new CAction();
			cAction.SetKey("");
			cAction.SetIdentifier(sAction);
			cAction.SetEvent(sAction[iDelim]);

			cVoteConfig.AddOnStartAction(cAction);

		} while(kvConfig.GotoNextKey(false));
	}

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

stock int OrderByLocation(int index1, int index2)
{
	float position[3];

	GetEntPropVector(index1, Prop_Send, "m_vecOrigin", position);
	float A = position[0] + position[1] + position[2];

	GetEntPropVector(index2, Prop_Send, "m_vecOrigin", position);
	float B = position[0] + position[1] + position[2];

	if (A > B)
		return 1;
	if (A < B)
		return -1;
	return 0;
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
