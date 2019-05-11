-- Copyright 2017-2018, 2017 Firaxis Games
include("ReportScreen");
include("CuiHelper"); -- CUI

-- ===========================================================================
-- Override base game
function ViewCityStatusPage()

  ResetTabForNewPageContent();

  local instance:table = m_simpleIM:GetInstance();	
  instance.Top:DestroyAllChildren();
  
  local pHeaderInstance:table = {}
  ContextPtr:BuildInstanceForControl( "CityStatusHeaderInstance", pHeaderInstance, instance.Top ) ;	

  -- CUI: sort by city name
  for cityName, kCityData in CuiSortedTable(m_kCityData, function(t, a, b) return t[a].CityName < t[b].CityName; end) do

    local pCityInstance:table = {}
    ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, instance.Top ) ;

    -- CUI: city status	
    -- CUI: move to city
    pCityInstance.MoveToCityButton:SetVoid1(kCityData.City:GetID());
    pCityInstance.MoveToCityButton:RegisterCallback(Mouse.eLClick, CuiRealizeLookAtCity);
    
    -- religion
    local eCityReligion:number = kCityData.City:GetReligion():GetMajorityReligion();
    local eCityPantheon:number = kCityData.City:GetReligion():GetActivePantheon();

    if eCityReligion > 0 then
      local iconName:string = "ICON_" .. GameInfo.Religions[eCityReligion].ReligionType;
      local majorityReligionColor:number = UI.GetColorValue(GameInfo.Religions[eCityReligion].Color);
      if (majorityReligionColor ~= nil) then
        pCityInstance.ReligionIcon:SetColor(majorityReligionColor);
      end
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,22);
      if (textureOffsetX ~= nil) then
        pCityInstance.ReligionIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        pCityInstance.ReligionIcon:SetToolTipString(Game.GetReligion():GetName(eCityReligion));
      end
      pCityInstance.ReligionIcon:SetHide(false);

    elseif eCityPantheon >= 0 then
      local iconName:string = "ICON_" .. GameInfo.Religions[0].ReligionType;
      local majorityReligionColor:number = UI.GetColorValue(GameInfo.Religions.RELIGION_PANTHEON.Color);
      if (majorityReligionColor ~= nil) then
        pCityInstance.ReligionIcon:SetColor(majorityReligionColor);
      end
      local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,22);
      if (textureOffsetX ~= nil) then
        pCityInstance.ReligionIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
        pCityInstance.ReligionIcon:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_PANTHEON_TT", GameInfo.Beliefs[eCityPantheon].Name));
      end
      pCityInstance.ReligionIcon:SetHide(false);

    else
      pCityInstance.ReligionIcon:SetToolTipString("");
      pCityInstance.ReligionIcon:SetHide(true);
    end

    -- city name
    local sCityName = kCityData.City:IsCapital() and "[ICON_Capital]" or "";
    sCityName = sCityName .. Locale.Lookup(kCityData.CityName);
    TruncateStringWithTooltip(pCityInstance.CityName, 180, sCityName);

    -- governor
    local pAssignedGovernor = kCityData.City:GetAssignedGovernor();
    if pAssignedGovernor then
      local eGovernorType = pAssignedGovernor:GetType();
      local governorDefinition = GameInfo.Governors[eGovernorType];
      local governorMode = pAssignedGovernor:IsEstablished() and "_FILL" or "_SLOT";
      local governorIcon = "ICON_" .. governorDefinition.GovernorType .. governorMode;
      local governorName = pAssignedGovernor:GetName();
      pCityInstance.Governor:SetText("[" .. governorIcon .. "]");
      pCityInstance.Governor:SetToolTipString(Locale.Lookup(governorName));
    else
      pCityInstance.Governor:SetText("");
      pCityInstance.Governor:SetToolTipString("");
    end

    -- Loyalty
    local pCulturalIdentity = kCityData.City:GetCulturalIdentity();
    local currentLoyalty = Round(pCulturalIdentity:GetLoyalty(), 0);
    local loyaltyPerTurn:number = Round(pCulturalIdentity:GetLoyaltyPerTurn(), 0);
    local loyaltyFontIcon:string = loyaltyPerTurn >= 0 and "[ICON_PressureUp]" or "[ICON_PressureDown]";
    pCityInstance.Loyalty:SetText(loyaltyFontIcon .. " " .. currentLoyalty .. "(" .. CuiRedGreenNumber(loyaltyPerTurn) .. ")");

    -- population
    if kCityData.HousingMultiplier == 0 or kCityData.Occupied then
      pCityInstance.Population:SetText("[COLOR: 200,62,52,255]" .. tostring(kCityData.Population) .. "[ENDCOLOR]");
      pCityInstance.Population:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_HALTED"));
    elseif kCityData.HousingMultiplier <= 0.5 then
      local iPercent = (1 - kCityData.HousingMultiplier) * 100;
      pCityInstance.Population:SetText("[COLOR: 200,146,52,255]" .. tostring(kCityData.Population) .. "[ENDCOLOR]");
      pCityInstance.Population:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_SLOWED", iPercent));
    else
      pCityInstance.Population:SetText( tostring(kCityData.Population) );
      pCityInstance.Population:SetToolTipString(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_NORMAL"));
    end

    -- housing
    pCityInstance.Housing:SetText( CuiRedGreenNumber(kCityData.Housing - kCityData.Population) );

    -- amenities
    pCityInstance.Amenities:SetText( CuiRedGreenNumber(kCityData.AmenitiesNum - kCityData.AmenitiesRequiredNum) );

    -- defense
    pCityInstance.Defense:SetText( tostring(kCityData.Defense) );

    -- damage
    if kCityData.GarrisonUnitIcon then
      pCityInstance.GarrisonUnit:SetIcon( kCityData.GarrisonUnitIcon );
      pCityInstance.GarrisonUnit:SetToolTipString( kCityData.GarrisonUnitName );
    else
      pCityInstance.GarrisonUnit:SetIcon("");
      pCityInstance.GarrisonUnit:SetToolTipString("");
    end

    -- trade routes
    local sRoutes:string = #kCityData.OutgoingRoutes > 0 and tostring(#kCityData.OutgoingRoutes) or "-";
    pCityInstance.TradeRoutes:SetText( sRoutes );

    -- districts
    pCityInstance.Districts:SetText( GetDistrictsForCity(kCityData) );
  end

  Controls.Stack:CalculateSize();
  Controls.Scroll:CalculateSize();

  Controls.CollapseAll:SetHide(true);
  Controls.BottomYieldTotals:SetHide( true );
  Controls.BottomResourceTotals:SetHide( true );
  Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88);
end

-- ===========================================================================
function CuiRedGreenNumber(num)
  if num > 0 then
    return "[COLOR: 80,255,90,160]+" .. tostring(num) .. "[ENDCOLOR]";
  elseif num < 0 then
    return "[COLOR: 255,40,50,160]"  .. tostring(num) .. "[ENDCOLOR]";
  else
    -- return "[COLOR_White]"          .. tostring(num) .. "[ENDCOLOR]";
    return tostring(num);
  end
end