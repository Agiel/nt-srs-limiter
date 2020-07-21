#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name = "Neotokyo SRS Quickswitch Limiter",
	description = "SRS rof limiter timed from time of shot, inspired by Rain's nt_quickswitchlimiter.",
	author = "Agiel",
	version = PLUGIN_VERSION,
	url = "https://github.com/Agiel/nt-srs-limiter"
};

#define NEO_MAX_CLIENTS 32
static float _flNextAttack[NEO_MAX_CLIENTS + 1];

ConVar g_cvarSRSRof = null;

public void OnPluginStart()
{
	CreateConVar("sm_srs_limiter_version", PLUGIN_VERSION,
		"NT autoswitch limiter version.", FCVAR_DONTRECORD);

	// The time between shots without quickswapping is just under 1.4 seconds. I put the default at 1.38 because
	// I'd rather be on the conservative side. Subject to future tweaking.
	g_cvarSRSRof = CreateConVar("sm_srs_rof", "1.38",
		"Minimum delay between shots when quickswapping, in seconds.", _, true, 0.0, true, 10.0);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch_Post);
		}
	}

	AddTempEntHook("Shotgun Shot", OnFireBullets);
}

public Action OnFireBullets(const char[] te_name, const int[] Players, int numClients, float delay)
{
	int weapon = TE_ReadNum("m_iWeaponID");
	if(weapon == 28) // weapon_SRS
	{
		int client = TE_ReadNum("m_iPlayer") + 1;
		_flNextAttack[client] = GetGameTime() + g_cvarSRSRof.FloatValue;
	}
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
	{
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch_Post);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch_Post);
	}
}

bool IsSRS(int weapon)
{
	char name[11]; // weapon_srs\0
	GetEdictClassname(weapon, name, sizeof(name));
	if (StrEqual(name, "weapon_srs"))
	{
		return true;
	}

	return false;
}

public void OnWeaponSwitch_Post(int client, int weapon)
{
	if (!IsValidClient(client) || !IsValidEdict(weapon))
	{
		return;
	}

	if (IsSRS(weapon) && (_flNextAttack[client] > GetNextAttack(client)))
	{
		SetNextAttack(client, _flNextAttack[client]);
	}
}

void SetNextAttack(int client, float nextTime)
{
	static int ptrHandle = 0;
	char sOffsetName[] = "m_flNextAttack";

	if ((!ptrHandle) && (ptrHandle = FindSendPropInfo(
		"CNEOPlayer", sOffsetName)) == -1)
	{
		SetFailState("Failed to obtain offset: \"%s\"!", sOffsetName);
	}

	SetEntDataFloat(client, ptrHandle, nextTime);
}

float GetNextAttack(int client)
{
	static int ptrHandle = 0;
	char sOffsetName[] = "m_flNextAttack";

	if ((!ptrHandle) && (ptrHandle = FindSendPropInfo(
		"CNEOPlayer", sOffsetName)) == -1)
	{
		SetFailState("Failed to obtain offset: \"%s\"!", sOffsetName);
	}

	return GetEntDataFloat(client, ptrHandle);
}

bool IsValidClient(client) {

	if (client == 0)
		return false;

	if (!IsClientConnected(client))
		return false;

	if (IsFakeClient(client))
		return false;

	if (!IsClientInGame(client))
		return false;

	return true;
}