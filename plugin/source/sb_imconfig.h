// Dear ImGui's configuration for the plugin (IMGUI_USER_CONFIG).
#pragma once
// A failed ImGui check while the script runs becomes a Lua error the window
// shows, instead of stopping the DAW (Session.cpp).
void sbImAssertFailed(const char *expr);
#define IM_ASSERT(_EXPR) do { if (!(_EXPR)) sbImAssertFailed(#_EXPR); } while (0)
#define IMGUI_DISABLE_OBSOLETE_FUNCTIONS
#define IMGUI_DISABLE_DEMO_WINDOWS
#define IMGUI_DISABLE_DEBUG_TOOLS
