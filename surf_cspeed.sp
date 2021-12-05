#define PLUGIN_NAME           "Center HUD Speed"
#define PLUGIN_AUTHOR         "Ciallo, original by wangwei"
#define PLUGIN_DESCRIPTION    "Center hud speed for surf"
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            "https://space.bilibili.com/2988883"

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <convar_class>
#include <shavit>

Database gH_SQL;
bool gB_Late = false;

bool gB_CenterSpeed[MAXPLAYERS+1];
bool gB_DynamicSpeed[MAXPLAYERS+1];
int gI_Horizontally[MAXPLAYERS+1];
int gI_Vertically[MAXPLAYERS+1];
int gI_StaticColor[MAXPLAYERS+1][4];
int gI_IncreaseColor[MAXPLAYERS+1][4];
int gI_DecreaseColor[MAXPLAYERS+1][4];
char gS_Choice[MAXPLAYERS+1][32];

bool gB_MenuStatic[MAXPLAYERS+1];
bool gB_MenuDynamic[MAXPLAYERS+1];

// HUD
Handle gH_CenterSpeedhud = null;
int gI_PreviousSpeed[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	return APLRes_Success;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_cspeed", Command_CenterSpeed, "Open centerspeed menu");
    RegConsoleCmd("sm_centerspeed", Command_CenterSpeed, "Open centerspeed menu");

    gH_CenterSpeedhud = CreateHudSynchronizer();

    SQL_DBConnect();

    if(gB_Late)
    {
        for(int i = 1; i <= MaxClients; i++)
        {
            OnClientPutInServer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    if(IsValidClient(client))
    {
        GetCenterSpeedSettings(client);
    }
}

void GetCenterSpeedSettings(int client)
{
    char sQuery[512];
    FormatEx(sQuery, 512, "SELECT"...
        "`bcenter`, `dynamic`, `horizontally`, `vertically`, "...
        "`StaticColor_r`, `StaticColor_g`, `StaticColor_b`, `StaticColor_a`, "...
        "`IncreaseColor_r`, `IncreaseColor_g`, `IncreaseColor_b`, `IncreaseColor_a`, "...
        "`DecreaseColor_r`, `DecreaseColor_g`, `DecreaseColor_b`, `DecreaseColor_a` "...
        "FROM `centerspeed` WHERE auth = %d", GetSteamAccountID(client));

    gH_SQL.Query(SQL_InitCenterSpeed_Callback, sQuery, GetClientSerial(client));
}

public void SQL_InitCenterSpeed_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
	{
        LogError("InitCenterSpeed error! Reason: %s", error);
        
        return;
	}
    
    int client = GetClientFromSerial(data);
    
    if(results.FetchRow())
    {
        gB_CenterSpeed[client] = view_as<bool>(results.FetchInt(0));
        gB_DynamicSpeed[client] = view_as<bool>(results.FetchInt(1));
        gI_Horizontally[client] = results.FetchInt(2);
        gI_Vertically[client] = results.FetchInt(3);

        gI_StaticColor[client][0] = results.FetchInt(4);
        gI_StaticColor[client][1] = results.FetchInt(5);
        gI_StaticColor[client][2] = results.FetchInt(6);
        gI_StaticColor[client][3] = results.FetchInt(7);
        
        gI_IncreaseColor[client][0] = results.FetchInt(8);
        gI_IncreaseColor[client][1] = results.FetchInt(9);
        gI_IncreaseColor[client][2] = results.FetchInt(10);
        gI_IncreaseColor[client][3] = results.FetchInt(11);

        gI_DecreaseColor[client][0] = results.FetchInt(12);
        gI_DecreaseColor[client][1] = results.FetchInt(13);
        gI_DecreaseColor[client][2] = results.FetchInt(14);
        gI_DecreaseColor[client][3] = results.FetchInt(15);
    }
    else
    {
        char sQuery[512];
        FormatEx(sQuery, 512, "INSERT INTO `centerspeed` (auth) VALUES (%d)", GetSteamAccountID(client));

        gH_SQL.Query(SQL_InitCenterSpeed_Callback2, sQuery, GetClientSerial(client));
    }
}

public void SQL_InitCenterSpeed_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
	{
        LogError("InitCenterSpeed Callback2 error! Reason: %s", error);
        
        return;
	}

    int client = GetClientFromSerial(data);

    GetCenterSpeedSettings(client);
}

public void OnClientDisconnect(int client)
{
    char sQuery[512];
    FormatEx(sQuery, 512, "UPDATE `centerspeed`"...
        "SET bcenter = %d, dynamic = %d, horizontally = %d, vertically = %d, "...
        "StaticColor_r = %d, StaticColor_g = %d, StaticColor_b = %d, StaticColor_a = %d, "...
        "IncreaseColor_r = %d, IncreaseColor_g = %d, IncreaseColor_b = %d, IncreaseColor_a = %d, "...
        "DecreaseColor_r = %d, DecreaseColor_g = %d, DecreaseColor_b = %d, DecreaseColor_a = %d "...
        "WHERE auth = %d",
        gB_CenterSpeed[client], gB_DynamicSpeed[client], gI_Horizontally[client], gI_Vertically[client],
        gI_StaticColor[client][0], gI_StaticColor[client][1], gI_StaticColor[client][2], gI_StaticColor[client][3],
        gI_IncreaseColor[client][0], gI_IncreaseColor[client][1], gI_IncreaseColor[client][2], gI_IncreaseColor[client][3],
        gI_DecreaseColor[client][0], gI_DecreaseColor[client][1], gI_DecreaseColor[client][2], gI_DecreaseColor[client][3],
        GetSteamAccountID(client));

    gH_SQL.Query(SQL_UpdateCenterSpeed_Callback, sQuery, GetSteamAccountID(client));
}

public void SQL_UpdateCenterSpeed_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
	{
        LogError("UpdateCenterSpeed error! Reason: %s", error);
        
        return;
	}
}

public Action Command_CenterSpeed(int client, int args)
{
    OpenCenterSpeedMenu(client);
    return Plugin_Handled;
}

void OpenCenterSpeedMenu(int client)
{
    strcopy(gS_Choice[client], 32, "NONE");
    gB_MenuStatic[client] = false;
    gB_MenuDynamic[client] = false;

    Menu menu = new Menu(CenterSpeedMenu_Handler);

    char sDisplay[64];

    Format(sDisplay, 64, "[%s]显示屏幕中间速度", (gB_CenterSpeed[client])?"ON":"OFF");
    menu.AddItem("centerbool", sDisplay);

    Format(sDisplay, 64, "[%s]动态显示速度", (gB_DynamicSpeed[client])?"ON":"OFF");
    menu.AddItem("dynamicbool", sDisplay);

    Format(sDisplay, 64, "[%d]调整速度水平显示", gI_Horizontally[client]);
    menu.AddItem("horizontal", sDisplay);

    Format(sDisplay, 64, "[%d]调整速度垂直显示", gI_Vertically[client]);
    menu.AddItem("vertical", sDisplay);

    Format(sDisplay, 64, "调整静态显示颜色");
    menu.AddItem("static", sDisplay, (gB_DynamicSpeed[client])?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);

    Format(sDisplay, 64, "调整动态显示颜色");
    menu.AddItem("dynamic", sDisplay, (gB_DynamicSpeed[client])?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);

    menu.Display(client, -1);
}

public int CenterSpeedMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        char sInfo[16];
        menu.GetItem(param2, sInfo, 16);

        if(StrEqual(sInfo, "centerbool"))
        {
            gB_CenterSpeed[param1] = !gB_CenterSpeed[param1];
        }

        else if(StrEqual(sInfo, "dynamicbool"))
        {
            gB_DynamicSpeed[param1] = !gB_DynamicSpeed[param1];
        }

        else if(StrEqual(sInfo, "horizontal"))
        {
            strcopy(gS_Choice[param1], 32, "horizontal");
            OpenAdjustMenu(param1);

            return 0;
        }

        else if(StrEqual(sInfo, "vertical"))
        {
            strcopy(gS_Choice[param1], 32, "vertical");
            OpenAdjustMenu(param1);

            return 0;
        }

        else if(StrEqual(sInfo, "static"))
        {
            OpenStaticColorMenu(param1);

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

void OpenStaticColorMenu(int client)
{
    gB_MenuStatic[client] = true;
    Menu menu = new Menu(StaticColorMenu_Handler);
    menu.SetTitle("调整静态颜色\n ");

    char sDisplay[64];

    Format(sDisplay, 64, "[%d]调整静态颜色: Red", gI_StaticColor[client][0]);
    menu.AddItem("R", sDisplay);

    Format(sDisplay, 64, "[%d]调整静态颜色: Green", gI_StaticColor[client][1]);
    menu.AddItem("G", sDisplay);

    Format(sDisplay, 64, "[%d]调整静态颜色: Blue", gI_StaticColor[client][2]);
    menu.AddItem("B", sDisplay);

    Format(sDisplay, 64, "[%d]调整静态颜色: Alpha", gI_StaticColor[client][3]);
    menu.AddItem("A", sDisplay);

    menu.ExitBackButton = true;
    menu.Display(client, -1);
}

public int StaticColorMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        char sInfo[8];
        menu.GetItem(param2, sInfo, 8);

        if(StrEqual(sInfo, "R"))
        {
            strcopy(gS_Choice[param1], 32, "Static_Red");
        }

        else if(StrEqual(sInfo, "G"))
        {
            strcopy(gS_Choice[param1], 32, "Static_Green");
        }

        else if(StrEqual(sInfo, "B"))
        {
            strcopy(gS_Choice[param1], 32, "Static_Blue");
        }

        else if(StrEqual(sInfo, "A"))
        {
            strcopy(gS_Choice[param1], 32, "Static_Alpha");
        }

        OpenAdjustMenu(param1);
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
    gB_MenuDynamic[client] = true;
    Menu menu = new Menu(DynamicColorMenu_Handler);
    menu.SetTitle("调整动态颜色\n ");

    char sDisplay[64];

    Format(sDisplay, 64, "[%d]调整动态加速颜色: Red", gI_IncreaseColor[client][0]);
    menu.AddItem("+R", sDisplay);

    Format(sDisplay, 64, "[%d]调整动态加速颜色: Green", gI_IncreaseColor[client][1]);
    menu.AddItem("+G", sDisplay);

    Format(sDisplay, 64, "[%d]调整动态加速颜色: Blue", gI_IncreaseColor[client][2]);
    menu.AddItem("+B", sDisplay);

    Format(sDisplay, 64, "[%d]调整动态加速颜色: Alpha\n ", gI_IncreaseColor[client][3]);
    menu.AddItem("+A", sDisplay);

    menu.AddItem("", sDisplay, ITEMDRAW_NOTEXT);
    menu.AddItem("", sDisplay, ITEMDRAW_NOTEXT);
    menu.AddItem("", sDisplay, ITEMDRAW_NOTEXT);

    Format(sDisplay, 64, "[%d]调整动态减速颜色: Red", gI_DecreaseColor[client][0]);
    menu.AddItem("-R", sDisplay);

    Format(sDisplay, 64, "[%d]调整动态减速颜色: Green", gI_DecreaseColor[client][1]);
    menu.AddItem("-G", sDisplay);

    Format(sDisplay, 64, "[%d]调整动态减速颜色: Blue", gI_DecreaseColor[client][2]);
    menu.AddItem("-B", sDisplay);

    Format(sDisplay, 64, "[%d]调整动态减速颜色: Alpha", gI_DecreaseColor[client][3]);
    menu.AddItem("-A", sDisplay);

    menu.ExitBackButton = true;
    menu.Display(client, -1);
}

public int DynamicColorMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        char sInfo[8];
        menu.GetItem(param2, sInfo, 8);

        if(StrEqual(sInfo, "+R"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_+Red");
        }

        else if(StrEqual(sInfo, "+G"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_+Green");
        }

        else if(StrEqual(sInfo, "+B"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_+Blue");
        }

        else if(StrEqual(sInfo, "+A"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_+Alpha");
        }

        else if(StrEqual(sInfo, "-R"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_-Red");
        }

        else if(StrEqual(sInfo, "-G"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_-Green");
        }

        else if(StrEqual(sInfo, "-B"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_-Blue");
        }

        else if(StrEqual(sInfo, "-A"))
        {
            strcopy(gS_Choice[param1], 32, "Dynamic_-Alpha");
        }

        OpenAdjustMenu(param1);
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

void OpenAdjustMenu(int client)
{
    Menu menu = new Menu(AdjustMenu_Handler);
    if(gB_MenuStatic[client])
    {
        menu.SetTitle("设置静态速度颜色\n ");
    }

    else if(gB_MenuDynamic[client])
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
    if(action == MenuAction_Select)
    {
        char sInfo[8];
        menu.GetItem(param2, sInfo, 8);

        int fAdjust;

        if(StrEqual(sInfo, "+1"))
        {
            fAdjust = 1;
        }

        else if(StrEqual(sInfo, "+10"))
        {
            fAdjust = 10;
        }

        else if(StrEqual(sInfo, "+50"))
        {
            fAdjust = 50;
        }

        else if(StrEqual(sInfo, "-1"))
        {
            fAdjust = -1;
        }

        else if(StrEqual(sInfo, "-10"))
        {
            fAdjust = -10;
        }

        else if(StrEqual(sInfo, "-50"))
        {
            fAdjust = -50;
        }


        if(StrEqual(gS_Choice[param1], "horizontal"))
        {
            gI_Horizontally[param1] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "vertical"))
        {
            gI_Vertically[param1] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Static_Red"))
        {
            gI_StaticColor[param1][0] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Static_Green"))
        {
            gI_StaticColor[param1][1] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Static_Blue"))
        {
            gI_StaticColor[param1][2] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Static_Alpha"))
        {
            gI_StaticColor[param1][3] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_+Red"))
        {
            gI_IncreaseColor[param1][0] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_+Green"))
        {
            gI_IncreaseColor[param1][1] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_+Blue"))
        {
            gI_IncreaseColor[param1][2] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_+Alpha"))
        {
            gI_IncreaseColor[param1][3] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_-Red"))
        {
            gI_DecreaseColor[param1][0] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_-Green"))
        {
            gI_DecreaseColor[param1][1] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_-Blue"))
        {
            gI_DecreaseColor[param1][2] += fAdjust;
        }

        else if(StrEqual(gS_Choice[param1], "Dynamic_-Alpha"))
        {
            gI_DecreaseColor[param1][3] += fAdjust;
        }


        if(gI_Horizontally[param1] < -100)
        {
            gI_Horizontally[param1] = -100;
        }
        
        else if(gI_Horizontally[param1] > 100)
        {
            gI_Horizontally[param1] = 100;
        }

        else if(gI_Vertically[param1] < -100)
        {
            gI_Vertically[param1] = -100;
        }

        else if(gI_Vertically[param1] > 100)
        {
            gI_Vertically[param1] = 100;
        }

        for(int i = 0; i < 4; i++)
        {
            if(gI_IncreaseColor[param1][i] < 0)
            {
                gI_IncreaseColor[param1][i] = 0;
            }

            else if(gI_IncreaseColor[param1][i] > 255)
            {
                gI_IncreaseColor[param1][i] = 255;
            }

            else if(gI_DecreaseColor[param1][i] < 0)
            {
                gI_DecreaseColor[param1][i] = 0;
            }

            else if(gI_DecreaseColor[param1][i] > 255)
            {
                gI_DecreaseColor[param1][i] = 255;
            }
        }

        OpenAdjustMenu(param1);
    }

    else if(action == MenuAction_Cancel)
    {
        if(gB_MenuStatic[param1])
        {
            OpenStaticColorMenu(param1);
        }

        else if(gB_MenuDynamic[param1])
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

public void OnGameFrame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || IsFakeClient(i) || !gB_CenterSpeed[i])
		{
			continue;
		}

		UpdateCenterSpeedHUD(i);
	}
}

void UpdateCenterSpeedHUD(int client)
{
    int target = GetHUDTarget(client);
    
    float fHorizontally = gI_Horizontally[client] * 0.01;
    float fVertically = gI_Vertically[client] * 0.01;
    
    float fSpeed[3];
    GetEntPropVector(target, Prop_Data, "m_vecVelocity", fSpeed);
    
    int iSpeed = RoundToNearest(SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
    
    bool bDynamic = gB_DynamicSpeed[client];
    
    if(!bDynamic)
	{
		SetHudTextParams(fHorizontally, fVertically, 1.0, 
            gI_StaticColor[client][0], gI_StaticColor[client][1], gI_StaticColor[client][2], gI_StaticColor[client][3],
            0, 0.25, 0.0, 0.0);
	}
	else 
	{
		if(gI_PreviousSpeed[client] <= iSpeed)
		{
			SetHudTextParams(fHorizontally, fVertically, 1.0, 
                gI_IncreaseColor[client][0], gI_IncreaseColor[client][1], gI_IncreaseColor[client][2], gI_IncreaseColor[client][3],
                0, 0.25, 0.0, 0.0);
		}
		else
		{
			SetHudTextParams(fHorizontally, fVertically, 1.0, 
                gI_DecreaseColor[client][0], gI_DecreaseColor[client][1], gI_DecreaseColor[client][2], gI_DecreaseColor[client][3],
                0, 0.25, 0.0, 0.0);
		}

		gI_PreviousSpeed[client] = iSpeed;
	}
    
    ShowSyncHudText(client, gH_CenterSpeedhud, "%d", iSpeed);
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

void SQL_DBConnect()
{
	gH_SQL = GetTimerDatabaseHandle();

	char sQuery[2048];
	FormatEx(sQuery, 2048,
		"CREATE TABLE IF NOT EXISTS `centerspeed` (`id` INT AUTO_INCREMENT, `auth` INT, "...
        "`bcenter` TINYINT(1) NOT NULL DEFAULT 1, `dynamic` TINYINT(1) NOT NULL DEFAULT 1, `horizontally` INT NOT NULL DEFAULT -100, `vertically` INT NOT NULL DEFAULT 36, "...
        "`StaticColor_r` INT NOT NULL DEFAULT 255, `StaticColor_g` INT NOT NULL DEFAULT 255, `StaticColor_b` INT NOT NULL DEFAULT 255, `StaticColor_a` INT NOT NULL DEFAULT 255, "...
        "`IncreaseColor_r` INT NOT NULL DEFAULT 0, `IncreaseColor_g` INT NOT NULL DEFAULT 180, `IncreaseColor_b` INT NOT NULL DEFAULT 255, `IncreaseColor_a` INT NOT NULL DEFAULT 255, "...
        "`DecreaseColor_r` INT NOT NULL DEFAULT 255, `DecreaseColor_g` INT NOT NULL DEFAULT 90, `DecreaseColor_b` INT NOT NULL DEFAULT 0, `DecreaseColor_a` INT NOT NULL DEFAULT 255, "...
        "PRIMARY KEY (`id`)) ENGINE=INNODB;");

	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null)
    {
        LogError("Centerspeed error! Centerspeed' table creation failed. Reason: %s", error);
        
        return;
    }
}