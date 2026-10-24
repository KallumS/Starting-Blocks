# Starting Blocks as a VST3 and CLAP plugin (MIDI out). The window is
# reascripts/Starting Blocks.lua, unchanged, run by an embedded Lua on a
# stand-in for ReaImGui (source/ImGuiLua.cpp); lua/sb_place.lua stands in for
# the REAPER half. Build with plugin/build.sh, which fetches JUCE, Lua and
# Dear ImGui first.
cmake_minimum_required(VERSION 3.22)
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "")
if(APPLE)
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "")
endif()
project(StartingBlocksPlugin VERSION 1.0.0 LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)

# ---- what this plugin is -----------------------------------------------------
set(PLUG_NAME "Starting Blocks")
set(PLUG_SCRIPT "Starting Blocks.lua")
set(PLUG_CODE "StBl")
set(PLUG_ID "com.kallums.starting-blocks")
# ------------------------------------------------------------------------------

set(DEPS "${CMAKE_CURRENT_SOURCE_DIR}/deps")
add_subdirectory("${DEPS}/JUCE" juce EXCLUDE_FROM_ALL)
add_subdirectory("${DEPS}/clap-juce-extensions" clap-juce-extensions EXCLUDE_FROM_ALL)

juce_add_plugin(StartingBlocks
    PRODUCT_NAME "${PLUG_NAME}"
    COMPANY_NAME "KallumS"
    BUNDLE_ID "${PLUG_ID}"
    PLUGIN_MANUFACTURER_CODE "Klms"
    PLUGIN_CODE "${PLUG_CODE}"
    DESCRIPTION "The smallest useful pieces of music, played into your song"
    FORMATS VST3 Standalone                 # the standalone app is only for checking the window
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    VST3_CATEGORIES Fx Generator
    COPY_PLUGIN_AFTER_BUILD FALSE)

# The window script and its modules; the plugin's sb_place.lua and imgui.lua
# replace the REAPER ones.
file(GLOB SCRIPTS "${CMAKE_CURRENT_SOURCE_DIR}/../reascripts/*.lua")
list(FILTER SCRIPTS EXCLUDE REGEX "sb_place\\.lua$")
juce_add_binary_data(Scripts SOURCES ${SCRIPTS}
    "${CMAKE_CURRENT_SOURCE_DIR}/lua/sb_place.lua"
    "${CMAKE_CURRENT_SOURCE_DIR}/lua/imgui.lua")

# Lua 5.4, built as C++ so an error raised inside ImGui unwinds cleanly
add_library(lua STATIC "${DEPS}/lua/onelua.c")
set_source_files_properties("${DEPS}/lua/onelua.c" PROPERTIES LANGUAGE CXX)
target_compile_definitions(lua PUBLIC MAKE_LIB $<$<NOT:$<BOOL:${WIN32}>>:LUA_USE_POSIX>)
target_include_directories(lua PUBLIC "${DEPS}/lua")
set_target_properties(lua PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Dear ImGui
add_library(imgui STATIC
    "${DEPS}/imgui/imgui.cpp" "${DEPS}/imgui/imgui_draw.cpp"
    "${DEPS}/imgui/imgui_tables.cpp" "${DEPS}/imgui/imgui_widgets.cpp")
target_include_directories(imgui PUBLIC "${DEPS}/imgui" "${CMAKE_CURRENT_SOURCE_DIR}/source")
target_compile_definitions(imgui PUBLIC IMGUI_USER_CONFIG="sb_imconfig.h")
set_target_properties(imgui PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_sources(StartingBlocks PRIVATE
    source/Plugin.cpp source/Session.cpp source/ImGuiLua.cpp)
target_compile_definitions(StartingBlocks PUBLIC
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0
    SB_SCRIPT="${PLUG_SCRIPT}")
target_link_libraries(StartingBlocks
    PRIVATE
        Scripts lua imgui
        juce::juce_audio_processors
        juce::juce_audio_utils
        juce::juce_gui_basics
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_warning_flags)

clap_juce_extensions_plugin(TARGET StartingBlocks
    CLAP_ID "${PLUG_ID}"
    CLAP_FEATURES note-effect utility
    CLAP_PROCESS_EVENTS_RESOLUTION_SAMPLES 32)

# A smoke test with no host (test/smoke.cpp): build.sh with EXTRA_TARGETS=sb_smoke
add_executable(sb_smoke EXCLUDE_FROM_ALL test/smoke.cpp)
target_link_libraries(sb_smoke PRIVATE StartingBlocks)
# JUCE's modules are compiled into StartingBlocks; borrow its headers and flags
target_include_directories(sb_smoke PRIVATE $<TARGET_PROPERTY:StartingBlocks,INCLUDE_DIRECTORIES>)
target_compile_definitions(sb_smoke PRIVATE $<TARGET_PROPERTY:StartingBlocks,COMPILE_DEFINITIONS>)
