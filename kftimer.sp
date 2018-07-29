#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
public Plugin myinfo = {
	name = "KFTimer",
	author = "l2zq",
	description = "",
	version = "1.0",
	url = ""
}

bool g_iscss  = false;
bool g_iscsgo = false;
int  g_tickrate;
new  Float:g_tickintv;

public void OnPluginStart(){
	EngineVersion engine = GetEngineVersion();
	if(engine==Engine_CSGO) g_iscsgo = true;
	else if(engine==Engine_CSS) g_iscss = true;
	else SetFailState("This timer only works on cstrike and csgo");
	g_tickintv = GetTickInterval();
	g_tickrate = RoundToFloor(1.0/g_tickintv);
	if(g_iscsgo) HookEvent("round_start", KF_RoundStart, EventHookMode_Pre);
	Cvar_OnPluginStart();
	Nodmg_OnPluginStart();
	EzHop_OnPluginStart();
	Setting_OnPluginStart();
	Mode_OnPluginStart();
	PrintToServer("[KF] tickrate: %d interval: %f iscss: %d iscsgo: %d", g_tickrate, g_tickintv, g_iscss, g_iscsgo);
}
public void OnMapStart(){
	Cvar_OnMapStart();
	//Nodmg_OnMapStart();
	//EzHop_OnMapStart();
	//Setting_OnMapStart();
	ServerCommand("sv_pure 0");
	ServerCommand("mp_warmup_end");
	ServerExecute();
}
public void OnPluginEnd(){
	Cvar_OnPluginEnd();
	Nodmg_OnPluginEnd();
	EzHop_OnPluginEnd();
	Setting_OnPluginEnd();
	Mode_OnPluginEnd();
	if(g_iscsgo) UnhookEvent("round_start", KF_RoundStart, EventHookMode_Pre);
}
public void OnClientPutInServer(int client){
	Setting_OnClientPutInServer(client);
	Mode_OnClientPutInServer(client);
}
public void OnClientDisconnect(int client){
	Setting_OnClientDisconnect(client);
}

public Action KF_RoundStart(Event evt, const char[] name, bool dontBroadcast){
	ServerCommand("mp_warmup_end");
	ServerExecute();
}
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float velx[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]){
	Setting_OnPlayerRunCmd(client, buttons, impulse, velx, angles, weapon, subtype, cmdnum, tickcount, seed, mouse);
}

#include "kftimer/cvar.sp"
#include "kftimer/nodmg.sp"
#include "kftimer/ezhop.sp"
#include "kftimer/setting.sp"
#include "kftimer/mode.sp"