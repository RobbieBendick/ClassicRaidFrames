local core                             = {};
RaidFrameTinker                        = AceLibrary("AceAddon-2.0"):new();
core.HealthBar_OnValueChanged          = HealthBar_OnValueChanged

core.UnitFrameHealthBar_OnValueChanged = UnitFrameHealthBar_OnValueChanged



function RaidFrameTinker:PrintMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function RaidFrameTinker:Variables()
    self.mouseoverunit                              = nil
    self.enabled                                    = false
    self.preparesort                                = false
    self.frames, self.visible, self.groupframes     = {}, {}, {}
    self.feign, self.unavail, self.res, self.hpaura = {}, {}, {}, {}


    self.TempTooltipDebuffs      = {}
    self.carrier                 = {}
    self.UnitSortOrder           = {}
    self.UnitFocusHPArray        = {}
    self.UnitFocusArray          = {}
    self.UnitRangeArray          = {}
    self.indicator               = {}
    self.debuff                  = {}
    self.targeting               = {}

    self.debuffColors            = {}
    self.debuffColors["Curse"]   = { ["r"] = 1,["g"] = 0,["b"] = 0.75,["a"] = 0.5,["priority"] = 4 }
    self.debuffColors["Magic"]   = { ["r"] = 1,["g"] = 0,["b"] = 0,["a"] = 0.5,["priority"] = 3 }
    self.debuffColors["Disease"] = { ["r"] = 1,["g"] = 1,["b"] = 0,["a"] = 0.5,["priority"] = 2 }
    self.debuffColors["Poison"]  = { ["r"] = 0,["g"] = 0.5,["b"] = 0,["a"] = 0.5,["priority"] = 1 }
    self.debuffColors["Blue"]    = { ["r"] = 0,["g"] = 0,["b"] = 1,["a"] = 1,["priority"] = 4 }
    self.debuffColors["Red"]     = { ["r"] = 1,["g"] = 0,["b"] = 0,["a"] = 1,["priority"] = 4 }

    self.RAID_CLASS_COLORS       = {
        ["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45, colorStr = "|cffabd473" },
        ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "|cff9482c9" },
        ["PRIEST"] = { r = 1.0, g = 1.0, b = 1.0, colorStr = "|cffffffff" },
        ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "|cfff58cba" },
        ["MAGE"] = { r = 0.41, g = 0.8, b = 0.94, colorStr = "|cff69ccf0" },
        ["ROGUE"] = { r = 1.0, g = 0.96, b = 0.41, colorStr = "|cfffff569" },
        ["DRUID"] = { r = 1.0, g = 0.49, b = 0.04, colorStr = "|cffff7d0a" },
        ["SHAMAN"] = { r = 0.0, g = 0.44, b = 0.87, colorStr = "|cff0070de" },
        ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "|cffc79c6e" },
    };

    self.cooldownSpells          = {}
end

function RaidFrameTinker:OnInitialize()
    self:Variables()

    self.master = CreateFrame("Frame", "RaidFrameTinker", UIParent)
    self.master:ClearAllPoints()
    self.master:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
    self.master:SetMovable(true)

    self.master:SetHeight(200);
    self.master:SetWidth(200);

    self.master:SetBackdropColor(0.5, 0.5, 0.5, 0.5)
    self.master:Show()

    self.tooltip = CreateFrame("GameTooltip", "sRaidFramesTooltip", WorldFrame, "GameTooltipTemplate")
    self.tooltip:SetOwner(WorldFrame, "ANCHOR_NONE");


    for i = 1, MAX_RAID_MEMBERS do
        self:CreateUnitFrame(i)
    end

    for i = 1, 9 do
        self:CreateGroupFrame(i)
    end

    self:PrintMessage("RaidFrameTinker loaded")
end

function myFunction()
    DEFAULT_CHAT_FRAME:AddMessage("Hello World!")
end

local interval = 1
local timeElapsed = 0

function onEvent()
    local unit = arg1;
    if string.sub(unit, 1, 4) ~= "raid" then
        return
    end

    local frame = getglobal("RaidFrameTinker_" .. string.sub(unit, 5, 5))
    frame.hpbar:SetValue(UnitHealth(unit) / UnitHealthMax(unit) * 100)

    DEFAULT_CHAT_FRAME:AddMessage("unit: " .. unit)
end

local f = CreateFrame("Frame")
f:RegisterEvent("UNIT_HEALTH")
f:SetScript("OnEvent", onEvent)




-- Define a function to update the raid members' health values
function RaidFrameTinker:UpdateRaidMemberHealth()
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitExists(unit) then
            self.raidMemberHealth[unit] = { current = UnitHealth(unit), max = UnitHealthMax(unit) }
        else
            self.raidMemberHealth[unit] = nil
        end
    end
end

-- Define a function to check for changes in raid member health values
function RaidFrameTinker:CheckRaidMemberHealth()
    for unit, health in pairs(self.raidMemberHealth) do
        local currentHealth = UnitHealth(unit)
        if currentHealth < health.current then
            -- The raid member has taken damage, update their health values
            self.raidMemberHealth[unit].current = currentHealth
            self.raidMemberHealth[unit].max = UnitHealthMax(unit)
        end
    end
end

function RaidFrameTinker:PLAYER_ENTERING_WORLD()
    if UnitInRaid("player") then
        self:JoinedRaid();
    end
end

function HealthBar_OnValueChanged(v)
    core.HealthBar_OnValueChanged(v)
    if this == PlayerFrameHealthBar or this == TargetFrameHealthBar then
        local r, g, b
        if UnitIsPlayer(this.unit) then
            local _, class = UnitClass(this.unit)
            local color = RAID_CLASS_COLORS[class]
            r, g, b = color.r, color.g, color.b;
        else
            r, g, b = TargetFrameNameBackground:GetVertexColor();
        end
        this:SetStatusBarColor(r, g, b);
    end
end

function UnitFrameHealthBar_OnValueChanged(v)
    core.UnitFrameHealthBar_OnValueChanged(v)
end

function RaidFrameTinker:UpdateAllUnits()
    self:UpdateUnit(self.frames)
end

function RaidFrameTinker:UpdateUnit(units)
    local class_color = self.opt.statusbar_color
    self:PrintMessage("Updating unit: ")

    for unit in pairs(units) do
        --local focus_unit = self:CheckFocusUnit(unit)
        if self.visible[unit] and UnitExists(unit) then
            --if (not self.opt.dynamic_sort or not focus_unit and not force_focus or focus_unit and force_focus) then
            local f = self.frames[unit]
            local range = ""

            local id_str = string.gsub(unit, "raid", "")
            local _, _, subgroup = GetRaidRosterInfo(id_str)

            if self.opt.grp_name then
                subgroup = "(" .. subgroup .. ")"
            else
                subgroup = ""
            end

            if self.opt.RangeShow and (not self.opt.FocusRangeShow or self.opt.FocusRangeShow and self:CheckFocusUnit(unit)) then
                range = self.UnitRangeArray[unit]
                if not range or range == "" or range == 0 or UnitIsDeadOrGhost("player") then
                    range = ""
                else
                    range = " " .. range .. "Y"
                end
            end

            local _, class = UnitClass(unit)
            local unit_name = subgroup .. UnitName(unit)

            if self.opt.unit_name_lenght or self.opt.RangeShow then
                unit_name = subgroup .. string.sub(UnitName(unit), 1, 3) --UnitName(unit)
            end

            local unit_aggro = Banzai:GetUnitAggroByUnitId(unit)

            if unit_aggro and self.opt.red then
                f.title:SetText("|cffff0000" .. unit_name .. range .. "|r")
            elseif not self.opt.unitname_color then
                f.title:SetText(unit_name .. range .. "|r")
            elseif class then
                f.title:SetText(self.RAID_CLASS_COLORS[class].colorStr .. unit_name .. range .. "|r")
            else
                f.title:SetText(unit_name or L["Unknown"])
            end

            self.feign[unit] = nil

            -- Silly hunters, why do you have to be so annoying
            if UnitExists(unit .. "target") and not UnitAffectingCombat(unit) and UnitIsUnit(unit .. "target", "player") and not UnitIsUnit(unit, "player") then
                self.targeting[unit] = true
            else
                self.targeting[unit] = nil
            end

            if class == "HUNTER" then
                if UnitIsDead(unit) then
                    for i = 1, 32 do
                        local texture = UnitBuff(unit, i)
                        if not texture then break end
                        if texture == "Interface\\Icons\\Ability_Rogue_FeignDeath" then
                            self.feign[unit] = true
                            break
                        end
                    end
                end
            end


            if not self.feign[unit] then
                local status, dead, ghost = nil, UnitIsDead(unit) or UnitHealth(unit) <= 1, UnitIsGhost(unit)
                if not UnitIsConnected(unit) then
                    status = "|cff858687" .. L["Offline"] .. "|r"
                elseif self.res[unit] == 1 and dead then
                    status = "|cffff8c00" .. L["Can Recover"] .. "|r"
                elseif self.res[unit] == 2 and (dead or ghost) then
                    status = "|cffff8c00" .. L["Rezzed"] .. "|r"
                elseif self.hpaura[unit] then
                    status = "|cffff8c00" .. self.hpaura[unit] .. "|r"
                elseif ghost then
                    status = "|cffff0000" .. L["Ghost"] .. "|r"
                elseif dead or UnitHealth(unit) <= 1 then
                    status = "|cffff0000" .. L["Dead"] .. "|r"
                end


                if status and not self.unavail[unit] or not status and self.unavail[unit] then
                    self.preparesort = true
                end


                if status then
                    self.unavail[unit] = true
                    f.hpbar.text:SetText(status)
                    f.hpbar:SetValue(0)
                    --f.mpbar.text:SetText()
                    f.mpbar:SetValue(0)
                    --f:SetBackdropColor(0.3, 0.3, 0.3, 1)

                    self:HideHealIndicator(unit, true)
                else
                    --self:CreateHealIndicator(unit)

                    self.unavail[unit] = false
                    self.res[unit] = nil
                    local hp = UnitHealth(unit) or 0
                    local hpmax = UnitHealthMax(unit)
                    local hpp = (hpmax ~= 0) and ceil((hp / hpmax) * 100) or 0
                    local hptext, hpvalue = nil, nil

                    if self.opt.healthDisplayType == "percent" then
                        hptext = hpp .. "%"
                    elseif self.opt.healthDisplayType == "deficit" then
                        hptext = (hp - hpmax) ~= 0 and (hp - hpmax) or nil
                    elseif self.opt.healthDisplayType == "current" then
                        hptext = hp
                    elseif self.opt.healthDisplayType == "curmax" then
                        hptext = hp .. "/" .. hpmax
                    end

                    if self.opt.Invert then
                        hpvalue = 100 - hpp
                    else
                        hpvalue = hpp
                    end

                    f.hpbar.text:SetText(hptext)
                    f.hpbar:SetValue(hpvalue)


                    if unit_aggro and self.opt.redbar then
                        f.hpbar:SetStatusBarColor(1, 0, 0)
                    elseif self.opt.self_targeting and UnitExists("target") and UnitIsUnit("target", unit) then
                        f.hpbar:SetStatusBarColor(1, 0, 1, 0.75)
                    elseif self.opt.targeting and self.targeting[unit] then
                        f.hpbar:SetStatusBarColor(0, 0, 0, 0.75)
                    elseif class_color then
                        local class, fileName = UnitClass(unit)
                        local color = self.RAID_CLASS_COLORS[fileName]
                        if color then
                            f.hpbar:SetStatusBarColor(color.r, color.g, color.b)
                        end
                    else
                        f.hpbar:SetStatusBarColor(self:GetHPSeverity(hpp / 100))
                    end

                    local mp = UnitMana(unit) or 0
                    local mpmax = UnitManaMax(unit)
                    local mpp = (mpmax ~= 0) and ceil((mp / mpmax) * 100) or 0

                    local powerType = UnitPowerType(unit)
                    if self.opt.PowerFilter[powerType] == false then
                        f.mpbar:SetValue(0)
                    else
                        local color = self.ManaBarColor[powerType]
                        f.mpbar:SetStatusBarColor(color.r, color.g, color.b)
                        f.mpbar:SetValue(mpp)
                    end
                end
            else
                f.hpbar.text:SetText("|cff00ff00" .. L["Feign Death"] .. "|r")
                f.hpbar:SetValue(100)
                f.hpbar:SetStatusBarColor(0, 0.9, 0.5)
                f.mpbar:SetValue(0)
            end
            --end	
        end
    end
end

function RaidFrameTinker:JoinedRaid()
    self:Print("Joined a raid, enabling raid frames")


    self:RegisterBucketEvent("UNIT_HEALTH", 0.2, "UpdateUnit")
    self:RegisterBucketEvent("UNIT_AURA", 0.2, "UpdateBuffs")

    self:RegisterBucketEvent("ZONE_CHANGED_NEW_AREA", 1, "ZoneCheck")
    self:RegisterBucketEvent("PLAYER_UNGHOST", 1, "ZoneCheck")

    self:RegisterBucketEvent("PLAYER_REGEN_ENABLED", 2, "CombatEnds")
    self:RegisterBucketEvent("PLAYER_REGEN_DISABLED", 2, "CombatStarts")
    self:RegisterBucketEvent("PLAYER_DEAD", 2, "ResetHealIndicators")

    self:RegisterBucketEvent("PLAYER_TARGET_CHANGED", 0.01)

    self:RegisterEvent("Banzai_UnitGainedAggro")
    self:RegisterEvent("Banzai_UnitLostAggro")

    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE", "TrackCarrier")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE", "TrackCarrier")


    self:ScheduleRepeatingEvent("sRaidFramesUpdateAllUnits", self.UpdateAllUnits, 1, self)
    self:ScheduleRepeatingEvent("sRaidFramesUpdateAllBuffs", self.UpdateAllBuffs, 0.33, self)

    self:UpdateRoster()

    self:UpdateAllUnits()
    self:UpdateAllBuffs()

    self.master:Show()
    self:ZoneCheck()
    self:UpdateParty()
end

function RaidFrameTinker:OnUnitClick()
    local unitid, button = this.unit, arg1;
    if (SpellIsTargeting()) then
        SpellTargetUnit(unitid)
    else
        TargetUnit(unitid)
    end
end

function RaidFrameTinker:MouseOverHighlight(f, type)
    if type == "ENTER" then
        f.hpbar.highlight:Show()
    else
        f.hpbar.highlight:Hide()
    end
end

function RaidFrameTinker:UNIT_HEALTH(qrg1)
    local unit = arg1
    local id = self:GetUnitID(unit)
    if id then
        self:UpdateUnit(unit)
    end
end

function getHealthPercentage(unit)
    local maxHealth = UnitHealthMax(unit)
    local currentHealth = UnitHealth(unit)
    local healthPercentage = math.floor((currentHealth / maxHealth) * 100)
    return healthPercentage
end

function RaidFrameTinker:CreateUnitFrame(id)
    local _, class = UnitClass("raid" .. id)
    local frame = CreateFrame("Button", "RaidFrameTinker_" .. id, self.master)
    frame:SetScript("OnClick", self.OnUnitClick)

    frame:SetScript("OnEnter", function()
        self:MouseOverHighlight(frame, "ENTER")
    end)


    frame:SetScript("OnLeave", function()
        self:MouseOverHighlight(frame, "LEAVE")
    end)

    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:RegisterEvent("UNIT_HEALTH")
    frame:SetScript("OnEvent", function(a, event)
        self:PrintMessage(a)
        self:PrintMessage(event)
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        edgeFile = "Interface\\Addons\\RaidFrameTinker\\borders\\UI-Tooltip-Border_Grid.tga",
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    frame:SetBackdropColor(0.5, 0.5, 0.5, 1)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
    frame:SetHeight(32)
    frame:SetWidth(50)
    frame:Show()


    -- FOR NOW

    if id == 1 then
        frame:SetPoint("TOPLEFT", self.master, "TOPLEFT", 0, 0)
    elseif id == 6 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    elseif id == 11 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    elseif id == 16 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    elseif id == 21 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    elseif id == 26 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    elseif id == 31 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    elseif id == 36 then
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 5)), "TOPRIGHT",
            2)
    else
        frame:SetPoint("TOPLEFT", getglobal("RaidFrameTinker_" .. (id - 1)), "BOTTOMLEFT",
            -2)
    end


    frame.title = frame:CreateFontString(nil, "ARTWORK")
    frame.title:SetAllPoints(frame)
    frame.title:SetFontObject(GameFontNormalSmall)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetText(UnitName("raid" .. id))
    frame.title:Show()

    if class and RAID_CLASS_COLORS[class] then
        frame.title:SetTextColor(RAID_CLASS_COLORS[class].r,
            RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b)
    end
    frame.hpbar = CreateFrame("StatusBar", nil, frame)
    frame.hpbar:SetScript("OnEvent", function(self, event, unit)
        DEFAULT_CHAT_FRAME:AddMessage(event)
        DEFAULT_CHAT_FRAME:AddMessage(unit)
    end)
    frame.hpbar:SetAllPoints(frame)
    frame.hpbar:SetMinMaxValues(0, 100)
    if UnitHealth("raid" .. id) > 100 then
        frame.hpbar:SetValue(getHealthPercentage("raid" .. id))
    else
        frame.hpbar:SetValue(UnitHealth("raid" .. id))
    end

    frame.hpbar:SetFrameLevel(2)
    frame.hpbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    if class and RAID_CLASS_COLORS[class] then
        frame.hpbar:SetStatusBarColor(RAID_CLASS_COLORS[class].r,
            RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b)
    else
        frame.hpbar:SetStatusBarColor(0.5, 0.5, 0.5)
    end


    frame.hpbar.highlight = frame.hpbar:CreateTexture(nil, "OVERLAY")
    frame.hpbar.highlight:SetAlpha(0.3)
    frame.hpbar.highlight:SetTexture("Interface\\AddOns\\RaidFrameTinker\\textures\\mouseoverHighlight.tga")
    frame.hpbar.highlight:SetBlendMode("ADD")
    frame.hpbar.highlight:Show()

    frame.buff1 = CreateFrame("Button", nil, frame)
    frame.buff1.texture = frame.buff1:CreateTexture(nil, "ARTWORK")
    frame.buff1.texture:SetAllPoints(frame.buff1)
    frame.buff1.count = frame.buff1:CreateFontString(nil, "OVERLAY")
    frame.buff1.count:SetFontObject(GameFontHighlightSmallOutline)
    frame.buff1.count:SetJustifyH("CENTER")
    frame.buff1.count:SetPoint("CENTER", frame.buff1, "CENTER", 0, 0);
    frame.buff1:Hide()

    frame.buff2 = CreateFrame("Button", nil, frame)
    frame.buff2.texture = frame.buff2:CreateTexture(nil, "ARTWORK")
    frame.buff2.texture:SetAllPoints(frame.buff2)
    frame.buff2.count = frame.buff2:CreateFontString(nil, "OVERLAY")
    frame.buff2.count:SetFontObject(GameFontHighlightSmallOutline)
    frame.buff2.count:SetJustifyH("CENTER")
    frame.buff2.count:SetPoint("CENTER", frame.buff2, "CENTER", 0, 0);
    frame.buff2:Hide()

    frame.buff3 = CreateFrame("Button", nil, frame)
    frame.buff3.texture = frame.buff3:CreateTexture(nil, "ARTWORK")
    frame.buff3.texture:SetAllPoints(frame.buff3)
    frame.buff3.count = frame.buff3:CreateFontString(nil, "OVERLAY")
    frame.buff3.count:SetFontObject(GameFontHighlightSmallOutline)
    frame.buff3.count:SetJustifyH("CENTER")
    frame.buff3.count:SetPoint("CENTER", frame.buff3, "CENTER", 0, 0);
    frame.buff3:Hide()

    frame.buff4 = CreateFrame("Button", nil, frame)
    frame.buff4.texture = frame.buff4:CreateTexture(nil, "ARTWORK")
    frame.buff4.texture:SetAllPoints(frame.buff4)
    frame.buff4.count = frame.buff4:CreateFontString(nil, "OVERLAY")
    frame.buff4.count:SetFontObject(GameFontHighlightSmallOutline)
    frame.buff4.count:SetJustifyH("CENTER")
    frame.buff4.count:SetPoint("CENTER", frame.buff4, "CENTER", 0, 0);
    frame.buff4:Hide()

    frame:SetID(id)
    frame.id = id
    frame.unit = "raid" .. id

    -- f:Show();
    self.frames["raid" .. id] = frame
end

function RaidFrameTinker:SetWHP(frame, width, height, p1, relative, p2, x, y)
    frame:SetWidth(width)
    frame:SetHeight(height)

    if (p1) then
        frame:ClearAllPoints()
        frame:SetPoint(p1, relative, p2, x, y)
    end
end

function RaidFrameTinker:CreateGroupFrame(id)
    local frame = CreateFrame("Frame", "RaidFrameTinkerGroup_" .. id, self.master)
    frame:SetHeight(60);
    frame:SetWidth(50);
    frame:SetBackdropColor(0.5, 0.5, 0.5, 1)

    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:ClearAllPoints();
    frame:SetParent(self.master);
    frame:SetPoint("LEFT", self.master, "LEFT");
    frame:SetScript("OnDragStart",
        function()
            if IsAltKeyDown() then self:StartMovingAll() end
            frame:StartMoving()
        end)
    frame:SetScript("OnDragStop",
        function()
            if frame.multidrag == 1 then self:StopMovingOrSizingAll() end
            frame:StopMovingOrSizing()
        end)
    frame:RegisterForDrag("LeftButton")
    frame:SetParent(self.master)



    frame.title = frame:CreateFontString(nil, "ARTWORK")
    frame.title:ClearAllPoints()
    frame.title:SetFontObject(GameFontNormalSmall)
    frame.title:SetText("Group" .. tostring(id))
    frame.title:Show()

    for i = 1, 9 do
        if id == i then
            self:SetWHP(frame.title, 80, frame:GetHeight(), "TOP", getglobal("RaidFrameTinker_" .. (i * 5) - 4), "TOP", 0,
                45)
        end
    end





    frame:ClearAllPoints();
    frame:SetPoint("LEFT", UIParent, "LEFT", 20, 50)

    frame:SetID(id)
    frame.id = id

    frame:Show();
end

function RaidFrameTinker:CreateLayout()
    local members = GetNumRaidMembers()

    for i = 1, members do
        -- if i is a multiple of 5, create a new group frame
        if i == 1 or math.mod(i, 5) == 0 then
            -- ternary operator
            self:PrintMessage("Creating group frame " .. (i / 5 >= 1 and i / 5 >= 1 or 1));
            self:CreateGroupFrame((i / 5 >= 1 and i / 5 >= 1 or 1));
        end
        self:PrintMessage("Creating raid frame " .. i);
        self:CreateUnitFrame(i);
    end
end

function RaidFrameTinker:UpdateRoster()
    local raidMembers = GetNumRaidMembers()

    if raidMembers == 0 then
        if self.enabled then
            self:LeftRaid()
        end
        return
    end

    if not self.enabled then
        self:JoinedRaid()
    end

    self:ResetHealIndicators()
    self:UpdateRaidFrames()
end
