#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <adt_trie>
#include <basecomm>
#include <files>
#include <keyvalues>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma newdecls required

#define PLUGIN_VERSION		"1.9.0"
#define PLUGIN_VERSION_CVAR	"sm_4chquoter_version"
#define UPDATE_URL			"http://208.167.249.183/tf/addons/update.txt"

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
ConVar g_cvMaskOff;

GlobalForward g_FloodCheck;
GlobalForward g_FloodResult;

StringMap g_Nicknames;

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
	char path[PLATFORM_MAX_PATH], userid[32], nickname[64];
	KeyValues kv;

	AddCommandListener(OnSay, "say");

	g4chVersion = CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PRINTABLEONLY);
	g_cvAnonymize = CreateConVar("sm_anonymize", "0", "Enables name anonymization in chat", FCVAR_PROTECTED);
	g_cvColoredBrohoof = CreateConVar("sm_coloredbrohoof", "0", "Enables mane six-colored brohooves in chat", FCVAR_PROTECTED);
	g_cvMaskOff = CreateConVar("sm_nicknames", "1", "Use colored player nicknames", FCVAR_PROTECTED);

	g_FloodCheck = new GlobalForward("OnClientFloodCheck", ET_Single, Param_Cell);
	g_FloodResult = new GlobalForward("OnClientFloodResult", ET_Event, Param_Cell, Param_Cell);

	g_Nicknames = new StringMap();

	CreateTimer(900.0, SelfAdvertise, _, TIMER_REPEAT);

	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);

	BuildPath(Path_SM, path, sizeof(path), "configs/tf2_greentext_anonymizer.cfg");
	
	if (!FileExists(path)) {
		SetFailState("Configuration file %s not found.", path);
		return;
	}

	kv = new KeyValues("GreentextAnonymizer");

	if (!kv.ImportFromFile(path)) {
		SetFailState("Error importing config file %s", path);
		delete kv;
		return;
	}

	if (!kv.GotoFirstSubKey()) {
		SetFailState("Error reading first key from config file %s", path);
		delete kv;
		return;
	}

	do {
		kv.GetSectionName(userid, sizeof(userid));
		kv.GetString("nickname", nickname, sizeof(nickname));
		g_Nicknames.SetString(userid, nickname, true);
	} while (kv.GotoNextKey());

	kv.Rewind();
	delete kv;
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
	bool spamming = true, bAnonymize = g_cvAnonymize.BoolValue, bBrohoof = g_cvColoredBrohoof.BoolValue, bMaskOff = g_cvMaskOff.BoolValue;
	char brohoof[3], coloredbrohoof[12], color[8] = "\x01", nickname[64], prefix[16], steamid[32], text[254];
	TFTeam clientteam;

	if (!client || client > MaxClients || !IsClientInGame(client))
		return Plugin_Continue;

	if (BaseComm_IsClientGagged(client))
		return Plugin_Stop;

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
		return Plugin_Stop;

	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);

	if (bBrohoof) {
		for (int i = 0; i < sizeof(brohoofs); ++i) {
			strcopy(brohoof, sizeof(brohoof), brohoofs[i]);
			if (StrContains(text, brohoof) != -1) {
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
		if (bMaskOff) {
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
			if (g_Nicknames.GetString(steamid, nickname, sizeof(nickname))) {
				if (SendMessage(client, "\x07%s\x01 :  %s%s", nickname, color, text)) {
					PrintToServer("%s: %s", nickname, text);

					return Plugin_Handled;
				}
			}
		}

		clientteam = TF2_GetClientTeam(client);

		Format(prefix, sizeof(prefix), "%s%s", (clientteam == TFTeam_Spectator || IsPlayerAlive(client)) ? NULL_STRING : "*DEAD* ", teamcolors[clientteam]);

		if (SendMessage(client, "\x01%s%N\x01 :  %s%s", prefix, client, color, text))
			PrintToServer("%N: %s", client, text);
	}

	return Plugin_Handled;
}
