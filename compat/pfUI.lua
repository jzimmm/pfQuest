-- Initialize pfUI core table for non-pfUI environments
if not pfUI then
  pfUI = {
    ["api"] = {},
    ["cache"] = {},
    ["backdrop"] = {
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 }
    },
    ["backdrop_small"] = {
      bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
      edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1,
      insets = {left = 0, right = 0, top = 0, bottom = 0},
    },
    ["font_default"] = "Fonts\\ARIALN.TTF",
   }

  pfUI_config = {
    ["appearance"] = {
      ["border"] = {
        ["default"] = "3",
      }
    },
    ["global"] = {
      ["font_size"] = 12
    },
    -- fix for old questie releases
    ["disabled"] = {
      ["minimap"] = "1"
    }
  }
end

-- Add API support non-pfUI environments and for old pfUI versions:
-- strsplit, SanitizePattern, CreateBackdrop, SkinButton, CreateScrollFrame, CreateScrollChild
if pfUI.api and pfUI.api.strsplit and pfUI.api.CreateBackdrop and
   pfUI.api.SkinButton and pfUI.api.CreateScrollFrame and
   pfUI.api.CreateScrollChild and pfUI.api.SanitizePattern then
     return
end

function pfUI.api.strsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

local sanitize_cache = {}
function pfUI.api.SanitizePattern(pattern, dbg)
  if not sanitize_cache[pattern] then
    local ret = pattern
    -- escape magic characters
    ret = gsub(ret, "([%+%-%*%(%)%?%[%]%^])", "%%%1")
    -- remove capture indexes
    ret = gsub(ret, "%d%$","")
    -- catch all characters
    ret = gsub(ret, "(%%%a)","%(%1+%)")
    -- convert all %s to .+
    ret = gsub(ret, "%%s%+",".+")
    -- set priority to numbers over strings
    ret = gsub(ret, "%(.%+%)%(%%d%+%)","%(.-%)%(%%d%+%)")
    -- cache it
    sanitize_cache[pattern] = ret
  end

  return sanitize_cache[pattern]
end

local er, eg, eb, ea = .4,.4,.4,1
local br, bg, bb, ba = 0,0,0,.8
function pfUI.api.CreateBackdrop(f, inset, legacy, transp)
  -- exit if now frame was given
  if not f then return end

  -- use default inset if nothing is given
  local border = inset
  if not border then
    border = tonumber(pfUI_config.appearance.border.default)
  end

  if transp then ba = transp end

  -- use legacy backdrop handling
  if legacy then
    f:SetBackdrop(pfUI.backdrop)
    f:SetBackdropColor(br, bg, bb, ba)
    f:SetBackdropBorderColor(er, eg, eb , ea)
    return
  end

  -- increase clickable area if available
  if f.SetHitRectInsets then
    f:SetHitRectInsets(-border,-border,-border,-border)
  end

  -- use new backdrop behaviour
  if not f.backdrop then
    f:SetBackdrop(nil)

    local border = tonumber(border) - 1
    local backdrop = pfUI.backdrop
    if border < 1 then backdrop = pfUI.backdrop_small end
  	local b = CreateFrame("Frame", nil, f)
  	b:SetPoint("TOPLEFT", f, "TOPLEFT", -border, border)
  	b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", border, -border)

    local level = f:GetFrameLevel()
    if level < 1 then
  	  --f:SetFrameLevel(level + 1)
      b:SetFrameLevel(level)
    else
      b:SetFrameLevel(level - 1)
    end

    f.backdrop = b
    b:SetBackdrop(backdrop)
  end

  local b = f.backdrop
  b:SetBackdropColor(br, bg, bb, ba)
  b:SetBackdropBorderColor(er, eg, eb , ea)
end

function pfUI.api.SkinButton(button, cr, cg, cb)
  local b = getglobal(button)
  if not b then b = button end
  if not b then return end
  if not cr or not cg or not cb then
    _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    cr, cg, cb = color.r , color.g, color.b
  end
  pfUI.api.CreateBackdrop(b, nil, true)
  b:SetNormalTexture(nil)
  b:SetHighlightTexture(nil)
  b:SetPushedTexture(nil)
  b:SetDisabledTexture(nil)
  local funce = b:GetScript("OnEnter")
  local funcl = b:GetScript("OnLeave")
  b:SetScript("OnEnter", function()
    if funce then funce() end
    pfUI.api.CreateBackdrop(b, nil, true)
    b:SetBackdropBorderColor(cr,cg,cb,1)
  end)
  b:SetScript("OnLeave", function()
    if funcl then funcl() end
    pfUI.api.CreateBackdrop(b, nil, true)
  end)
  b:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
end

function pfUI.api.CreateScrollFrame(name, parent)
  local f = CreateFrame("ScrollFrame", name, parent)

  -- create slider
  f.slider = CreateFrame("Slider", nil, f)
  f.slider:SetOrientation('VERTICAL')
  f.slider:SetPoint("TOPLEFT", f, "TOPRIGHT", -7, 0)
  f.slider:SetPoint("BOTTOMRIGHT", 0, 0)
  f.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetHeight(50)
  f.slider.thumb:SetTexture(.3,1,.8,.5)

  f.slider:SetScript("OnValueChanged", function()
    f:SetVerticalScroll(this:GetValue())
    f.UpdateScrollState()
  end)

  f.UpdateScrollState = function()
    f.slider:SetMinMaxValues(0, f:GetVerticalScrollRange())
    f.slider:SetValue(f:GetVerticalScroll())

    local m = f:GetHeight()+f:GetVerticalScrollRange()
    local v = f:GetHeight()
    local ratio = v / m

    if ratio < 1 then
      local size = math.floor(v * ratio)
      f.slider.thumb:SetHeight(size)
      f.slider:Show()
    else
      f.slider:Hide()
    end
  end

  f.Scroll = function(self, step)
    local step = step or 0

    local current = f:GetVerticalScroll()
    local max = f:GetVerticalScrollRange()
    local new = current - step

    if new >= max then
      f:SetVerticalScroll(max)
    elseif new <= 0 then
      f:SetVerticalScroll(0)
    else
      f:SetVerticalScroll(new)
    end

    f:UpdateScrollState()
  end

  f:EnableMouseWheel(1)
  f:SetScript("OnMouseWheel", function()
    this:Scroll(arg1*10)
  end)

  return f
end

function pfUI.api.CreateScrollChild(name, parent)
  local f = CreateFrame("Frame", name, parent)

  -- dummy values required
  f:SetWidth(1)
  f:SetHeight(1)
  f:SetAllPoints(parent)

  parent:SetScrollChild(f)

  -- OnShow is fired too early, postpone to the first frame draw
  f:SetScript("OnUpdate", function()
    this:GetParent():Scroll()
    this:SetScript("OnUpdate", nil)
  end)

  return f
end
