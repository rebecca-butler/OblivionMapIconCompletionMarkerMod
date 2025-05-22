-- This file is part of MapIconCompletionMarkerMod
local enums = {}

enums.ELegacyPlayerMenuPage = {
    Stats = 0,
    Inventory = 1,
    Magic = 2,
    Map = 3,
    Quest = 4,
    Codex = 5,
    Settings = 6,
    MAX = 7,
}

enums.ELegacyMapMenuPage = {
    LocalMap = 0,
    WorldMap = 1,
    ActiveQuest = 2,
    CurrentQuests = 3,
    CompletedQuests = 4,
    ELegacyMapMenuPage_MAX = 5,
};

enums.ELegacyMapMenuIcon = {
    Empty = 0,
    Camp = 1,
    Cave = 2,
    City = 3,
    ElvenRuin = 4,
    FortRuin = 5,
    Mine = 6,
    MountainPeak = 7,
    Tavern = 8,
    Settlement = 9,
    DaedricShrine = 10,
    OblivionGate = 11,
    Door = 12,
    Quest = 13,
    Player = 14,
    PlayerMarker = 15,
    All = 16,
};

enums.iconMaterialsOn = {
    [enums.ELegacyMapMenuIcon.Camp]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Camp.MIC_UI_MapIcon_Camp",
    [enums.ELegacyMapMenuIcon.Cave]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Cave.MIC_UI_MapIcon_Cave",
    [enums.ELegacyMapMenuIcon.City]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_City.MIC_UI_MapIcon_City",
    [enums.ELegacyMapMenuIcon.ElvenRuin]    = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Ruins.MIC_UI_MapIcon_Ruins",
    [enums.ELegacyMapMenuIcon.FortRuin]     = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Fort.MIC_UI_MapIcon_Fort",
    [enums.ELegacyMapMenuIcon.Mine]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Mines.MIC_UI_MapIcon_Mines",
    [enums.ELegacyMapMenuIcon.MountainPeak] = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Peaks.MIC_UI_MapIcon_Peaks",
    [enums.ELegacyMapMenuIcon.Tavern]       = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Inn.MIC_UI_MapIcon_Inn",
    [enums.ELegacyMapMenuIcon.Settlement]   = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Settlement.MIC_UI_MapIcon_Settlement",
    [enums.ELegacyMapMenuIcon.DaedricShrine]= "/Game/UI/Materials/Map/MIC_UI_MapIcon_Shrines.MIC_UI_MapIcon_Shrines",
    [enums.ELegacyMapMenuIcon.OblivionGate] = "/Game/UI/Materials/Map/MIC_UI_MapIcon_Gates.MIC_UI_MapIcon_Gates",
};

enums.iconMaterialsOff = {
    [enums.ELegacyMapMenuIcon.Camp]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_CampOff.MIC_UI_MapIcon_CampOff",
    [enums.ELegacyMapMenuIcon.Cave]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_CaveOff.MIC_UI_MapIcon_CaveOff",
    [enums.ELegacyMapMenuIcon.City]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_CityOff.MIC_UI_MapIcon_CityOff",
    [enums.ELegacyMapMenuIcon.ElvenRuin]    = "/Game/UI/Materials/Map/MIC_UI_MapIcon_RuinsOff.MIC_UI_MapIcon_RuinsOff",
    [enums.ELegacyMapMenuIcon.FortRuin]     = "/Game/UI/Materials/Map/MIC_UI_MapIcon_FortOff.MIC_UI_MapIcon_FortOff",
    [enums.ELegacyMapMenuIcon.Mine]         = "/Game/UI/Materials/Map/MIC_UI_MapIcon_MinesOff.MIC_UI_MapIcon_MinesOff",
    [enums.ELegacyMapMenuIcon.MountainPeak] = "/Game/UI/Materials/Map/MIC_UI_MapIcon_PeaksOff.MIC_UI_MapIcon_PeaksOff",
    [enums.ELegacyMapMenuIcon.Tavern]       = "/Game/UI/Materials/Map/MIC_UI_MapIcon_InnOff.MIC_UI_MapIcon_InnOff",
    [enums.ELegacyMapMenuIcon.Settlement]   = "/Game/UI/Materials/Map/MIC_UI_MapIcon_SettlementOff.MIC_UI_MapIcon_SettlementOff",
    [enums.ELegacyMapMenuIcon.DaedricShrine]= "/Game/UI/Materials/Map/MIC_UI_MapIcon_ShrinesOff.MIC_UI_MapIcon_ShrinesOff",
    [enums.ELegacyMapMenuIcon.OblivionGate] = "/Game/UI/Materials/Map/MIC_UI_MapIcon_GatesOff.MIC_UI_MapIcon_GatesOff",
};

return enums