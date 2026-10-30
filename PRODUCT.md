# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

## Stack

Swift 6, SwiftUI inside AppKit, macOS 26 and Swift Package Manager, the same as Peek. Releases are unsigned DMGs on GitHub Releases with Sparkle updates. The license is GPL-3.0.

## Users

Oslo commuters with a Mac who ride Ruter's metro, tram and bus. They look at the menu bar before leaving home, work or campus to see if it is time to go.

## Product Purpose

Avgang shows live departures from your stops and the stops nearest you in the menu bar, using Entur's open API. Success means you no longer unlock your phone to check when to leave.

## Positioning

A native Mac menu bar app for Entur data. The phone apps take an unlock and a few taps, and Avgang takes a glance.

## Operating Context

- Favorites come from Entur's stop search, each with platform, line, walking time and row count filters.
- Nearby shows the closest stops from CoreLocation within a radius.
- The label shows the next departure by default. Icon only and time to leave are settings.
- The popover opens on hover like Peek, or by click or a global shortcut.

## Capabilities and Constraints

- Journey Planner v3 and Geocoder v3, with `ET-Client-Name` on every request.
- Line colors come from the operator through `presentation.colour`.
- UI copy follows the system language, in Norwegian and English.
- Departures you can't reach on foot are hidden, scheduled-only times say ca., and cancellations and disruptions are shown.
- There is no refresh interval setting.

## Brand Commitments

- Entur's navy `#181c56` departure board popover, design A from the design round on 2026-10-30.
- Peek's sibling, with the same build, release and settings patterns.

## Product Principles

1. A glance answers when to leave.
2. Pick, never type. Stops, platforms and lines come from Entur.
3. Show only what you can still catch.
4. No setting where a sensible default works.
