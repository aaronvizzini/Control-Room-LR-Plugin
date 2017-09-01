require 'Value_Types.lua' 

local LrApplication = import 'LrApplication'
local LrApplicationView = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrSelection = import 'LrSelection'
local LrShell = import 'LrShell'
local LrSocket = import 'LrSocket'
local LrTasks = import 'LrTasks'
local LrUndo = import 'LrUndo'

local handleMessage
local sendSpecificSettings
local startServer
local lastKnownTempMin
local sendTempTintRanges
local sendStarRating

--remove and test w/o
local updateParam

--observers
cr = {VALUE_TYPES = {}, PICKUP_ENABLED = true, SERVER = {} }
photoChangeObserver = 0

local receivedType
local receivedValue

-- handle an incoming message, either update the appropriate development value or execute a command
function handleMessage(message)
        
    local prefix, typeValue = message:match("(%S+):(%S+)")
    local typeStr, value = typeValue:match("(%S+),(%S+)")
        
    if (prefix == 'ValueType') then
        for _, valueType in ipairs(VALUE_TYPES) do
            if(valueType == typeStr) then
                receivedType = valueType
                receivedValue = (tonumber(value))
                
                LrDevelopController.setValue(valueType, (tonumber(value)))
            end
        end
    end
    
    if (prefix == 'Preset') then        
        local preset = LrApplication.developPresetByUuid( typeValue )
        local activeCatalog = LrApplication.activeCatalog()

        LrTasks.startAsyncTask (function ()
            activeCatalog:withWriteAccessDo ("Apply Preset", function ()
                activeCatalog:getTargetPhoto():applyDevelopPreset(preset)
            end, {timeout = 15})
        end)
    end

    if (prefix == 'CMD') then
        if(typeValue == 'requestVersion') then
            cr.SERVER:send(string.format('Version:%s\r\n', '1.4'))
        end
        
        if(typeValue == 'library' or typeValue == 'develop') then
            LrApplicationView.switchToModule( typeValue )
            
            if (typeValue == 'library') then
                sendStarRating( nil )
            end
        end

        if(typeValue == 'reset') then
            LrDevelopController.resetAllDevelopAdjustments()
        end
        
        if(typeValue == 'sendAllSettings') then
            sendAllSettings()
        end
        
        if(typeValue == 'requestPresets') then
            sendDeveloperPresets()
        end 
        
        if(typeValue == 'getStarRating') then
            sendStarRating( nil )
        end 
        
        if(typeValue == 'undo') then
            if(LrUndo.canUndo()) then
                LrUndo.undo()
            end
        end 
        
        if(typeValue == 'redo') then
            if(LrUndo.canRedo()) then
                LrUndo.redo()
            end 
        end 
        
        if(typeValue == 'forward') then
            LrSelection.nextPhoto()
        end 
        
        if(typeValue == 'backward') then
            LrSelection.previousPhoto()
        end 
        
        if(typeValue == 'flagSave') then
            LrSelection.flagAsPick()
        end 
        
        if(typeValue == 'flagDelete') then
            LrSelection.flagAsReject()
        end 
        
        if(typeValue == 'unflag') then
            LrSelection.removeFlag()
        end
        
        if(typeValue == 'starZero') then
            LrSelection.setRating(0)
        end 
        
        if(typeValue == 'starOne') then
            LrSelection.setRating(1)
        end 
        
        if(typeValue == 'starTwo') then
            LrSelection.setRating(2)
        end 
        
        if(typeValue == 'starThree') then
            LrSelection.setRating(3)
        end 
        
        if(typeValue == 'starFour') then
            LrSelection.setRating(4)
        end 
        
        if(typeValue == 'starFive') then
            LrSelection.setRating(5)
        end 
    end
end
--end handleMessage

-- called when the Lightroom photo selection changes
function sendStarRating( observer )
    receivedType = ""
    receivedValue = -999999
            
    local starRating = ''
    local activeCatalog = LrApplication.activeCatalog()
    local targetPhoto = activeCatalog:getTargetPhoto()
    
    LrTasks.startAsyncTask (function ()
        if targetPhoto ~= nil then 
            starRating = targetPhoto:getFormattedMetadata('rating')
            
            if starRating ~= nil then 
                    cr.SERVER:send(string.format('ValueType:%s,%s\r\n', 'StarRating', starRating))
            end
                
            if starRating == nil then 
                cr.SERVER:send(string.format('ValueType:%s,%s\r\n', 'StarRating', 0))
            end
        end
    end)
        
end
--end sendStarRating
    
-- send all of the development values to the app
function sendAllSettings()
    lastKnownTempMin = 0
    
    sendTempTintRanges()
    
    for _, valueType in ipairs(VALUE_TYPES) do
        cr.SERVER:send(string.format('ValueType:%s,%g\r\n', valueType, LrDevelopController.getValue(valueType)))  -- sends 
    end
end
-- end sendAllSettings

-- send the specific updated development value change made locally to the app
function sendSpecificSettings( observer )
    sendTempTintRanges() -- Was at LOC A - Problem?
    
    for _, valueType in ipairs(VALUE_TYPES) do
        -- LOC A
        if(observer[valueType] ~= LrDevelopController.getValue(valueType)) then
            if( (valueType ~= receivedType) or (tostring(LrDevelopController.getValue(valueType)) ~= tostring(receivedValue)) ) then
                cr.SERVER:send(string.format('ValueType:%s,%g\r\n', valueType, LrDevelopController.getValue(valueType)))  -- sends  string followed by value
                
                receivedType = ""
                receivedValue = -999999
            end
            
            observer[valueType] = LrDevelopController.getValue(valueType)
        end 
    end
end
-- end sendSpecificSettings

-- send the temp and tint range for the photo to the app
function sendTempTintRanges()
    local tempMin, tempMax = LrDevelopController.getRange( 'Temperature' )
    local tintMin, tintMax = LrDevelopController.getRange( 'Tint')
    
    if (lastKnownTempMin ~= tempMin) then
        lastKnownTempMin = tempMin
        cr.SERVER:send(string.format('TempRange:%g,%g\r\n', tempMin, tempMax))
        cr.SERVER:send(string.format('TintRange:%g,%g\r\n', tintMin, tintMax))
    end
end
-- end sendTempTintRanges

-- send developer presets
function sendDeveloperPresets()
    local presetFolders = LrApplication.developPresetFolders()
    
    for i, folder in ipairs( presetFolders ) do
        
        local presets = folder:getDevelopPresets()
        
        for i2, preset in ipairs( presets ) do
            --send preset
            --LrDialogs.message(folder:getName(), preset:getUuid(),nil)
            cr.SERVER:send(string.format('Preset:%s,%s,%s\r\n', folder:getName(), preset:getName(), preset:getUuid()))
        end
    end
end
-- end sendDeveloperPresets

-- start send server
function startServer(context)
    cr.SERVER = LrSocket.bind {
    functionContext = context,
    plugin = _PLUGIN,
    port = 54347,
    mode = 'send',
    onClosed = function( socket ) 
        end,
    onError = function( socket, err )
            socket:reconnect()
        end,
    }
end
-- end startServer

-- main, start receive server
LrTasks.startAsyncTask( function()
    LrFunctionContext.callWithContext( 'start_servers', function( context )
        LrDevelopController.revealAdjustedControls( true ) -- reveal affected parameter in panel track

        LrApplication.addActivePhotoChangeObserver( context, photoChangeObserver, sendStarRating )

        --Adjustment change observer can only be added when in the develop module. Therefore, we briefly switch to the develop module add the observer and switch back to the previously module 
        local oldModule = LrApplicationView.getCurrentModuleName()
        LrApplicationView.switchToModule( 'develop' )
                
        if LrApplicationView.getCurrentModuleName() == 'develop' then
            LrDevelopController.addAdjustmentChangeObserver( context, cr.VALUE_TYPES, sendSpecificSettings )
        end

        LrApplicationView.switchToModule( oldModule )
                
        local client = LrSocket.bind {
            functionContext = context,
            plugin = _PLUGIN,
            port = 54346,
            mode = 'receive',
            
            onConnecting = function( socket, port )
                --LrDialogs.message("Connecting","connecting",nil)
            end,
            
            onConnected = function( socket, port )
                --LrDialogs.message("Connected","connected",nil)
            end,
            
            onMessage = function(socket, message)
                handleMessage(message)
            end,
            
            onClosed = function( socket )
                --socket:reconnect()
                cr.SERVER:close()
                --startServer(context)
            end,
                    
            onError = function(socket, err)
                if err == 'timeout' then 
                    socket:reconnect()
                end
            end
        }

        startServer(context)

        while true do
           LrTasks.sleep( 1/2 )
        end

        client:close()
        cr.SERVER:close()
    end )
end )
-- end main

-- open the control room server app
LrTasks.startAsyncTask( function()
   LrShell.openFilesInApp({_PLUGIN.path..'/info.lua'}, _PLUGIN.path..'/Control\ Room\ Server.app') 
   LrDevelopController.revealAdjustedControls(false)
end)
-- end open the control room server app