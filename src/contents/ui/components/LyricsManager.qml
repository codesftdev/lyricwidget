import QtQuick

QtObject {
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

    onTitleChanged: fetchLyrics()
    onArtistsChanged: fetchLyrics()
    onAlbumChanged: fetchLyrics()
    onDurationChanged: fetchLyrics()

    onPositionChanged: updateCurrentLine()

    function cacheKey() {
        return `${artists}|${title}|${album}|${duration}`
    }

    function fetchLyrics() {
        if (!title || !artists) {
            currentLineText = ""
            hasLyrics = false
            isLoading = false
            return
        }

        const key = cacheKey()
        if (lyricsCache[key]) {
            hasLyrics = true
            isLoading = false
            updateCurrentLine()
            return
        }

        // Don't fetch if already loading the same key
        if (isLoading && _currentFetchKey === key) {
            return
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

        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isLoading = false
                _currentFetchKey = ""
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
        xhr.open("GET", url)
        xhr.send()
    }

    function addToCache(key, lyrics) {
        // Simple LRU: if cache too big, remove oldest entries
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
        // Match [mm:ss.xx] or [mm:ss.xxx] where xx/xxx can be 2-3 digits
        const lineRegex = /^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$/
        const textLines = lrcText.split('\n')

        for (let i = 0; i < textLines.length; i++) {
            const match = textLines[i].match(lineRegex)
            if (match) {
                const minutes = parseInt(match[1])
                const seconds = parseInt(match[2])
                // Pad to 3 digits to treat as milliseconds
                const fractionStr = match[3].padEnd(3, '0')
                const fraction = parseInt(fractionStr)
                const timeMs = (minutes * 60 + seconds) * 1000 + fraction
                const text = match[4].trim()
                // Skip empty lines for display purposes
                if (text.length > 0) {
                    lines.push({ time: timeMs, text: text })
                }
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
