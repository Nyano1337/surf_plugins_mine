#include <sourcemod>

ConVar mp_startmoney;
ConVar mp_teamcashawards;
ConVar mp_playercashawards;

public void OnPluginStart()
{
    OnMapStart();
}

public void OnMapStart()
{
    mp_startmoney = FindConVar("mp_startmoney");
    mp_startmoney.IntValue = 0;

    mp_teamcashawards = FindConVar("mp_teamcashawards");
    mp_teamcashawards.IntValue = 0;

    mp_playercashawards = FindConVar("mp_playercashawards");
    mp_playercashawards.IntValue = 0;
}