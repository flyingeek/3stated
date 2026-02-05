------------------------------------------------------------------------------------------------------------------------
---  Widget Paint Functions
------------------------------------------------------------------------------------------------------------------------
---
---  wPaint library with functions for painting title, footer and center text in the widget:
---
---    init(parameters)
---    text(text, fontSize, horizontalAlign, verticalAlign, shiftLine)
---    title(titleText, titleBGColor, titleTxColor)
---    footer(footerText, footerBGColor, footerTxColor)
---    widgetText(widgetText, fontSize, horizontalAlign, verticalAlign, shiftLine)
---    return function(parameters)
---
---  Version:                 1.1.0
---  Development Environment: Ethos X20S Simulator Version 1.6.3
---  Test Environment:        FrSky Tandem X20 | Ethos 1.6.3 EU
---
---  Author: Andreas Kuhl (https://github.com/andreaskuhl)
---  License: GPL 3.0
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--- Modul locals (constants, variables, ...)
------------------------------------------------------------------------------------------------------------------------

-- library structure
local wPaint = {
    titleHeight   = 0, -- height of title box
    footerHeight  = 0, -- height of footer box

    -- Vertical alignment constants for function wPaint.text()
    FREE_ABOVE    = 2, -- pixel free space at above
    FREE_BELOW    = 2, -- pixel free space below
    FREE_LEFT     = 6, -- pixel free space at left
    FREE_RIGHT    = 6, -- pixel free space at right
    LINE_TOP      = 1, -- align top
    LINE_CENTERED = 2, -- align middle (vertical centered)
    LINE_BOTTOM   = 3, -- align bottom

    -- Transparency Box offset (to show that widget has the Focus)
    TRANSPARENCY_X_OFFSET = 1, -- left and right offset
    TRANSPARENCY_Y_OFFSET = 1, -- top and bottom offset
}                      -- library structure

--  required libraries
local helper = {} -- helper library

-- config parameters
local widget = { height = 0, width = 0 } -- widget size structure

-----------------------------------------------------------------------------------------------------------------------
--- Init with actual form and widget
function wPaint.init(parameters)
    widget.height       = parameters.widgetHeight
    widget.width        = parameters.widgetWidth
    wPaint.titleHeight  = 0
    wPaint.footerHeight = 0
end

---------------------------------------------------------------------------------------------------------------------
--- Paint text in the widget.
--- Parameters:
---   text           : text to draw (string)
---   fontSize       : font size (FONT_XS, FONT_S, FONT_L, FONT_STD, FONT_XL, FONT_XXL) - default: FONT_STD
---   horizontalAlign: horizontal alignment (TEXT_LEFT, TEXT_CENTERED, TEXT_RIGHT) - default: TEXT_CENTERED
---   verticalAlign  : vertical alignment (LINE_TOP, LINE_CENTERED, LINE_BOTTOM) - default: LINE_CENTERED
---   shiftLine      : shift line (example: 0 = no shift, -1 = one line up, 0.5 = half line down) - default: 0
--------------------------------------------------------------------------------------------------------------------
function wPaint.text(text, fontSize, horizontalAlign, verticalAlign, shiftLine)
    local textWidth, textHeight -- text width and height
    local textPosY              -- text y position

    if not helper.existText(text) then return end
    if not fontSize then fontSize = FONT_STD end
    if not horizontalAlign then horizontalAlign = wPaint.TEXT_CENTERED end
    if not verticalAlign then verticalAlign = wPaint.LINE_CENTERED end
    if not shiftLine then shiftLine = 0 end

    lcd.font(fontSize) -- set font size
    _, textHeight = lcd.getTextSize("")

    if verticalAlign == wPaint.LINE_TOP then        -- align top
        textPosY = wPaint.TRANSPARENCY_Y_OFFSET + wPaint.FREE_ABOVE + wPaint.titleHeight
    elseif verticalAlign == wPaint.LINE_BOTTOM then -- align bottom
        textPosY = (widget.height - textHeight - wPaint.footerHeight - wPaint.FREE_BELOW - wPaint.TRANSPARENCY_Y_OFFSET)
    else                                            -- align centered (default)
        -- textPosY = wPaint.FREE_ABOVE +
        --     ((widget.height - wPaint.titleHeight - wPaint.FREE_ABOVE - wPaint.footerHeight - wPaint.FREE_BELOW) / 2 - textHeight / 2) +
        --     wPaint.titleHeight

        local boxTop = wPaint.titleHeight + wPaint.FREE_ABOVE + wPaint.TRANSPARENCY_Y_OFFSET
        local boxHeight = widget.height - wPaint.FREE_BELOW - wPaint.footerHeight - wPaint.TRANSPARENCY_Y_OFFSET - boxTop
        local boxMiddle = boxTop + boxHeight / 2
        textPosY = boxMiddle - textHeight / 2
    end

    textPosY = textPosY + (shiftLine * textHeight) -- shift line

    if horizontalAlign == TEXT_LEFT then
        lcd.drawText(wPaint.FREE_LEFT + wPaint.TRANSPARENCY_X_OFFSET, textPosY, text, TEXT_LEFT)
    elseif horizontalAlign == TEXT_RIGHT then
        lcd.drawText(widget.width - wPaint.FREE_RIGHT - wPaint.TRANSPARENCY_X_OFFSET, textPosY, text, TEXT_RIGHT)
    else
        lcd.drawText((widget.width / 2), textPosY, text, TEXT_CENTERED)
    end
end

--------------------------------------------------------------------------------------------------------------------
--- Paint title text.
function wPaint.title(titleText, titleBGColor, titleTxColor)
    local titleHeight

    -- reset title height
    wPaint.titleHeight = 0

    -- calculate title box height an draw box
    lcd.font(FONT_S)
    _, titleHeight = lcd.getTextSize("")
    titleHeight = wPaint.FREE_ABOVE + titleHeight + wPaint.FREE_BELOW

    lcd.color(titleBGColor)
    lcd.drawFilledRectangle(wPaint.TRANSPARENCY_X_OFFSET, wPaint.TRANSPARENCY_Y_OFFSET, widget.width - (2 * wPaint.TRANSPARENCY_X_OFFSET), titleHeight - wPaint.TRANSPARENCY_Y_OFFSET)

    --- draw title text
    lcd.color(titleTxColor)
    wPaint.text(titleText, FONT_S, TEXT_CENTERED, wPaint.LINE_TOP, 0)

    wPaint.titleHeight = titleHeight
end

--------------------------------------------------------------------------------------------------------------------
--- Paint footer text.
function wPaint.footer(footerText, footerBGColor, footerTxColor)
    local footerHeight

    -- reset footer height
    wPaint.footerHeight = 0

    -- calculate footer box height an draw box
    lcd.font(FONT_XS)
    _, footerHeight = lcd.getTextSize("")
    footerHeight = footerHeight + wPaint.FREE_BELOW

    if footerBGColor ~= nil then
        footerHeight = wPaint.FREE_ABOVE + footerHeight
        lcd.color(footerBGColor)
        lcd.drawFilledRectangle(wPaint.TRANSPARENCY_X_OFFSET, widget.height - footerHeight - (2 * wPaint.TRANSPARENCY_Y_OFFSET), widget.width - (2 * wPaint.TRANSPARENCY_X_OFFSET), widget.height - (2 * wPaint.TRANSPARENCY_Y_OFFSET))
    end
    --- draw footer text
    lcd.color(footerTxColor)
    wPaint.text(footerText, FONT_XS, TEXT_CENTERED, wPaint.LINE_BOTTOM, 0)

    wPaint.footerHeight = footerHeight
end

--------------------------------------------------------------------------------------------------------------------
---  wPaint multiline widget text
function wPaint.widgetText(widgetText, fontSize, horizontalAlign, verticalAlign, shiftLine)
    -- local debug = helper.Debug:new(0, "wPaint.widgetText")
    local lines = helper.splitLines(widgetText)
    local n = #lines

    if not shiftLine then shiftLine = 0 end
    lcd.font(fontSize)
    for i, line in ipairs(lines) do
        local localShiftLine = -n / 2 - 0.5 + i + shiftLine
        -- debug:info(string.format("localShiftLine: %.2f | line: %s | lineIndex: %d", localShiftLine, line, i))
        wPaint.text(line, fontSize, horizontalAlign, verticalAlign, localShiftLine)
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Library settings and export
return function(parameters)
    helper = parameters.wHelper

    return wPaint
end
