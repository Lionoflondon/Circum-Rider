# Plugins provide their consumer rules; keep application rules narrowly scoped.
# Flutter resolves its generated plugin registrant by reflection at startup.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
