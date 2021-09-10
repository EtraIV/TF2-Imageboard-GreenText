#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>

#define PLUGIN_VERSION            "1.2.0"
#define PLUGIN_VERSION_CVAR       "sm_4chquoter_version"

public Plugin myinfo = 
{
	name = "[TF2] Anonymizer and Greentexter",
	author = "2010kohtep, Etra",
	description = "Greentexts lines that start with a >, and anonymizes usernames in chat.",
	version = PLUGIN_VERSION,
	url = "https://github.com/EtraIV/TF2-Imageboard-GreenText"
};

ConVar g4chVersion;
ConVar g_cvAnonymize;

public void OnPluginStart()
{	
	AddCommandListener(OnSay, "say");
	
	g4chVersion = CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PRINTABLEONLY);
	g_cvAnonymize = CreateConVar("sm_anonymize", "1", "Enables name anonymization in chat", FCVAR_PROTECTED);
	CreateTimer(900.0, SelfAdvertise, _, TIMER_REPEAT);
}

public Action SelfAdvertise(Handle timer)
{
	PrintToChatAll("It's Anonymous Friday! All names in allchat are anonymized.");

	return Plugin_Continue;
}

public Action OnSay(int client, const char[] command, int argc)
{
	if(!client || client > MaxClients || !IsClientInGame(client)) 
		return Plugin_Continue;

	char text[128];
	
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);

	if (g_cvAnonymize.BoolValue) {
		PrintToChatAll(text[0] == '>' ? "\x07117743Anonymous\x01 : \x07789922%s" : "\x07117743Anonymous\x01 : %s", text);
	} else {
		if (text[0] == '>') {
			char output[256];

			switch (GetClientTeam(client)) {
				case TFTeam_Blue:
					Format(output, sizeof(output), "\x0799CCFF%N\x01 : \x07789922%s", client, text);
				case TFTeam_Red:
					Format(output, sizeof(output), "\x07FF4040%N\x01 : \x07789922%s", client, text);
				default:
					Format(output, sizeof(output), "\x07CCCCCC%N\x01 : \x07789922%s", client, text);
			}
			PrintToChatAll(output);
		} else {
			return Plugin_Continue;
		}
	}

	return Plugin_Handled;
}