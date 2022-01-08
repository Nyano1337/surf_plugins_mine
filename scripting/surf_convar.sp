#include <sourcemod>

char gS_ForcedCvars[][][] = 
{
    { "mp_startmoney", "0" },
    { "mp_teamcashawards", "0" },
    { "mp_playercashawards", "0" },
    { "sv_alltalk", "1" },
    { "sv_allchat", "1" },
    { "sv_talk_enemy_living", "1" },
    { "sv_talk_enemy_dead", "1" },
    { "sv_full_alltalk", "1" },
    { "sv_deadtalk", "1" }
};

public void OnPluginStart()
{
    OnMapStart();
}

public void OnMapStart()
{
    for(int i = 0; i < sizeof(gS_ForcedCvars); i++)
	{
		ConVar hCvar = FindConVar(gS_ForcedCvars[i][0]);

		if(hCvar != null)
		{
			hCvar.SetString(gS_ForcedCvars[i][1]);
		}
	}
}