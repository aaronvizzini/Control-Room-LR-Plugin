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

local handleMessage
local sendSpecificSettings
local startServer
local lastKnownTempMin;

--remove and test w/o
local updateParam

cr = {VALUE_TYPES = {}, PICKUP_ENABLED = true, SERVER = {} } 

-- handle an incoming message, either update the appropriate development value or execute a command
function handleMessage(message)
        
    local prefix, typeValue = message:match("(%S+):(%S+)")
    local typeStr, value = typeValue:match("(%S+),(%S+)")
        
    if (prefix == 'ValueType') then
        for _, valueType in ipairs(VALUE_TYPES) do
            if(valueType == typeStr) then
                LrDevelopController.setValue(valueType, (tonumber(value)))
            end
        end
    end

    if (prefix == 'CMD') then
        if(typeValue == 'library' or typeValue == 'develop') then
            LrApplicationView.switchToModule( typeValue )
        end

        if(typeValue == 'connected') then
            sendAllSettings()
        end
    end
end
--end handleMessage

-- send all of the development values to the app
function sendAllSettings()
    lastKnownTempMin = 0
    
    --sendTempRange()
    --sendVersionNumber()
    
    for _, valueType in ipairs(VALUE_TYPES) do
        cr.SERVER:send(string.format('ValueType:%s,%g\r\n', valueType, LrDevelopController.getValue(valueType)))  -- sends 
    end
end
-- end sendAllSettings

-- send the specific updated development value change made locally to the app
function sendSpecificSettings( observer )
    for _, valueType in ipairs(VALUE_TYPES) do
        if(observer[valueType] ~= LrDevelopController.getValue(valueType)) then
            cr.SERVER:send(string.format('ValueType:%s,%g\r\n', valueType, LrDevelopController.getValue(valueType)))  -- sends  string followed by value
            observer[valueType] = LrDevelopController.getValue(valueType)
        end
       
        sendTempRange()
    end
end
-- end sendSpecificSettings

-- send the temp range for the photo to the app
function sendTempRange()
    local tempMin, tempMax = LrDevelopController.getRange( 'Temperature' )
    local tintMin, tintMax = LrDevelopController.getRange( 'Tint')
    
    if (lastKnownTempMin ~= tempMin) then
        lastKnownTempMin = tempMin
        cr.SERVER:send(string.format('%s %g %g \r\n', 'TempRange', tempMin, tempMax))  -- sends string followed by value\
        cr.SERVER:send(string.format('%s %g %g \r\n', 'TintRange', tintMin, tintMax))
    end
end
-- end sendTempRange

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

        LrDevelopController.addAdjustmentChangeObserver( context, cr.VALUE_TYPES, sendSpecificSettings )

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
--LrTasks.startAsyncTask( function()
    --  LrShell.openFilesInApp({_PLUGIN.path..'/info.lua'}, _PLUGIN.path..'/Control\ Room.app') 
--  end)
-- end open the control room server app
