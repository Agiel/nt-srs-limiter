#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = {
	name = "Neotokyo SRS Quickswitch Limiter",
	description = "SRS rof limiter timed from time of shot, inspired by Rain's nt_quickswitchlimiter.",
	author = "Agiel",
	version = PLUGIN_VERSION,
	url = "https://github.com/Agiel/nt-srs-limiter"
};

#define NEO_MAX_CLIENTS 32
static float _flNextAttack[NEO_MAX_CLIENTS + 1];

static int _srs_edicts[NEO_MAX_CLIENTS];
static int _srs_edicts_head = 0;

#define SRS_ROF_MAX 2.0
ConVar g_cvarSRSRof = null;

public void OnPluginStart()
{
	CreateConVar("sm_srs_limiter_version", PLUGIN_VERSION,
		"NT SRS quickswitch limiter version.", FCVAR_DONTRECORD);

	// The time between shots without quickswapping is just under 1.4 seconds. I put the default at 1.38 because
	// I'd rather be on the conservative side. Subject to future tweaking.
	g_cvarSRSRof = CreateConVar("sm_srs_rof", "1.38",
		"Minimum delay between shots when quickswapping, in seconds.", _, true, 1.0, true, SRS_ROF_MAX);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			SDKHook(client, SDKHook_SpawnPost, OnClientSpawned_Post);
			SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch_Post);
		}
	}

	AddTempEntHook("Shotgun Shot", OnFireBullets);

	// Find all of the pre-existing SRS.
	char classname[11]; // weapon_srs\0
	for (int edict = NEO_MAX_CLIENTS + 1; edict <= GetMaxEntities(); edict++)
	{
		if (!IsValidEdict(edict) || !GetEdictClassname(edict, classname, sizeof(classname)))
		{
			continue;
		}
		if (StrEqual(classname, "weapon_srs"))
		{
			AddTrackedSRS(edict);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "weapon_srs"))
	{
		AddTrackedSRS(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	RemoveTrackedSRS(entity);
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
		SDKHook(client, SDKHook_SpawnPost, OnClientSpawned_Post);
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch_Post);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_SpawnPost, OnClientSpawned_Post);
		SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch_Post);
	}
}

public void OnClientSpawned_Post(int client)
{
	_flNextAttack[client] = 0.0;
}

bool IsSRS(int weapon)
{
	for (int i = 0; i < sizeof(_srs_edicts); ++i)
	{
		if (_srs_edicts[i] == weapon)
		{
			return true;
		}
	}

	return false;
}

public void OnWeaponSwitch_Post(int client, int weapon)
{
	if (!IsValidClient(client) || !IsValidEdict(weapon))
	{
		return;
	}

	if (!IsSRS(weapon)) {
		return;
	}

	// GetGameTime is accurate up to 0.1 seconds, so offsetting this check by that amount.
	if (_flNextAttack[client] - GetGameTime() > SRS_ROF_MAX + 0.1) {
		// If the diff is this big something weird is going on, better reset and return.
		_flNextAttack[client] = 0.0;
		return;
	}

	if (_flNextAttack[client] > GetNextAttack(client))
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

	SetEntDataFloat(client, ptrHandle, nextTime, true);
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

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client))
		return false;

	return true;
}

void AddTrackedSRS(int srs_edict)
{
	_srs_edicts[_srs_edicts_head] = srs_edict;
	_srs_edicts_head = (_srs_edicts_head + 1) % sizeof(_srs_edicts);
}

void RemoveTrackedSRS(int srs_edict)
{
	for (int i = 0; i < sizeof(_srs_edicts); ++i)
	{
		if (_srs_edicts[i] == srs_edict)
		{
			_srs_edicts[i] = 0;
			return;
		}
	}
}