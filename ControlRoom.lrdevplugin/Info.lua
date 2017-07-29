return {
    LrSdkVersion = 6.0,
    LrToolkitIdentifier = 'com.adobe.cr',
    LrPluginName = 'Control Room',
    LrInitPlugin = 'cr.lua', 
    LrForceInitPlugin = true,
    LrExportMenuItems = {
        {
            title = "Start Control Room",
            file = "cr.lua"
        },  
    },
    VERSION = { major=1, minor=0, revision=0}
}
