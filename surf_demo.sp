#include <sourcemod>
#include <system2>
#include <sourcetvmanager>
#include <convar_class>

#define PER_MEGABTYES (1 << 20)

native int Shavit_PrintToChat(int client, const char[] format, any ...);
native void Shavit_PrintToChatAll(const char[] format, any ...);

//ServerCommand("tv_record \"%s/auto-%s-%s\"", sPath, sTime, sMap);
//ServerCommand("tv_stoprecord");

enum struct demo_t
{
	int iCreateTime;
	char sName[PLATFORM_MAX_PATH];
}

char gS_DemoName[PLATFORM_MAX_PATH];
char gS_Map[160];

int gI_DemoStartRecordTime;

Menu gH_DemoMenuList = null;
StringMap gSM_DemoStatus = null;

Convar gCV_FTP_PORT = null;
Convar gCV_FTP_USER = null;
Convar gCV_FTP_PWD = null;
Convar gCV_FTP_PREFIX = null;
Convar gCV_HTTP_PREFIX = null;
Convar gCV_DOWNLOAD_LIB = null;
Convar gCV_TIME_OFFSET = null;

public void OnPluginStart()
{
	RegConsoleCmd("sm_demos", Command_ShowDemos, "Show demo list to players.");
	RegConsoleCmd("sm_debugdemo", Command_Debug);

	gCV_FTP_PORT = new Convar("demo_ftp_port", "21", "ftp port");
	gCV_FTP_USER = new Convar("demo_ftp_user", "ftp", "ftp user");
	gCV_FTP_PWD = new Convar("demo_ftp_password", "123456", "ftp password");
	gCV_FTP_PREFIX = new Convar("demo_ftp_prefix", "ftp://43.240.157.98:21/", "ftp link prefix");
	gCV_HTTP_PREFIX = new Convar("demo_http_prefix", "http://43.240.157.98:40000/file/1/", "http link prefix");
	gCV_DOWNLOAD_LIB = new Convar("demo_download_lib", "http://43.240.157.98:40000/1/main", "demo download library link");
	gCV_TIME_OFFSET = new Convar("demo_time_offset", "28800", "local time offset (based on CET, Example: CET 8:00 in china is 16:00, demo_time_offset should be 28800)");

	Convar.AutoExecConfig();
}

public Action Command_Debug(int client, int args)
{
	gSM_DemoStatus = new StringMap();

	char sDemo[PLATFORM_MAX_PATH];
	if(SourceTV_GetDemoFileName(sDemo, PLATFORM_MAX_PATH))
	{
		Shavit_PrintToChat(client, "Debuging demo, current name-> [%s]", sDemo);
		LoadDemos(sDemo);
	}
	else
	{
		Shavit_PrintToChat(client, "Debuging demo, *but* get current name error!!!");
	}
}

public Action Command_ShowDemos(int client, int args)
{
	gH_DemoMenuList.Display(client, -1);

	return Plugin_Handled;
}

public int DemoMenuList_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sDemo[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sDemo, sizeof(sDemo));

		int ch = FindCharInString(sDemo, 'm', true);
		if(ch != -1)
		{
			sDemo[ch + 1] = '\0';
		}

		OpenSubDemoMenu(param1, sDemo);
	}

	return 0;
}

void OpenSubDemoMenu(int client, const char[] sDemo)
{
	int status = -1;
	gSM_DemoStatus.GetValue(sDemo, status);
	bool bUploaded = (status == 1);

	Menu menu = new Menu(SubDemoMenu_Handler);

	char sDate[64];
	FormatTime(sDate, 64, "%A %B %C %G %T", GetFileTime(sDemo, FileTime_Created) + gCV_TIME_OFFSET.IntValue);

	menu.SetTitle("Demo 名字: %s  \n"...
					"Demo 创建日期: %s  \n"...
					"类型: Normal  \n"...
					"状态: %s  \n", 
					sDemo, sDate, bUploaded?"已上传":"未上传");

	char sInfo[PLATFORM_MAX_PATH];
	FormatEx(sInfo, PLATFORM_MAX_PATH, "%s"..."%s", sDemo, bUploaded ? "" : "<should>");

	menu.AddItem(sInfo, bUploaded ? "获取链接" : "上传录像");
	menu.AddItem("lib", "浏览demo库");
	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int SubDemoMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sInfo, PLATFORM_MAX_PATH);

		if(StrContains(sInfo, "<should>") != -1)
		{
			ReplaceString(sInfo, PLATFORM_MAX_PATH, "<should>", "");
			TrimString(sInfo);
			UploadDemo(sInfo);
		}

		else if(StrEqual(sInfo, "lib"))
		{
			char sDownloadLibLink[PLATFORM_MAX_PATH];
			gCV_DOWNLOAD_LIB.GetString(sDownloadLibLink, sizeof(sDownloadLibLink));
			Shavit_PrintToChat(param1, "Demo下载库链接: [{lightgreen}%s{default}]", sDownloadLibLink);
		}

		else
		{
			char sHttpPrefix[PLATFORM_MAX_PATH];
			gCV_HTTP_PREFIX.GetString(sHttpPrefix, sizeof(sHttpPrefix));
			Shavit_PrintToChat(param1, "下载链接: [{lightgreen}%s%s{default}]", sHttpPrefix, sInfo);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		Command_ShowDemos(param1, 0);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SourceTV_OnStartRecording(int instance, const char[] filename)
{
	if(gSM_DemoStatus != null)
	{
		delete gSM_DemoStatus;
	}

	gSM_DemoStatus = new StringMap();

	if(!RenameOldDemo(gS_DemoName))
	{
		LogError("Rename old demo failed.\nName: [%s]", gS_DemoName);
	}

	GetCurrentMap(gS_Map, 160);

	LoadDemos(filename);

	gI_DemoStartRecordTime = GetTime() + gCV_TIME_OFFSET.IntValue;
}

public void SourceTV_OnStopRecording(int instance, const char[] filename, int recordingtick)
{
	strcopy(gS_DemoName, sizeof(gS_DemoName), filename);
}

static bool RenameOldDemo(const char[] oldname)
{
	char sTime[50];
	FormatTime(sTime, sizeof(sTime), "%F-%H-%M-%S", gI_DemoStartRecordTime);

	char sNewDemoName[PLATFORM_MAX_PATH];
	FormatEx(sNewDemoName, PLATFORM_MAX_PATH, "%s-%s.dem", sTime, gS_Map);

	return RenameFile(sNewDemoName, oldname);
}

static void LoadDemos(const char[] nowDemoName)
{
	if(gH_DemoMenuList != null)
	{
		delete gH_DemoMenuList;
	}

	gH_DemoMenuList = new Menu(DemoMenuList_Handler);
	gH_DemoMenuList.SetTitle("Demo 列表 | Demo 名字 [距今]");

	DirectoryListing dir = OpenDirectory("./");
	if(dir == null)
	{
		LogError("Failed to open current dir");
		return;
	}

	FileType type = FileType_Unknown;

	ArrayList aDemos = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	demo_t info;

	char sDemo[PLATFORM_MAX_PATH];
	while(dir.GetNext(sDemo, sizeof(sDemo), type))
	{
		if(type != FileType_File || StrContains(sDemo, ".dem", false) == -1)
		{
			continue;
		}

		GetDemoStatus(sDemo);

		info.iCreateTime = GetFileTime(sDemo, FileTime_Created);
		if(info.iCreateTime - GetTime() >= 604800) // after 7 days
		{
			DeleteFile(sDemo);
			continue;
		}

		int ch = FindCharInString(sDemo, 'T', false);
		if(ch != -1)
		{
			sDemo[ch] = '\0';
		}

		strcopy(info.sName, sizeof(demo_t::sName), sDemo);

		aDemos.PushArray(info, sizeof(demo_t));
	}

	aDemos.SortCustom(ADT_SortCreateTimeAscending);

	for(int i = 0; i < aDemos.Length; i++)
	{
		aDemos.GetArray(i, info, sizeof(demo_t));

		char sItem[PLATFORM_MAX_PATH];
		if(StrContains(nowDemoName, info.sName) != -1)
		{
			FormatEx(sItem, PLATFORM_MAX_PATH, "%s [当前录像]", info.sName);
			gH_DemoMenuList.AddItem(sItem, sItem, ITEMDRAW_DISABLED);
		}
		else
		{
			FormatEx(sItem, PLATFORM_MAX_PATH, "%s [%d 小时]", info.sName, (GetTime() - info.iCreateTime) / 3600);
			gH_DemoMenuList.AddItem(sItem, sItem);
		}
	}

	delete aDemos;
	delete dir;
}

public int ADT_SortCreateTimeAscending(int index1, int index2, Handle array, Handle hndl)
{
	demo_t info1, info2;
	ArrayList aDemos = view_as<ArrayList>(array);
	aDemos.GetArray(index1, info1, sizeof(demo_t));
	aDemos.GetArray(index2, info2, sizeof(demo_t));

	return info1.iCreateTime < info2.iCreateTime;
}

static void GetDemoStatus(const char[] sDemo)
{
	char sURL[PLATFORM_MAX_PATH];
	char sHttpPrefix[PLATFORM_MAX_PATH];
	gCV_HTTP_PREFIX.GetString(sHttpPrefix, sizeof(sHttpPrefix));
	FormatEx(sURL, sizeof(sURL), "%s"..."%s", sHttpPrefix, sDemo);

	System2HTTPRequest demoStatus = new System2HTTPRequest(GetDemoStatusCallback, sURL);
	demoStatus.Timeout = 30;
	demoStatus.GET();
	delete demoStatus;
}

public void GetDemoStatusCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	char sDemo[512];
	request.GetURL(sDemo, sizeof(sDemo));

	bool bUploaded = (success && response.DownloadSize > 0);

	if(bUploaded)
	{
		PrintToServer("a uploaded demo-> %s", sDemo);
	}

	char sHttpPrefix[PLATFORM_MAX_PATH];
	gCV_HTTP_PREFIX.GetString(sHttpPrefix, sizeof(sHttpPrefix));
	GetDemoNameFromURL(sHttpPrefix, sDemo, 512);

	gSM_DemoStatus.SetValue(sDemo, bUploaded?1:0);
}

static void UploadDemo(const char[] sDemo)
{
	char sFtpUser[PLATFORM_MAX_PATH], sFtpPWD[PLATFORM_MAX_PATH], sFtpPrefix[PLATFORM_MAX_PATH];
	gCV_FTP_USER.GetString(sFtpUser, sizeof(sFtpUser));
	gCV_FTP_PWD.GetString(sFtpPWD, sizeof(sFtpPWD));
	gCV_FTP_PREFIX.GetString(sFtpPrefix, sizeof(sFtpPrefix));

	char sURL[PLATFORM_MAX_PATH];
	FormatEx(sURL, sizeof(sURL), "%s"..."%s", sFtpPrefix, sDemo);

	System2FTPRequest upload = new System2FTPRequest(UploadDemoCallback, sURL);
	upload.SetAuthentication(sFtpUser, sFtpPWD);
	upload.SetPort(gCV_FTP_PORT.IntValue);
	upload.SetInputFile(sDemo);
	upload.AppendToFile = false;
	upload.StartRequest();
	delete upload;
}

public void UploadDemoCallback(bool success, const char[] error, System2FTPRequest request, System2FTPResponse response)
{
	if(success)
	{
		Shavit_PrintToChatAll("上传成功! 花费时间: %.1f秒 | 上传大小: %dM | 上传速度: %d M/s \n", 
								response.TotalTime, 
								response.UploadSize / PER_MEGABTYES, 
								response.UploadSpeed / PER_MEGABTYES);

		char sFtpPrefix[PLATFORM_MAX_PATH], sHttpPrefix[PLATFORM_MAX_PATH];
		gCV_FTP_PREFIX.GetString(sFtpPrefix, sizeof(sFtpPrefix));
		gCV_HTTP_PREFIX.GetString(sHttpPrefix, sizeof(sHttpPrefix));

		char sDemo[512];
		request.GetURL(sDemo, sizeof(sDemo));
		GetDemoNameFromURL(sFtpPrefix, sDemo, 512);
		gSM_DemoStatus.SetValue(sDemo, 1);

		Shavit_PrintToChatAll("下载链接: [{lightgreen}%s%s{default}]", sHttpPrefix, sDemo);
	}
	else
	{
		Shavit_PrintToChatAll("上传失败, 原因: [{darkred}%s{default}]", error);
	}
}

stock void GetDemoNameFromURL(const char[] remove, char[] origin, int len)
{
	ReplaceString(origin, len, remove, "");
	TrimString(origin);
}