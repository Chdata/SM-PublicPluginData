#pragma semicolon 1
#include <sourcemod>

enum MOTDFailureReason {
    MOTDFailure_Unknown, // Failure reason unknown
    MOTDFailure_Disabled, // Client has explicitly disabled HTML MOTDs
    MOTDFailure_Matchmaking, // HTML MOTD is disabled by Quickplay/matchmaking (TF2 only)
    MOTDFailure_QueryFailed // cl_disablehtmlmotd convar query failed
};

functag public MOTDFailure(client, MOTDFailureReason:reason);

#define MAX_STEAMAUTH_LENGTH 21 
#define MAX_COMMUNITYID_LENGTH 18 

#define PLUGIN_VERSION          "0x01"

#define FCVAR_VERSION           FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT

public Plugin:myinfo = {
    name = "Profile Data Viewer",
    author = "Chdata",
    description = "Find steamIDs with /id and see profiles with /profile",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/tf2data"
};

public OnPluginStart()
{
    CreateConVar("cv_profile_version", PLUGIN_VERSION, "Profile Check Version", FCVAR_VERSION);
    RegConsoleCmd("sm_profile", profile);
    RegAdminCmd("sm_steamid", steamid, ADMFLAG_BAN);
    RegAdminCmd("sm_id", steamid, ADMFLAG_BAN);
    LoadTranslations("common.phrases");
}

public Action:steamid(iClient, iArgc)
{
    if (!iArgc)
    {
        ReplyToCommand(iClient, "[SM] Usage: /steamid <#userid|playername>");
        return Plugin_Handled;
    }

    decl String:szArg[128];
    GetCmdArgString(szArg, sizeof(szArg));

    new iTarget = FindTarget(iClient, szArg, true, false);

    if (iTarget == -1)
    {
        return Plugin_Handled;
    }
    
    decl String:szSteamId2[MAX_STEAMAUTH_LENGTH];
    GetClientAuthId(iTarget, AuthId_Steam2, szSteamId2, sizeof(szSteamId2));

    decl String:szSteamId3[MAX_STEAMAUTH_LENGTH];
    GetClientAuthId(iTarget, AuthId_Steam3, szSteamId3, sizeof(szSteamId3));

    decl String:szSteamId4[MAX_STEAMAUTH_LENGTH];
    GetClientAuthId(iTarget, AuthId_SteamID64, szSteamId4, sizeof(szSteamId4));

    ReplyToCommand(iClient, "[SM] %N's SteamID: %s | %s | http://steamcommunity.com/profiles/%s", iTarget, szSteamId2, szSteamId3, szSteamId4);
    return Plugin_Handled;
}

public Action:profile(iClient, iArgc)
{
    if (!iArgc)
    {
        ReplyToCommand(iClient, "[SM] Usage: /profile <steamid|#userid|playername>");
        return Plugin_Handled;
    }

    decl String:szArg[128];
    GetCmdArgString(szArg, sizeof(szArg));
    TrimString(szArg);
    StripQuotes(szArg);

    if (IsValidSteamId(szArg))
    {
        DisplayProfileTo(iClient, szArg);
        return Plugin_Handled;
    }
    else if (IsValidSteamId(szArg, AuthId_Steam3))
    {
        steam2(szArg);
        DisplayProfileTo(iClient, szArg);
        return Plugin_Handled;
    }

    new iTarget = FindTarget(iClient, szArg, true, false);

    if (iTarget == -1)
    {
        return Plugin_Handled;
    }
    
    decl String:szSteamId[MAX_STEAMAUTH_LENGTH];
    GetClientAuthId(iTarget, AuthId_Steam2, szSteamId, sizeof(szSteamId));

    DisplayProfileTo(iClient, szSteamId);

    return Plugin_Handled;
}

stock DisplayProfileTo(iClient, const String:szSteamId2[])
{
    decl String:szLink[128];
    decl String:szCommunityID[MAX_COMMUNITYID_LENGTH];

    GetCommunityIDString(szSteamId2, szCommunityID, sizeof(szCommunityID)); 
    Format(szLink, sizeof(szLink), "http://steamcommunity.com/profiles/%s", szCommunityID);
    
    if (iClient)
    {
        //ShowMOTDPanel(iClient, "Steam Profile", szLink, MOTDPANEL_TYPE_URL);
        AdvMOTD_ShowMOTDPanel(iClient, "Steam Profile", szLink, MOTDPANEL_TYPE_URL, true, false, true, MOTDFailureCallback);
    }
    else
    {
        PrintToServer("%s", szLink);
    }
}

public MOTDFailureCallback(iClient, MOTDFailureReason:iReason)
{
    PrintToChat(iClient, "[SM] Cannot show profile, you have HTML motds disabled.");
}

stock bool:GetCommunityIDString(const String:SteamID[], String:CommunityID[], const CommunityIDSize) 
{ 
    decl String:SteamIDParts[3][11]; 
    new const String:Identifier[] = "76561197960265728"; 
     
    if ((CommunityIDSize < 1) || (ExplodeString(SteamID, ":", SteamIDParts, sizeof(SteamIDParts), sizeof(SteamIDParts[])) != 3)) 
    { 
        CommunityID[0] = '\0'; 
        return false; 
    } 

    new Current, CarryOver = (SteamIDParts[1][0] == '1'); 
    for (new i = (CommunityIDSize - 2), j = (strlen(SteamIDParts[2]) - 1), k = (strlen(Identifier) - 1); i >= 0; i--, j--, k--) 
    { 
        Current = (j >= 0 ? (2 * (SteamIDParts[2][j] - '0')) : 0) + CarryOver + (k >= 0 ? ((Identifier[k] - '0') * 1) : 0); 
        CarryOver = Current / 10; 
        CommunityID[i] = (Current % 10) + '0'; 
    } 

    CommunityID[CommunityIDSize - 1] = '\0'; 
    return true; 
}

/*
 Convert '[U:1:Z]'' where Z is (Y*2)+X
 To 'STEAM_0:X:Y'

*/
stock steam2(String:steam3[])
{
    new m_unAccountID = StringToInt(steam3[5]);
    new m_unMod = m_unAccountID % 2;
    Format(steam3, MAX_STEAMAUTH_LENGTH, "STEAM_0:%d:%d", m_unMod, (m_unAccountID-m_unMod)/2);
}

stock bool:IsValidSteamId(const String:szId[], AuthIdType:iAuthId = AuthId_Steam2)
{
    if (strlen(szId) > MAX_STEAMAUTH_LENGTH)
    {
        return false;
    }
    switch (iAuthId)
    {
        case AuthId_Steam2: return (StrContains(szId, "STEAM_0:") == 0);
        case AuthId_Steam3: return (StrContains(szId, "[U:1:") == 0);
    }
    return false;
}

// #include <advanced_motd>

/**
 * Displays an MOTD panel to a client with advanced options
 * 
 * @param client        Client index the panel should be shown to
 * @param title         Title of the MOTD panel (not displayed on all games)
 * @param msg           Content of the MOTD panel; could be a URL, plain text, or a stringtable index
 * @param type          Type of MOTD this is, one of MOTDPANEL_TYPE_TEXT, MOTDPANEL_TYPE_INDEX, MOTDPANEL_TYPE_URL, MOTDPANEL_TYPE_FILE
 * @param visible       Whether the panel should be shown to the client
 * @param big           true if this should be a big MOTD panel (TF2 only)
 * @param verify        true if we should check if the client can actually receive HTML MOTDs before sending it, false otherwise
 * @param callback      A callback to be called if we determine that the client can't receive HTML MOTDs
 * @noreturn
 */
stock AdvMOTD_ShowMOTDPanel(client, const String:title[], const String:msg[], type=MOTDPANEL_TYPE_INDEX, bool:visible=true, bool:big=false, bool:verify=false, MOTDFailure:callback=INVALID_FUNCTION) {
    decl String:connectmethod[32];
    if(verify && GetClientInfo(client, "cl_connectmethod", connectmethod, sizeof(connectmethod))) {
        if(StrContains(connectmethod, "quickplay", false) != -1 || StrContains(connectmethod, "matchmaking", false) != -1) {
            if(callback != INVALID_FUNCTION) {
                AdvMOTD_CallFailure(callback, client, MOTDFailure_Matchmaking);
            }
            return;
        }
    }
    
    new Handle:kv = CreateKeyValues("data");
    KvSetString(kv, "title", title);
    KvSetNum(kv, "type", type);
    KvSetString(kv, "msg", msg);
    if(big) {
        KvSetNum(kv, "customsvr", 1);
    }
    
    if(verify) {
        new Handle:pack = CreateDataPack();
        WritePackCell(pack, _:kv);
        WritePackCell(pack, _:visible);
        WritePackCell(pack, _:callback);
        QueryClientConVar(client, "cl_disablehtmlmotd", AdvMOTD_OnQueryFinished, pack);
    } else {
        ShowVGUIPanel(client, "info", kv);
        CloseHandle(kv);
    }
}

public AdvMOTD_OnQueryFinished(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[], any:pack) {
    ResetPack(pack);
    new Handle:kv = Handle:ReadPackCell(pack);
    new bool:visible = bool:ReadPackCell(pack);
    new MOTDFailure:callback = MOTDFailure:ReadPackCell(pack);
    CloseHandle(pack);
    
    if(result != ConVarQuery_Okay || bool:StringToInt(cvarValue)) {
        CloseHandle(kv);
        if(callback != INVALID_FUNCTION) {
            AdvMOTD_CallFailure(callback, client, (result != ConVarQuery_Okay) ? MOTDFailure_QueryFailed : MOTDFailure_Disabled);
        }
        return;
    }
    
    ShowVGUIPanel(client, "info", kv, visible);
    CloseHandle(kv);
}

AdvMOTD_CallFailure(MOTDFailure:callback, client, MOTDFailureReason:reason) {
    Call_StartFunction(INVALID_HANDLE, callback);
    Call_PushCell(client);
    Call_PushCell(reason);
    Call_Finish();
}
