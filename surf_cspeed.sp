#include <sourcemod>
#include <clientprefs>
#include <shavit>
#include <surf>

#pragma newdecls required
#pragma semicolon 1

// velocity has to change this much before it is colored as increase/decrease
#define COLORIZE_DEADZONE 2.0

enum
{
	Pref_CSpeed_Display,
	Pref_CSpeed_Dynamic,
	Pref_CSpeed_Position,
	Pref_CSpeed_Normal_Color,
	Pref_CSpeed_Increase_Color,
	Pref_CSpeed_Decrease_Color,
	PREF_COUNT
};

static char Preference_Names[PREF_COUNT][MAX_PREFERENCE_NAME_LENGTH] =
{
	"cspeed_display",
	"cspeed_dynamic",
	"cspeed_position",
	"cspeed_normal_color",
	"cspeed_increase_color",
	"cspeed_decrease_color",
};

// https://github.com/momentum-mod/game/blob/4cb4ce37ed1c16de61d3d93d4b735ab93ee3867c/mp/game/momentum/resource/ClientScheme.res#L15
static char Preference_Defaults[PREF_COUNT][MAX_PREFERENCE_VALUE_LENGTH] =
{
	"1",
	"1",
	"-1.00 0.36",
	"200 200 200 255",
	"24 150 211 255",
	"255 106 106 255",
};

static char Preference_Displays[PREF_COUNT][MAX_PREFERENCE_DISPLAY_LENGTH] =
{
	"CSpeed Display",
	"CSpeed Dynamic",
	"CSpeed Position",
	"CSpeed Normal Color",
	"CSpeed Increase Color",
	"CSpeed Decrease Color",
};

static int Preference_Types[PREF_COUNT] =
{
	PrefType_Numeric,
	PrefType_Numeric,
	PrefType_XY,
	PrefType_RGBA,
	PrefType_RGBA,
	PrefType_RGBA,
};

static int Preference_Limits[PREF_COUNT] =
{
	1,
	1,
	-1,
	-1,
	-1,
	-1,
};

enum struct cspeed_t
{
	bool bMaster;
	bool bDynamic;
	float fPosition[2];
	int iNormal[4];
	int iIncrease[4];
	int iDecrease[4];
}

cspeed_t gA_CenterSpeed[MAXPLAYERS+1];

float gF_PrevSpeed[MAXPLAYERS+1];
char gS_Choice[MAXPLAYERS+1][32];

// HUD
Preferences gH_Cookie = null;
Handle gH_CenterSpeedhud = null;

bool gB_Late = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	RegPluginLibrary("surf_cspeed");

	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "Center HUD Speed",
	author = "Ciallo-Ani",
	description = "Center hud speed for surf, based on MovementHUD",
	version = "2.0",
	url = "https://space.bilibili.com/2988883"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_cspeed", Command_CenterSpeed, "Open centerspeed menu");
	RegConsoleCmd("sm_centerspeed", Command_CenterSpeed, "Open centerspeed menu");

	gH_CenterSpeedhud = CreateHudSynchronizer();

	gH_Cookie = InitPrefs();

	if(gB_Late)
	{
		gB_Late = false;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(!IsValidClient(i))
			{
				continue;
			}

			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
		}
	}
}

public void OnClientCookiesCached(int client)
{
	if(!IsFakeClient(client))
	{
		InitPrefsForClient(client, gH_Cookie);
	}
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
	{
		SavePrefsForClient(client);
	}
}

public Action Command_CenterSpeed(int client, int args)
{
	OpenCenterSpeedMenu(client);
	return Plugin_Handled;
}

void OpenCenterSpeedMenu(int client)
{
	strcopy(gS_Choice[client], sizeof(gS_Choice[]), "NONE");

	Menu menu = new Menu(CenterSpeedMenu_Handler);

	char sDisplay[64];

	Format(sDisplay, sizeof(sDisplay), "[%s]显示屏幕中间速度", (gA_CenterSpeed[client].bMaster)?"ON":"OFF");
	menu.AddItem("centerbool", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%s]动态显示速度", (gA_CenterSpeed[client].bDynamic)?"ON":"OFF");
	menu.AddItem("dynamicbool", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%.2f]调整速度水平显示", gA_CenterSpeed[client].fPosition[0]);
	menu.AddItem("x", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%.2f]调整速度垂直显示", gA_CenterSpeed[client].fPosition[1]);
	menu.AddItem("y", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "调整普通显示颜色");
	menu.AddItem("normal", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "调整动态显示颜色");
	menu.AddItem("dynamic", sDisplay, (gA_CenterSpeed[client].bDynamic)?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

	menu.Display(client, -1);
}

public int CenterSpeedMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "centerbool"))
		{
			gA_CenterSpeed[param1].bMaster = !gA_CenterSpeed[param1].bMaster;
		}
		else if(StrEqual(sInfo, "dynamicbool"))
		{
			gA_CenterSpeed[param1].bDynamic = !gA_CenterSpeed[param1].bDynamic;
		}
		else if(StrEqual(sInfo, "x"))
		{
			strcopy(gS_Choice[param1], sizeof(gS_Choice[]), "x");
			OpenAdjustMenu(param1);

			return 0;
		}
		else if(StrEqual(sInfo, "y"))
		{
			strcopy(gS_Choice[param1], sizeof(gS_Choice[]), "y");
			OpenAdjustMenu(param1);

			return 0;
		}
		else if(StrEqual(sInfo, "normal"))
		{
			OpenNormalColorMenu(param1);

			return 0;
		}
		else if(StrEqual(sInfo, "dynamic"))
		{
			OpenDynamicColorMenu(param1);

			return 0;
		}

		OpenCenterSpeedMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenNormalColorMenu(int client)
{
	Menu menu = new Menu(NormalColorMenu_Handler);
	menu.SetTitle("调整普通颜色\n ");

	char sDisplay[64];

	Format(sDisplay, sizeof(sDisplay), "[%d]调整普通颜色: Red", gA_CenterSpeed[client].iNormal[0]);
	menu.AddItem("Red", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整普通颜色: Green", gA_CenterSpeed[client].iNormal[1]);
	menu.AddItem("Green", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整普通颜色: Blue", gA_CenterSpeed[client].iNormal[2]);
	menu.AddItem("Blue", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整普通颜色: Alpha", gA_CenterSpeed[client].iNormal[3]);
	menu.AddItem("Alpha", sDisplay);

	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int NormalColorMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		FormatEx(gS_Choice[param1], sizeof(gS_Choice[]), "Normal_%s", sInfo);

		OpenAdjustMenu(param1, true);
	}

	else if(action == MenuAction_Cancel)
	{
		OpenCenterSpeedMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenDynamicColorMenu(int client)
{
	Menu menu = new Menu(DynamicColorMenu_Handler);
	menu.SetTitle("调整动态颜色\n ");

	char sDisplay[64];

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态加速颜色: Red", gA_CenterSpeed[client].iIncrease[0]);
	menu.AddItem("+Red", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态加速颜色: Green", gA_CenterSpeed[client].iIncrease[1]);
	menu.AddItem("+Green", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态加速颜色: Blue", gA_CenterSpeed[client].iIncrease[2]);
	menu.AddItem("+Blue", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态加速颜色: Alpha\n ", gA_CenterSpeed[client].iIncrease[3]);
	menu.AddItem("+Alpha", sDisplay);

	menu.AddItem("", sDisplay, ITEMDRAW_NOTEXT);
	menu.AddItem("", sDisplay, ITEMDRAW_NOTEXT);
	menu.AddItem("", sDisplay, ITEMDRAW_NOTEXT);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态减速颜色: Red", gA_CenterSpeed[client].iDecrease[0]);
	menu.AddItem("-Red", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态减速颜色: Green", gA_CenterSpeed[client].iDecrease[1]);
	menu.AddItem("-Green", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态减速颜色: Blue", gA_CenterSpeed[client].iDecrease[2]);
	menu.AddItem("-Blue", sDisplay);

	Format(sDisplay, sizeof(sDisplay), "[%d]调整动态减速颜色: Alpha", gA_CenterSpeed[client].iDecrease[3]);
	menu.AddItem("-Alpha", sDisplay);

	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int DynamicColorMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, sizeof(sInfo));
		FormatEx(gS_Choice[param1], sizeof(gS_Choice[]), "Dynamic_%s", sInfo);

		OpenAdjustMenu(param1, false);
	}

	else if(action == MenuAction_Cancel)
	{
		OpenCenterSpeedMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenAdjustMenu(int client, bool normal = false, bool dynamic = false)
{
	Menu menu = new Menu(AdjustMenu_Handler);
	if(normal)
	{
		menu.SetTitle("设置普通速度颜色\n ");
	}

	else if(dynamic)
	{
		menu.SetTitle("设置动态速度颜色\n ");
	}

	else
	{
		menu.SetTitle("设置速度显示位置\n ");
	}

	menu.AddItem("+1", "+1");
	menu.AddItem("+10", "+10");
	menu.AddItem("+50", "+50\n ");

	menu.AddItem("-1", "-1");
	menu.AddItem("-10", "-10");
	menu.AddItem("-50", "-50");

	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int AdjustMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	bool normal = false;
	bool dynamic = false;

	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		int iAdjust = StringToInt(sInfo);

		if(StrEqual(gS_Choice[param1], "x"))
		{
			gA_CenterSpeed[param1].fPosition[0] = ClampXY(gA_CenterSpeed[param1].fPosition[0] + iAdjust * 0.01);
		}
		else if(StrEqual(gS_Choice[param1], "y"))
		{
			gA_CenterSpeed[param1].fPosition[1] = ClampXY(gA_CenterSpeed[param1].fPosition[1] + iAdjust * 0.01);
		}
		else if(StrContains(gS_Choice[param1], "normal", false) != -1)
		{
			normal = true;
			int color = GetRGBAFromStr(gS_Choice[param1]);
			gA_CenterSpeed[param1].iNormal[color] = ClampRGBA(gA_CenterSpeed[param1].iNormal[color] + iAdjust);
		}
		else if(StrContains(gS_Choice[param1], "dynamic", false) != -1)
		{
			dynamic = true;
			int color = GetRGBAFromStr(gS_Choice[param1]);
			if(FindCharInString(gS_Choice[param1], '+', true) != -1)
			{
				gA_CenterSpeed[param1].iIncrease[color] = ClampRGBA(gA_CenterSpeed[param1].iIncrease[color] + iAdjust);
			}
			else
			{
				gA_CenterSpeed[param1].iDecrease[color] = ClampRGBA(gA_CenterSpeed[param1].iDecrease[color] + iAdjust);
			}
		}

		OpenAdjustMenu(param1, normal, dynamic);
	}

	else if(action == MenuAction_Cancel)
	{
		if(normal)
		{
			OpenNormalColorMenu(param1);
		}
		else if(dynamic)
		{
			OpenDynamicColorMenu(param1);
		}
		else
		{
			OpenCenterSpeedMenu(param1);
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(!IsValidClient(client) || IsFakeClient(client) || !gA_CenterSpeed[client].bMaster)
	{
		return;
	}

	UpdateCenterSpeedHUD(client);
}

static void UpdateCenterSpeedHUD(int client)
{
	int target = GetHUDTarget(client);

	float fSpeed[3];
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", fSpeed);

	float fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
	float fPrevSpeed = gF_PrevSpeed[client];
	int iColors[4];

	if(!gA_CenterSpeed[client].bDynamic)
	{
		SetColors(iColors, gA_CenterSpeed[client].iNormal);
	}
	else
	{
		SetPrimaryFgColor(iColors, fCurrentSpeed - fPrevSpeed, COLORIZE_DEADZONE, 
			gA_CenterSpeed[client].iNormal, gA_CenterSpeed[client].iIncrease, gA_CenterSpeed[client].iDecrease);

		gF_PrevSpeed[client] = fCurrentSpeed;
	}

	SetHudTextParamsEx(gA_CenterSpeed[client].fPosition[0], gA_CenterSpeed[client].fPosition[1], 1.0, iColors, _, 0, 1.0, 0.0, 0.0);

	ShowSyncHudText(client, gH_CenterSpeedhud, "%d", RoundToNearest(fCurrentSpeed));
}

void SetColors(int[] output, int[] origin)
{
	output[0] = origin[0];
	output[1] = origin[1];
	output[2] = origin[2];
	output[3] = origin[3];
}

// https://github.com/momentum-mod/game/blob/09f0c8a65181daa454e559ef0cef9324e9b30420/mp/src/game/shared/momentum/util/mom_util.cpp#L325
void SetPrimaryFgColor(int[] origin, const float diff, float deadZone, int[] normalcolor, int[] increasecolor, int[] decreasecolor)
{
	// variation is current velocity minus previous velocity.
	SetColors(origin, normalcolor);
	deadZone = FloatAbs(deadZone);

	if(diff < -deadZone) // our velocity decreased
	{
		SetColors(origin, decreasecolor);
	}
	else if(diff > deadZone) // our velocity increased
	{
		SetColors(origin, increasecolor);
	}
}

int GetHUDTarget(int client)
{
	int target = client;

	if(IsClientObserver(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if(iObserverMode >= 3 && iObserverMode <= 5)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if(IsValidClient(iTarget, true))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

Preference Pref(int pref)
{
	return gH_Cookie.GetPreference(pref);
}

Preferences InitPrefs()
{
	Preferences prefs = new Preferences();
	for (int i = 0; i < PREF_COUNT; i++)
	{
		prefs.CreatePreference(Preference_Names[i],
								Preference_Displays[i],
								Preference_Defaults[i],
								Preference_Types[i],
								Preference_Limits[i]);
	}

	return prefs;
}

void InitPrefsForClient(int client, Preferences prefs)
{
	for (int i = 0; i < prefs.Length; i++)
	{
		Pref(i).Init(client);
	}

	gA_CenterSpeed[client].bMaster = view_as<bool>(Pref(Pref_CSpeed_Display).GetIntVal(client));
	gA_CenterSpeed[client].bDynamic = view_as<bool>(Pref(Pref_CSpeed_Dynamic).GetIntVal(client));

	char posBuf[16];
	Pref(Pref_CSpeed_Position).GetStringVal(client, posBuf, sizeof(posBuf));
	BufferToXY(posBuf, gA_CenterSpeed[client].fPosition, sizeof(cspeed_t::fPosition));

	char colorBuf[32];
	Pref(Pref_CSpeed_Normal_Color).GetStringVal(client, colorBuf, sizeof(colorBuf));
	BufferToRGBA(colorBuf, gA_CenterSpeed[client].iNormal, sizeof(cspeed_t::iNormal));

	Pref(Pref_CSpeed_Increase_Color).GetStringVal(client, colorBuf, sizeof(colorBuf));
	BufferToRGBA(colorBuf, gA_CenterSpeed[client].iIncrease, sizeof(cspeed_t::iIncrease));

	Pref(Pref_CSpeed_Decrease_Color).GetStringVal(client, colorBuf, sizeof(colorBuf));
	BufferToRGBA(colorBuf, gA_CenterSpeed[client].iDecrease, sizeof(cspeed_t::iDecrease));
}

void SavePrefsForClient(int client)
{
	Pref(Pref_CSpeed_Display).SetIntVal(client, gA_CenterSpeed[client].bMaster ? 1 : 0);
	Pref(Pref_CSpeed_Dynamic).SetIntVal(client, gA_CenterSpeed[client].bDynamic ? 1 : 0);

	char posBuf[16];
	FormatXY(gA_CenterSpeed[client].fPosition, posBuf, sizeof(posBuf));
	Pref(Pref_CSpeed_Position).SetStringVal(client, posBuf);

	char colorBuf[32];
	FormatRGBA(gA_CenterSpeed[client].iNormal, colorBuf, sizeof(colorBuf));
	Pref(Pref_CSpeed_Normal_Color).SetStringVal(client, colorBuf);

	FormatRGBA(gA_CenterSpeed[client].iIncrease, colorBuf, sizeof(colorBuf));
	Pref(Pref_CSpeed_Increase_Color).SetStringVal(client, colorBuf);

	FormatRGBA(gA_CenterSpeed[client].iDecrease, colorBuf, sizeof(colorBuf));
	Pref(Pref_CSpeed_Decrease_Color).SetStringVal(client, colorBuf);
}