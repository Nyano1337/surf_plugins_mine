#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

//===================================================================================================================
// Hud Element hiding flags
#define HIDEHUD_DEFAULT 				0
#define HIDEHUD_WEAPONSELECTION 		(1 << 0)	// Hide ammo count & weapon selection
#define HIDEHUD_FLASHLIGHT				(1 << 1)
#define HIDEHUD_ALL 					(1 << 2)
#define HIDEHUD_HEALTH					(1 << 3)	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD				(1 << 4)	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT				(1 << 5)	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS				(1 << 6)	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT					(1 << 7)	// Hide all communication elements (saytext, voice icon, etc)
#define HIDEHUD_CROSSHAIR				(1 << 8)	// Hide crosshairs
#define HIDEHUD_VEHICLE_CROSSHAIR		(1 << 9)	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE				(1 << 10)
#define HIDEHUD_BONUS_PROGRESS			(1 << 11)	// Hide bonus progress display (for bonus map challenges)
#define HIDEHUD_RADAR					(1 << 12)   // Hides the radar in CS1.5
#define HIDEHUD_MINISCOREBOARD      	(1 << 13)   // Hides the miniscoreboard in CS1.5

#define HIDEHUD_BITCOUNT				14

char gS_CSGOHudSettings[][] = 
{
	"弹药数和武器选择",
	"手电筒",
	"全部",
	"血量和护甲",
	"死亡时全部隐藏",
	"当没有护甲时隐藏",
	"其他状态元素(火车、接送历史、死亡通知等)",
	"所有通信元素(SayText、语音图标等)",
	"准心线",
	"车辆准心线",
	"InVehicle",
	"奖励进度显示(用于奖励地图挑战)",
	"雷达",
	"迷你计分板",
};

bool gB_Late = false;

Handle gH_HUDCookie = null;

int gI_HUDSettings[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_csgohud", Command_Hud, "Toggle csgo hud");

	gH_HUDCookie = RegClientCookie("csgo_hud_setting", "CSGO HUD settings", CookieAccess_Protected);

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				if(AreClientCookiesCached(i) && !IsFakeClient(i))
				{
					OnClientCookiesCached(i);
				}
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sHUDSettings[8];
	GetClientCookie(client, gH_HUDCookie, sHUDSettings, 8);

	if(strlen(sHUDSettings) == 0)
	{
		IntToString(HIDEHUD_DEFAULT, sHUDSettings, sizeof(sHUDSettings));

		SetClientCookie(client, gH_HUDCookie, sHUDSettings);
		gI_HUDSettings[client] = HIDEHUD_DEFAULT;
	}

	else
	{
		gI_HUDSettings[client] = StringToInt(sHUDSettings);
	}
}

public Action Command_Hud(int client, int args)
{
	return ShowHUDMenu(client, 0);
}

Action ShowHUDMenu(int client, int item)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	Menu menu = new Menu(HUDMenu_Handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle("设置CSGO HUD");

	char sInfo[16];
	for(int i = 0; i < HIDEHUD_BITCOUNT; i++)
	{
		FormatEx(sInfo, 16, "%d", (1 << i));
		menu.AddItem(sInfo, gS_CSGOHudSettings[i]);
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, item, -1);

	return Plugin_Handled;
}

public int HUDMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sCookie[16];
		menu.GetItem(param2, sCookie, 16);

		int iSelection = StringToInt(sCookie);

		gI_HUDSettings[param1] ^= iSelection;
		IntToString(gI_HUDSettings[param1], sCookie, 16);
		SetClientCookie(param1, gH_HUDCookie, sCookie);

		SetEntProp(param1, Prop_Send, "m_iHideHUD", gI_HUDSettings[param1]);

		ShowHUDMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_DisplayItem)
	{
		char sInfo[16];
		char sDisplay[64];

		int style = ITEMDRAW_DEFAULT;

		menu.GetItem(param2, sInfo, sizeof(sInfo), style, sDisplay, sizeof(sDisplay), param1);

		Format(sDisplay, 64, "[%s] %s", ((gI_HUDSettings[param1] & StringToInt(sInfo)) > 0)? "＋":"－", sDisplay);

		return RedrawMenuItem(sDisplay);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

stock bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}