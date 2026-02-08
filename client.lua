local isUiOpen = false
local currentVehicleNetId = nil
local knownRadios = {}
local lastVehicle = nil

local function debugLog(message)
    if Config.Debug then
        print(('[radio] %s'):format(message))
    end
end

local function isPlayerInVehicle()
    local ped = PlayerPedId()
    return IsPedInAnyVehicle(ped, false)
end

local function getPlayerVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return nil
    end

    return GetVehiclePedIsIn(ped, false)
end

local function canUseRadio()
    local vehicle = getPlayerVehicle()
    if not vehicle then
        return false
    end

    return true
end

local function setUiOpen(state)
    isUiOpen = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(state)
    SendNUIMessage({
        type = 'setVisible',
        visible = state
    })
end

local function ensureUiClosed()
    if isUiOpen then
        setUiOpen(false)
        return
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        type = 'setVisible',
        visible = false
    })
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ensureUiClosed()
end)

AddEventHandler('playerSpawned', function()
    ensureUiClosed()
end)

local function openRadio()
    if not canUseRadio() then
        TriggerEvent('chat:addMessage', {
            color = {255, 150, 50},
            args = {'Radio', 'You must be inside a vehicle to use the radio.'}
        })
        return
    end

    local vehicle = getPlayerVehicle()
    currentVehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    setUiOpen(true)

    TriggerServerEvent('radio:requestState', currentVehicleNetId)
end

RegisterCommand(Config.OpenCommand, openRadio, false)
RegisterCommand('+' .. Config.OpenCommand, openRadio, false)
RegisterCommand('-' .. Config.OpenCommand, function() end, false)

RegisterKeyMapping('+' .. Config.OpenCommand, 'Open car radio', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb)
    setUiOpen(false)
    cb('ok')
end)

RegisterNUICallback('requestConfig', function(_, cb)
    cb({
        minRadius = Config.MinRadius,
        maxRadius = Config.MaxRadius,
        minVolume = Config.MinVolume,
        maxVolume = Config.MaxVolume,
        blacklistedWords = Config.BlacklistedWords
    })
end)

RegisterNUICallback('updateSettings', function(data, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:updateSettings', netId, data)
    cb({ok = true})
end)

RegisterNUICallback('playUrl', function(data, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:playUrl', netId, data)
    cb({ok = true})
end)

RegisterNUICallback('togglePause', function(data, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:togglePause', netId, data)
    cb({ok = true})
end)

RegisterNUICallback('nextTrack', function(_, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:nextTrack', netId)
    cb({ok = true})
end)

RegisterNUICallback('prevTrack', function(_, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:prevTrack', netId)
    cb({ok = true})
end)

RegisterNUICallback('toggleShuffle', function(data, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:toggleShuffle', netId, data)
    cb({ok = true})
end)

RegisterNUICallback('toggleReplay', function(data, cb)
    if not canUseRadio() then
        cb({ok = false, error = 'not_in_vehicle'})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerServerEvent('radio:toggleReplay', netId, data)
    cb({ok = true})
end)

RegisterNUICallback('syncState', function(data, cb)
    if not canUseRadio() then
        cb({ok = false})
        return
    end

    local vehicle = getPlayerVehicle()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    data.netId = netId
    TriggerServerEvent('radio:syncState', data)
    cb({ok = true})
end)

RegisterNetEvent('radio:sendState', function(netId, state)
    knownRadios[netId] = state

    if isUiOpen and currentVehicleNetId == netId then
        SendNUIMessage({
            type = 'stateUpdate',
            state = state
        })
    end
end)

RegisterNetEvent('radio:removeState', function(netId)
    knownRadios[netId] = nil
end)

RegisterNetEvent('radio:applyAction', function(netId, action, payload)
    local state = knownRadios[netId]
    if not state then
        state = {}
    end

    knownRadios[netId] = state

    SendNUIMessage({
        type = 'radioAction',
        netId = netId,
        action = action,
        payload = payload
    })
end)

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestNetId = nil
        local nearestDistance = nil

        for netId, state in pairs(knownRadios) do
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(playerCoords - vehicleCoords)

                if distance <= (state.radius or Config.DefaultRadius) then
                    if not nearestDistance or distance < nearestDistance then
                        nearestDistance = distance
                        nearestNetId = netId
                    end
                end
            end
        end

        if nearestNetId then
            local state = knownRadios[nearestNetId]
            local radius = state.radius or Config.DefaultRadius
            local volume = state.volume or Config.DefaultVolume
            local distanceRatio = 1.0
            if radius > 0 then
                distanceRatio = math.max(0.0, 1.0 - (nearestDistance / radius))
            end

            local effectiveVolume = math.floor(volume * distanceRatio)

            SendNUIMessage({
                type = 'listenerUpdate',
                netId = nearestNetId,
                state = state,
                effectiveVolume = effectiveVolume
            })
        else
            SendNUIMessage({
                type = 'listenerClear'
            })
        end

        Wait(500)
    end
end)

CreateThread(function()
    while true do
        local vehicle = getPlayerVehicle()

        if vehicle ~= lastVehicle then
            lastVehicle = vehicle
            if vehicle then
                currentVehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
                TriggerServerEvent('radio:requestState', currentVehicleNetId)
            else
                if isUiOpen then
                    setUiOpen(false)
                end
            end
        end

        Wait(1000)
    end
end)
