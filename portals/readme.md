# Power Pages Solutions

This folder contains Power Pages solutions (portals) that are designed for government use cases. These solutions include portal configurations, web templates, and other components specific to Power Pages.

Power Pages solutions work similarly to regular Dataverse solutions but are specifically designed for external-facing websites and portals that allow external users to interact with government services and data.

## Naming Policy

**IMPORTANT**: When creating portal solutions, always include the word "Portal" in the solution name to avoid name collisions with regular modules.

For example:
- ✅ "Event Management Portal" (good)
- ❌ "Event Management" (bad - could collide with the main Event Management module)

This policy ensures that portal solutions have unique solution names and won't conflict with existing or future regular modules in the repository.

## Solution Structure

Each Power Pages solution follows the same structure as other solutions in this repository:
- `src/` - Contains the solution components
- `releases/` - Contains packaged solution files
- `*.cdsproj` - Visual Studio project file for the solution

## Usage

Use the `.scripts\New-Module.ps1` script and select "portals" to create a new Power Pages solution template. Remember to include "Portal" in your solution name!