import QtQuick

Item {
    id: root

    property string title: ""
    property string artists: ""
    property string album: ""
    property real duration: 0 // microseconds
    property real position: 0 // microseconds

    property string currentLineText: ""
    property bool hasLyrics: false
    property bool isLoading: false

    // In-memory cache: key -> parsed lyrics array
    property var lyricsCache: ({})
    readonly property int maxCacheSize: 50

    property string _currentFetchKey: ""
    property var activeXhr: null

    Timer {
        id: debounceTimer
        interval: 300
        onTriggered: _doFetchLyrics()
    }

    onTitleChanged: debounceTimer.restart()
    onArtistsChanged: debounceTimer.restart()
    onAlbumChanged: debounceTimer.restart()
    onDurationChanged: debounceTimer.restart()

    onPositionChanged: updateCurrentLine()

    function cacheKey() {
        return `${artists}|${title}|${album}|${duration}`
    }

    function fetchLyrics() {
        debounceTimer.restart()
    }

    function _doFetchLyrics() {
        if (!title || !artists) {
            currentLineText = ""
            hasLyrics = false
            isLoading = false
            return
        }

        const key = cacheKey()
        const cached = lyricsCache[key]
        if (Array.isArray(cached) && cached.length > 0) {
            hasLyrics = true
            isLoading = false
            updateCurrentLine()
            return
        }

        // Don't fetch if already loading the same key
        if (isLoading && _currentFetchKey === key) {
            return
        }

        if (activeXhr) {
            try { activeXhr.abort() } catch (e) {}
            activeXhr = null
        }

        _currentFetchKey = key
        isLoading = true
        hasLyrics = false
        currentLineText = ""

        const durationSec = Math.round(duration / 1000000)
        let url = `https://lrclib.net/api/get?` +
            `artist_name=${encodeURIComponent(artists)}&` +
            `track_name=${encodeURIComponent(title)}`

        if (album) {
            url += `&album_name=${encodeURIComponent(album)}`
        }
        if (durationSec > 0) {
            url += `&duration=${durationSec}`
        }

        const requestKey = cacheKey()
        const xhr = new XMLHttpRequest()
        activeXhr = xhr
        xhr.timeout = 10000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (activeXhr === xhr) {
                    activeXhr = null
                }
                isLoading = false
                _currentFetchKey = ""
                if (requestKey !== cacheKey()) {
                    return
                }
                if (xhr.status === 200) {
                    try {
                        const data = JSON.parse(xhr.responseText)
                        if (data.syncedLyrics) {
                            const parsed = parseLRC(data.syncedLyrics)
                            if (parsed.length > 0) {
                                addToCache(key, parsed)
                                hasLyrics = true
                                updateCurrentLine()
                            }
                        } else if (data.plainLyrics) {
                            // Use plain lyrics with pseudo-timing (5s per line)
                            const lines = data.plainLyrics.split('\n').filter(l => l.trim())
                            if (lines.length > 0) {
                                const parsed = lines.map((text, i) => ({
                                    time: i * 5000,
                                    text: text.trim()
                                }))
                                addToCache(key, parsed)
                                hasLyrics = true
                                updateCurrentLine()
                            }
                        }
                    } catch (e) {
                        console.error("Failed to parse lyrics:", e)
                    }
                } else if (xhr.status === 404) {
                    // No lyrics found - cache empty result to avoid repeated 404s
                    addToCache(key, [])
                }
            }
        }
        xhr.ontimeout = function() {
            console.error("Lyrics request timed out for:", requestKey)
        }
        xhr.onerror = function() {
            console.error("Lyrics request failed for:", requestKey)
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("User-Agent", "LyricWidget v4.1.0 (https://github.com/codesftdev/lyricwidget)")
        xhr.send()
    }

    function addToCache(key, lyrics) {
        // Simple FIFO: if cache too big, remove oldest entries
        const keys = Object.keys(lyricsCache)
        if (keys.length >= maxCacheSize) {
            const toRemove = keys.slice(0, keys.length - maxCacheSize + 1)
            for (let i = 0; i < toRemove.length; i++) {
                delete lyricsCache[toRemove[i]]
            }
        }
        lyricsCache[key] = lyrics
    }

    function parseLRC(lrcText) {
        const lines = []
        const tsRegex = /^\[(\d{2}):(\d{2})\.(\d{2,3})\]/
        const textLines = lrcText.split('\n')

        for (let i = 0; i < textLines.length; i++) {
            const line = textLines[i]
            const timestamps = []
            let remaining = line

            while (true) {
                const match = remaining.match(tsRegex)
                if (!match) break
                timestamps.push(match)
                remaining = remaining.substring(match[0].length)
            }

            const text = remaining.trim()
            if (text.length === 0 || timestamps.length === 0) continue

            for (let j = 0; j < timestamps.length; j++) {
                const match = timestamps[j]
                const minutes = parseInt(match[1])
                const seconds = parseInt(match[2])
                // Pad to 3 digits to treat as milliseconds
                const fractionStr = match[3].padEnd(3, '0')
                const fraction = parseInt(fractionStr)
                const timeMs = (minutes * 60 + seconds) * 1000 + fraction
                lines.push({ time: timeMs, text: text })
            }
        }

        return lines.sort((a, b) => a.time - b.time)
    }

    function updateCurrentLine() {
        if (!hasLyrics) {
            currentLineText = ""
            return
        }

        const key = cacheKey()
        const lyrics = lyricsCache[key]
        if (!lyrics || lyrics.length === 0) {
            currentLineText = ""
            return
        }

        const posMs = position / 1000 // convert microseconds to milliseconds

        // Find the current line - binary search would be more efficient but linear is fine for typical lyric counts
        let currentLine = ""
        for (let i = 0; i < lyrics.length; i++) {
            if (lyrics[i].time <= posMs) {
                currentLine = lyrics[i].text
            } else {
                break
            }
        }

        currentLineText = currentLine
    }
}
