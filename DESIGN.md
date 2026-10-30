---
name: Avgang
description: Live Entur departures for your stops in the macOS menu bar.
colors:
  board-navy: "#181C56"
  band-navy: "#11143C"
  lavender: "#AEB7E2"
  coral: "#FF5959"
  canary: "#FFE082"
  rule: "rgba(255, 255, 255, 0.08)"
typography:
  stop-header:
    fontFamily: "SF Pro"
    fontSize: "16pt"
    fontWeight: 600
  destination:
    fontFamily: "SF Pro"
    fontSize: "15pt"
    fontWeight: 400
  time-realtime:
    fontFamily: "SF Pro"
    fontSize: "17pt"
    fontWeight: 600
    fontFeature: "tnum"
  time-scheduled:
    fontFamily: "SF Pro"
    fontSize: "17pt"
    fontWeight: 500
    fontFeature: "tnum"
  meta:
    fontFamily: "SF Pro"
    fontSize: "13pt"
    fontWeight: 400
    fontFeature: "tnum"
  badge:
    fontFamily: "SF Pro"
    fontSize: "15pt"
    fontWeight: 700
    fontFeature: "tnum"
  chip:
    fontFamily: "SF Pro"
    fontSize: "12pt"
    fontWeight: 400
  menu-bar-line:
    fontFamily: "SF Pro"
    fontSize: "11pt"
    fontWeight: 700
    fontFeature: "tnum"
  menu-bar-time:
    fontFamily: "SF Pro"
    fontSize: "13pt"
    fontWeight: 500
    fontFeature: "tnum"
rounded:
  board: "16px"
  badge: "6px"
  field: "7px"
  chip: "4px"
spacing:
  side: "14px"
  row: "40px"
  band: "6px"
  rule: "1px"
  section-top: "12px"
  section-bottom: "4px"
  row-gap: "10px"
  settings-pad: "16px"
components:
  board-panel:
    backgroundColor: "{colors.board-navy}"
    rounded: "{rounded.board}"
    width: "344px"
  departure-row:
    typography: "{typography.destination}"
    padding: "0 14px"
    height: "{spacing.row}"
  stop-header:
    typography: "{typography.stop-header}"
    height: "26px"
  line-badge:
    typography: "{typography.badge}"
    rounded: "{rounded.badge}"
    padding: "0 6px"
    height: "26px"
    width: "34px"
  platform-chip:
    textColor: "{colors.lavender}"
    typography: "{typography.chip}"
    rounded: "{rounded.chip}"
    padding: "0 4px"
    height: "18px"
  menu-bar-label:
    typography: "{typography.menu-bar-time}"
    height: "22px"
  settings-search-field:
    rounded: "{rounded.field}"
    padding: "0 8px"
    height: "28px"
---

# Design System: Avgang

## Overview

Avgang is a departure board in a popover. The board is an opaque navy panel taken from Entur's own boards, and it stays dark whatever the system appearance is. Each stop is a block of rows: line badge, destination, platform, time. The only saturated color on the board comes from the line badges and from status (delay, cancellation, disruption). Settings is a plain macOS preferences window with grouped forms and no custom styling beyond the shared badge and chip.

**Key Characteristics:**
- An always-dark navy board, 344px wide.
- Line colors come from the operator, not from the app.
- Rows are separated by hairlines, stops by a darker band.
- Every changing number uses monospaced digits.
- Native settings that follow the system appearance.

## Colors

The board uses four fixed colors plus white text. All saturated color beyond those comes from the transit data.

### Primary
- **Board navy**: the board background and the app icon fill. It is Entur's navy and the product's main brand commitment.

### Secondary
- **Coral**: the word Cancelled in place of a time.
- **Canary**: delay minutes (`+3`) next to the time, and the disruption notice line with its warning triangle.

### Neutral
- **Band navy**: the 6pt band between two stops.
- **Lavender**: secondary text on the board. That covers the stop's mode or location icon, walking time or distance, scheduled-only times, empty and offline messages, and the platform chip outline and text.
- **Rule**: 1pt hairlines above each row, notice and footer.
- White is the primary text on the board. Settings use the system hierarchy (primary, secondary, separator) and the system accent.

### Named Rules
**The Operator Color Rule.** A line badge's fill is the operator's `presentation.colour` from Entur, and its text is the operator's `presentation.textColour`. If the operator gives a fill but no text color, the text is white. If the operator gives no fill, the badge uses the Entur mode color (metro #F08901, tram #B482FB, bus and coach #FF6392, rail #42A5F5, water #6FDFFF, any other mode lavender) with board navy text. Never hard-code a line's color in the app.

**The Status Color Rule.** Coral means cancelled and canary means late or disrupted. Neither is used for anything else on the board.

## Typography

**Font:** the system font (SF Pro) at fixed point sizes on the board and in the menu bar label. Settings use system text styles (body, callout, caption).

### Hierarchy
- **Stop header** (16pt semibold): the stop name, one line, truncated at the tail.
- **Time** (17pt): the largest text in a row, so the answer to "when" reads first.
- **Destination** (15pt regular): one line, truncated at the tail.
- **Badge** (15pt bold, 13pt in settings): the line code.
- **Meta** (13pt): walking time, distance, notices and board messages.
- **Chip** (12pt): platform codes, and the 12pt semibold delay minutes.

### Named Rules
**The Steady Digits Rule.** Every number that changes over time uses monospaced digits: countdowns, delays, line codes, walking time, distance and the menu bar label.

**The Realtime Rule.** A realtime time is white and semibold. A time with no realtime data is lavender, medium weight and prefixed with `ca.`.

## Layout

The board is 344px wide with 14px side padding and grows to fit its stops. A stop starts 12px below the band, with a 26px header and 4px under it, then one 40px row per departure, and 4px after the last row. Rows have 10px between items: a 38px badge column, the destination filling the rest, an optional platform chip and a time column at least 64px wide, aligned right. The footer is 8px by 6px with the settings gear (28 by 24px) at the trailing edge and the offline message at the leading edge.

The panel sits 1pt below the menu bar and 4pt left of the status item, at least 8pt from the screen edges. Settings is a 640px wide toolbar-tab window. The Stops tab is 460px tall, split into a 250px list column with 16px padding and a grouped form for the selected stop. The other tabs are grouped forms sized to their content.

## Elevation & Depth

The board is opaque and flat inside, with no glass, gradient or translucency. The panel window carries the standard macOS window shadow so it lifts off the desktop. Depth inside the board comes only from the darker band between stops and the hairline rules between rows.

## Shapes

The board has 16px corners. Line badges have 6px corners, and platform chips and the menu bar line box have 4px corners. The settings search field and its results list have 7px corners with a separator stroke. Platform chips are outlined at 45% of their tint and never filled.

## Components

### Departure row
Line badge, destination, platform chip and time, 40px tall with a hairline on top. A cancelled departure dims its badge and destination to 55%, strikes through the destination and shows Cancelled in coral instead of a time. A late departure shows the delay minutes in canary before the time. The whole row reads as one accessibility element.

### Stop header
A 14pt lavender icon in an 18px column, the stop name and trailing meta. Favorites show the mode symbol of the stop's first mode and a walking figure with the walking time. Nearby stops show a location arrow and the distance in meters. The first disruption notice for the stop appears under the header in canary, with a warning triangle.

### Line badge
The line code in a filled rounded rectangle, at least 34px wide and 26px tall on the board, 24px tall in settings. Colors follow the Operator Color Rule. In settings, badges are toggles for line filters, and an excluded line drops to 30% opacity.

### Platform chip
The platform code in an outlined box at least 20 by 18px. Lavender on the board, secondary gray in settings.

### Menu bar label
A template image 22pt tall, so macOS tints it for the menu bar. It has three forms: the tram symbol alone, the next departure as the line code in a 1.5pt stroked box followed by the countdown, or a walking figure and the time to leave. Countdowns read `now`, `5 min` or a 24-hour clock time past the clock threshold. A right click or Ctrl-click opens a menu with Settings…, Check for updates…, Refresh now and Quit Avgang.

### Panel behavior
When Open with is set to Hover, the panel opens after the pointer rests 140ms on the status item and closes 50ms after the pointer leaves both item and panel. A click on the item or the global shortcut also opens it, and Escape closes it.

### Settings
Native grouped forms, checkboxes, steppers, pickers and a bordered list in toolbar tabs (Stops, Nearby, Menu Bar, General). The only custom pieces are the stop search field and the shared line badge and platform chip. Explanations sit in the control's secondary label, never in a heading.

### App icon
A solid board navy square with three stylized board rows, each a mode-colored badge (metro, tram, bus) and a lavender bar. It has no glass, no shadow, no translucency and no specular highlight.

## Do's and Don'ts

### Do:
- **Do** keep the board navy and dark in every system appearance.
- **Do** take line colors from Entur's operator data, falling back to the Entur mode colors.
- **Do** use monospaced digits for every changing number.
- **Do** separate stops with the 6pt band and rows with the 1pt rule.
- **Do** use native grouped forms and system colors in settings.

### Don't:
- **Don't** use coral or canary for anything except cancellation, delay and disruption.
- **Don't** add glass, gradients or translucency to the board.
- **Don't** add a title bar or subheading to the board.
- **Don't** use em dashes or middle dot or bullet separators in UI text.
