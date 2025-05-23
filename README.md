travelassistant Script Overview

The travelassistant script is an advanced Lua tool for use with MacroQuest (MQ) and the ImGui UI library, designed to make zone travel in EverQuest easier for Project Lazarus servers.

Key Features:

    Zone Search & Selection:
    Provides a searchable list of all game zones, supporting both long names and shortnames. Includes fuzzy search to catch typos or partial matches.

    User Interface:
    Uses ImGui to present an interactive GUI, allowing users to select expansions, search for zones, and initiate travel with buttons (Start, Pause, End, Group Travel, etc.).

    Travel Automation:
    Automates the /travelto command to send your character to the selected zone. Supports pausing, resuming, and ending travel.

    Group Coordination:
    Integrates with DanNet for broadcasting status and initiating group travel, so all group members can travel together.

    Debugging & Feedback:
    Includes a toggleable debug mode for troubleshooting and prints helpful messages for user actions and errors.

    Customization for Project Lazarus:
    Specifically adapted for Project Lazarus, with support for its unique zone set and quick-travel options.

Typical Usage:
Launch the script through MacroQuest. Use the GUI to search for your destination zone (by name or shortname), select it, and click "Start" to begin automated travel. You can pause/resume, end travel, or initiate group travel as needed.
