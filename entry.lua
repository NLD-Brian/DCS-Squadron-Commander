declare_plugin("DCS-SC-ACARS",
{
	installed 	 = true, 
	dirName	  	 = current_mod_path,

	developerName = _("NLD_Brian"),
	developerLink = _("https://github.com/NLD-Brian/DCS-Squadron-Commander"),

	version		 = "0.0.1.0",		 
	state		 = "installed",

	displayName = _("Squadron Commander ACARS"),
	shortName = 'Squadron Commander ACARS',
	fileMenuName = "Squadron Commander ACARS",
	info		  = _("This plugin adds the Squadron Commander ACARS system to DCS World. It provides real-time flight data, weather updates, and communication features for virtual pilots."),
	-- binaries = {"srs.dll"},
    -- load_immediate = true,
	Skins = {
		{ 
			name = "DCS-SC-ACARS", 
			dir = "Theme" 
		},
	},
	Options = {
		{ 
			name = "DCS-SC-ACARS", 
			nameId = "DCS-SC-ACARS", 
			dir = "Options", 
			allow_in_simulation = true; },
	},
})
)
---------------------------------------------------------------------------------------
-- mount_vfs_model_path	(current_mod_path.."/Shapes")
-- mount_vfs_texture_path (current_mod_path.."/Textures/*.zip")
-- mount_vfs_texture_path (current_mod_path.."/Textures")

dofile(current_mod_path..'/Scripts/DCS-SC-Main.lua')


plugin_done()