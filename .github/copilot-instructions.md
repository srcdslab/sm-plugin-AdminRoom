# AdminRoom Plugin - Copilot Instructions

## Repository Overview

This repository contains the **AdminRoom** plugin for SourceMod, designed for Counter-Strike: Source and Counter-Strike: Global Offensive zombie escape servers. The plugin provides admin room teleportation and stage management functionality for zombie escape maps.

### Core Functionality
- **Admin Room Detection**: Automatically detects admin rooms using configurable keywords
- **Player Teleportation**: Teleports players to admin rooms with anti-stuck mechanisms
- **Stage Management**: Allows admins to change map stages/levels through triggers
- **Map-Specific Configuration**: Per-map configuration files for admin room locations and stages

## Technical Architecture

### Main Components

1. **AdminRoom.sp** (1040 lines) - Main plugin file containing:
   - Command handlers (`sm_adminroom`, `sm_stage`, `sm_adminroom_reloadcfg`)
   - Auto-detection logic for admin rooms
   - Player teleportation with anti-stuck mechanics
   - Configuration file parsing
   - Menu system for admin room selection

2. **Include Files**:
   - `AdminRoom.inc` - Simple shared plugin definition
   - `CAdminRoom.inc` - Complex methodmap classes defining data structures:
     - `CAdminRoomLocation` - Admin room coordinates and names
     - `CTrigger` - Stage trigger key-value pairs
     - `CAction` - Stage actions (commands to execute)
     - `CStage` - Complete stage definitions
     - `CAdminRoom` - Main container class

3. **Configuration System**:
   - `adminroom.cfg` - Global auto-detection keywords
   - `maps/*.cfg` - Per-map configurations with admin room locations and stages

### Dependencies
- **SourceMod 1.11+** - Core scripting platform
- **multicolors** - Chat color formatting
- **outputinfo** - Entity output information
- **basic** - Base class system for methodmaps
- **utilshelper** - Utility functions

## Development Guidelines

### Code Style (Repository-Specific)
```sourcepawn
// Use tabs for indentation (4 spaces)
// Global variables prefixed with g_
int g_fPlayerOrigin[MAXPLAYERS+1][3];
ArrayList g_cAdminRoomLocationsDetected = null;

// PascalCase for functions
public void OnPluginStart()

// camelCase for local variables
int menuSelected[MAXPLAYERS+1] = { 0, ... };

// Use methodmaps for object-oriented design
CAdminRoom g_AdminRoom = null;
```

### Memory Management Patterns
```sourcepawn
// Always use delete without null checks (plugin convention)
delete g_cAdminRoomLocationsDetected;
g_cAdminRoomLocationsDetected = new ArrayList();

// Never use .Clear() - causes memory leaks
// Instead: delete and recreate
```

### Configuration File Format
```
// adminroom.cfg - Auto-detection keywords
"AutoDetect"
{
    "admin"     { "name" "admin" }
    "stage"     { "name" "stage" }
    "level"     { "name" "level" }
}

// maps/mapname.cfg - Map-specific configuration
"AdminRoom"
{
    "adminrooms"
    {
        "0"
        {
            "name"      "Admin Room"
            "origin"    "x y z"
        }
    }
    "stages"
    {
        "Stage1"
        {
            "triggers"
            {
                "0" { "key" "case_01" "value" "stage1" }
            }
            "actions"
            {
                "0" { "key" "case_01" "identifier" "OnCase01" "event" "FireUser1" }
            }
        }
    }
}
```

## Build System

### SourceKnight Configuration
The project uses **SourceKnight** (`sourceknight.yaml`) for:
- Dependency management (automatically downloads SourceMod, includes)
- Build compilation
- Package creation

### Build Commands
```bash
# Install SourceKnight (if not available)
pip install sourceknight

# Build the plugin
sourceknight build

# Clean build artifacts
sourceknight clean
```

### CI/CD Pipeline
- **Trigger**: Push, PR, or manual dispatch
- **Build**: Compiles plugin using SourceKnight action
- **Release**: Creates tagged releases with compiled binaries
- **Artifacts**: Uploads build results for testing

## Common Development Tasks

### Adding New Admin Room Detection Keywords
1. Edit `addons/sourcemod/configs/adminroom/adminroom.cfg`
2. Add new keyword in AutoDetect section
3. Test with `sm_adminroom_reloadcfg` command

### Adding Map-Specific Configuration
1. Create `addons/sourcemod/configs/adminroom/maps/mapname.cfg`
2. Use lowercase map name for filename
3. Define admin room locations and stages
4. Test in-game with the map loaded

### Modifying Methodmap Classes
1. Edit `addons/sourcemod/scripting/include/CAdminRoom.inc`
2. Follow existing patterns for get/set methods
3. Use `Basic` class inheritance for data storage
4. Ensure proper memory management in main plugin

### Debugging Common Issues

#### Plugin Not Loading
- Check dependencies are installed
- Verify SourceMod version compatibility (1.11+)
- Check logs for compilation errors

#### Admin Rooms Not Detected
- Verify map configuration file exists and is named correctly
- Check auto-detection keywords in adminroom.cfg
- Use `sm_adminroom_reloadcfg` to reload configurations
- Check entity outputs using outputinfo extension

#### Stage Changes Not Working
- Verify stage triggers are correctly configured
- Check map-specific stage definitions
- Ensure trigger key-value pairs match entity outputs
- Test with developer console enabled

## Testing Guidelines

### Manual Testing
1. Load a configured map
2. Test `sm_adminroom` command with multiple admin rooms
3. Test `sm_stage` command to change stages
4. Verify anti-stuck mechanisms work correctly
5. Test configuration reload functionality

### Configuration Validation
```sourcepawn
// Check for configuration errors in logs
ConVar sm_adminroom_debug = CreateConVar("sm_adminroom_debug", "0");

// Test auto-detection
PrintToChatAll("Detected %d admin rooms", g_cAdminRoomLocationsDetected.Length);
```

## File Organization

```
addons/sourcemod/
├── scripting/
│   ├── AdminRoom.sp              # Main plugin
│   └── include/
│       ├── AdminRoom.inc         # Plugin definition
│       └── CAdminRoom.inc        # Data structures
├── configs/adminroom/
│   ├── adminroom.cfg             # Auto-detection keywords
│   └── maps/                     # Map-specific configs
│       └── mapname.cfg
└── plugins/
    └── AdminRoom.smx             # Compiled plugin
```

## Performance Considerations

### Optimization Patterns
- Cache admin room locations after detection
- Use ArrayList for dynamic collections
- Minimize timer usage (anti-stuck system only)
- Avoid string operations in frequently called functions
- Use methodmaps for O(1) property access

### Memory Management
```sourcepawn
// Plugin uses Basic class system for methodmaps
// Always delete ArrayLists and StringMaps properly
delete arrayList;  // Don't check for null first

// Create new instances instead of clearing
arrayList = new ArrayList();
```

## Integration Points

### External Dependencies
- **multicolors**: Chat message formatting
- **outputinfo**: Entity output monitoring
- **basic**: Methodmap base class system
- **utilshelper**: Common utility functions

### Plugin Natives/Forwards
- Check `AdminRoom.inc` for available natives
- Plugin provides shared library for other plugins
- Use `GetFeatureStatus(FeatureType_Native, "AdminRoom_*")` to check availability

## Version Information
- **Current Version**: 2.1.4
- **SourceMod Requirement**: 1.11+
- **Supported Games**: CS:S, CS:GO
- **Authors**: IT-KILLER, BotoX, maxime1907, .Rushaway

This plugin follows modern SourcePawn development practices and maintains backward compatibility while leveraging advanced features like methodmaps and proper memory management.