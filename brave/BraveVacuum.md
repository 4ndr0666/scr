cd ~/.config/BraveSoftware/Brave-Browser

# Remove cached data directories
rm -rf component_crx_cache extensions_crx_cache Crash Reports Greaselion GrShaderCache ShaderCache GraphiteDawnCache 

# Remove guest profile
rm -rf ~/.config/BraveSoftware/Brave-Browser/Guest\ Profile/*

# Remove Local Traces directory if it contains old logs or unnecessary data
rm -rf Local\ Traces
