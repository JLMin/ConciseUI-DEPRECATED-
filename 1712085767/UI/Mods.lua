-------------------------------------------------
-- Mods Browser Screen
-------------------------------------------------
include( "InstanceManager" );
include( "SupportFunctions" );
include( "PopupDialog" );
include( "CustomFolder" );

LOC_MODS_SEARCH_NAME = Locale.Lookup("LOC_MODS_SEARCH_NAME");

g_ModListingsManager = InstanceManager:new("ModInstance", "ModInstanceRoot", Controls.ModListingsStack);
g_SubscriptionsListingsManager = InstanceManager:new("SubscriptionInstance", "SubscriptionInstanceRoot", Controls.SubscriptionListingsStack);
g_DependencyListingsManager = InstanceManager:new("ReferenceItemInstance", "Item", Controls.ModDependencyItemsStack);


g_SearchContext = "Mods";
g_SearchQuery = nil;
g_ModListings = nil;			-- An array of pairs containing the mod handle and its associated listing.
g_SelectedModHandle = nil;		-- The currently selected mod entry.
g_CurrentListingsSort = nil;	-- The current method of sorting the mod listings.
g_ModSubscriptions = nil;
g_SubscriptionsSortingMap = {};

-- ===========================================================================
-- CUI Variables
-- ===========================================================================
local cui_FolderIM    = InstanceManager:new("FolderInstance", "Top", Controls.ModListingsStack);
local cui_NestedModIM = InstanceManager:new("NestedModInstance", "ModInstanceRoot", Controls.ModListingsStack);

local CuiModManager = {
  ModManagerID = "269337bd-75d8-409e-a055-7b70b6d4242e",
  ModManager   = {},

  ModInstalled = 0,
  ModEnabled   = 0,

  HasEnabled   = false,
  HasDisabled  = false,

  Folders = {},
  FolderOpenStates = {},

  NeedOrganize = true,
  OrganizeBy   = "",
  OrganizeFunc = nil,

  FullModList   = {},
  FullModIDList = {},

  CustomFolders = {};
};

local ProfileName = "eudaimonia";
local ConciseMods = "Concise UI";


-- ===========================================================================
-- CUI Folder Functions
-- ===========================================================================
------------------------------------------------------------------------------
function CuiResetManagerDate()
  CuiModManager.ModInstalled = 0;
  CuiModManager.ModEnabled   = 0;

  CuiModManager.HasEnabled   = false;
  CuiModManager.HasDisabled  = false;

  CuiModManager.Folders      = {};

  CuiModManager.NeedOrganize = true;
end

------------------------------------------------------------------------------
function CuiCreateFolder(name, mods)
  local folder = {
    Name     = "",
    Enabled  = 0,
    Total    = 0,
    Mods     = {}
  };

  local uniqueName = name;
  local dupNum = 2;
  while CuiIsFolderNameExists(uniqueName) do
    uniqueName = name .. " #" .. dupNum;
    dupNum = dupNum + 1;
  end
  folder.Name = uniqueName;

  for _, mod in ipairs(mods) do
    folder.Total = folder.Total + 1;
    if mod.Enabled then
      folder.Enabled = folder.Enabled + 1;
    end
  end

  folder.Mods = mods;

  table.insert(CuiModManager.Folders, folder);
end


-- ===========================================================================
-- CUI Populate Functions
-- ===========================================================================
------------------------------------------------------------------------------
function CuiPopulateMods(mods, modIM, folder)
  if CuiIsNil(mods) then return; end

  for i, mod in ipairs(mods) do
    local instance = modIM:GetInstance();

    local handle = mod.Handle;
    table.insert(g_ModListings, {handle, instance});

    instance.ModInstanceButton:RegisterCallback(Mouse.eLClick, function() CuiOnModLeftClick(mod);  end);
    instance.ModInstanceButton:RegisterCallback(Mouse.eRClick, function() CuiOnModRightClick(mod); end);
    instance.ModInstanceButton:RegisterCallback(Mouse.eMClick, function() CuiOnModMiddleClick(folder); end);

    local bIsModManager = mod.Id == CuiModManager.ModManagerID;
    local bOfficial     = mod.Official;
    local bIsMap        = mod.Source == "Map";
    local bIsEnabled    = mod.Enabled;

    local offsetTitle    = bOfficial and 23 or 15;
    local offsetSubTitle = 10;

    instance.ModTitle   :SetOffsetY( offsetTitle    );
    instance.ModSubTitle:SetOffsetY( offsetSubTitle );
    instance.ModSubTitle:SetHide( bOfficial );
    instance.ModSubTitle:SetText( "" );

    local name = CuiGetModName(mod);
    instance.ModTitle:LocalizeAndSetText(name);

    -- sub title
    if not bOfficial then
      local subTitle = "";
      -- steam mods
      if mod.SubscriptionId then
        local details = Modding.GetSubscriptionDetails(mod.SubscriptionId);
        if details and details.LastUpdated then
          subTitle = Locale.Lookup("LOC_MODS_LAST_UPDATED", details.LastUpdated);
        end
      -- maps
      elseif mod.Created then
        local createdDate = mod.Created;
        if createdDate then
          subTitle = Locale.Lookup("LOC_CUI_MM_MAP_CREATED", createdDate);
        end
      -- none steam mods
      else
        subTitle = Locale.Lookup("LOC_CUI_MM_NON_STEAM_MOD");
      end
      instance.ModSubTitle:SetText(subTitle);
    end

    local tooltip;
    if #mod.Teaser then tooltip = Locale.Lookup(mod.Teaser); end
    instance.ModInstanceButton:SetToolTipString(tooltip);

    local iconColor = bIsModManager and "Clear" or "White";
    instance.IconBacking:SetColorByName(iconColor);

    local buttonColor = bIsEnabled and "White" or "Gray_Black";
    instance.ModInstanceButton:SetColorByName(buttonColor);

    local enableText = bIsEnabled and "[ICON_CheckmarkBlue]" or "";
    instance.ModEnabled:SetText(enableText);

    -- mod code button, nested mods only
    if modIM == cui_NestedModIM then
      local showCode = mod.SubscriptionId ~= nil;
      instance.ModCodeButton:SetHide(not showCode);
      instance.ModCodeButton:RegisterCallback(Mouse.eLClick, function() CuiOnModCodeClick(mod); end);
    end

    -- mod icon, add a special icon for this mod
    instance.MapIcon      :SetHide(not bIsMap);
    instance.OfficialIcon :SetHide(bIsModManager or bIsMap or not bOfficial);
    instance.CommunityIcon:SetHide(bIsModManager or bIsMap or bOfficial);
    instance.GearIcon     :SetHide(not bIsModManager);

  end
end

------------------------------------------------------------------------------
function CuiPopulateFolders(folders, foderIM, modIM)
  if CuiIsNil(folders) then return; end

  for i, folder in ipairs(folders) do
    local mods = folder.Mods;
    if #mods > 0 then
      local name     = folder.Name;
      local enabled  = folder.Enabled;
      local total    = folder.Total;
      local isOpened = CuiIsFolderOpened(folder);

      local numIncompatible = CuiCountIncompatibleModsInFolder(folder);
      if numIncompatible > 0 then
        name = name .. " [COLOR_RED](" .. numIncompatible .. ")[ENDCOLOR]";
      end

      local instance = foderIM:GetInstance();

      instance.FolderInstanceButton:RegisterCallback(Mouse.eLClick, function() CuiOnFolderLeftClick(folder);  end);
      instance.FolderInstanceButton:RegisterCallback(Mouse.eRClick, function() CuiOnFolderRightClick(folder); end);

      instance.FolderName:SetText(name);
      instance.ClosedIcon:SetHide(isOpened);
      instance.OpenedIcon:SetHide(not isOpened);
      instance.ClosedArrow:SetHide(isOpened);
      instance.OpenedArrow:SetHide(not isOpened);
      instance.Content:SetText(Locale.Lookup("LOC_CUI_MM_MODS_CONTAINS", total, enabled));

      local color = enabled == 0 and "Gray_Black" or "White";
      instance.FolderInstanceButton:SetColorByName(color);

      if isOpened then CuiPopulateMods(mods, modIM, folder); end
    end
  end
end


-- ===========================================================================
-- CUI Event Functions
-- ===========================================================================
------------------------------------------------------------------------------
function CuiOnModLeftClick(mod)
  local handle = mod.Handle;
  if g_SelectedModHandle == handle then
    SelectMod(nil);
  else
    SelectMod(handle);
  end
end

------------------------------------------------------------------------------
function CuiOnModRightClick(mod)
  local handle = mod.Handle;

  if mod.Enabled then
    local err, xtra, sources = Modding.CanDisableMod(handle);
    if err == "OK" then
      Modding.DisableMod(handle);
      RefreshListings();
    end
  else
    local OnEnable = function()
      Modding.EnableMod(handle, true);
      RefreshListings();
    end

    if (Modding.ShouldShowCompatibilityWarnings() and
        not Modding.IsModCompatible(handle) and
        not Modding.GetIgnoreCompatibilityWarnings(handle)) then

        m_kPopupDialog:AddText(Locale.Lookup("LOC_MODS_ENABLE_WARNING_NOT_COMPATIBLE"));
        m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_MODS_TITLE")));
        m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES_BUTTON"), OnEnable, nil, nil, "PopupButtonInstanceGreen");
        m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO_BUTTON"), nil);
        m_kPopupDialog:Open();
    else
      OnEnable();
    end
  end
end

------------------------------------------------------------------------------
function CuiOnModMiddleClick(folder)
  if CuiIsNil(folder) then return; end

  CuiModManager.FolderOpenStates[folder.Name] = false;
  CuiModManager.NeedOrganize = false;
  local contains = CuiIsFolderContains(folder, g_SelectedModHandle);
  if contains then SelectMod(nil); end
  RefreshListings();
  CuiScrollToFolder(folder);
end

------------------------------------------------------------------------------
function CuiOnFolderLeftClick(folder)
  local isOpened = CuiIsFolderOpened(folder);
  if isOpened then
    local contains = CuiIsFolderContains(folder, g_SelectedModHandle);
    if contains then SelectMod(nil); end
  end
  CuiModManager.FolderOpenStates[folder.Name] = not isOpened;
  CuiModManager.NeedOrganize = false;
  RefreshListings();
  CuiScrollToFolder(folder);
end

------------------------------------------------------------------------------
function CuiOnFolderRightClick(folder)
  local isEnable = folder.Enabled < folder.Total;
  local action   = isEnable and "Enable" or "Disable";
  CuiActionOnAllModsInFolder(folder, action);
end

------------------------------------------------------------------------------
function CuiOnModCodeClick(mod)
  local modInfo = Modding.GetModInfo(mod.Handle);
  local modID   = modInfo.SubscriptionId;
  local modCode = "";

  if modID then
    local modName = Modding.GetSubscriptionDetails(modID).Name;
    modCode = "\"" .. modID .. "\"" .. ",  -- " .. modName;
  end

  if modCode ~= "" then
    Controls.ModCodeEditBox:SetText(modCode);
    Controls.ModCodeEditBox:TakeFocus();

    Controls.CuiModCodePopup:SetHide(false);
    Controls.CuiModCodePopupAlpha:SetToBeginning();
    Controls.CuiModCodePopupAlpha:Play();
    Controls.CuiModCodePopupSlide:SetToBeginning();
    Controls.CuiModCodePopupSlide:Play();
  end
end

------------------------------------------------------------------------------
function CuiOnUserGuideIconClick()
  local isHidden = Controls.ModDetailGrid:IsHidden();
  Controls.ModDetailGrid:SetHide(not isHidden);
  Controls.UserGuideGrid:SetHide(isHidden);
end

------------------------------------------------------------------------------
function CuiOnUserGuideButtonClick()
  Controls.ModDetailGrid:SetHide(false);
  Controls.UserGuideGrid:SetHide(true);
end


-- ===========================================================================
-- CUI Organize Functions
-- ===========================================================================
------------------------------------------------------------------------------
function CuiOrganizedBy(rule)
  if rule == nil then return; end

  if rule ~= CuiModManager.OrganizeBy then
    local organizeFuncs = {
      { "Enabled", CuiOrganizeByEnabled },
      { "Author",  CuiOrganizeByAuthor  },
      { "Update",  CuiOrganizeByUpdate  },
      { "Custom",  CuiOrganizeByCustom  },
    };

    for _, func in pairs(organizeFuncs) do
      local iconID = func[1] .. "Icon";
      local icon   = Controls[iconID];
      if func[1] == rule then
        icon:SetColorByName("White");
        CuiModManager.OrganizeBy   = func[1];
        CuiModManager.OrganizeFunc = func[2];
      else
        icon:SetColorByName("Gray");
      end
    end

    for name, _ in pairs(CuiModManager.FolderOpenStates) do
      CuiModManager.FolderOpenStates[name] = false;
    end
    SelectMod(nil);
    RefreshListings();
    Controls.ModListings:SetScrollValue(0);
  end
end

------------------------------------------------------------------------------
function CuiOrganizeMods(unorganizedMods)

  -- only refresh folders when a organize button was clicked
  if not CuiModManager.NeedOrganize then
    CuiModManager.NeedOrganize = true;
    return CuiModManager.ModManager;
  end

  local isFinalRelease = UI.IsFinalRelease();
  mods = {};

  CuiResetManagerDate();

  local officialMods = {};
  local mapMods      = {};
  local modManager   = {};
  local nonSteamMods = {};
  local otherMods    = {};

  for _, mod in ipairs(unorganizedMods) do
    -- Hide mods marked as always hidden or DLC which is not owned.
    local category = Modding.GetModProperty(mod.Handle, "ShowInBrowser");
    if (category ~= "AlwaysHidden" and not (isFinalRelease and mod.Allowance == false)) then

      local isModManager = mod.Id == CuiModManager.ModManagerID;
      local isOfficial   = mod.Official;
      local isMap        = mod.Source == "Map";
      local isEnabled    = mod.Enabled;
      local nonSteam     = CuiIsNonSteamMod(mod);

      -- mark enable & disable
      if not isModManager then
        if     isEnabled then CuiModManager.HasEnabled  = true; end
        if not isEnabled then CuiModManager.HasDisabled = true; end
      end

      -- count enable & disable
      if not mod.Official then
        CuiModManager.ModInstalled = CuiModManager.ModInstalled + 1;
        if isEnabled then
          CuiModManager.ModEnabled = CuiModManager.ModEnabled + 1;
        end
      end

      if     isOfficial   then table.insert(officialMods, mod);
      elseif isMap        then table.insert(mapMods,      mod);
      elseif isModManager then table.insert(modManager,   mod); CuiModManager.ModManager = modManager;
      elseif nonSteam     then table.insert(nonSteamMods, mod);
                          else table.insert(otherMods,    mod);
      end

    end
  end

  -- official mods
  if #officialMods > 0 then
    SortListingsByName(officialMods);
    CuiCreateFolder(Locale.Lookup("LOC_MODS_FIRAXIAN_CONTENT"), officialMods);
  end

  -- maps
  if #mapMods > 0 then
    SortListingsByName(mapMods);
    CuiCreateFolder(Locale.Lookup("LOC_MODS_WORLDBUILDER_CONTENT"), mapMods);
  end

  -- other mods
  CuiModManager.OrganizeFunc(otherMods);

  -- non-steam mods
  if #nonSteamMods > 0 then
    SortListingsByName(nonSteamMods);
    CuiCreateFolder(Locale.Lookup("LOC_CUI_MM_NON_STEAM_FOLDER"), nonSteamMods);
  end

  return modManager;
end

------------------------------------------------------------------------------
function CuiOrganizeByEnabled(unorganizedMods)
  local enabledMods  = {};
  local disabledMods = {};

  for _, mod in ipairs(unorganizedMods) do
    if mod.Enabled then table.insert(enabledMods,  mod);
                   else table.insert(disabledMods, mod);
    end
  end

  if #enabledMods > 0 then
    SortListingsByName(enabledMods);
    CuiCreateFolder(Locale.Lookup("LOC_MODS_ENABLED"), enabledMods);
  end

  if #disabledMods > 0 then
    SortListingsByName(disabledMods);
    CuiCreateFolder(Locale.Lookup("LOC_MODS_DISABLED"), disabledMods);
  end
end

------------------------------------------------------------------------------
function CuiOrganizeByAuthor(unorganizedMods)
  local authorList = {};

  for _, mod in ipairs(unorganizedMods) do
    local author = Modding.GetModProperty(mod.Handle, "Authors");
    if author and author ~= "" then author = Locale.Lookup(author);
                               else author = "Anonymous"; end
    if authorList[author] == nil then authorList[author] = {}; end
    table.insert(authorList[author], mod);
  end

  local cmpAuthor = function(t, a, b)
                      if a == ProfileName then return true;  end
                      if b == ProfileName then return false; end
                      return a > b;
                    end;

  local sortedAuthor = {};
  for author, mods in CuiSortedTable(authorList, cmpAuthor) do
    table.insert(sortedAuthor, {Name = author, Mods = mods});
  end

  -- add author folder only if his/her mods is more than 3
  local modsLeft = {};
  for _, author in ipairs(sortedAuthor) do
    if #author.Mods >= 3 then
      local folderName = "";
      if author.Name == ProfileName then
        folderName = ConciseMods;
      else
        folderName = Locale.Lookup("LOC_CUI_MM_MODS_BY", author.Name);
      end
      SortListingsByName(author.Mods);
      CuiCreateFolder(folderName, author.Mods);
    else
      for _, mod in ipairs(author.Mods) do
        table.insert(modsLeft, mod);
      end
    end
  end

  if #modsLeft > 0 then
    SortListingsByName(modsLeft);
    CuiCreateFolder(Locale.Lookup("LOC_GAMESUMMARY_CATEGORY_EXTRA"), modsLeft);
  end
end

------------------------------------------------------------------------------
function CuiOrganizeByUpdate(unorganizedMods)
  local localTime  = os.time();
  local day_time   = 24  * 3600;
  local month_time = 30  * day_time;
  local year_time  = 365 * day_time;

  local updateFolders = {
    { Name = "LOC_CUI_MM_UPDATED_WEEK",   Mods = {} },
    { Name = "LOC_CUI_MM_UPDATED_MONTH1", Mods = {} },
    { Name = "LOC_CUI_MM_UPDATED_MONTH3", Mods = {} },
    { Name = "LOC_CUI_MM_UPDATED_MONTH6", Mods = {} },
    { Name = "LOC_CUI_MM_UPDATED_MORE",   Mods = {} }
  }
  local modsLeft = {};

  for _, mod in ipairs(unorganizedMods) do
    local modTime = CuiGetModTime(mod);
    if modTime ~= nil then
      local  dTime = localTime - modTime;
      if     dTime < 7 * day_time   then table.insert(updateFolders[1].Mods, mod);
      elseif dTime <     month_time then table.insert(updateFolders[2].Mods, mod);
      elseif dTime < 3 * month_time then table.insert(updateFolders[3].Mods, mod);
      elseif dTime < 6 * month_time then table.insert(updateFolders[4].Mods, mod);
                                    else table.insert(updateFolders[5].Mods, mod); end
                                    else table.insert(modsLeft, mod);
    end
  end

  local cmpTime = function(a, b)
                    local aTime = CuiGetModTime(a);
                    local bTime = CuiGetModTime(b);
                    return aTime > bTime;
                  end;

  for _, folder in pairs(updateFolders) do
    local mods = folder.Mods;
    if #mods > 0 then
      table.sort(mods, cmpTime);
      CuiCreateFolder(Locale.Lookup(folder.Name), mods);
    end
  end

  if #modsLeft > 0 then
    table.sort(modsLeft, cmpTime);
    CuiCreateFolder(Locale.Lookup("LOC_GAMESUMMARY_CATEGORY_EXTRA"), modsLeft);
  end
end

------------------------------------------------------------------------------
function CuiOrganizeByCustom(unorganizedMods)

  CuiBuildFullModList(unorganizedMods);

  local cuiCustomFolders = CuiModManager.CustomFolders;
  if cuiCustomFolders and #cuiCustomFolders > 0 then
    for _, folder in ipairs(cuiCustomFolders) do
      local mods = {};
      for _, modID in pairs(folder.ModList) do
        local mod = CuiModManager.FullModList[modID];
        if mod ~= nil then
          table.insert(mods, mod);
          CuiModManager.FullModIDList[modID] = true;
        end
      end

      if #mods > 0 then
        CuiCreateFolder(folder.FolderName, mods);
      end
    end
  end

  local modsLeft = {};
  for modID, isAdded in pairs(CuiModManager.FullModIDList) do
    if not isAdded then
      local mod = CuiModManager.FullModList[modID];
      table.insert(modsLeft, mod);
    end
  end

  if #modsLeft > 0 then
    SortListingsByName(modsLeft);
    CuiCreateFolder(Locale.Lookup("LOC_GAMESUMMARY_CATEGORY_EXTRA"), modsLeft);
  end
end


-- ===========================================================================
-- CUI Config Functions
-- ===========================================================================
------------------------------------------------------------------------------
function CuiLoadConfigFile()
  local userFolders = CustomFolders and CustomFolders or C;
  if userFolders then
    for _, folder in pairs(userFolders) do
      local modList = folder.ModList;
      if modList then
        local folderName = folder.FolderName;
        if folderName == nil or folderName == "" then
          folderName = Locale.Lookup("LOC_CUI_MM_UNNAMED_FOLDER");
        end

        local customFolder = {
          FolderName = folderName;
          ModList    = modList;
        };
        table.insert(CuiModManager.CustomFolders, customFolder);
      end
    end
  end
end

------------------------------------------------------------------------------
function CuiBuildFullModList(mods)
  CuiModManager.FullModList   = {};
  CuiModManager.FullModIDList = {};

  if CuiIsNil(mods) then return; end

  for _, mod in ipairs(mods) do
    local modInfo = Modding.GetModInfo(mod.Handle);
    local modID   = modInfo.SubscriptionId;
    modID = modID or mod.Id;
    CuiModManager.FullModList[modID]   = mod;
    CuiModManager.FullModIDList[modID] = false;
  end
end


-- ===========================================================================
-- CUI Help Functions
-- ===========================================================================
------------------------------------------------------------------------------
function CuiGetModName(mod)
  mod.DisplayName         = Locale.Lookup(mod.Name);
  mod.StrippedDisplayName = Locale.StripTags(mod.DisplayName);

  local name = TruncateStringByLength(mod.DisplayName, 96);
  if not mod.Allowance then
    name = name .. " [COLOR_RED](" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")[ENDCOLOR]";
  end
  if Modding.ShouldShowCompatibilityWarnings() then
    if (not Modding.IsModCompatible(mod.Handle)) and (not Modding.GetIgnoreCompatibilityWarnings(mod.Handle)) then
      name = name .. " [COLOR_RED](" .. Locale.Lookup("LOC_MODS_DETAILS_COMPATIBLE_NOT") .. ")[ENDCOLOR]";
    end
  end
  if name == nil or name == "" then name = "Unnamed Mod"; end
  return name;
end

------------------------------------------------------------------------------
function CuiGetModTime(mod)
  local modTime = 0;
  if mod.SubscriptionId then
    modTime = Modding.GetSubscriptionDetails(mod.SubscriptionId).LastUpdated;
  elseif mod.Created then
    modTime = mod.Created;
  end
  return modTime;
end

------------------------------------------------------------------------------
function CuiIsFolderOpened(folder)
  local name = folder.Name;
  if CuiModManager.FolderOpenStates[name] == nil then
    CuiModManager.FolderOpenStates[name] = false;
    return false;
  else
    return CuiModManager.FolderOpenStates[name];
  end
end

------------------------------------------------------------------------------
function CuiIsFolderNameExists(name)
  for _, folder in ipairs(CuiModManager.Folders) do
    if folder.Name == name then return true; end
  end
  return false;
end

------------------------------------------------------------------------------
function CuiCountIncompatibleModsInFolder(folder)
  local numIncompatible = 0;
  if Modding.ShouldShowCompatibilityWarnings() then
    local mods = folder.Mods;
    for _, mod in ipairs(mods) do
      if (not Modding.IsModCompatible(mod.Handle)) and (not Modding.GetIgnoreCompatibilityWarnings(mod.Handle)) then
        numIncompatible = numIncompatible + 1;
      end
    end
  end
  return numIncompatible;
end

------------------------------------------------------------------------------
function CuiGetFolderDependencies(folder, action)
  local mods = folder.Mods;
  local dependencies = {};
  local dpdIndex = {};

  for _, mod in ipairs(mods) do

    local err, tagMods;
    if     action == "Enable"  then err,    tagMods = Modding.CanEnableMod(mod.Handle);
    elseif action == "Disable" then err, _, tagMods = Modding.CanDisableMod(mod.Handle);
    end

    if err == "MissingDependencies" then
      local containsAll, missingMods = CuiIsFolderContainsAll(folder, tagMods);
      if (not containsAll) and (#missingMods > 0) then
        for _, dependence in ipairs(missingMods) do
          if not dpdIndex[dependence.Id] then
            dpdIndex[dependence.Id] = true;
            table.insert(dependencies, dependence);
          end
        end
      end
    end
  end

  return dependencies;
end

------------------------------------------------------------------------------
function CuiIsFolderContains(folder, handle)
  if CuiIsNil(folder) then return true; end
  for _, mod in ipairs(folder.Mods) do
    if mod.Handle == handle then return true; end
  end
  return false;
end

------------------------------------------------------------------------------
function CuiIsFolderContainsAll(folder, tagMods)
  if CuiIsNil(tagMods) then return true, nil; end

  local srcMods     = folder.Mods;
  local modIndex    = {};
  local containsAll = true;
  local missingMods = {};

  for _, mod in ipairs(srcMods) do
    modIndex[mod.Id] = true;
  end

  for _, mod in ipairs(tagMods) do
    if not modIndex[mod.Id] then
      containsAll = false;
      table.insert(missingMods, mod);
    end
  end

  return containsAll, missingMods;
end

------------------------------------------------------------------------------
function CuiIsNonSteamMod(mod)
  if mod.Official       then return false; end
  if mod.Created        then return false; end
  if mod.SubscriptionId then return false; end
  return true;
end

------------------------------------------------------------------------------
function CuiSortedTable(t, f)
  local a = {};

  for n in pairs(t) do table.insert(a, n); end

  if f then table.sort(a, function(k1, k2) return f(t, k1, k2); end);
       else table.sort(a);
  end

  local i = 0;
  local iter =  function ()
                  i = i + 1;
                  if a[i] == nil then return nil;
                                 else return a[i], t[a[i]];
                  end
                end
  return iter;
end

------------------------------------------------------------------------------
function CuiIsNil(t)
  return t == nil or next(t) == nil;
end

------------------------------------------------------------------------------
function CuiFilterListings(mods)
  local isFinalRelease = UI.IsFinalRelease();

  local unorganizedMods = mods;
  mods = {};
  for i,v in ipairs(unorganizedMods) do
    -- Hide mods marked as always hidden or DLC which is not owned.
    local category = Modding.GetModProperty(v.Handle, "ShowInBrowser");
    if(category ~= "AlwaysHidden" and not (isFinalRelease and v.Allowance == false)) then
      table.insert(mods, v);
    end
  end

  return mods;
end

------------------------------------------------------------------------------
function CuiActionOnAllModsInFolder(folder, action)

  local isEnable;
  if action ~= "Enable" and action ~= "Disable" then return;
  else isEnable = action == "Enable";
  end

  local ActionFunc  = isEnable and EnableAllMods
                               or  DisableAllMods;
  local dialogTitle = isEnable and "LOC_CUI_MM_ENABLE_CONFIRM"
                               or  "LOC_CUI_MM_DISABLE_CONFIRM";
  local dialogText  = isEnable and "LOC_CUI_MM_ENABLE_DIALOG"
                               or  "LOC_CUI_MM_DISABLE_DIALOG";

  local folderMods   = folder.Mods;
  local dependencies = CuiGetFolderDependencies(folder, action);
  local listLength   = 11; -- 10 mods

  if #dependencies > 0 then
    local title = Locale.Lookup(dialogTitle);
    local text  = Locale.Lookup(dialogText, #dependencies) .. "[NEWLINE]";
    for i, mod in ipairs(dependencies) do
      if     i <  listLength then
        text = text .. "[NEWLINE]" .. CuiGetModName(mod);
      elseif i == listLength then
        text = text .. "[NEWLINE]" .. "...";
      else break; end
    end

    function ConfirmFunc()
      ActionFunc(dependencies);
      ActionFunc(folderMods);
    end

    CuiOnDialogPopup(title, text, ConfirmFunc);
  else
    ActionFunc(folderMods);
  end
end

------------------------------------------------------------------------------
function CuiOnDialogPopup(title, text, yesCallback)
  m_kPopupDialog:AddTitle(Locale.ToUpper(title));
  m_kPopupDialog:AddText(text);
  m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES_BUTTON"), yesCallback, nil, nil, "PopupButtonInstanceGreen");
  m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO_BUTTON"),  nil);
  m_kPopupDialog:Open();
end

------------------------------------------------------------------------------
function CuiScrollToFolder(target)
  local totalRow  = 0;
  local targetRow = 0;
  for _, folder in ipairs(CuiModManager.Folders) do
    totalRow = totalRow + 1;
    if folder.Name == target.Name then
      targetRow = totalRow;
    end
    if CuiIsFolderOpened(folder) then
      totalRow = totalRow + #folder.Mods;
    end
  end
  totalRow = totalRow + 1; -- mod manager

  local pos = 0;
  if totalRow > 8 then
    local above = targetRow - 1;
    local below = totalRow - targetRow - 7;
    if below <= 0 then pos = 1;
                  else pos = above / (above + below);
    end
  end
  Controls.ModListings:SetScrollValue(pos);
end


-- ===========================================================================
-- CUI Init
-- ===========================================================================
------------------------------------------------------------------------------
function CuiInit()
  CuiLoadConfigFile();
  --
  CuiOrganizedBy("Enabled");
  Controls.EnabledButton:RegisterCallback(Mouse.eLClick, function() CuiOrganizedBy("Enabled"); end);
  Controls.AuthorButton :RegisterCallback(Mouse.eLClick, function() CuiOrganizedBy("Author");  end);
  Controls.DateButton   :RegisterCallback(Mouse.eLClick, function() CuiOrganizedBy("Update");  end);
  Controls.CustomButton :RegisterCallback(Mouse.eLClick, function() CuiOrganizedBy("Custom");  end);
  --
  local userGuide = "[Concise Mod Manager] " .. Locale.Lookup("LOC_CUI_MM_USER_GUIDE");
  Controls.UserGuideButton:SetToolTipString(userGuide);
  Controls.UserGuideButton:RegisterCallback(Mouse.eLClick, CuiOnUserGuideIconClick);
  Controls.CloseUserGuideButton:RegisterCallback(Mouse.eLClick, CuiOnUserGuideButtonClick);
  --
  Controls.ModCodeCloseButton:RegisterCallback(Mouse.eLClick, function()
    Controls.CuiModCodePopup:SetHide(true);
  end);
end


-- ===========================================================================
-- CUI Funcitons End
-- ===========================================================================


---------------------------------------------------------------------------
function RefreshModGroups()
  local groups = Modding.GetModGroups();
  for i, v in ipairs(groups) do
    v.DisplayName = Locale.Lookup(v.Name);
  end
  table.sort(groups, function(a,b)
    if(a.SortIndex == b.SortIndex) then
      -- Sort by Name.
      return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
    else
      return a.SortIndex < b.SortIndex;
    end
  end);

  local g = Modding.GetCurrentModGroup();

  local comboBox = Controls.ModGroupPullDown;
  comboBox:ClearEntries();
  for i, v in ipairs(groups) do
    local controlTable = {};
    comboBox:BuildEntry( "InstanceOne", controlTable );
    controlTable.Button:LocalizeAndSetText(v.Name);

    controlTable.Button:RegisterCallback(Mouse.eLClick, function()
      Modding.SetCurrentModGroup(v.Handle);
      RefreshModGroups();
      RefreshListings();
    end);

    if(v.Handle == g) then
      comboBox:GetButton():SetText(v.DisplayName);
      Controls.DeleteModGroup:SetDisabled(not v.CanDelete);
    end
  end

  comboBox:CalculateInternals();
end
---------------------------------------------------------------------------
---------------------------------------------------------------------------
function RefreshListings()
  local mods = Modding.GetInstalledMods();

  g_ModListings = {};
  g_ModListingsManager:ResetInstances();

  cui_FolderIM:ResetInstances(); -- CUI, folders
  cui_NestedModIM:ResetInstances(); -- CUI, nested mods

  Controls.EnableAll:SetDisabled(true);
  Controls.DisableAll:SetDisabled(true);

  if(mods == nil or #mods == 0) then
    Controls.ModListings:SetHide(true);
    Controls.NoModsInstalled:SetHide(false);
    Controls.ModsInstalled:SetHide(true); -- CUI
  else
    Controls.ModListings:SetHide(false);
    Controls.NoModsInstalled:SetHide(true);
    Controls.ModsInstalled:SetHide(false); -- CUI

    PreprocessListings(mods);

    -- CUI, use organize functions instead
    -- mods = FilterListings(mods);
    mods = CuiOrganizeMods(mods);

    -- CUI, mod installed and enabled
    local modEnalbed    = CuiModManager.ModEnabled;
    local modInstalled  = CuiModManager.ModInstalled;
    local installedInfo = Locale.Lookup("LOC_MODS_USER_CONTENT") .. "  (" .. modEnalbed .. "/" .. modInstalled .. ")"
    Controls.ModsInstalled:SetText(installedInfo);

    -- CUI: there will be only this mod left at this point, no need to sort
    -- SortListings(mods);

    -- CUI, use populate functions instead
    CuiPopulateFolders(CuiModManager.Folders, cui_FolderIM, cui_NestedModIM);
    CuiPopulateMods(mods, g_ModListingsManager, nil);

    if CuiModManager.HasEnabled then
      Controls.DisableAll:SetDisabled(false);
    end

    if CuiModManager.HasDisabled then
      Controls.EnableAll:SetDisabled(false);
    end

    Controls.ModListingsStack:CalculateSize();
    Controls.ModListingsStack:ReprocessAnchoring();
    Controls.ModListings:CalculateInternalSize();
  end

  -- Update the selection state of each listing.
  RefreshListingsSelectionState();
  RefreshModDetails();
end

---------------------------------------------------------------------------
-- Pre-process listings by translating strings or stripping tags.
---------------------------------------------------------------------------
function PreprocessListings(mods)
  for i,v in ipairs(mods) do
    v.DisplayName = Locale.Lookup(v.Name);
    v.StrippedDisplayName = Locale.StripTags(v.DisplayName);
  end
end

---------------------------------------------------------------------------
-- Filter the listings, returns filtered list.
---------------------------------------------------------------------------
function FilterListings(mods)

  local isFinalRelease = UI.IsFinalRelease();
  local showOfficialContent = Controls.ShowOfficialContent:IsChecked();
  local showCommunityContent = Controls.ShowCommunityContent:IsChecked();

  local original = mods;
  mods = {};
  for i,v in ipairs(original) do
    -- Hide mods marked as always hidden or DLC which is not owned.
    local category = Modding.GetModProperty(v.Handle, "ShowInBrowser");
    if(category ~= "AlwaysHidden" and not (isFinalRelease and v.Allowance == false)) then
      -- Filter by selected options (currently only official and community content).
      if(v.Official and showOfficialContent) then
        table.insert(mods, v);
      elseif(not v.Official and showCommunityContent) then
        table.insert(mods, v);
      end
    end
  end

  -- Index remaining mods and filter by search query.
  if(Search.HasContext(g_SearchContext)) then
    Search.ClearData(g_SearchContext);
    for i, v in ipairs(mods) do
      Search.AddData(g_SearchContext, v.Handle, v.DisplayName, Locale.Lookup(v.Teaser or ""));
    end
    Search.Optimize(g_SearchContext);

    if(g_SearchQuery) then
      if (g_SearchQuery ~= nil and #g_SearchQuery > 0 and g_SearchQuery ~= LOC_MODS_SEARCH_NAME) then
        local include_map = {};
        local search_results = Search.Search(g_SearchContext, g_SearchQuery);
        if (search_results and #search_results > 0) then
          for i, v in ipairs(search_results) do
            include_map[tonumber(v[1])] = v[2];
          end
        end

        local original = mods;
        mods = {};
        for i,v in ipairs(original) do
          if(include_map[v.Handle]) then
            v.DisplayName = include_map[v.Handle];
            v.StrippedDisplayName = Locale.StripTags(v.DisplayName);
            table.insert(mods, v);
          end
        end
      end
    end
  end

  return mods;
end

---------------------------------------------------------------------------
-- Sort the listings in-place.
---------------------------------------------------------------------------
function SortListings(mods)
  if(g_CurrentListingsSort) then
    g_CurrentListingsSort(mods);
  end
end

-- Update the state of each instanced listing to reflect whether it is selected.
function RefreshListingsSelectionState()

  -- CUI, this function has been called once before this table gets any data
  if CuiIsNil(g_ModListings) then return; end

  for i,v in ipairs(g_ModListings) do
    if(v[1] == g_SelectedModHandle) then
      v[2].ModInstanceButton:SetSelected(true);
    else
      v[2].ModInstanceButton:SetSelected(false);
    end
  end
end

function RefreshModDetails()
  if(g_SelectedModHandle == nil) then
    -- Hide details and offer up a guidance string.
    Controls.NoModSelected:SetHide(false);
    Controls.ModDetailsContainer:SetHide(true);

  else
    Controls.NoModSelected:SetHide(true);
    Controls.ModDetailsContainer:SetHide(false);

    local modHandle = g_SelectedModHandle;
    local info = Modding.GetModInfo(modHandle);

    local bIsMap = info.Source == "Map";

    if(bIsMap) then
      Controls.ModContent:LocalizeAndSetText("LOC_MODS_WORLDBUILDER_CONTENT");
    elseif(info.Official) then
      Controls.ModContent:LocalizeAndSetText("LOC_MODS_FIRAXIAN_CONTENT");
    else
      Controls.ModContent:LocalizeAndSetText("LOC_MODS_USER_CONTENT");
    end

    local compatible = Modding.IsModCompatible(modHandle);
    Controls.ModCompatibilityWarning:SetHide(compatible);
    Controls.WhitelistMod:SetHide(compatible);

    if(not compatible) then
      Controls.WhitelistMod:SetCheck(Modding.GetIgnoreCompatibilityWarnings(modHandle));
      Controls.WhitelistMod:RegisterCallback(Mouse.eLClick, function()
        Modding.SetIgnoreCompatibilityWarnings(modHandle, Controls.WhitelistMod:IsChecked());
        RefreshListings();
      end);
    end

    -- Official/Community Icons
    local bIsOfficial = info.Official;
    local bIsMap = info.Source == "Map";
    Controls.MapIcon:SetHide(not bIsMap);
    Controls.OfficialIcon:SetHide(bIsMap or not bIsOfficial);
    Controls.CommunityIcon:SetHide(bIsMap or bIsOfficial);

    local enableButton = Controls.EnableButton;
    local disableButton = Controls.DisableButton;
    if(info.Official and info.Allowance == false) then
      enableButton:SetHide(true);
      disableButton:SetHide(true);
    else
      local enabled = info.Enabled;
      if(enabled) then
        enableButton:SetHide(true);
        disableButton:SetHide(false);

        local err, xtra, sources = Modding.CanDisableMod(modHandle);
        if(err == "OK") then
          disableButton:SetDisabled(false);
          disableButton:SetToolTipString(nil);

          disableButton:RegisterCallback(Mouse.eLClick, function()
            Modding.DisableMod(modHandle);
            RefreshListings();
          end);
        else
          disableButton:SetDisabled(true);

          -- Generate tip w/ list of mods to enable.
          local error_suffix;

          local tip = {};
          local items = xtra or {};

          if(err == "OwnershipRequired") then
            error_suffix = "(" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")";
          end

          if(err == "MissingDependencies") then
            tip[1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR_DEPENDS");
            items = sources or {}; -- show sources of errors rather than targets of error.
          else
            tip[1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR") .. err;
          end

          for k,ref in ipairs(items) do
            local item = "[ICON_BULLET] " .. Locale.Lookup(ref.Name);
            if(error_suffix) then
              item = item .. " " .. error_suffix;
            end

            table.insert(tip, item);
          end

          disableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"));
        end
      else
        enableButton:SetHide(false);
        disableButton:SetHide(true);
        local err, xtra = Modding.CanEnableMod(modHandle);
        if(err == "MissingDependencies") then
          -- Don't replace xtra since we want the old list to enumerate missing mods.
          err, _ = Modding.CanEnableMod(modHandle, true);
        end

        if(err == "OK") then
          enableButton:SetDisabled(false);

          if(xtra and #xtra > 0) then
            -- Generate tip w/ list of mods to enable.
            local tip = {Locale.Lookup("LOC_MODS_ENABLE_INCLUDE")};
            for k,ref in ipairs(xtra) do
              table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
            end

            enableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"));
          else
            enableButton:SetToolTipString(nil);
          end

          local OnEnable = function()
            Modding.EnableMod(modHandle, true);
            RefreshListings();
          end

          if(	Modding.ShouldShowCompatibilityWarnings() and
            not Modding.IsModCompatible(modHandle) and
            not Modding.GetIgnoreCompatibilityWarnings(modHandle)) then

            enableButton:RegisterCallback(Mouse.eLClick, function()
              m_kPopupDialog:AddText(Locale.Lookup("LOC_MODS_ENABLE_WARNING_NOT_COMPATIBLE"));
              m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_MODS_TITLE")));
              m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES_BUTTON"), OnEnable, nil, nil, "PopupButtonInstanceGreen");
              m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO_BUTTON"), nil);
              m_kPopupDialog:Open();
            end);

          else
            enableButton:RegisterCallback(Mouse.eLClick, OnEnable);
          end
        else
          enableButton:SetDisabled(true);

          if(err == "ContainsDuplicates") then
            enableButton:SetToolTipString(Locale.Lookup("LOC_MODS_ERROR_MOD_VERSION_ALREADY_ENABLED"));
          else
            -- Generate tip w/ list of mods to enable.
            local error_suffix;

            if(err == "OwnershipRequired") then
              error_suffix = "(" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")";
            end

            local tip = {Locale.Lookup("LOC_MODS_ENABLE_ERROR")};
            for k,ref in ipairs(xtra) do
              local item = "[ICON_BULLET] " .. Locale.Lookup(ref.Name);
              if(error_suffix) then
                item = item .. " " .. error_suffix;
              end

              table.insert(tip, item);
            end

            enableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"));
          end

        end
      end
    end

    Controls.ModTitle:LocalizeAndSetText(info.Name, 64);
    Controls.ModIdVersion:SetText(info.Id);

    local desc = Modding.GetModProperty(g_SelectedModHandle, "Description") or info.Teaser;
    if(desc) then
      desc = Modding.GetModText(g_SelectedModHandle, desc) or desc
      Controls.ModDescription:LocalizeAndSetText(desc);
      Controls.ModDescription:SetHide(false);
    else
      Controls.ModDescription:SetHide(true);
    end

    local authors = Modding.GetModProperty(g_SelectedModHandle, "Authors");
    if(authors) then
      authors = Modding.GetModText(g_SelectedModHandle, authors) or authors
      Controls.ModAuthorsValue:LocalizeAndSetText(authors);

      local width, height = Controls.ModAuthorsValue:GetSizeVal();
      Controls.ModAuthorsCaption:SetSizeY(height);
      Controls.ModAuthorsCaption:SetHide(false);
      Controls.ModAuthorsValue:SetHide(false);
    else
      Controls.ModAuthorsCaption:SetHide(true);
      Controls.ModAuthorsValue:SetHide(true);
    end

    local specialThanks = Modding.GetModProperty(g_SelectedModHandle, "SpecialThanks");
    if(specialThanks) then
      specialThanks = Modding.GetModText(g_SelectedModHandle, specialThanks) or specialThanks
      Controls.ModSpecialThanksValue:LocalizeAndSetText(specialThanks);

      local width, height = Controls.ModSpecialThanksValue:GetSizeVal();
      Controls.ModSpecialThanksCaption:SetSizeY(height);
      Controls.ModSpecialThanksValue:SetHide(false);
      Controls.ModSpecialThanksCaption:SetHide(false);

    else
      Controls.ModSpecialThanksCaption:SetHide(true);
      Controls.ModSpecialThanksValue:SetHide(true);
    end

    local created = info.Created;
    if(created) then
      Controls.ModCreatedValue:LocalizeAndSetText("{1_Created : date long}", created);
      Controls.ModCreatedCaption:SetHide(false);
      Controls.ModCreatedValue:SetHide(false);
    else
      Controls.ModCreatedCaption:SetHide(true);
      Controls.ModCreatedValue:SetHide(true);
    end

    if(info.Official and info.Allowance ~= nil) then

      Controls.ModOwnershipCaption:SetHide(false);
      Controls.ModOwnershipValue:SetHide(false);
      if(info.Allowance) then
        Controls.ModOwnershipValue:SetText("[COLOR_GREEN]" .. Locale.Lookup("LOC_MODS_YES") .. "[ENDCOLOR]");
      else
        Controls.ModOwnershipValue:SetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]");
      end
    else
      Controls.ModOwnershipCaption:SetHide(true);
      Controls.ModOwnershipValue:SetHide(true);
    end

    local affectsSavedGames = Modding.GetModProperty(g_SelectedModHandle, "AffectsSavedGames");
    if(affectsSavedGames and tonumber(affectsSavedGames) == 0) then
      Controls.ModAffectsSavedGamesValue:LocalizeAndSetText("LOC_MODS_NO");
    else
      Controls.ModAffectsSavedGamesValue:LocalizeAndSetText("LOC_MODS_YES");
    end

    local supportsSinglePlayer = Modding.GetModProperty(g_SelectedModHandle, "SupportsSinglePlayer");
    if(supportsSinglePlayer and tonumber(supportsSinglePlayer) == 0) then
      Controls.ModSupportsSinglePlayerValue:LocalizeAndSetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]");
    else
      Controls.ModSupportsSinglePlayerValue:LocalizeAndSetText("LOC_MODS_YES");
    end

    local supportsMultiplayer = Modding.GetModProperty(g_SelectedModHandle, "SupportsMultiplayer");
    if(supportsMultiplayer and tonumber(supportsMultiplayer) == 0) then
      Controls.ModSupportsMultiplayerValue:LocalizeAndSetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]");
    else
      Controls.ModSupportsMultiplayerValue:LocalizeAndSetText("LOC_MODS_YES");
    end

    local dependencies, references, blocks = Modding.GetModAssociations(g_SelectedModHandle);



    g_DependencyListingsManager:ResetInstances();
    if(dependencies) then
      local dependencyStrings = {}
      for i,v in ipairs(dependencies) do
        dependencyStrings[i] = Locale.Lookup(v.Name);
      end
      table.sort(dependencyStrings, function(a,b) return Locale.Compare(a,b) == -1 end);

      for i,v in ipairs(dependencyStrings) do
        local instance = g_DependencyListingsManager:GetInstance();
        instance.Item:SetText( "[ICON_BULLET] " .. v);
      end
    end
    Controls.ModDependenciesStack:SetHide(dependencies == nil or #dependencies == 0);


    Controls.ModDependencyItemsStack:CalculateSize();
    Controls.ModDependencyItemsStack:ReprocessAnchoring();
    Controls.ModDependenciesStack:CalculateSize();
    Controls.ModDependenciesStack:ReprocessAnchoring();
    Controls.ModPropertiesValuesStack:CalculateSize();
    Controls.ModPropertiesValuesStack:ReprocessAnchoring();
    Controls.ModPropertiesCaptionStack:CalculateSize();
    Controls.ModPropertiesCaptionStack:ReprocessAnchoring();
    Controls.ModPropertiesStack:CalculateSize();
    Controls.ModPropertiesStack:ReprocessAnchoring();
    Controls.ModDetailsStack:CalculateSize();
    Controls.ModDetailsStack:ReprocessAnchoring();
    Controls.ModDetailsScrollPanel:CalculateInternalSize();
  end
end

-- Select a specific entry in the listings.
function SelectMod(handle)
  g_SelectedModHandle = handle;
  RefreshListingsSelectionState();
  RefreshModDetails();
end

function CreateModGroup()
  Controls.ModGroupEditBox:SetText("");
  Controls.CreateModGroupButton:SetDisabled(true);

  Controls.NameModGroupPopup:SetHide(false);
  Controls.NameModGroupPopupAlpha:SetToBeginning();
  Controls.NameModGroupPopupAlpha:Play();
  Controls.NameModGroupPopupSlide:SetToBeginning();
  Controls.NameModGroupPopupSlide:Play();

  Controls.ModGroupEditBox:TakeFocus();
end

function DeleteModGroup()
  local currentGroup = Modding.GetCurrentModGroup();
  local groups = Modding.GetModGroups();
  for i, v in ipairs(groups) do
    v.DisplayName = Locale.Lookup(v.Name);
  end

  table.sort(groups, function(a,b)
    if(a.SortIndex == b.SortIndex) then
      -- Sort by Name.
      return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
    else
      return a.SortIndex < b.SortIndex;
    end
  end);

  for i, v in ipairs(groups) do
    if(v.Handle ~= currentGroup) then
      Modding.SetCurrentModGroup(v.Handle);
      Modding.DeleteModGroup(currentGroup);
      break;
    end
  end

  RefreshModGroups();
  RefreshListings();
end

function EnableAllMods(mods)
  -- CUI, add param for enable specified mods
  if mods == nil then
    mods = Modding.GetInstalledMods();
    PreprocessListings(mods);
    mods = CuiFilterListings(mods); -- CUI
  end

  local modHandles = {};
  for i,v in ipairs(mods) do
    local err, _ =  Modding.CanEnableMod(v.Handle, true);
    if (err == "OK") then
      table.insert(modHandles, v.Handle);
    end
  end

  if(	Modding.ShouldShowCompatibilityWarnings()) then
    local whitelistMods = false;
    local incompatibleMods = {};
    for i,v in ipairs(modHandles) do
      if(	not Modding.IsModCompatible(v) and
        not Modding.GetIgnoreCompatibilityWarnings(v)) then
        table.insert(incompatibleMods, v);
      end
    end

    function OnYes()
      if(whitelistMods) then
        for i,v in ipairs(incompatibleMods) do
          Modding.SetIgnoreCompatibilityWarnings(v, true);
        end
      end

      Modding.EnableMod(modHandles, true); -- CUI, focus enable
      RefreshListings();
    end

    if(#incompatibleMods > 0) then
      m_kPopupDialog:AddText(Locale.Lookup("LOC_MODS_ENABLE_WARNING_NOT_COMPATIBLE_MANY"));
      m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_MODS_TITLE")));
      m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES_BUTTON"), OnYes, nil, nil, "PopupButtonInstanceGreen");
      m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO_BUTTON"), nil);
      m_kPopupDialog:AddCheckBox(Locale.Lookup("LOC_MODS_WARNING_WHITELIST_MANY"), false, function(checked) whitelistMods = checked; end);
      m_kPopupDialog:Open();
    else
      OnYes();
    end
  else
    Modding.EnableMod(modHandles, true); -- CUI, focus enable
    RefreshListings();
  end
end

function DisableAllMods(mods)
  -- CUI, add param for enable specified mods
  if mods == nil then
    mods = Modding.GetInstalledMods();
    PreprocessListings(mods);
    mods = CuiFilterListings(mods); -- CUI
  end

  local modHandles = {};
  for i,v in ipairs(mods) do
    -- CUI, this mod will not be disabled by "Disable All"
    if v.Id ~= CuiModManager.ModManagerID then
      modHandles[i] = v.Handle;
    end
  end
  Modding.DisableMod(modHandles);
  RefreshListings();
end

----------------------------------------------------------------
-- Subscriptions Tab
----------------------------------------------------------------
function RefreshSubscriptions()
  local subs = Modding.GetSubscriptions();

  g_Subscriptions = {};
  g_SubscriptionsSortingMap = {};
  g_SubscriptionsListingsManager:ResetInstances();

  Controls.NoSubscriptions:SetHide(#subs > 0);

  for i,v in ipairs(subs) do
    local instance = g_SubscriptionsListingsManager:GetInstance();
    table.insert(g_Subscriptions, {
      SubscriptionId = v,
      Instance = instance,
      NeedsRefresh = true
    });
  end
  UpdateSubscriptions()

  Controls.SubscriptionListingsStack:CalculateSize();
  Controls.SubscriptionListingsStack:ReprocessAnchoring();
  Controls.SubscriptionListings:CalculateInternalSize();
end
----------------------------------------------------------------
function RefreshSubscriptionItem(item)

  local needsRefresh = false;
  local instance = item.Instance;
  local subscriptionId = item.SubscriptionId;

  local details = Modding.GetSubscriptionDetails(subscriptionId);

  local name = details.Name;
  if(name == nil) then
    name = Locale.Lookup("LOC_MODS_SUBSCRIPTION_NAME_PENDING");
    needsRefresh = true;
  end

  instance.SubscriptionTitle:SetText(name);
  g_SubscriptionsSortingMap[tostring(instance.SubscriptionInstanceRoot)] = name;

  if(details.LastUpdated) then
    instance.LastUpdated:SetText(Locale.Lookup("LOC_MODS_LAST_UPDATED", details.LastUpdated));
  end

  instance.UnsubscribeButton:SetHide(true);

  local status = details.Status;
  instance.SubscriptionDownloadProgress:SetHide(status ~= "Downloading");
  if(status == "Downloading") then
    local downloaded, total = Modding.GetSubscriptionDownloadStatus(subscriptionId);

    if(total > 0) then
      local w = instance.SubscriptionInstanceRoot:GetSizeX();
      local pct = downloaded/total;

      instance.SubscriptionDownloadProgress:SetSizeX(math.floor(w * pct));
      instance.SubscriptionDownloadProgress:SetHide(false);
    else
      instance.SubscriptionDownloadProgress:SetHide(true);
    end

    instance.SubscriptionStatus:LocalizeAndSetText("LOC_MODS_SUBSCRIPTION_DOWNLOADING", downloaded, total);
  else
    local statusStrings = {
      ["Installed"] = "LOC_MODS_SUBSCRIPTION_DOWNLOAD_INSTALLED",
      ["DownloadPending"] = "LOC_MODS_SUBSCRIPTION_DOWNLOAD_PENDING",
      ["Subscribed"] = "LOC_MODS_SUBSCRIPTION_SUBSCRIBED"
    };
    instance.SubscriptionStatus:LocalizeAndSetText(statusStrings[status]);
  end

  if(Steam and Steam.IsOverlayEnabled and Steam.IsOverlayEnabled()) then
    instance.SubscriptionViewButton:SetHide(false);
    instance.SubscriptionViewButton:RegisterCallback(Mouse.eLClick, function()
      local url = "http://steamcommunity.com/sharedfiles/filedetails/?id=" .. subscriptionId;
      Steam.ActivateGameOverlayToUrl(url);
    end);
  else
    instance.SubscriptionViewButton:SetHide(true);
  end

  -- If we're downloading or about to download, keep refreshing the details.
  if(status == "Downloading" or status == "DownloadingPending") then
    needsRefresh = true;
    instance.SubscriptionUpdateButton:SetHide(true);
  else
    local needsUpdate = details.NeedsUpdate;
    if(needsUpdate) then
      instance.SubscriptionUpdateButton:SetHide(false);
      instance.SubscriptionUpdateButton:RegisterCallback(Mouse.eLClick, function()
        Modding.UpdateSubscription(subscriptionId);
        RefreshSubscriptions();
      end);
    else
      instance.SubscriptionUpdateButton:SetHide(true);
      instance.UnsubscribeButton:SetHide(false);
      instance.UnsubscribeButton:RegisterCallback(Mouse.eLClick, function()
        Modding.Unsubscribe(subscriptionId);
        instance.SubscriptionInstanceRoot:SetHide(true);
      end);
    end
  end


  instance.SubscriptionInstanceRoot:SetHide(false);
  item.NeedsRefresh = needsRefresh;
end
----------------------------------------------------------------
function SortSubscriptionListings(a,b)
  -- ForgUI requires a strict weak ordering sort.
  local ap = g_SubscriptionsSortingMap[tostring(a)];
  local bp = g_SubscriptionsSortingMap[tostring(b)];

  if(ap == nil and bp ~= nil) then
    return true;
  elseif(ap == nil and bp == nil) then
    return tostring(a) < tostring(b);
  elseif(ap ~= nil and bp == nil) then
    return false;
  else
    return Locale.Compare(ap, bp) == -1;
  end
end
----------------------------------------------------------------
function UpdateSubscriptions()
  local updated = false;
  if(g_Subscriptions) then
    for i, v in ipairs(g_Subscriptions) do
      if(v.NeedsRefresh) then
        RefreshSubscriptionItem(v);
        updated = true;
      end
    end
  end

  if(updated) then
    Controls.SubscriptionListingsStack:SortChildren(SortSubscriptionListings);
  end
end


----------------------------------------------------------------
-- Input Handler
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
  if uiMsg == KeyEvents.KeyUp then
    if wParam == Keys.VK_ESCAPE then
      if (Controls.NameModGroupPopup ~= nil and Controls.NameModGroupPopup:IsVisible()) then
        Controls.NameModGroupPopup:SetHide(true);

      -- CUI, mod code popup
      elseif (Controls.CuiModCodePopup ~= nil and Controls.CuiModCodePopup:IsVisible()) then
        Controls.CuiModCodePopup:SetHide(true);
      --

      else
        HandleExitRequest();
      end
      return true;
    end
  end
  return false;
end
ContextPtr:SetInputHandler( InputHandler );

----------------------------------------------------------------
function OnInstalledModsTabClick(bForce)
  if(Controls.InstalledTabPanel:IsHidden() or bForce) then
    Controls.SubscriptionsTabPanel:SetHide(true);
    Controls.InstalledTabPanel:SetHide(false);

    -- Clear search queries.
    g_SearchQuery = nil;
    g_SelectedModHandle = nil;

    -- CUI: disable search box
    -- Controls.SearchEditBox:SetText(LOC_MODS_SEARCH_NAME);
    RefreshModGroups();
    RefreshListings();
  end
end
----------------------------------------------------------------
function OnSubscriptionsTabClick()
  if(Controls.SubscriptionsTabPanel:IsHidden() or bForce) then
    Controls.InstalledTabPanel:SetHide(true);
    Controls.SubscriptionsTabPanel:SetHide(false);

    RefreshSubscriptions();
  end
end
----------------------------------------------------------------
function OnOpenWorkshop()
  if (Steam ~= nil) then
    Steam.ActivateGameOverlayToWorkshop();
  end
end

----------------------------------------------------------------
function OnWorldBuilder()
  local worldBuilderMenu = ContextPtr:LookUpControl("/FrontEnd/MainMenu/WorldBuilder");
  if (worldBuilderMenu ~= nil) then
    GameConfiguration.SetWorldBuilderEditor(true);
    UIManager:QueuePopup(worldBuilderMenu, PopupPriority.Current);
  end
end

----------------------------------------------------------------
function OnShow()
  OnInstalledModsTabClick(true);
  -- CUI, always show world build button
  -- if(GameConfiguration.IsAnyMultiplayer() or not UI.HasFeature("WorldBuilder")) then
  if(GameConfiguration.IsAnyMultiplayer()) then
    Controls.WorldBuilder:SetHide(true);
    Controls.BrowseWorkshop:SetHide(true);
  else
    Controls.WorldBuilder:SetHide(false);
    Controls.BrowseWorkshop:SetHide(false);
  end
end
----------------------------------------------------------------
function HandleExitRequest()
  GameConfiguration.UpdateEnabledMods();
  UIManager:DequeuePopup( ContextPtr );
end
----------------------------------------------------------------
function PostInit()
  if(not ContextPtr:IsHidden()) then
    OnShow();
  end
end

function OnUpdate(delta)
  -- Overkill..
  UpdateSubscriptions();
end
----------------------------------------------------------------
-- ===========================================================================
--	Handle Window Sizing
-- ===========================================================================
function Resize()
  local screenX, screenY:number = UIManager:GetScreenSizeVal();
  local hideLogo = true;
  if(screenY >= Controls.MainWindow:GetSizeY() + (Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY())*2) then
    hideLogo = false;
  end
  Controls.LogoContainer:SetHide(hideLogo);
  Controls.MainGrid:ReprocessAnchoring();
end

function OnSearchBarGainFocus()
  Controls.SearchEditBox:ClearString();
end

function OnSearchCharCallback()
  local str = Controls.SearchEditBox:GetText();
  if (str ~= nil and #str > 0 and str ~= LOC_MODS_SEARCH_NAME) then
    g_SearchQuery = str;
    RefreshListings();
  elseif(str == nil or #str == 0) then
    g_SearchQuery = nil;
    RefreshListings();
  end
end


---------------------------------------------------------------------------
-- Sort By Pulldown setup
-- Must exist below callback function names
---------------------------------------------------------------------------
function SortListingsByName(mods)
  -- Keep XP1 and XP2 at the top of the list, regardless of sort.
  local sortOverrides = {
    ["4873eb62-8ccc-4574-b784-dda455e74e68"] = -2,
    ["1B28771A-C749-434B-9053-D1380C553DE9"] = -1
  };

  table.sort(mods, function(a,b)
    local aSort = sortOverrides[a.Id] or 0;
    local bSort = sortOverrides[b.Id] or 0;

    if(aSort ~= bSort) then
      return aSort < bSort;
    else
      return Locale.Compare(a.StrippedDisplayName, b.StrippedDisplayName) == -1;
    end
  end);
end
---------------------------------------------------------------------------
function SortListingsByEnabled(mods)
  -- Keep XP1 and XP2 at the top of the list, regardless of sort.
  local sortOverrides = {
    ["4873eb62-8ccc-4574-b784-dda455e74e68"] = -2,
    ["1B28771A-C749-434B-9053-D1380C553DE9"] = -1
  };

  table.sort(mods, function(a,b)
    local aSort = sortOverrides[a.Id] or 0;
    local bSort = sortOverrides[b.Id] or 0;

    if(aSort ~= bSort) then
      return aSort < bSort;
    elseif(a.Enabled ~= b.Enabled) then
      return a.Enabled;
    else
      -- Sort by Name.
      return Locale.Compare(a.StrippedDisplayName, b.StrippedDisplayName) == -1;
    end
  end);
end
---------------------------------------------------------------------------
local g_SortListingsOptions = {
  {"LOC_MODS_SORTBY_NAME", SortListingsByName},
  {"LOC_MODS_SORTBY_ENABLED", SortListingsByEnabled},
};
---------------------------------------------------------------------------
function InitializeSortListingsPulldown()
  local sortByPulldown = Controls.SortListingsPullDown;
  sortByPulldown:ClearEntries();
  for i, v in ipairs(g_SortListingsOptions) do
    local controlTable = {};
    sortByPulldown:BuildEntry( "InstanceOne", controlTable );
    controlTable.Button:LocalizeAndSetText(v[1]);

    controlTable.Button:RegisterCallback(Mouse.eLClick, function()
      sortByPulldown:GetButton():LocalizeAndSetText( v[1] );
      g_CurrentListingsSort = v[2];
      RefreshListings();
    end);

  end
  sortByPulldown:CalculateInternals();

  sortByPulldown:GetButton():LocalizeAndSetText(g_SortListingsOptions[1][1]);
  g_CurrentListingsSort = g_SortListingsOptions[1][2];
end

function Initialize()
  m_kPopupDialog = PopupDialog:new( "Mods" );

  -- CUI
  Controls.EnableAll :RegisterCallback(Mouse.eLClick, function() EnableAllMods(nil);  end);
  Controls.DisableAll:RegisterCallback(Mouse.eLClick, function() DisableAllMods(nil); end);
  --

  Controls.CreateModGroup:RegisterCallback(Mouse.eLClick, CreateModGroup);
  Controls.DeleteModGroup:RegisterCallback(Mouse.eLClick, DeleteModGroup);

  if(not Search.CreateContext(g_SearchContext, "[COLOR_LIGHTBLUE]", "[ENDCOLOR]", "...")) then
    print("Failed to create mods browser search context!");
  end

  --[[ CUI: disable search box
  Controls.SearchEditBox:RegisterStringChangedCallback(OnSearchCharCallback);
  Controls.SearchEditBox:RegisterHasFocusCallback(OnSearchBarGainFocus);
  ]]

  local refreshListings = function() RefreshListings(); end;

  --[[ CUI: disable content checkbox
  Controls.ShowOfficialContent:RegisterCallback(Mouse.eLClick, refreshListings);
  Controls.ShowCommunityContent:RegisterCallback(Mouse.eLClick, refreshListings);
  ]]

  CuiInit(); -- CUI

  Controls.CancelBindingButton:RegisterCallback(Mouse.eLClick, function()
    Controls.NameModGroupPopup:SetHide(true);
  end);

  Controls.CreateModGroupButton:RegisterCallback(Mouse.eLCick, function()
    Controls.NameModGroupPopup:SetHide(true);
    local groupName = Controls.ModGroupEditBox:GetText();
    local currentGroup = Modding.GetCurrentModGroup();
    Modding.CreateModGroup(groupName, currentGroup);
    RefreshModGroups();
    RefreshListings();
  end);

  Controls.ModGroupEditBox:RegisterStringChangedCallback(function()
    local str = Controls.ModGroupEditBox:GetText();
    Controls.CreateModGroupButton:SetDisabled(str == nil or #str == 0);
  end);

  Controls.ModGroupEditBox:RegisterCommitCallback(function()
    local str = Controls.ModGroupEditBox:GetText();
    if(str and #str > 0) then
      Controls.NameModGroupPopup:SetHide(true);
      local currentGroup = Modding.GetCurrentModGroup();
      Modding.CreateModGroup(str, currentGroup);
      RefreshModGroups();
      RefreshListings();
    end
  end);

  if(Steam ~= nil and Steam.GetAppID() ~= 0) then
    Controls.SubscriptionsTab:RegisterCallback(Mouse.eLClick, function() OnSubscriptionsTabClick() end);
    Controls.SubscriptionsTab:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.SubscriptionsTab:SetHide(false);
  else
    Controls.SubscriptionsTab:SetHide(true);
  end

  local pFriends = Network.GetFriends();
  if(pFriends ~= nil and pFriends:IsOverlayEnabled()) then
    Controls.BrowseWorkshop:RegisterCallback( Mouse.eLClick, OnOpenWorkshop );
    Controls.BrowseWorkshop:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  else
    Controls.BrowseWorkshop:SetDisabled(true);
  end

  --[[ CUI: disable content checkbox / sort
  Controls.ShowOfficialContent:SetCheck(true);
  Controls.ShowCommunityContent:SetCheck(true);

  InitializeSortListingsPulldown();
  ]]

  Resize();
  Controls.InstalledTab:RegisterCallback(Mouse.eLClick, function() OnInstalledModsTabClick() end);
  Controls.InstalledTab:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
  Controls.CloseButton:RegisterCallback( Mouse.eLClick, HandleExitRequest );
  Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  Controls.WorldBuilder:RegisterCallback(Mouse.eLClick, OnWorldBuilder);
  Controls.WorldBuilder:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

  ContextPtr:SetShowHandler( OnShow );
  ContextPtr:SetUpdate(OnUpdate);
  ContextPtr:SetPostInit(PostInit);
end

Initialize();
