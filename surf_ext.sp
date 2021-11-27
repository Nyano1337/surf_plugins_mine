#include <sourcemod>

int gI_WinVotes;
int gI_LoseVotes;

Handle gH_ExtFailTimer = null;

native int Shavit_PrintToChat(int client, const char[] format, any ...);
native void Shavit_PrintToChatAll(const char[] format, any ...);

public void OnPluginStart()
{
	RegConsoleCmd("sm_ext", Command_Ext);
}

public Action Command_Ext(int client, int args)
{
	if(IsVoteInProgress())
	{
		Shavit_PrintToChat(client, "已经在投票中");

		return Plugin_Handled;
	}

	gI_WinVotes = 0;
	gI_LoseVotes = 0;

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);

	Shavit_PrintToChatAll("玩家 {gold}%s{default} 启动了延长投票.", sName);

	Menu menu = new Menu(ExtMenu_Hander);
	menu.VoteResultCallback = Handler_ExtFinished;

	menu.SetTitle("是否延长该地图 20 分钟?\n ");

	menu.AddItem("", "是");
	menu.AddItem("", "否");

	menu.ExitButton = false;
	menu.DisplayVoteToAll(15);
	gH_ExtFailTimer = CreateTimer(15.0, Timer_ExtFail);

	return Plugin_Handled;
}

public int ExtMenu_Hander(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				gI_WinVotes++;
			}
			
			case 1:
			{
				gI_LoseVotes++;
			}
		}
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public void Handler_ExtFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if(gH_ExtFailTimer != null)
	{
		delete gH_ExtFailTimer;
	}

	ShouldExtend();
}

public Action Timer_ExtFail(Handle timer, any data)
{
	if(ShouldExtend())
	{
		return Plugin_Stop;
	}

	Shavit_PrintToChatAll("投票已超时, 当前无投票, 默认不延长.");

	return Plugin_Stop;
}

bool ShouldExtend()
{
	if(gI_WinVotes < gI_LoseVotes)
	{
		Shavit_PrintToChatAll("延长失败, 还需要%d票, 有%d个内鬼", gI_LoseVotes - gI_WinVotes, gI_LoseVotes);

		return false;
	}
	else if(gI_WinVotes == 0) // wtf for u?
	{
		return false;
	}

	Shavit_PrintToChatAll("延长了地图20分钟");

	ExtendMapTimeLimit(20 * 60); // 单位是秒

	return true;
}