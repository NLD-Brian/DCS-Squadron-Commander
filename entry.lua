declare_plugin("DCS-SC",
{
	installed 	 = true, 
	dirName	  	 = current_mod_path,
	developerName = _("NLD_Brian"),
	developerLink = _("https://github.com/NLD-Brian/DCS-Squadron-Commander"),
	version		 = "WIP-0.0.1",		 
	state		 = "installed",

	displayName = _("Squadron CommanderS"),
	shortName = 'Squadron Commander',
	fileMenuName = "Squadron Commander",
	info		  = _("This plugin adds the Squadron Commander ACARS system to DCS World. It provides real-time flight data, weather updates, and communication features for virtual pilots."),
    load_immediate = true,
	Skins = {
		{ 
			name = "DCS-SC", 
			dir = "Theme" 
		},
	},
	-- Options = {
	-- 	{ 
	-- 		name = "DCS-SC-ACARS", 
	-- 		nameId = "DCS-SC-ACARS", 
	-- 		dir = "Options", 
	-- 		allow_in_simulation = true; },
	-- },
})

dofile(current_mod_path..'/Scripts/DCS-SC-Main.lua')


plugin_done()