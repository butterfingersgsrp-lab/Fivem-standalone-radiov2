local radioStates = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function ensureState(netId)
    if not radioStates[netId] then
        radioStates[netId] = {
            volume = Config.DefaultVolume,
            radius = Config.DefaultRadius,
            isPlaying = false,
            sourceType = 'video',
            videoId = nil,
            playlistId = nil,
            currentIndex = 0,
            currentTime = 0,
            shuffle = false,
            replayMode = 0,
            updatedAt = os.time()
        }
    end

    return radioStates[netId]
end

RegisterNetEvent('radio:requestState', function(netId)
    local state = radioStates[netId]
    if state then
        TriggerClientEvent('radio:sendState', source, netId, state)
    end
end)

RegisterNetEvent('radio:updateSettings', function(netId, data)
    local state = ensureState(netId)

    state.volume = clamp(tonumber(data.volume) or state.volume, Config.MinVolume, Config.MaxVolume)
    state.radius = clamp(tonumber(data.radius) or state.radius, Config.MinRadius, Config.MaxRadius)
    state.updatedAt = os.time()

    TriggerClientEvent('radio:sendState', -1, netId, state)
end)

RegisterNetEvent('radio:playUrl', function(netId, data)
    local state = ensureState(netId)

    state.sourceType = data.sourceType
    state.videoId = data.videoId
    state.playlistId = data.playlistId
    state.currentIndex = data.currentIndex or 0
    state.currentTime = data.currentTime or 0
    state.isPlaying = true
    state.shuffle = data.shuffle or false
    state.replayMode = data.replayMode or 0
    state.updatedAt = os.time()

    TriggerClientEvent('radio:sendState', -1, netId, state)
    TriggerClientEvent('radio:applyAction', -1, netId, 'play', state)
end)

RegisterNetEvent('radio:togglePause', function(netId, data)
    local state = ensureState(netId)
    state.isPlaying = data.isPlaying
    state.currentTime = data.currentTime or state.currentTime
    state.updatedAt = os.time()

    TriggerClientEvent('radio:sendState', -1, netId, state)
    TriggerClientEvent('radio:applyAction', -1, netId, 'pause', {
        isPlaying = state.isPlaying,
        currentTime = state.currentTime
    })
end)

RegisterNetEvent('radio:nextTrack', function(netId)
    TriggerClientEvent('radio:applyAction', -1, netId, 'next', {})
end)

RegisterNetEvent('radio:prevTrack', function(netId)
    TriggerClientEvent('radio:applyAction', -1, netId, 'prev', {})
end)

RegisterNetEvent('radio:toggleShuffle', function(netId, data)
    local state = ensureState(netId)
    state.shuffle = data.shuffle
    state.updatedAt = os.time()

    TriggerClientEvent('radio:sendState', -1, netId, state)
    TriggerClientEvent('radio:applyAction', -1, netId, 'shuffle', {
        shuffle = state.shuffle
    })
end)

RegisterNetEvent('radio:toggleReplay', function(netId, data)
    local state = ensureState(netId)
    state.replayMode = data.replayMode or 0
    state.updatedAt = os.time()

    TriggerClientEvent('radio:sendState', -1, netId, state)
    TriggerClientEvent('radio:applyAction', -1, netId, 'replay', {
        replayMode = state.replayMode
    })
end)

RegisterNetEvent('radio:syncState', function(data)
    local netId = data.netId
    if not netId then
        return
    end

    local state = ensureState(netId)

    state.currentIndex = data.currentIndex or state.currentIndex
    state.videoId = data.videoId or state.videoId
    state.currentTime = data.currentTime or state.currentTime
    state.isPlaying = data.isPlaying
    state.sourceType = data.sourceType or state.sourceType
    state.playlistId = data.playlistId or state.playlistId
    state.updatedAt = os.time()

    TriggerClientEvent('radio:sendState', -1, netId, state)
end)
