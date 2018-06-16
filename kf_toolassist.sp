#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
	name = "KF_TAS",
	author = "l2zq",
	description = "",
	version = "1.0",
	url = ""
}
enum TAS_STATE {
	TAS_NONE=0,
	TAS_PAUSE,
	TAS_RECORD,
	TAS_REPLAY,
	TAS_STATE_COUNT
}
enum TAP_STATE { // TAS Pause
	TAP_NONE=0,
	TAP_REWIND, TAP_REW1TK,
	TAP_FSTFWD, TAP_FFW1TK,
	TAP_GOTOEND,
	TAP_GOSTART,
	TAP_LASTPAU,
	TAP_STATE_COUNT
}
enum FRAME_DATA{
	F_BUTTONS = 0, F_MOVETYPE, F_ENTFLAGS,
	F_ORIGIN0, F_ORIGIN1, F_ORIGIN2,
	F_ANGLES0, F_ANGLES1, F_ANGLES2,
	F_SPEEDV0, F_SPEEDV1, F_SPEEDV2,
	F_VELVEL0, F_VELVEL1, F_VELVEL2, F_STAMINA
}
enum PLAY_MODE{
	PL_TELEPORT = 0,
	PL_FAKEINPUT,
	PL_SETENTPROP,
	PLCOUNT
}

#define REWIND_STEP g_rewsteps[g_rewindstep[client]]
#define FRAME_SIZE 16
int				g_playmode = 0;
int       g_rewsteps[] = {1,2,4,8,16,32};
int       g_rewindstep[MAXPLAYERS+1];
int       g_framenum[MAXPLAYERS+1];
TAS_STATE g_tasstate[MAXPLAYERS+1];
TAS_STATE g_pauresume[MAXPLAYERS+1];
TAP_STATE g_tapstate[MAXPLAYERS+1];
ArrayList g_recframes[MAXPLAYERS+1];
int       g_last_pause_frame[MAXPLAYERS+1];
bool      g_playstate_firstframe[MAXPLAYERS+1];
bool cheater = false;
public void OnPluginStart(){
	int i;
	for(i=1;i<MaxClients;i++)
		g_recframes[i] = new ArrayList(FRAME_SIZE);
	RegConsoleCmd("ta_start", Cmd_Start);
	RegConsoleCmd("ta_pause_resume", Cmd_Pause);
	RegConsoleCmd("ta_resume_replay", Cmd_ResReplay);
	RegConsoleCmd("ta_resume_record", Cmd_ResRecord);
	RegConsoleCmd("ta_stop", Cmd_Stop);
	RegConsoleCmd("+ta_rewind", Cmd_Rewind);
	RegConsoleCmd("+ta_fastforward", Cmd_FastForward);
	RegConsoleCmd("-ta_rewind", Cmd_TapNone);
	RegConsoleCmd("-ta_fastforward", Cmd_TapNone);
	RegConsoleCmd("ta_lastpause", Cmd_LastPause);
	RegConsoleCmd("ta_gotostart", Cmd_GoStart);
	RegConsoleCmd("ta_gotoend", Cmd_GotoEnd);
	RegConsoleCmd("ta_tickadv", Cmd_Ffw1Tick);
	RegConsoleCmd("ta_tickrew", Cmd_Rew1Tick);
	
	RegConsoleCmd("ta_rewstep", Cmd_RewStep);
	
	RegConsoleCmd("ta_load", Cmd_Load);
	RegConsoleCmd("ta_save", Cmd_Save);
	
	CreateConVar("ta_cheater", "0").AddChangeHook(ShowMenu);
	CreateConVar("ta_playmode", "0", "0/teleport;1/fakebtn;2/entprop", FCVAR_NOTIFY).AddChangeHook(PlayModeChange);
}
public void ShowMenu(ConVar c, const char[] s, const char[] s2){
	cheater = c.BoolValue;
}
public void PlayModeChange(ConVar c, const char[] s, const char[] s2){
	g_playmode = c.IntValue;
	if(g_playmode>=view_as<int>(PLCOUNT))
		c.IntValue = view_as<int>(PLCOUNT)-1;
}

public Action Cmd_RewStep(int client, int argc){
	if(client==0) client=1;
	g_rewindstep[client]++;
	if(g_rewindstep[client]>=sizeof(g_rewsteps))
		g_rewindstep[client]=0;
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]){
	if(g_tasstate[client]!=TAS_REPLAY)
		g_playstate_firstframe[client] = true;
	if(g_tasstate[client]!=TAS_PAUSE)
		g_pauresume[client] = g_tasstate[client];
	int total_frames = g_recframes[client].Length;
	new current_frame[FRAME_SIZE];
	GetCurrentFrame(client, current_frame, buttons, vel, angles);
	switch(g_tasstate[client]){
		case TAS_NONE:{}
		case TAS_RECORD:{
			g_recframes[client].Resize(g_framenum[client]+1);
			g_recframes[client].SetArray(g_framenum[client], current_frame);
			g_framenum[client]++;
		}
		case TAS_REPLAY:
			if(total_frames!=0){
				if(g_framenum[client]<1) g_framenum[client]=0;
				if(g_framenum[client]>total_frames) g_framenum[client]=total_frames;
				g_recframes[client].GetArray(g_framenum[client]-1, current_frame);
				LoadFrame(client, current_frame, g_playstate_firstframe[client], buttons, vel, angles);
				g_framenum[client]++;
				g_playstate_firstframe[client] = false;
			}
		case TAS_PAUSE:
			if(total_frames!=0){
				switch(g_tapstate[client]){
					case TAP_NONE:{}
					case TAP_REWIND: g_framenum[client]-=REWIND_STEP;
					case TAP_FSTFWD: g_framenum[client]+=REWIND_STEP;
					case TAP_REW1TK:{
						g_framenum[client]--;
						g_tapstate[client] = TAP_NONE;
					}
					case TAP_FFW1TK:{
						g_framenum[client]++;
						g_tapstate[client] = TAP_NONE;
					}
					case TAP_GOSTART:{
						g_framenum[client]=1;
						g_tapstate[client] = TAP_NONE;
					}
					case TAP_GOTOEND:{
						g_framenum[client]=total_frames;
						g_tapstate[client] = TAP_NONE;
					}
					case TAP_LASTPAU:{
						g_framenum[client]=g_last_pause_frame[client];
						g_tapstate[client] = TAP_NONE;
					}
				}
				if(g_framenum[client]<1) g_framenum[client]=1;
				if(g_framenum[client]>total_frames) g_framenum[client]=total_frames;
				g_last_pause_frame[client] = g_framenum[client];
				g_recframes[client].GetArray(g_framenum[client]-1, current_frame);
				LoadFrame(client, current_frame, true, buttons, vel, angles);
			}
	}
	ShowTasHint(client, total_frames, current_frame);
	return Plugin_Continue;
}

stock void GetCurrentFrame(int client, frame[FRAME_SIZE], int buttons, float vel[3], float angles[3]){
	float origin[3], speedv[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", speedv);
	frame[F_BUTTONS] = view_as<int>(buttons);// btn
	frame[F_ENTFLAGS]= view_as<int>(GetEntityFlags(client));
	frame[F_MOVETYPE]= view_as<int>(GetEntityMoveType(client));
	frame[F_VELVEL0] = view_as<int>(vel[0]); // vel
	frame[F_VELVEL1] = view_as<int>(vel[1]);
	frame[F_VELVEL2] = view_as<int>(vel[2]);
	frame[F_ANGLES0] = view_as<int>(angles[0]); // ang
	frame[F_ANGLES1] = view_as<int>(angles[1]);
	frame[F_ANGLES2] = view_as<int>(angles[2]);
	frame[F_ORIGIN0] = view_as<int>(origin[0]); // origin
	frame[F_ORIGIN1] = view_as<int>(origin[1]);
	frame[F_ORIGIN2] = view_as<int>(origin[2]);
	frame[F_SPEEDV0] = view_as<int>(speedv[0]); // speedv
	frame[F_SPEEDV1] = view_as<int>(speedv[1]);
	frame[F_SPEEDV2] = view_as<int>(speedv[2]);
	frame[F_STAMINA] = view_as<int>(GetEntPropFloat(client, Prop_Send, "m_flStamina"));
}
stock void LoadFrame(int client, frame[FRAME_SIZE], bool teleport, int &buttons, float vel[3], float angles[3]){
	int flags; MoveType movetype;
	float origin[3], speedv[3], stamina;
	buttons                   = frame[F_BUTTONS] ;
	flags                     = frame[F_ENTFLAGS];
	stamina                   = view_as<float>(frame[F_STAMINA]);
	movetype                  = view_as<MoveType>(frame[F_MOVETYPE]);
	vel[0]                    = view_as<float>(frame[F_VELVEL0]);
	vel[1]                    = view_as<float>(frame[F_VELVEL1]);
	vel[2]                    = view_as<float>(frame[F_VELVEL2]);
	angles[0]                 = view_as<float>(frame[F_ANGLES0]);
	angles[1]                 = view_as<float>(frame[F_ANGLES1]);
	angles[2]                 = view_as<float>(frame[F_ANGLES2]);
	origin[0]                 = view_as<float>(frame[F_ORIGIN0]);
	origin[1]                 = view_as<float>(frame[F_ORIGIN1]);
	origin[2]                 = view_as<float>(frame[F_ORIGIN2]);
	speedv[0]                 = view_as<float>(frame[F_SPEEDV0]);
	speedv[1]                 = view_as<float>(frame[F_SPEEDV1]);
	speedv[2]                 = view_as<float>(frame[F_SPEEDV2]);
	SetEntPropFloat(client, Prop_Send, "m_flStamina", stamina);
	if(teleport){
		SetEntityFlags(client, flags);
		SetEntityMoveType(client, movetype);
		TeleportEntity(client, origin, angles, speedv);
	}
	else
		switch(g_playmode){
			case PL_TELEPORT:{
				SetEntityFlags(client, flags);
				SetEntityMoveType(client, movetype);
				TeleportEntity(client, origin, angles, speedv);
			}
			case PL_FAKEINPUT:{
			}
			case PL_SETENTPROP:{
				SetEntityFlags(client, flags);
				SetEntityMoveType(client, movetype);
				SetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
				SetEntPropVector(client, Prop_Data, "m_vecVelocity", speedv);
			}
		}
}

public Action Cmd_Start(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]!=TAS_NONE){
		PrintToConsole(client, "[KF] Already in TAS");
		return Plugin_Handled;
	}
	g_framenum[client]=0;
	g_recframes[client].Resize(0);
	g_tasstate[client]=TAS_RECORD;
	g_tapstate[client]=TAP_NONE;
	PrintToConsole(client, "[KF] Started TAS");
	return Plugin_Handled;
}
public Action Cmd_Stop(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	g_framenum[client]=0;
	g_recframes[client].Resize(0);
	g_tasstate[client]=TAS_NONE;
	g_tapstate[client]=TAP_NONE;
	PrintToConsole(client, "[KF] Stopped TAS");
	return Plugin_Handled;
}
public Action Cmd_Pause(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	if(g_tasstate[client]!=TAS_PAUSE){
		g_tasstate[client]=TAS_PAUSE;
		PrintToConsole(client, "[KF] paused record/replay");
	}
	else{
		g_tasstate[client]=g_pauresume[client];
		PrintToConsole(client, "[KF] resumed record/replay");
	}
	g_tapstate[client]=TAP_NONE;
	return Plugin_Handled;
}
public Action Cmd_ResReplay(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	if(g_tasstate[client]!=TAS_PAUSE){
		PrintToConsole(client, "[KF] You must be in Pause first");
		return Plugin_Handled;
	}
	g_pauresume[client]=TAS_REPLAY;
	PrintToConsole(client, "[KF] will resume to Record");
	return Plugin_Handled;
}
public Action Cmd_ResRecord(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	if(g_tasstate[client]!=TAS_PAUSE){
		PrintToConsole(client, "[KF] You must be in Pause first");
		return Plugin_Handled;
	}
	g_pauresume[client]=TAS_RECORD;
	PrintToConsole(client, "[KF] will resume to Record");
	return Plugin_Handled;
}
public Action Cmd_Rewind(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	if(g_tasstate[client]!=TAS_PAUSE){
		PrintToConsole(client, "[KF] You must be in Pause first");
		return Plugin_Handled;
	}
	g_tapstate[client]=TAP_REWIND;
	return Plugin_Handled;
}
public Action Cmd_FastForward(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	if(g_tasstate[client]!=TAS_PAUSE){
		PrintToConsole(client, "[KF] You must be in Pause first");
		return Plugin_Handled;
	}
	g_tapstate[client]=TAP_FSTFWD;
	return Plugin_Handled;
}
public Action Cmd_TapNone(int client, int argc){
	if(client==0) client=1;
	g_tapstate[client] = TAP_NONE;
	return Plugin_Handled;
}

public Action Cmd_LastPause(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	g_tasstate[client]=TAS_PAUSE;
	g_tapstate[client]=TAP_LASTPAU;
	PrintToConsole(client, "[KF] goto last pause");
	return Plugin_Handled;
}
public Action Cmd_GoStart(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	g_tasstate[client]=TAS_PAUSE;
	g_tapstate[client]=TAP_GOSTART;
	PrintToConsole(client, "[KF] goto start");
	return Plugin_Handled;
}
public Action Cmd_GotoEnd(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	g_tasstate[client]=TAS_PAUSE;
	g_tapstate[client]=TAP_GOTOEND;
	PrintToConsole(client, "[KF] goto end");
	return Plugin_Handled;
}
public Action Cmd_Rew1Tick(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	g_tasstate[client]=TAS_PAUSE;
	g_tapstate[client]=TAP_REW1TK;
	PrintToConsole(client, "[KF] rewind 1tick");
	return Plugin_Handled;
}
public Action Cmd_Ffw1Tick(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]==TAS_NONE){
		PrintToConsole(client, "[KF] Not in TAS");
		return Plugin_Handled;
	}
	g_tasstate[client]=TAS_PAUSE;
	g_tapstate[client]=TAP_FFW1TK;
	PrintToConsole(client, "[KF] advance 1tick");
	return Plugin_Handled;
}
public Action Cmd_Load(int client, int argc){
	if(client==0) client=1;
	if(argc<1){
		PrintToConsole(client, "[KF] usage: <this_cmd> <filename>");
		return Plugin_Handled;
	}
	char filename[256];
	GetCmdArg(1, filename, sizeof(filename));
	File f = OpenFile(filename, "rb+");
	if(f==null)
		PrintToConsole(client, "[KF] cannot play %s", filename);
	else{
		new frame[FRAME_SIZE], thisread;
		ArrayList tmp = new ArrayList(FRAME_SIZE);
		while((thisread=ReadFile(f, frame, FRAME_SIZE, 4))==FRAME_SIZE)
			tmp.PushArray(frame);
		if(thisread==0){
			CloseHandle(g_recframes[client]);
			g_recframes[client] = tmp;
			
			g_framenum[client]=1;
			g_tasstate[client]=TAS_PAUSE;
			g_tapstate[client]=TAP_NONE;
			g_pauresume[client]=TAS_REPLAY;
			g_last_pause_frame[client]=1;
			g_playstate_firstframe[client]=true;
			
			PrintToConsole(client, "[KF] loaded %s, framecount %d", filename, tmp.Length);
		}
		else{
			PrintToConsole(client, "[KF] maybe an incomplte replay file");
			CloseHandle(tmp);
		}
		CloseHandle(f);
	}
	return Plugin_Handled;
}
public Action Cmd_Save(int client, int argc){
	if(client==0) client=1;
	if(g_tasstate[client]!=TAS_PAUSE&&g_tasstate[client]!=TAS_REPLAY){
		PrintToConsole(client, "[KF] must be in Pause/Replay to save");
		return Plugin_Handled;
	}
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	if(StrContains(mapname, "workshop")!=-1){
		char segments[32][3];
		ReplaceString(mapname, sizeof(mapname), "\\", "/");
		ExplodeString(mapname, "/", segments, 3, 64);
		Format(mapname, sizeof(mapname), "[w]%s", segments[2]);
	}
	char filename[256];
	FormatTime(filename, sizeof(filename), "%Y%m%d%H%M%S");
	Format(filename, sizeof(filename), "%s_%s.tas.kfdem", mapname, filename);
	File f = OpenFile(filename, "ab+");
	if(f==null)
		PrintToConsole(client, "[KF] cannot create file for saving");
	else{
		for(int i=0;i<g_recframes[client].Length;i++){
			new write_data[FRAME_SIZE];
			g_recframes[client].GetArray(i, write_data);
			WriteFile(f, write_data, FRAME_SIZE, 4);
		}
		CloseHandle(f);
		PrintToConsole(client, "[KF] saved to %s", filename);
	}
	return Plugin_Handled;
}

public void ShowTasHint(int client, int totalframes, frame[FRAME_SIZE]){
	if(cheater) return;
	float tickintv = GetTickInterval();
	SetHudTextParams(0.1, -1.0, 0.5, 0x66, 0xCC, 0xFF, 0xFF, 0, 0.0, 0.0, 0.0);
	char str[128];
	Format(str, sizeof(str),   "KF_TAS\n");
	Format(str, sizeof(str), "%sframe: %03d/%03d\n", str, g_framenum[client]-1, totalframes);
	float time = tickintv*(g_framenum[client]-1);
	float time_origin = time;
	int hour = RoundToFloor(time/3600.0); time -= float(hour)*3600.0;
	int minute = RoundToFloor(time/60.0); time -= float(minute)*60.0;
	Format(str, sizeof(str), "%stime:  %07.3fs %02d:%02d:%06.3f\n", str, time_origin, hour, minute, time);
	Format(str, sizeof(str), "%srewind_step: %d playmode: %d\n", str, REWIND_STEP, g_playmode);
	Format(str, sizeof(str), "%sstate: ", str);
	switch(g_tasstate[client]){
		case TAS_NONE:
			Format(str, sizeof(str), "%snone", str);
		case TAS_PAUSE:{
			Format(str, sizeof(str), "%spause[%s]", str, g_pauresume[client]==TAS_REPLAY?"replay":"record");
			if(g_tapstate[client]==TAP_REWIND)
				Format(str, sizeof(str), "%s rewind", str);
			if(g_tapstate[client]==TAP_FSTFWD)
				Format(str, sizeof(str), "%s fastforward", str);
		}
		default:
			Format(str, sizeof(str), "%s%s", str, g_tasstate[client]==TAS_REPLAY?"replay":"record");
	}
	int buttons = frame[F_BUTTONS];
	Format(str, sizeof(str), "%s\nkeys: %c%c%c%c %c%c", str,
		(buttons&IN_MOVELEFT)?'A':' ', (buttons&IN_FORWARD)?'W':' ', (buttons&IN_BACK)?'S':' ', (buttons&IN_MOVERIGHT)?'D':' ',
		(buttons&IN_DUCK)?'C':' ',     (buttons&IN_JUMP)?'J':' ');
	ShowHudText(client, 0, "%s", str);
}