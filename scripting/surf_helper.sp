#include <sourcemod>

#pragma newdecls required
#pragma semicolon 1

public void OnPluginStart()
{
	RegConsoleCmd("sm_timer", Command_ShavitTimerHelper, "打开助手菜单");
	RegConsoleCmd("sm_surftimer", Command_ShavitTimerHelper, "打开助手菜单");
	RegConsoleCmd("sm_help", Command_Help, "打开本菜单");
}

public Action Command_Help(int client, int args)
{
	OpenCommandsMenu(client);

	return Plugin_Handled;
}

void OpenCommandsMenu(int client)
{
	Menu menu = new Menu(CommandsMenu_Handler);
	menu.SetTitle("指令菜单\n  ");

	CommandIterator it = new CommandIterator();
	while(it.Next())
	{
		char sCommand[32];
		it.GetName(sCommand, sizeof(sCommand));
		if(!CheckCommandAccess(client, sCommand, it.Flags) || 
			StrEqual(sCommand, "ff") || 
			StrEqual(sCommand, "motd") || 
			StrEqual(sCommand, "nextmap"))
		{
			continue;
		}

		char sDescription[128];
		it.GetDescription(sDescription, sizeof(sDescription));

		char sItem[160];
		FormatEx(sItem, sizeof(sItem), "%s - %s", sCommand, sDescription);
		menu.AddItem(sItem, sItem, ITEMDRAW_DISABLED);
	}

	delete it;

	menu.Display(client, -1);
}

public int CommandsMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_ShavitTimerHelper(int client, int args)
{
	OpenHelperMenu(client);

	return Plugin_Handled;
}

void OpenHelperMenu(int client)
{
	Menu menu = new Menu(HelperMenu_Handler);
	menu.SetTitle("计时器助手菜单\n  ");

	menu.AddItem("cpmenu", "练习模式");
	menu.AddItem("style", "切换模式");
	menu.AddItem("cspeed", "中心速度显示");
	menu.AddItem("hud", "HUD设置(打开后按1关闭整个hud!!!)");
	menu.AddItem("mhud", "打开mhud菜单(已汉化)");
	menu.AddItem("nv", "开启夜视仪");
	menu.AddItem("nvs", "夜视仪设置");
	menu.AddItem("top", "排行");
	menu.AddItem("yd", "预定地图");
	menu.AddItem("rtv", "投票换图");
	menu.AddItem("ext", "延长地图!!!");
	menu.AddItem("help", "打开指令菜单");

	menu.Display(client, -1);
}

public int HelperMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		char sCommand[16];
		FormatEx(sCommand, sizeof(sCommand), "sm_%s", sInfo);
		FakeClientCommand(param1, sCommand);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}