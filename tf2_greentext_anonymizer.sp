#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <adt_trie>
#include <basecomm>
#include <files>
#include <keyvalues>

#pragma newdecls required

#define PLUGIN_VERSION		"1.10.5"
#define PLUGIN_VERSION_CVAR	"sm_4chquoter_version"

public Plugin myinfo = {
	name = "[TF2] Greentexter and Anonymizer",
	author = "2010kohtep, Etra",
	description = "Greentexts lines that start with a >, and anonymizes usernames in chat.",
	version = PLUGIN_VERSION,
	url = "https://github.com/EtraIV/TF2-Imageboard-GreenText"
};

ConVar g4chVersion = null;
ConVar g_cvAnonymize = null;
ConVar g_cvColoredBrohoof = null;
ConVar g_cvNicknames = null;

GlobalForward g_FloodCheck = null;
GlobalForward g_FloodResult = null;

StringMap g_Nicknames = null;

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

public void OnPluginStart()
{
	AddCommandListener(OnSay, "say");

	g4chVersion = CreateConVar(PLUGIN_VERSION_CVAR, PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PRINTABLEONLY);
	g_cvAnonymize = CreateConVar("sm_anonymize", "0", "Enables name anonymization in chat", FCVAR_PROTECTED);
	g_cvColoredBrohoof = CreateConVar("sm_coloredbrohoof", "0", "Enables mane six-colored brohooves in chat", FCVAR_PROTECTED);
	g_cvNicknames = CreateConVar("sm_nicknames", "1", "Use colored player nicknames", FCVAR_PROTECTED);
	RegAdminCmd("sm_reloadnicknames", ReloadNicknames, ADMFLAG_CONFIG, "Reload nicknames from configuration file");

	g_FloodCheck = new GlobalForward("OnClientFloodCheck", ET_Single, Param_Cell);
	g_FloodResult = new GlobalForward("OnClientFloodResult", ET_Event, Param_Cell, Param_Cell);

	g_Nicknames = new StringMap();

	CreateTimer(900.0, SelfAdvertise, _, TIMER_REPEAT);

	ReloadNicknames(0, 1);
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
	BfWrite buffer = UserMessageToBfWrite(StartMessageAll("SayText2"));

	if (buffer == INVALID_HANDLE)
		return false;

	VFormat(message, sizeof(message), format, 3);
	buffer.WriteNum(client);
	buffer.WriteBool(true);
	buffer.WriteString(message);
	EndMessage();

	return true;
}

public Action ReloadNicknames(int client, int args)
{
	char path[PLATFORM_MAX_PATH], userid[32], nickname[64], colortag[32], colorhex[7], color[8];
	KeyValues kv = null;
	StringMap colors = new StringMap();
	StringMapSnapshot colorkeys = null;

	g_Nicknames.Clear();

	BuildPath(Path_SM, path, sizeof(path), "configs/nickname_colors.cfg");

	if (!FileExists(path)) {
		SetFailState("Configuration file %s not found.", path);
		return Plugin_Stop;
	}

	kv = new KeyValues("Nickname Colors");

	if (!kv.ImportFromFile(path)) {
		SetFailState("Error importing config file %s", path);
		delete kv;
		return Plugin_Stop;
	}

	if (!kv.GotoFirstSubKey()) {
		SetFailState("Error reading first key from config file %s", path);
		delete kv;
		return Plugin_Stop;
	}

	do {
		kv.GetSectionName(colortag, sizeof(colortag));
		kv.GetString("color", colorhex, sizeof(colorhex));
		Format(color, sizeof(color), "\x07%s", colorhex);
		colors.SetString(colortag, color, true);
	} while (kv.GotoNextKey());

	kv.Rewind();
	delete kv;
	colorkeys = colors.Snapshot();

	BuildPath(Path_SM, path, sizeof(path), "configs/tf2_greentext_anonymizer.cfg");

	if (!FileExists(path)) {
		SetFailState("Configuration file %s not found.", path);
		return Plugin_Stop;
	}

	kv = new KeyValues("GreentextAnonymizer");

	if (!kv.ImportFromFile(path)) {
		SetFailState("Error importing config file %s", path);
		delete kv;
		return Plugin_Stop;
	}

	if (!kv.GotoFirstSubKey()) {
		SetFailState("Error reading first key from config file %s", path);
		delete kv;
		return Plugin_Stop;
	}

	do {
		kv.GetSectionName(userid, sizeof(userid));
		kv.GetString("nickname", nickname, sizeof(nickname));
		for (int i = 0; i < colorkeys.Length; ++i) {
			colorkeys.GetKey(i, colortag, sizeof(colortag));
			colors.GetString(colortag, color, sizeof(color));
			ReplaceString(nickname, sizeof(nickname), colortag, color);
		}
		g_Nicknames.SetString(userid, nickname, true);
	} while (kv.GotoNextKey());

	kv.Rewind();
	delete kv;
	delete colorkeys;
	delete colors;

	if (client)
		PrintToChat(client, "Nicknames successfully reloaded.");

	return Plugin_Handled;
}

public Action OnSay(int client, const char[] command, int argc)
{
	bool spamming = true, bAnonymize = g_cvAnonymize.BoolValue, bBrohoof = g_cvColoredBrohoof.BoolValue, bNickname = g_cvNicknames.BoolValue;
	char brohoof[3], coloredbrohoof[12], color[8] = "\x01", nickname[64], prefix[8], steamid[32], text[254];
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
	TrimString(text);

	if (!strlen(text))
		return Plugin_Stop;

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
			LogMessage("Anonymous: %s", text);
	} else {
		clientteam = TF2_GetClientTeam(client);
		strcopy(prefix, sizeof(prefix), clientteam == TFTeam_Spectator ? "*SPEC* " : IsPlayerAlive(client) ? NULL_STRING : "*DEAD* ");

		if (bNickname) {
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
			if (g_Nicknames.GetString(steamid, nickname, sizeof(nickname))) {
				if (SendMessage(client, "\x01%s\x03%s\x01 :  %s%s", prefix, nickname, color, text)) {
					LogMessage("%N: %s", client, text);

					return Plugin_Handled;
				}
			}
		}

		if (SendMessage(client, "\x01%s\x03%N\x01 :  %s%s", prefix, client, color, text))
			LogMessage("%N: %s", client, text);
	}

	return Plugin_Handled;
}
