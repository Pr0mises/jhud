#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "⌐■_■ fuck knows, code was stolen from 5 ppl and all of them claim the ownership. Fixed by Nairda tho."
#define PLUGIN_VERSION "1.11"
#define BHOP_TIME 15

EngineVersion g_Game;

Handle g_hCookieEnabled;
Handle g_hCookieSpeed;
Handle g_hCookieGain;
Handle g_hCookieDisplayMode;
Handle g_hCookieDefault;
Handle g_hCookieDefaultColour;
Handle hText;

int g_iJump[MAXPLAYERS +1];
int g_strafeTick[MAXPLAYERS +1];
int g_iDisplayMode[MAXPLAYERS + 1];
int g_iTicksOnGround[MAXPLAYERS + 1]; // Let's count the ticks for scroll

bool g_bEnabled[MAXPLAYERS +1];
bool g_bTouchesWall[MAXPLAYERS +1];
bool g_bSpeedColour[MAXPLAYERS + 1] = false;
bool g_bGainColour[MAXPLAYERS + 1] = false;
bool g_bDefaultColour[MAXPLAYERS + 1] = true;

float g_flRawGain[MAXPLAYERS +1];

public Plugin myinfo = 
{
	name = "Jhud",
	description = "SSJ in Hud",
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/profiles/76561198075677363/"
};

public void OnAllPluginsLoaded()
{

	HookEvent("player_jump", OnPlayerJump);
}

public void OnPluginStart()
{	
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	RegConsoleCmd("sm_jhud", SM_JHUD, "opens Jhud");
	
	g_hCookieEnabled = RegClientCookie("jhud_enabled", "jhud_enabled", CookieAccess_Public);
	g_hCookieSpeed = RegClientCookie("speed_enabled", "speed_enabled", CookieAccess_Public);
	g_hCookieGain = RegClientCookie("gain_enabled", "gain_enabled", CookieAccess_Public);
	g_hCookieDisplayMode = RegClientCookie("usagemode", "usagemode", CookieAccess_Public);
	g_hCookieDefault = RegClientCookie("jhud_default", "jhud_default", CookieAccess_Public);
	g_hCookieDefaultColour = RegClientCookie("colour_default", "colour_default", CookieAccess_Public);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}
	hText = CreateHudSynchronizer();
}

public void OnClientCookiesCached(int client)
{	
	char sCookie[4];
	
	GetClientCookie(client, g_hCookieDefault, sCookie, sizeof(sCookie));
	
	if(StringToInt(sCookie) == 0)
	{
		SetCookie(client, g_hCookieEnabled, false);
		SetCookie(client, g_hCookieSpeed, false);
		SetCookie(client, g_hCookieGain, false);
		SetCookie(client, g_hCookieDisplayMode, 0);
		SetCookie(client, g_hCookieDefaultColour, true);
		
		SetCookie(client, g_hCookieDefault, true);
	}
	
	g_bEnabled[client] = GetCookie(client, g_hCookieEnabled);
	g_bSpeedColour[client] = GetCookie(client, g_hCookieSpeed);
	g_bGainColour[client] = GetCookie(client, g_hCookieGain);
	g_bDefaultColour[client] = GetCookie(client, g_hCookieDefaultColour);
	GetClientCookie(client, g_hCookieDisplayMode, sCookie, sizeof(sCookie));
	g_iDisplayMode[client] = StringToInt(sCookie);
}

public void OnClientPutInServer(int client)
{
	g_iJump[client] = 0;
	g_strafeTick[client] = 0;
	g_flRawGain[client] = 0.0;
	g_iTicksOnGround[client] = 0;
	SDKHook(client, SDKHook_Touch, onTouch);
}

public void OnClientDisconnect(int client)
{
	g_bEnabled[client] = false;
	g_bSpeedColour[client] = false;
	g_bGainColour[client] = false;
}

public Action SM_JHUD(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "[SM] This command can only used ingame");
		return Plugin_Handled;
	}
	else
	{
		JhudMenu(client);
	}

	return Plugin_Handled;
}

void JhudMenu(int client)
{
	char sBuffer[128];
	Panel panel = CreatePanel(); // panel cuz menu has no drawtext, and preview with numbers? hell na
	
	panel.SetTitle("Jhud Menu");
	
	panel.DrawText(" ");
	
	FormatEx(sBuffer, sizeof(sBuffer), "Jhud - [%s]", (g_bEnabled[client]) ? "x" : " ");
	panel.DrawItem(sBuffer);
	
	panel.DrawText(" ");
	
	//Display Mode preview
	if(g_iDisplayMode[client] == 0)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "jump: ssj");
	}
	else if (g_iDisplayMode[client] == 1)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "jump: gain %");
	}
	else if (g_iDisplayMode[client] == 2)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "jump: ssj - gain %");
	}
	panel.DrawText(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "%s", g_iDisplayMode[client] == 0 ? "Mode: default" : (g_iDisplayMode[client] == 1 ? "Mode: gain" : "Mode: vel-gain"));
	panel.DrawItem(sBuffer);
	
	panel.DrawText(" ");
	
	FormatEx(sBuffer, sizeof(sBuffer), "Default Colour - [%s]", (g_bDefaultColour[client]) ? "x" : " ");
	panel.DrawItem(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "Velocity Colour - [%s]", (g_bSpeedColour[client]) ? "x" : " ");
	panel.DrawItem(sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "Gain Colour - [%s]", (g_bGainColour[client]) ? "x" : " ");
	panel.DrawItem(sBuffer);
	
	panel.DrawItem("", ITEMDRAW_SPACER);

	panel.CurrentKey = 10;
	panel.DrawItem("Exit                          ", ITEMDRAW_CONTROL);
	
	panel.Send(client, menu_Jhud, 0);
	
	CloseHandle(panel);
}

public int menu_Jhud(Handle menu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 1: //Jhud on/off
				{
					g_bEnabled[client] = !g_bEnabled[client];
					SetCookie(client, g_hCookieEnabled, g_bEnabled[client]);
					JhudMenu(client);
				}
				case 2: //switch modes
				{
					g_iDisplayMode[client] = (g_iDisplayMode[client] + 1) % 3;
					SetCookie(client, g_hCookieDisplayMode, g_iDisplayMode[client]);
					JhudMenu(client);
				}
				case 3:
				{
					if (g_bGainColour[client] || g_bSpeedColour[client])
					{
						g_bGainColour[client] = false;
						g_bSpeedColour[client] = false;
						SetCookie(client, g_hCookieSpeed, g_bSpeedColour[client]);
						SetCookie(client, g_hCookieGain, g_bGainColour[client]);
						
						g_bDefaultColour[client] = !g_bDefaultColour[client];
						SetCookie(client, g_hCookieDefaultColour, g_bDefaultColour[client]);
						
					}
					JhudMenu(client);
				}
				case 4:
				{
					if (g_bGainColour[client] || g_bDefaultColour[client])
					{
						g_bGainColour[client] = false;
						g_bDefaultColour[client] = false;
						SetCookie(client, g_hCookieGain, g_bGainColour[client]);
						SetCookie(client, g_hCookieDefaultColour, g_bDefaultColour[client]);
						
						g_bSpeedColour[client] = !g_bSpeedColour[client];
						SetCookie(client, g_hCookieSpeed, g_bSpeedColour[client]);
						
					}
					JhudMenu(client);
				}
				case 5:
				{
					if (g_bSpeedColour[client] || g_bDefaultColour[client])
					{
						g_bSpeedColour[client] = false;
						g_bDefaultColour[client] = false;
						SetCookie(client, g_hCookieSpeed, g_bSpeedColour[client]);
						SetCookie(client, g_hCookieDefaultColour, g_bDefaultColour[client]);
						
						g_bGainColour[client] = !g_bGainColour[client];
						SetCookie(client, g_hCookieGain, g_bGainColour[client]);
						
					}
					JhudMenu(client);
				}
			}
		}
	}
}

public Action onTouch(int client, int entity)
{
	/* https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/public/engine/ICollideable.h
		SOLID_NONE = 0, // no solid model
		SOLID_BSP = 1, // a BSP tree
		SOLID_BBOX = 2, // an AABB
		SOLID_OBB = 3, // an OBB (not implemented yet)
		SOLID_OBB_YAW = 4, // an OBB, constrained so that it can only yaw
		SOLID_CUSTOM = 5, // Always call into the entity for tests
		SOLID_VPHYSICS = 6, // solid vphysics object, get vcollide from the model and collide with that
	*/
	
	if(!(GetEntProp(entity, Prop_Data, "m_usSolidFlags") & 28))	
		g_bTouchesWall[client] = true;
}

public Action OnPlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	
	if (!IsValidClientIndex(client) || IsFakeClient(client))
		return;
	
	if (g_iJump[client] && g_strafeTick[client] <= 0)
		return;
	
	g_iJump[client]++;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && ((!IsPlayerAlive(i) && GetEntPropEnt(i, Prop_Data, "m_hObserverTarget") == client && GetEntProp(i, Prop_Data, "m_iObserverMode") != 7 && g_bEnabled[i]) || (i == client && g_bEnabled[i])))
		{
			JHUD_Print(i, client);
		}
	}
	g_flRawGain[client] = 0.0;
	g_strafeTick[client] = 0;
}

void JHUD_Get(int client, float vel[3], float angles[3])
{
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
	
	float gaincoeff;
	g_strafeTick[client]++;
	
	
	float fore[3], side[3], wishvel[3], wishdir[3];
	float wishspeed, wishspd, currentgain;
	
	GetAngleVectors(angles, fore, side, NULL_VECTOR);
	
	fore[2] = 0.0;
	side[2] = 0.0;
	NormalizeVector(fore, fore);
	NormalizeVector(side, side);
	
	for (int i = 0; i < 2; i++)
		wishvel[i] = fore[i] * vel[0] + side[i] * vel[1];
	
	wishspeed = NormalizeVector(wishvel, wishdir);
	if (wishspeed > GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") && GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != 0.0)
		wishspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	
	if (wishspeed)
	{
		wishspd = (wishspeed > 30.0) ? 30.0 : wishspeed;
		
		currentgain = GetVectorDotProduct(velocity, wishdir);
		if(currentgain < 30.0)
		{
			gaincoeff = (wishspd - FloatAbs(currentgain)) / wishspd;
		}
		if(g_bTouchesWall[client] && gaincoeff > 0.5)
		{
			gaincoeff -= 1;
			gaincoeff = FloatAbs(gaincoeff);
		}
		g_flRawGain[client] += gaincoeff;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{	
	if (IsFakeClient(client)) 
		return Plugin_Continue;
	
	if (GetEntityFlags(client) & FL_ONGROUND)
	{
		if (g_iTicksOnGround[client] & BHOP_TIME)
		{
			g_iJump[client] = 0;
			g_strafeTick[client] = 0;
			g_flRawGain[client] = 0.0;
		}
		g_iTicksOnGround[client]++;
		if(buttons & IN_JUMP && (g_iTicksOnGround[client] <= 15))
		{
			JHUD_Get(client, vel, angles);
			g_iTicksOnGround[client] = 0;
		}
	}
	else 
	{
		if(GetEntityMoveType(client) != MOVETYPE_NONE && GetEntityMoveType(client) != MOVETYPE_NOCLIP && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
		{
			JHUD_Get(client, vel, angles);
		}
		g_iTicksOnGround[client] = 0;
	}
	
	g_bTouchesWall[client] = false;

	return Plugin_Continue;
}

void JHUD_Print(int client, int target)
{	
	float velocity[3], origin[3];
	GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", velocity);
	GetClientAbsOrigin(target, origin);
	velocity[2] = 0.0;
	
	float coeffsum = g_flRawGain[target];
	coeffsum /= g_strafeTick[target];
	coeffsum *= 100.0;
	
	coeffsum = RoundToFloor(coeffsum * 100.0 + 0.5) / 100.0;
	
	char JHUDText[255];
	
			//jump # - speed
	if(g_iDisplayMode[client] == 0)
	{
		if((g_iJump[target] <= 6) || g_iJump[target] == 16)
		{
			FormatEx(JHUDText, sizeof(JHUDText), "%i: %i", g_iJump[target], RoundToFloor(GetVectorLength(velocity)));
		}
		else
		{
			Format(JHUDText, sizeof(JHUDText), "%.0f%", coeffsum);
		}
	}
			//jump# - gain %
	else if(g_iDisplayMode[client] == 1)
	{
		if((g_iJump[target] == 1) || g_iJump[target] == 16)
		{
			FormatEx(JHUDText, sizeof(JHUDText), "%i: %i", g_iJump[target], RoundToFloor(GetVectorLength(velocity)));
		}
		else
		{
			Format(JHUDText, sizeof(JHUDText), "%i: %.0f%", g_iJump[target], coeffsum);
		}
	}
			//jump # - ssj - gain % 
	else if(g_iDisplayMode[client] == 2)
	{
		if(g_iJump[target] == 1)
		{
			FormatEx(JHUDText, sizeof(JHUDText), "%i: %i", g_iJump[target], RoundToFloor(GetVectorLength(velocity)));
		}
		else
		{
			FormatEx(JHUDText, sizeof(JHUDText), "%i: %i - %0.f%", g_iJump[target], RoundToFloor(GetVectorLength(velocity)), coeffsum);
		}
	}
	
	int newvelocity = RoundToFloor(GetVectorLength(velocity));
	
	// get the text color
	int r, g, b;
	
	if(g_bDefaultColour[client])
	{
		if(g_iJump[target] <= 6 || g_iJump[target] == 16)
		{
			GetSpeedColour(g_iJump[target], newvelocity, r, g, b);
		}
		else
		{
			GetGainColour(coeffsum, r, g, b);
		}
	}
	else if(g_bSpeedColour[client])
	{
		//Use speed as colour
		GetSpeedColour(g_iJump[target], newvelocity, r, g, b);
	}
	else if(g_bGainColour[client])
	{
	
		//Use gain as colour
	
		if(g_iJump[target] == 1)
		{
			GetSpeedColour(g_iJump[target], newvelocity, r, g, b);
		}
		else
		{
			GetGainColour(coeffsum, r, g, b);
		}
	}
	
	// print the text
	if(hText != INVALID_HANDLE)
	{
		SetHudTextParams(-1.0, -1.0, 1.0, r, g, b, 255);
		ShowSyncHudText(client, hText, JHUDText);
	}
}

void GetGainColour(float gain, int &r, int &g, int &b)
{	
	if (gain < 60.00)
	{
		r = 255;
		g = 0;		//red
		b = 0;
	}
	else if (60.00 <= gain < 70.00)
	{
		r = 255;
		g = 126;	//orange
		b = 0;
	}
	else if (70.00 <= gain < 80.00)
	{
		r = 0;
		g = 255;	//green
		b = 0;
	}
	else
	{
		r = 0;
		g = 255;	//blue
		b = 255;
	}
}

void GetSpeedColour(int jump, int speed, int &r, int &g, int &b)
{
	if ((jump == 1 && 280 <= speed < 282) || (jump == 2 && 366 <= speed < 370) || (jump == 3 && 438 <= speed < 442) || (jump == 4 && 500 <= speed < 505) || (jump == 5 && 555 <= speed < 560) || (jump == 6 && 605 <= speed < 610) ||  (jump == 16 && 965 <= speed < 980))
	{
		r = 255;
		g = 126; //orange
		b = 0;
	}
	else if ((jump == 1 && 282 <= speed < 287) || (jump == 2 && 370 <= speed < 375) || (jump == 3 && 442 <= speed < 450) || (jump == 4 && 505 <= speed < 515) || (jump == 5 && 560 <= speed < 570) || (jump == 6 && 610 <= speed < 620) || (jump == 16 && 980 <= speed < 1000))
	{
		r = 0;
		g = 255; //green
		b = 0;
	}
	else if ((jump == 1 && speed >= 287) || (jump == 2 && speed >= 375) || (jump == 3 && speed >= 450) || (jump == 4 && speed >= 515) || (jump == 5 && speed >= 570) || (jump == 6 && speed >= 620) || (jump == 16 && speed >= 1000))
	{
		r = 0;
		g = 255; //blue
		b = 255;
	}
	else
	{
		r = 255;
		g = 0;	//red
		b = 0;
	}
}

stock bool GetCookie(int client, Handle cookie)
{	
	char sValue[8];
	GetClientCookie(client, cookie, sValue, sizeof(sValue));
	
	return (sValue[0] != '\0' && StringToInt(sValue));
}

stock void SetCookie(int client, Handle hCookie, int n)
{
	char strCookie[64];
	
	IntToString(n, strCookie, sizeof(strCookie));

	SetClientCookie(client, hCookie, strCookie);
}

// We don't want the -1 client id bug. Thank Volvo™ for this
stock bool IsValidClientIndex(int client)
{
    return (0 < client <= MaxClients);
}
