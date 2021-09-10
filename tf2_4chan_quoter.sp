#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>

#define PLUGIN_VERSION            "1.1.0"
#define PLUGIN_VERSION_CVAR       "sm_4chquoter_version"

public Plugin myinfo = 
{
	name = "[TF2] Imageboard Green Text",
	author = "2010kohtep, Etra",
	description = "Print quote-styled text in global chat.",
	version = PLUGIN_VERSION,
	url = "https://github.com/EtraIV/TF2-Imageboard-GreenText"
};

ConVar g4chVersion;

public void OnPluginStart()
{	
	AddCommandListener(OnSay, "say");
	
	g4chVersion = CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PRINTABLEONLY);
}

public Action OnSay(int client, const char command[], int argc)
{
	if(!client || client > MaxClients || !IsClientInGame(client)) 
		return Plugin_Continue;

	char text[128];
	char output[256];
	
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);

	Format(output, sizeof(output), text[0] == '>' ? "\x07117743Anonymous\x01 : \x07789922%s" : "\x07117743Anonymous\x01 : %s", text);

	PrintToChatAll(output);
	return Plugin_Handled;
}