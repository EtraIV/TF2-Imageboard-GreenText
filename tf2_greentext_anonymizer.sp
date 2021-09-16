#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2>

#define PLUGIN_VERSION		"1.4.6"
#define PLUGIN_VERSION_CVAR	"sm_4chquoter_version"

public Plugin myinfo = {
	name = "[TF2] Greentexter and Anonymizer",
	author = "2010kohtep, Etra",
	description = "Greentexts lines that start with a >, and anonymizes usernames in chat.",
	version = PLUGIN_VERSION,
	url = "https://github.com/EtraIV/TF2-Imageboard-GreenText"
};

ConVar g4chVersion;
ConVar g_cvAnonymize;
ConVar g_cvColoredBrohoof;

public void OnPluginStart()
{
	AddCommandListener(OnSay, "say");

	g4chVersion = CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PRINTABLEONLY);
	g_cvAnonymize = CreateConVar("sm_anonymize", "0", "Enables name anonymization in chat", FCVAR_PROTECTED);
	g_cvColoredBrohoof = CreateConVar("sm_coloredbrohoof", "0", "Enables mane six-colored brohooves in chat", FCVAR_PROTECTED);
	CreateTimer(900.0, SelfAdvertise, _, TIMER_REPEAT);
}

public Action SelfAdvertise(Handle timer)
{
	if (g_cvAnonymize.BoolValue)
		PrintToChatAll("\x01It's \x07117743Anonymous\x01 Friday! All names in allchat are anonymized.");

	return Plugin_Continue;
}

void GetManeSixColorPrefix(char[] prefix, int length)
{
	switch(GetRandomInt(0, 5)) {
		case 0: strcopy(prefix, length, "\x07B57ECA");
		case 1: strcopy(prefix, length, "\x07EAEEF0");
		case 2: strcopy(prefix, length, "\x07E97035");
		case 3: strcopy(prefix, length, "\x07E580AD");
		case 4: strcopy(prefix, length, "\x07EAD566");
		case 5: strcopy(prefix, length, "\x0769A9DC");
	}
}

public Action OnSay(int client, const char[] command, int argc)
{
	char color[8] = "\x01", prefix[16], text[128];
	
	if(!client || client > MaxClients || !IsClientInGame(client)) 
		return Plugin_Continue;
	
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);

	switch (GetClientTeam(client)) {
		case TFTeam_Blue:	Format(prefix, sizeof(prefix), "%s\x0799CCFF", IsPlayerAlive(client) ? NULL_STRING : "*DEAD* ");
		case TFTeam_Red:	Format(prefix, sizeof(prefix), "%s\x07FF4040", IsPlayerAlive(client) ? NULL_STRING : "*DEAD* ");
		default:		strcopy(prefix, sizeof(prefix), "*SPEC* \x07CCCCCC");
	}

	if (g_cvColoredBrohoof.BoolValue) {
		if (!strcmp("/)", text) || !strcmp("(\\", text) || !strcmp("/]", text) || !strcmp("[\\", text)) {
			GetManeSixColorPrefix(color, sizeof(color));
			if (!(g_cvAnonymize.BoolValue)) {
				PrintToChatAll("\x01%s%N\x01 :  %s%s", prefix, client, color, text);
				PrintToServer("%N: %s", client, text);
				return Plugin_Handled;
			}
		}
	}
	
	if (text[0] == '>')
		strcopy(color, sizeof(color), "\x07789922");

	if (g_cvAnonymize.BoolValue) {
		PrintToChatAll("\x07117743Anonymous\x01 :  %s%s", color, text);
		PrintToServer("Anonymous: %s", text);
	} else {
		if (text[0] == '>') {
			PrintToChatAll("\x01%s%N\x01 :  %s%s", prefix, client, color, text);
			PrintToServer("%N: %s", client, text);
		} else {
			return Plugin_Continue;
		}
	}

	return Plugin_Handled;
}
