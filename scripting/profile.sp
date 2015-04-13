#pragma semicolon 1
#include <sourcemod>
#include <advanced_motd>

#define MAX_STEAMAUTH_LENGTH 21 
#define MAX_COMMUNITYID_LENGTH 18 

public OnPluginStart()
{
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
        AdvMOTD_ShowMOTDPanel(iClient, "Steam Profile", szLink, MOTDPANEL_TYPE_URL, true, true, true, MOTDFailureCallback);
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