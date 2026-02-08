const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fivem-standalone-radiov2';

const radioEl = document.getElementById('radio');
const closeBtn = document.getElementById('close');
const urlInput = document.getElementById('url');
const playBtn = document.getElementById('play');
const pauseBtn = document.getElementById('pause');
const prevBtn = document.getElementById('prev');
const nextBtn = document.getElementById('next');
const shuffleBtn = document.getElementById('shuffle');
const replayBtn = document.getElementById('replay');
const radiusInput = document.getElementById('radius');
const volumeInput = document.getElementById('volume');
const radiusValue = document.getElementById('radiusValue');
const volumeValue = document.getElementById('volumeValue');
const statusEl = document.getElementById('status');

let config = {
    minRadius: 0,
    maxRadius: 400,
    minVolume: 0,
    maxVolume: 100,
    blacklistedWords: []
};

let player = null;
let playerReady = false;
let currentNetId = null;
let currentState = null;
let shuffleEnabled = false;
let replayMode = 0;
let lastEffectiveVolume = 0;
let canControl = false;

const sendNui = (event, data = {}) =>
    fetch(`https://${resourceName}/${event}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    });

const setStatus = (text) => {
    statusEl.textContent = text;
};

const updateReplayLabel = () => {
    const label = replayMode === 1 ? 'Replay: Playlist' : replayMode === 2 ? 'Replay: Song' : 'Replay: Off';
    replayBtn.textContent = label;
};

const updateShuffleLabel = () => {
    shuffleBtn.textContent = shuffleEnabled ? 'Shuffle: On' : 'Shuffle: Off';
};

const parseYouTubeUrl = (url) => {
    try {
        const parsed = new URL(url);
        const host = parsed.hostname.replace('www.', '');
        let videoId = null;
        let playlistId = parsed.searchParams.get('list');

        if (host === 'youtu.be') {
            videoId = parsed.pathname.replace('/', '');
        } else if (host.includes('youtube.com')) {
            if (parsed.pathname === '/watch') {
                videoId = parsed.searchParams.get('v');
            } else if (parsed.pathname.startsWith('/shorts/')) {
                videoId = parsed.pathname.split('/')[2];
            }
        }

        if (playlistId) {
            return { sourceType: 'playlist', videoId, playlistId };
        }

        if (videoId) {
            return { sourceType: 'video', videoId, playlistId: null };
        }
    } catch (error) {
        return null;
    }

    return null;
};

const fetchTitle = async (url) => {
    const response = await fetch(`https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`);
    if (!response.ok) {
        return null;
    }

    const data = await response.json();
    return data.title || null;
};

const isBlacklisted = (title) => {
    if (!title) {
        return false;
    }

    const lower = title.toLowerCase();
    return config.blacklistedWords.some((word) => lower.includes(word.toLowerCase()));
};

const ensurePlayer = () => {
    if (!playerReady || !player) {
        return false;
    }

    return true;
};

const applyPlaybackState = (state, startSeconds = 0) => {
    if (!ensurePlayer()) {
        return;
    }

    if (!state) {
        return;
    }

    currentState = state;

    if (state.sourceType === 'playlist' && state.playlistId) {
        player.loadPlaylist({
            listType: 'playlist',
            list: state.playlistId,
            index: state.currentIndex || 0,
            startSeconds
        });
    } else if (state.videoId) {
        player.loadVideoById({
            videoId: state.videoId,
            startSeconds
        });
    }

    if (state.shuffle !== undefined) {
        player.setShuffle(state.shuffle);
    }

    shuffleEnabled = !!state.shuffle;
    replayMode = state.replayMode || 0;
    updateShuffleLabel();
    updateReplayLabel();

    if (!state.isPlaying) {
        player.pauseVideo();
    }
};

const updateVolume = (volume) => {
    if (!ensurePlayer()) {
        return;
    }

    player.setVolume(volume);
};

const handleListenerUpdate = (payload) => {
    if (!payload || !payload.state) {
        return;
    }

    currentNetId = payload.netId;
    applyPlaybackState(payload.state, payload.state.currentTime || 0);
    updateVolume(payload.effectiveVolume || 0);
    lastEffectiveVolume = payload.effectiveVolume || 0;
};

const handleListenerClear = () => {
    currentNetId = null;
    if (ensurePlayer()) {
        player.stopVideo();
    }
};

const handleRadioAction = (action, payload) => {
    if (!ensurePlayer()) {
        return;
    }

    if (action === 'play') {
        applyPlaybackState(payload, payload.currentTime || 0);
        return;
    }

    if (action === 'pause') {
        if (payload.isPlaying) {
            player.playVideo();
        } else {
            player.pauseVideo();
        }
        return;
    }

    if (action === 'next') {
        player.nextVideo();
        return;
    }

    if (action === 'prev') {
        player.previousVideo();
        return;
    }

    if (action === 'shuffle') {
        shuffleEnabled = payload.shuffle;
        player.setShuffle(shuffleEnabled);
        updateShuffleLabel();
        return;
    }

    if (action === 'replay') {
        replayMode = payload.replayMode || 0;
        updateReplayLabel();
        return;
    }
};

closeBtn.addEventListener('click', () => {
    sendNui('close');
    radioEl.classList.remove('visible');
    canControl = false;
});

playBtn.addEventListener('click', async () => {
    const url = urlInput.value.trim();
    if (!url) {
        setStatus('Enter a YouTube URL or playlist.');
        return;
    }

    const parsed = parseYouTubeUrl(url);
    if (!parsed) {
        setStatus('Invalid YouTube URL.');
        return;
    }

    setStatus('Checking blacklist...');
    const title = await fetchTitle(url);
    if (isBlacklisted(title) || isBlacklisted(url)) {
        setStatus('Blocked by blacklist.');
        return;
    }

    setStatus('Loading...');

    sendNui('playUrl', {
        ...parsed,
        currentIndex: 0,
        currentTime: 0,
        shuffle: shuffleEnabled,
        replayMode
    });
});

pauseBtn.addEventListener('click', () => {
    if (!ensurePlayer()) {
        return;
    }

    const state = player.getPlayerState();
    const isPlaying = state !== window.YT.PlayerState.PAUSED && state !== window.YT.PlayerState.ENDED;
    const currentTime = player.getCurrentTime();

    sendNui('togglePause', {
        isPlaying: !isPlaying,
        currentTime
    });
});

nextBtn.addEventListener('click', () => {
    sendNui('nextTrack');
});

prevBtn.addEventListener('click', () => {
    sendNui('prevTrack');
});

shuffleBtn.addEventListener('click', () => {
    shuffleEnabled = !shuffleEnabled;
    updateShuffleLabel();
    sendNui('toggleShuffle', { shuffle: shuffleEnabled });
});

replayBtn.addEventListener('click', () => {
    replayMode = (replayMode + 1) % 3;
    updateReplayLabel();
    sendNui('toggleReplay', { replayMode });
});

radiusInput.addEventListener('input', () => {
    radiusValue.textContent = radiusInput.value;
});

volumeInput.addEventListener('input', () => {
    volumeValue.textContent = volumeInput.value;
});

radiusInput.addEventListener('change', () => {
    sendNui('updateSettings', {
        radius: Number(radiusInput.value),
        volume: Number(volumeInput.value)
    });
});

volumeInput.addEventListener('change', () => {
    sendNui('updateSettings', {
        radius: Number(radiusInput.value),
        volume: Number(volumeInput.value)
    });
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.type) {
        return;
    }

    if (data.type === 'setVisible') {
        if (data.visible) {
            radioEl.classList.add('visible');
            canControl = true;
        } else {
            radioEl.classList.remove('visible');
            canControl = false;
        }
        return;
    }

    if (data.type === 'stateUpdate') {
        const state = data.state;
        if (!state) {
            return;
        }

        radiusInput.value = state.radius ?? radiusInput.value;
        volumeInput.value = state.volume ?? volumeInput.value;
        radiusValue.textContent = radiusInput.value;
        volumeValue.textContent = volumeInput.value;
        shuffleEnabled = !!state.shuffle;
        replayMode = state.replayMode || 0;
        updateShuffleLabel();
        updateReplayLabel();
        setStatus(state.isPlaying ? 'Playing' : 'Paused');
        return;
    }

    if (data.type === 'listenerUpdate') {
        handleListenerUpdate(data);
        return;
    }

    if (data.type === 'listenerClear') {
        handleListenerClear();
        return;
    }

    if (data.type === 'radioAction') {
        handleRadioAction(data.action, data.payload);
    }
});

window.onYouTubeIframeAPIReady = function () {
    player = new window.YT.Player('player', {
        height: '1',
        width: '1',
        playerVars: {
            autoplay: 0,
            controls: 0,
            rel: 0,
            fs: 0,
            modestbranding: 1
        },
        events: {
            onReady: () => {
                playerReady = true;
                sendNui('requestConfig').then(async (response) => {
                    const data = await response.json();
                    config = data;
                    radiusInput.min = config.minRadius;
                    radiusInput.max = config.maxRadius;
                    volumeInput.min = config.minVolume;
                    volumeInput.max = config.maxVolume;
                });
            },
            onStateChange: (event) => {
                if (!canControl) {
                    return;
                }

                if (!currentState) {
                    currentState = {};
                }

                if (event.data === window.YT.PlayerState.PLAYING) {
                    const currentIndex = player.getPlaylistIndex ? player.getPlaylistIndex() : 0;
                    const currentTime = player.getCurrentTime();
                    const currentVideoId = player.getVideoData().video_id;

                    sendNui('syncState', {
                        sourceType: currentState.sourceType,
                        playlistId: currentState.playlistId,
                        videoId: currentVideoId,
                        currentIndex,
                        currentTime,
                        isPlaying: true
                    });

                    setStatus('Playing');
                }

                if (event.data === window.YT.PlayerState.PAUSED) {
                    setStatus('Paused');
                }

                if (event.data === window.YT.PlayerState.ENDED) {
                    if (replayMode === 2) {
                        if (player.getPlaylist()) {
                            const index = player.getPlaylistIndex();
                            player.playVideoAt(index);
                        } else {
                            player.playVideo();
                        }
                        return;
                    }

                    if (replayMode === 1) {
                        const playlist = player.getPlaylist();
                        if (playlist && playlist.length > 0) {
                            const index = player.getPlaylistIndex();
                            if (index === playlist.length - 1) {
                                player.playVideoAt(0);
                            }
                        }
                    }
                }
            }
        }
    });
};
