------------------------------------------------------------------------------------------------------------------------
---                 3STATED | 3-State-Display - Widget für FrSky Ethos
---
---  FrSky Ethos Widget for textual and color-based display of 3 states from a source (switches, variables, ...).
---  Documentation: file://./readme.md
---
---  Development Environment: Ethos X20S Simulator Version 1.6.3
---  Test Environment:        FrSky Tandem X20 | Ethos 1.6.3 EU | Bootloader 1.4.15
---
---  Author: Andreas Kuhl (https://github.com/andreaskuhl)
---  License: GPL 3.0
---
---  Many thanks for the following helpful examples:
---    - Switch Display (V1.4 from 28.12.2024), JecoBerlin
---    - Ethos Status Widget / Ethos TriStatus Widget (V2.1 from 30.07.2025), Lothar Thole (https://github.com/lthole)
---
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--- Modul locals (constants and variables)
------------------------------------------------------------------------------------------------------------------------

--- Application control and information
local WIDGET_VERSION      = "2.0.1"                                 -- version information
local WIDGET_KEY          = "3STATED"                               -- unique widget key (max. 7 characters)
local WIDGET_AUTOR        = "Andreas Kuhl (github.com/andreaskuhl)" -- author information
local DEBUG_MODE          = false                                   -- true: show debug information, false: release mode
local widgetCounter       = 0                                       -- debug: counter for widget instances (0 = no instance)

--- Libraries
local wHelper             = {} -- widget helper library
local wPaint              = {} -- widget paint library
local wConfig             = {} -- widget config library
local wStorage            = {} -- widget storage library

--- Translation
local STR                 = assert(loadfile("i18n/i18n.lua"))().translate -- load i18n and get translate function
local WIDGET_NAME_MAP     = assert(loadfile("i18n/w_name.lua"))()         -- load widget name map
local currentLocale       = system.getLocale()                            -- current system language

--- State
local STATE               = { DOWN = 1, MIDDLE = 2, UP = 3 }
local THRESHOLD_RANGE     = 1024 -- Minimum and maximum threshold for configuration form.
local THRESHOLD_PRECISION = 2    -- Precision (number of decimals) for threshold configuration form.

--- User interface
local FONT_SIZES          = {
    FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL }                       -- global font IDs (1-6)
local FONT_SIZE_SELECTION = {
    { "XS", 1 }, { "S", 2 }, { "M", 3 }, { "L", 4 }, { "XL", 5 }, { "XXL", 6 } } -- list for config listbox

------------------------------------------------------------------------------------------------------------------------
--- Local Helper functions
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--- Load and init Libraries.
local function initLibraries()
    -- load libraries with dependencies
    wHelper = dofile("lib/w_helper.lua")({ widgetVersion = WIDGET_VERSION, widgetKey = WIDGET_KEY, debugMode = DEBUG_MODE })
    wPaint = dofile("lib/w_paint.lua")({ wHelper = wHelper })
    wConfig = dofile("lib/w_config.lua")({ wHelper = wHelper })
    wStorage = dofile("lib/w_storage.lua")({ wHelper = wHelper })

    wHelper.Debug:new(0, "initLibraries"):info("libraries loaded")
end

------------------------------------------------------------------------------------------------------------------------
-- Check if the system language has changed and reload i18n if necessary.
local function updateLanguage(widget)
    local localeNow = system.getLocale()
    if localeNow ~= currentLocale then -- Language has changed, reload i18n
        wHelper.Debug:new(widget.no, "updateLanguage")
            :info("Language changed from " .. currentLocale .. " to " .. localeNow)
        STR = assert(loadfile("i18n/i18n.lua"))().translate
        currentLocale = localeNow
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Widget handler
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Handler to get the widget name in the current system language.
local function name() -- Widget name (ASCII) - only for name() Handler
    local lang = system.getLocale and system.getLocale() or "en"
    return WIDGET_NAME_MAP[lang] or WIDGET_NAME_MAP["en"]
end

------------------------------------------------------------------------------------------------------------------------
--- Handler to create a new widget instance with default values.
local function create()
    widgetCounter                 = widgetCounter + 1
    local debug                   = wHelper.Debug:new(widgetCounter, "create"):info()

    --- widget defaults
    local FONT_SIZE_INDEX_DEFAULT = 5                      -- font size index default - see fontSizes (1=XS - 6=XXL)
    local BG_COLOR_TITLE          = lcd.RGB(40, 40, 40)    -- title background  -> dark gray
    local TX_COLOR_TITLE          = lcd.RGB(176, 176, 176) -- title text        -> light gray
    local BG_COLOR_DOWN           = lcd.RGB(0, 128, 0)     -- down background   -> green
    local TX_COLOR_DOWN           = COLOR_WHITE            -- down text         -> white
    local BG_COLOR_MID            = lcd.RGB(192, 128, 0)   -- middle background -> orange
    local TX_COLOR_MID            = COLOR_WHITE            -- middle text       -> white
    local BG_COLOR_UP             = lcd.RGB(192, 0, 0)     -- up background     -> red
    local TX_COLOR_UP             = COLOR_WHITE            -- up text           -> white

    --- Create widget data structure with default values.
    return {
        -- widget variables
        no              = widgetCounter,           -- widget instance number
        width           = nil,                     -- widget height
        height          = nil,                     -- widget width

        source          = nil,                     -- source
        sourceLastValue = 0,                       -- last source value
        titleShow       = true,                    -- title switch
        titleText       = STR("Title"),            -- title text
        titleColorUse   = true,                    -- title color switch
        titleBgColor    = BG_COLOR_TITLE,          -- title background color
        titleTxColor    = TX_COLOR_TITLE,          -- title text color
        thresholdDown   = -50,                     -- threshold for state down
        thresholdUp     = 50,                      -- threshold for state up
        fontSizeIndex   = FONT_SIZE_INDEX_DEFAULT, -- index of font size
        states          = {                        -- list of test and colors for title and states
            { title = "StateDown",   text = STR("StateDown"),   bgColor = BG_COLOR_DOWN, txColor = TX_COLOR_DOWN },
            { title = "StateMiddle", text = STR("StateMiddle"), bgColor = BG_COLOR_MID,  txColor = TX_COLOR_MID },
            { title = "StateUp",     text = STR("StateUp"),     bgColor = BG_COLOR_UP,   txColor = TX_COLOR_UP },
        },
        debugMode       = false, -- true: shows internal values in the widget

        -- get source name function
        getSourceName   = function(self) return (wHelper.existSource(self.source) and self.source:name()) or "---" end,
        -- get source value function
        getSourceValue  = function(self) return (wHelper.existSource(self.source) and self.source:value()) or 0 end,
        -- get source text function
        getSourceText   = function(self) return (wHelper.existSource(self.source) and self.source:stringValue()) or "" end,
        -- get state function (DOWN, MIDDLE, UP)
        getState        = function(self)
            local x = self:getSourceValue()
            return (x < self.thresholdDown and STATE.DOWN) or (x < self.thresholdUp and STATE.MIDDLE) or STATE.UP
        end,
        getStateTitle   = function(self) return self.states[self:getState()].title end,
        getStateText    = function(self) return self.states[self:getState()].text end,
        getStateBgColor = function(self) return self.states[self:getState()].bgColor end,
        getStateTxColor = function(self) return self.states[self:getState()].txColor end,
    }
end

------------------------------------------------------------------------------------------------------------------------
--- Handler to wake up the widget (check for source value changes and initiating redrawing if necessary).
local function wakeup(widget)
    local debug = wHelper.Debug:new(widget.no, "wakeup")
    if not wHelper.existSource(widget.source) then return end

    -- check if source value has changed
    local actValue = widget.source:value()
    if actValue ~= nil and widget.sourceLastValue ~= actValue then
        lcd.invalidate()
        widget.sourceLastValue = actValue
        debug:info("widget value is changed to " ..
            "value = " .. actValue .. ", text = " .. widget:getSourceText() ..
            ", " .. widget:getState() .. " = " .. STR(widget:getStateTitle()))
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Handler to paint (draw) the widget.
local function paint(widget)
    --------------------------------------------------------------------------------------------------------------------
    --- Format state text by replacing placeholders in a given string.
    --- Supported placeholders:
    ---   _v    -> widget:getSourceValue() as number (without decimals) -> "8"
    ---   _<N>v -> widget:getSourceValue() as float with N decimals (e.g., _3v for three decimals) -> "7,532"
    ---   _t    -> widget:getSourceText()-> "7,5V"
    ---   _n    -> widget:getSourceName() -> "Battery Voltage"
    ---   __    -> literal "_"
    local function formatText(stateText)
        -- local debug = wHelper.Debug:new(widget.no, "formatText")
        local UNDERSCORE_PLACEHOLDER = "\1"
        local sourceValue = widget and widget:getSourceValue()
        local sourceText = widget and widget:getSourceText()
        local sourceName = widget and widget:getSourceName()
        local text = stateText or ""
        -- debug:info("Input: " .. s .. ", value: " .. val .. ", text: " .. txt)

        if text == "" then return "" end

        text = text:gsub("__", UNDERSCORE_PLACEHOLDER) -- temporary placeholder for literal '__' to avoid accidental replacement

        text = text:gsub("_(%d+)v",                    -- value: replace floating formats like _0v, _1v, _2v, _3v etc. capture digits before v
            function(precision)
                local n = tonumber(precision) or 0
                local formatStr = string.format("%%.%df", n)
                return string.format(formatStr, tonumber(sourceValue) or 0)
            end)
        text = text:gsub("_v", string.format("%.0f", tonumber(sourceValue) or 0)) -- value: replace default float _v as value number (float without decimals)
        text = text:gsub("_t", function() return tostring(sourceText) end)        -- text: replace _t as value text
        text = text:gsub("_n", function() return tostring(sourceName) end)        -- text: replace _n_ as source name
        text = text:gsub(UNDERSCORE_PLACEHOLDER, "_")                             -- restore literal underscore

        return text
    end

    --------------------------------------------------------------------------------------------------------------------
    --- Paint title text.
    local function paintTitle()
        -- local debug = wHelper.Debug:new(widget.no, "paintTitle"):info()
        if not widget.titleShow then return end -- title disabled
        local titleText = formatText(widget.titleText)

        -- paint title
        if widget.titleColorUse then
            -- title background and title text color
            wPaint.title(titleText, widget.titleBgColor, widget.titleTxColor)
        else
            -- use state colors
            wPaint.title(titleText, widget:getStateBgColor(), widget:getStateTxColor())
        end
    end

    --------------------------------------------------------------------------------------------------------------------
    --- Paint debug information (shows internal values of the widget).
    local function paintDebugInfo()
        local debug = wHelper.Debug:new(widget.no, "paintDebugInfo"):info()
        assert(wHelper.existSource(widget.source))

        local line = {}

        --- line 1: source name and value
        line[1] = widget.source:name() .. ": " .. widget:getSourceValue() .. " (" .. widget:getSourceText() .. ")"

        -- line 2: state and thresholds
        if widget:getState() == STATE.DOWN then
            line[2] = "< " .. widget.thresholdDown
        elseif widget:getState() == STATE.MIDDLE then
            line[2] = ">= " .. widget.thresholdDown .. " & < " .. widget.thresholdUp
        elseif widget:getState() == STATE.UP then
            line[2] = ">= " .. widget.thresholdUp
        end

        -- line 3: state text
        if line[2] then
            line[2] = line[2] .. " -> " .. STR(widget:getStateTitle())
            line[3] = "\"" .. formatText(widget:getStateText()) .. "\""
        else
            line[2] = "Status: " .. STR("StateUnknown")
            line[3] = ""
        end

        -- draw debug lines
        wPaint.text(line[1], FONT_S, TEXT_CENTERED, wPaint.LINE_CENTERED, -1)
        wPaint.text(line[2], FONT_S, TEXT_CENTERED, wPaint.LINE_CENTERED, 0)
        wPaint.text(line[3], FONT_S, TEXT_CENTERED, wPaint.LINE_CENTERED, 1)
    end

    --------------------------------------------------------------------------------------------------------------------
    ---  paint multiline state text
    local function paintStateText()
        local lines = wHelper.splitLines(widget:getStateText())
        local n = #lines
        for i, line in ipairs(lines) do
            local offset = -n / 2 - 0.5 + i
            line = formatText(line)
            wPaint.text(line, FONT_SIZES[widget.fontSizeIndex], TEXT_CENTERED, wPaint.LINE_CENTERED, offset)
        end
    end

    --------------------------------------------------------------------------------------------------------------------
    --- Paint background, set text color and paint state text (or debug information in debug mode).
    local function paintState()
        local debug = wHelper.Debug:new(widget.no, "paintState"):info()
        assert(wHelper.existSource(widget.source))

        -- paint background
        lcd.color(widget:getStateBgColor())
        lcd.drawFilledRectangle(wPaint.TRANSPARENCY_X_OFFSET, wPaint.TRANSPARENCY_Y_OFFSET, widget.width - (2 * wPaint.TRANSPARENCY_X_OFFSET), widget.height - (2 * wPaint.TRANSPARENCY_Y_OFFSET))

        -- paint title (must be before paint state text or debug information)
        paintTitle()

        -- preset text color
        lcd.color(widget:getStateTxColor())

        -- paint state text (debug oder standard)
        if widget.debugMode then
            paintDebugInfo()
        else
            paintStateText()
        end
    end

    --------------------------------------------------------------------------------------------------------------------
    --- Paint source missed (no valid source selected) in red on black background.
    local function paintSourceMissed()
        local debug = wHelper.Debug:new(widget.no, "paintSourceMissed"):info()
        lcd.color(COLOR_BLACK)
        lcd.drawFilledRectangle(wPaint.TRANSPARENCY_X_OFFSET, wPaint.TRANSPARENCY_Y_OFFSET, widget.width - (2 * wPaint.TRANSPARENCY_X_OFFSET), widget.height - (2 * wPaint.TRANSPARENCY_Y_OFFSET))

        --- paint title
        paintTitle()

        debug:warning("source not defined")

        -- paint "Source missed" text
        lcd.color(COLOR_RED)
        wPaint.widgetText(STR("SourceMissed"), FONT_STD)
    end

    --------------------------------------------------------------------------------------------------------------------
    --- Paint main
    local debug = wHelper.Debug:new(widget.no, "paint"):info()

    updateLanguage(widget)
    widget.width, widget.height = lcd.getWindowSize() -- set the actual widget size (always if the layout has been changed)
    wPaint.init({ widgetHeight = widget.height, widgetWidth = widget.width })

    if not wHelper.existSource(widget.source) then -- source missed
        paintSourceMissed()
    elseif widget:getState() == STATE.DOWN or widget:getState() == STATE.MIDDLE or widget:getState() == STATE.UP then
        paintState()
    else -- invalid state
        assert(false, "Error: Invalid widget state")
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Handler to configure the widget (show configuration form).
local function configure(widget)
    local line
    local f

    --------------------------------------------------------------------------------------------------------------------
    --- Add configuration for title or state (text, background color and text color).
    local function addConfigBlock(index)
        wConfig.startPanel(widget.states[index].title)

        line = wConfig.addLineTitle(STR(widget.states[index].title) .. " " .. STR("Text"))
        form.addTextField(line, nil, function() return widget.states[index].text end,
            function(value) widget.states[index].text = value end)

        line = wConfig.addLineTitle(STR(widget.states[index].title) .. " " .. STR("BackgroundColor"))
        form.addColorField(line, nil, function() return widget.states[index].bgColor end,
            function(color) widget.states[index].bgColor = color end)

        line = wConfig.addLineTitle(STR(widget.states[index].title) .. " " .. STR("TextColor"))
        form.addColorField(line, nil, function() return widget.states[index].txColor end,
            function(color) widget.states[index].txColor = color end)

        wConfig.endPanel()
    end

    --------------------------------------------------------------------------------------
    --- Configure main
    local debug = wHelper.Debug:new(widget.no, "configure"):info()
    updateLanguage(widget) -- check if system language has changed
    wConfig.init({ form = form, widget = widget, STR = STR })

    -- Source
    wConfig.addSourceField("source")

    -- thresholds
    if wHelper.existSource(widget.source) and widget.source.maximum and widget.source.minimum then
        -- Not perfect since to have this code working you will need
        -- to configure the widget to set the source first
        -- and then to configure again to set the remaining parameters
        wConfig.addNumberField("thresholdDown", widget.source:minimum(), widget.source:maximum(), THRESHOLD_PRECISION)
        wConfig.addNumberField("thresholdUp", widget.source:minimum(), widget.source:maximum(), THRESHOLD_PRECISION)
    else
        wConfig.addNumberField("thresholdUp", -THRESHOLD_RANGE, THRESHOLD_RANGE, THRESHOLD_PRECISION)
        wConfig.addNumberField("thresholdDown", -THRESHOLD_RANGE, THRESHOLD_RANGE, THRESHOLD_PRECISION)
    end

    -- Font size
    wConfig.addChoiceField("fontSizeIndex", FONT_SIZE_SELECTION)

    -- Title
    wConfig.startPanel("Title")
    wConfig.addBooleanField("titleShow")
    wConfig.addTextField("titleText")
    wConfig.addBooleanField("titleColorUse")
    wConfig.addColorField("titleBgColor")
    wConfig.addColorField("titleTxColor")
    wConfig.endPanel()

    -- All states (with text, background color and text color)
    addConfigBlock(STATE.DOWN)   -- down
    addConfigBlock(STATE.MIDDLE) -- middle
    addConfigBlock(STATE.UP)     -- up

    -- Debug mode
    wConfig.addBooleanField("debugMode")

    -- Placeholder Information
    wConfig.startPanel("PlaceholderInfo")
    wConfig.addStaticText("PlaceholderName", "_n")
    wConfig.addStaticText("PlaceholderText", "_t")
    wConfig.addStaticText("PlaceholderValue", "_v")
    wConfig.addStaticText("PlaceholderFloat", "_<N>v")
    wConfig.addStaticText("PlaceholderBreak", "_b")
    wConfig.addStaticText("PlaceholderSpecial", "__")
    wConfig.endPanel()

    -- Widget Info
    wConfig.startPanel("WidgetInfo")
    wConfig.addStaticText("WidgetInfoName", STR("WidgetName"))
    wConfig.addStaticText("Version", WIDGET_VERSION)
    wConfig.addStaticText("Author", WIDGET_AUTOR)
    wConfig.endPanel()
end

------------------------------------------------------------------------------------------------------------------------
--- Handler to write (save) the widget configuration.
local function write(widget)
    local debug = wHelper.Debug:new(widget.no, "write"):info()
    wStorage.init({ storage = storage, widget = widget })

    -- write widget version number for user data format
    local versionNumber = wHelper.versionStringToNumber(WIDGET_VERSION)
    debug:info(string.format("store version %s (%d)", WIDGET_VERSION, versionNumber))
    storage.write("Version", versionNumber)

    -- Source and source switch
    wStorage.write("source")

    -- title show, text, background color and text color
    wStorage.write("titleShow")
    wStorage.write("titleText")
    wStorage.write("titleBgColor")
    wStorage.write("titleTxColor")
    wStorage.write("titleColorUse")

    -- state thresholds and font size
    wStorage.write("thresholdDown")
    wStorage.write("thresholdUp")
    wStorage.write("fontSizeIndex")

    -- state text, background color and text color
    for stateIndex = STATE.DOWN, STATE.UP do
        storage.write("StateText" .. stateIndex, widget.states[stateIndex].text)
        storage.write("StateBgColor" .. stateIndex, widget.states[stateIndex].bgColor)
        storage.write("StateTxColor" .. stateIndex, widget.states[stateIndex].txColor)
    end

    -- debug mode
    wStorage.write("debugMode")
end

------------------------------------------------------------------------------------------------------------------------
--- Handler to read (load) the widget configuration.
local function read(widget)
    local titlePrefix = ""
    local debug = wHelper.Debug:new(widget.no, "read"):info()
    wStorage.init({ storage = storage, widget = widget })

    -- check first field Version number ( storage of the version number only introduced with version 1.1.0)
    local firstField = storage.read("Version")
    local versionNumber = 10000 --- date source version number , default: 10000 (version 1.0.0)

    if firstField == nil or type(firstField) ~= "number" then
        debug:info("no version found -> set to Version 1.0.0 (010000)")
        versionNumber = 10000
    else
        versionNumber = firstField
        debug:info("found version: " .. tostring(versionNumber))
    end

    if versionNumber == 10000 then
        --  Version == 1.0.0.: no version number stored -> first field is source
        widget.source = firstField
    else
        -- Version > 1.0.0 first field is version number -> read source
        wStorage.read("source")
    end

    if versionNumber < 20000 then
        -- Version < 2.0.0: read ol value "SourceShow"
        local showSource = storage.read("SourceShow")
        if showSource then
            titlePrefix = "_n: "
        end
        debug:info("version < 2.0.0 -> SourceShow = " ..
            tostring(showSource) .. ", titlePrefix = '" .. titlePrefix .. "'")
    end

    -- title text, background color and text color
    wStorage.read("titleShow")
    wStorage.read("titleText")
    wStorage.read("titleBgColor")
    wStorage.read("titleTxColor")
    wStorage.read("titleColorUse")
    widget.titleText = titlePrefix .. widget.titleText

    -- state thresholds and font size
    wStorage.read("thresholdDown")
    wStorage.read("thresholdUp")
    wStorage.read("fontSizeIndex")

    -- state text, background color and text color
    for stateIndex = STATE.DOWN, STATE.UP do
        widget.states[stateIndex].text = storage.read("StateText" .. stateIndex)       -- state text
        widget.states[stateIndex].bgColor = storage.read("StateBgColor" .. stateIndex) -- background color
        widget.states[stateIndex].txColor = storage.read("StateTxColor" .. stateIndex) -- text color
    end

    -- debug mode
    wStorage.read("debugMode")
end

local function menu(widget)
    local CATEGORY_LUA = 29
    if wHelper.existSource(widget.source) and widget.source.reset then
        local category = widget.source:category()
        if
            category == CATEGORY_TIMER or
            category == CATEGORY_TELEMETRY_SENSOR or
            category == CATEGORY_LUA
        then
            return {
                {string.format(STR("SourceReset"), widget.source:name()),
                function()
                widget.source:reset()
                end},
            }
        end
    end
end
------------------------------------------------------------------------------------------------------------------------
--- Initialize the widget (register it in the system).
local function init()
    wHelper.Debug:new(0, "init")
    system.registerWidget({
        key = WIDGET_KEY,
        name = name,
        wakeup = wakeup,
        create = create,
        paint = paint,
        configure = configure,
        read = read,
        write = write,
        menu=menu,
        title = false
    })
end

------------------------------------------------------------------------------------------------------------------------
--- Module main
------------------------------------------------------------------------------------------------------------------------
warn("@on")
initLibraries()

return { init = init }
