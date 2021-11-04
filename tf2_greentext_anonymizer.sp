#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <basecomm>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_VERSION		"1.8.0"
#define PLUGIN_VERSION_CVAR	"sm_4chquoter_version"
#define UPDATE_URL			"http://208.167.249.183/addons/update.txt"

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

GlobalForward g_FloodCheck;
GlobalForward g_FloodResult;

char brohoofs[][] = {
	"/)",
	"(\\",
	"/]",
	"[\\"
};

char manesixcolors[][] = {
	"\x07EAEEF0",
	"\x07FABA62",
	"\x07E580AD",
	"\x07EAD566",
	"\x0769A9DC",
	"\x07B57ECA"
};

char teamcolors[][] = {
	"",
	"*SPEC* \x07CCCCCC",
	"\x07FF4040",
	"\x0799CCFF"
};

public void OnPluginStart()
{
	AddCommandListener(OnSay, "say");

	g4chVersion = CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PRINTABLEONLY);
	g_cvAnonymize = CreateConVar("sm_anonymize", "0", "Enables name anonymization in chat", FCVAR_PROTECTED);
	g_cvColoredBrohoof = CreateConVar("sm_coloredbrohoof", "0", "Enables mane six-colored brohooves in chat", FCVAR_PROTECTED);

	g_FloodCheck = new GlobalForward("OnClientFloodCheck", ET_Single, Param_Cell);
	g_FloodResult = new GlobalForward("OnClientFloodResult", ET_Event, Param_Cell, Param_Cell);

	CreateTimer(900.0, SelfAdvertise, _, TIMER_REPEAT);

	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL);
}

public Action SelfAdvertise(Handle timer)
{
	if (g_cvAnonymize.BoolValue)
		PrintToChatAll("\x01It's \x07117743Anonymous\x01 Friday! All names in allchat are anonymized.");

	return Plugin_Continue;
}

bool SendMessage(int client, const char[] format, any ...)
{
	char message[254];
	Handle buffer = StartMessageAll("SayText2");

	if (buffer == INVALID_HANDLE)
		return false;

	VFormat(message, sizeof(message), format, 3);
	BfWriteByte(buffer, client);
	BfWriteByte(buffer, true);
	BfWriteString(buffer, message);
	EndMessage();

	return true;
}

public Action OnSay(int client, const char[] command, int argc)
{
	bool spamming = true, bAnonymize = g_cvAnonymize.BoolValue, bBrohoof = g_cvColoredBrohoof.BoolValue;
	char color[8] = "\x01", prefix[16], text[254];
	TFTeam clientteam;

	if(!client || client > MaxClients || !IsClientInGame(client) || BaseComm_IsClientMuted(client))
		return Plugin_Continue;

	if (GetCommandFlags("sm_flood_time") != INVALID_FCVAR_FLAGS) {
		Call_StartForward(g_FloodCheck);
		Call_PushCell(client);
		Call_Finish(spamming);

		Call_StartForward(g_FloodResult);
		Call_PushCell(client);
		Call_PushCell(spamming);
		Call_Finish();
	} else {
		spamming = false;
	}

	if (spamming)
		return Plugin_Handled;

	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	
	clientteam = TF2_GetClientTeam(client);

	Format(prefix, sizeof(prefix), "%s%s", (clientteam == TFTeam_Spectator || IsPlayerAlive(client)) ? NULL_STRING : "*DEAD* ", teamcolors[clientteam]);

	if (bBrohoof) {
		for (int i = 0; i < sizeof(brohoofs); ++i) {
			char brohoof[3];
			strcopy(brohoof, sizeof(brohoof), brohoofs[i]);
			if (StrContains(text, brohoof) != -1) {
				char coloredbrohoof[12];
				Format(coloredbrohoof, sizeof(coloredbrohoof), "%s%s\x01", manesixcolors[GetRandomInt(0, sizeof(manesixcolors)-1)], brohoof);
				ReplaceString(text, sizeof(text), brohoof, coloredbrohoof);
			}
		}
	}

	if (text[0] == '>')
		strcopy(color, sizeof(color), "\x07789922");

	if (bAnonymize) {
		if (SendMessage(client, "\x07117743Anonymous\x01 :  %s%s", color, text))
			PrintToServer("Anonymous: %s", text);
	} else {
		if (SendMessage(client, "\x01%s%N\x01 :  %s%s", prefix, client, color, text))
			PrintToServer("%N: %s", client, text);
	}

	return Plugin_Handled;
}
