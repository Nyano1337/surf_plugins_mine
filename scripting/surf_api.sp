#include <sourcemod>
#include <sdktools>

#undef REQUIRE_EXTENSIONS
#include <dhooks>

DynamicHook gH_HookTeleport = null;

#define CHANGE_FLAGS(%1,%2) (%1 = (%2))

#define FL_ONTELEPORT              (1 << 0)   /**< Client is teleporting */

enum struct HookingPlayer
{
	int iHookedIndex;
	int iPlayerFlags;
	bool bHooked;

	void AddFlag(int flags)
	{
		CHANGE_FLAGS(this.iPlayerFlags, this.iPlayerFlags | flags);
	}

	void RemoveFlag(int flagsToRemove)
	{
		DataPack dp = new DataPack();
		dp.WriteCell(flagsToRemove);
		dp.WriteCell(this.iHookedIndex);

		RequestFrame(Frame_RemoveFlag, dp);
	}

	int GetFlags()
	{
		return this.iPlayerFlags;
	}
}

HookingPlayer gA_HookedPlayer[MAXPLAYERS+1];

public void Frame_RemoveFlag(DataPack dp)
{
	RequestFrame(Frame2_RemoveFlag, dp);
}

public void Frame2_RemoveFlag(DataPack dp)
{
	dp.Reset();

	int flagsToRemove = dp.ReadCell();
	int client = dp.ReadCell();

	delete dp;

	CHANGE_FLAGS(gA_HookedPlayer[client].iPlayerFlags, gA_HookedPlayer[client].iPlayerFlags & ~flagsToRemove);
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_tp", Command_TP);

	GameData gamedata = new GameData("sdktools.games");

	if (gamedata == null)
	{
		SetFailState("Failed to load sdktools gamedata");
	}

	int iOffset;

	if ((iOffset = GameConfGetOffset(gamedata, "Teleport")) != -1)
	{
		gH_HookTeleport = new DynamicHook(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
		gH_HookTeleport.AddParam(HookParamType_VectorPtr);
	}
	else
	{
		SetFailState("Couldn't get the offset for \"Teleport\" - make sure your gamedata is updated!");
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	if(gA_HookedPlayer[client].bHooked)
	{
		return;
	}

	gH_HookTeleport.HookEntity(Hook_Pre, client, Detour_OnTeleport);
	gH_HookTeleport.HookEntity(Hook_Post, client, Detour_OnTeleport_Post);
	gA_HookedPlayer[client].bHooked = true;
	gA_HookedPlayer[client].iHookedIndex = client;
}

public void OnClientDisconnect(int client)
{
	gA_HookedPlayer[client].bHooked = false;
	gA_HookedPlayer[client].iHookedIndex = 0;
}

public MRESReturn Detour_OnTeleport(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	gA_HookedPlayer[pThis].AddFlag(FL_ONTELEPORT);

	return MRES_Ignored;
}

public MRESReturn Detour_OnTeleport_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	gA_HookedPlayer[pThis].RemoveFlag(FL_ONTELEPORT);

	return MRES_Ignored;
}

public Action Command_TP(int client, int args)
{
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, {999.0, 999.0, 999.0});

	return Plugin_Continue;
}

stock bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}

public Action OnPlayerRunCmd(int client)
{
	if(gA_HookedPlayer[client].GetFlags() & FL_ONTELEPORT)
	{
		PrintToChat(client, "You are on teleport!");
	}

	return Plugin_Continue;
}