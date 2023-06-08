#Include JXON_ahk2\_JSON.ahk

; ------------------------------------------------------------------------------
;                                   CONFIG
; ------------------------------------------------------------------------------

DEFAULT_HOST := "localhost"
DEFAULT_PORT := 3333

; ------------------------------------------------------------------------------
;                                   HELPERS
; ------------------------------------------------------------------------------

class RestClient {

    __New(base_url) {
        This.DefaultBaseUrl := base_url
    }

    ; Send an HTTP request with the given method to the given url and endpoint, with the given data.
    ; METHOD base_url/endpoint { data }
    Http(method, endpoint, data := Map(), base_url := This.DefaultBaseUrl) {
        url := base_url . endpoint

        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(method, url, true)

        ; If any data is provided, include it in the request body, as JSON.
        if data.Count > 0 {
            whr.SetRequestHeader("Content-Type", "application/json")
            data := Jxon_Dump(data)
            whr.Send(data)
        }
        ; Otherwise just send the request with an empty body.
        else
            whr.Send()

        whr.WaitForResponse()

        if whr.Status != 200
            MsgBox "Error connecting to Kenku Remote:" . whr.StatusText . "\n" . whr.ResponseText

        return whr
    }

    Get(endpoint) {
        whr := This.Http("GET", endpoint)
        ; GET endpoints in the Kenku Remote API return a JSON body listing the results.
        ; Parse the JSON and return the results.
        text := whr.ResponseText
        results := Jxon_Load(&text)
        return results
    }

    Put(endpoint, data := Map()) {
        whr := This.Http("PUT", endpoint, data)
        ; PUT endpoints in the Kenku Remote API don't return much of interest.
        ; Just return the whole http request in case the caller wants to inspect anything.
        return whr
    }

    Post(endpoint) {
        whr := This.Http("POST", endpoint)
        ; POST endpoints in the Kenku Remote API neither accept data nor return a useful response.
        ; Just return the whole http request in case the caller wants to inspect anything.
        return whr
    }
}


; ------------------------------------------------------------------------------
;                                   REMOTE
; ------------------------------------------------------------------------------

; Provides access to the Kenku Remote interface.
; https://www.kenku.fm/docs/using-kenku-remote
class KenkuRemote {

    __New(host := DEFAULT_HOST, port := DEFAULT_PORT) {
        This.Host := host
        This.Port := port

        ; The base URL for the Kenku Remote API, e.g.:
        ;   http://localhost:3333/v1
        This.BaseUrl := "http://" . This.Host . ":" . This.Port . "/v1"

        This.RestClient := RestClient(This.BaseUrl)

        This.Soundboard := KenkuRemote.SoundboardClient(This.RestClient)
        This.Playlist := KenkuRemote.PlaylistClient(This.RestClient)
    }

    ; Stop all sounds on the soundboard, and pause the currently playing playlist.
    StopAll() {
        This.Soundboard.StopAll()
        This.Playlist.Pause()
    }

    ; Provides access to the Kenku Soundboard interface.
    class SoundboardClient {
        __New(rest_client) {
            This.RestClient := rest_client
        }

        Get() {
            return This.RestClient.Get("/soundboard")
        }

        Play(id) {
            return This.RestClient.Put("/soundboard/play", Map("id", id))
        }

        Stop(id) {
            return This.RestClient.Put("/soundboard/stop", Map("id", id))
        }

        ; Stop all currently playing sounds.
        StopAll() {
            PlaybackState := This.GetPlaybackState()
            for Sound in PlaybackState.Get("sounds") {
                This.Stop(Sound.Get("id"))
            }
        }

        GetPlaybackState() {
            return This.RestClient.Get("/soundboard/playback")
        }
    }

    ; Provides access to the Kenku Playlist interface.
    class PlaylistClient {
        __New(rest_client) {
            This.RestClient := rest_client
        }

        Get() {
            return This.RestClient.Get("/playlist")
        }

        Play(id) {
            return This.RestClient.Put("/playlist/play", Map("id", id))
        }

        GetPlaybackState() {
            return This.RestClient.Get("/playlist/playback")
        }

        Unpause() {
            return This.RestClient.Put("/playlist/playback/play")
        }

        Pause() {
            return This.RestClient.Put("/playlist/playback/pause")
        }

        TogglePause() {
            PlaybackState := This.GetPlaybackState()
            if PlaybackState.Get("playing")
                return This.Pause()
            else
                return This.Unpause()
        }

        NextTrack() {
            return This.RestClient.Post("/playlist/playback/next")
        }

        PreviousTrack() {
            return This.RestClient.Post("/playlist/playback/previous")
        }

        Mute(muted := true) {
            ; AHK doesn't have booleans, so it represents `false` as 0 and `true` as 1.
            ; Jxon uses "true" and "false" to avoid mistakenly reporting a "bool" as an int
            mute_setting := muted ? "true" : "false"

            return This.RestClient.Put("/playlist/playback/mute", Map("mute", mute_setting))
        }

        Unmute() {
            return This.Mute(false)
        }

        ToggleMute() {
            PlaybackState := This.GetPlaybackState()
            if PlaybackState.Get("muted")
                return This.Unmute()
            else
                return This.Mute()
        }

        SetVolume(volume) {
            return This.RestClient.Put("/playlist/playback/volume", Map("volume", volume))
        }

        Shuffle(shuffle := true) {
            ; AHK doesn't have booleans, so it represents `false` as 0 and `true` as 1.
            ; Jxon uses "true" and "false" to avoid mistakenly reporting a "bool" as an int
            shuffle_setting := shuffle ? "true" : "false"

            return This.RestClient.Put("/playlist/playback/shuffle", Map("shuffle", shuffle_setting))
        }

        Unshuffle() {
            return This.ShufflePlaylist(false)
        }

        ToggleShuffle() {
            PlaybackState := This.GetPlaybackState()
            if PlaybackState.Get("shuffle")
                return This.Unshuffle()
            else
                return This.Shuffle()
        }

        Repeat(repeat := "playlist") {
            return This.RestClient.Put("/playlist/playback/repeat", Map("repeat", repeat))
        }

        RepeatTrack() {
            return This.RepeatPlaylist("track")
        }

        Unrepeat() {
            return This.RepeatPlaylist("off")
        }

        ToggleRepeat(repeat := "playlist") {
            PlaybackState := This.GetPlaybackState()
            if PlaybackState.Get("repeat") == repeat
                This.Unrepeat()
            else
                This.Repeat(repeat)
        }

        ToggleRepeatTrack() {
            return This.ToggleRepeat("track")
        }

        VolumeChange(offset := 0.10) {
            PlaybackState := This.GetPlaybackState()
            Volume := PlaybackState.Get("volume")
            NewVolume := Volume + offset
            if NewVolume > 1.0
                NewVolume := 1.0
            if NewVolume < 0.0
                NewVolume := 0.0
            return This.SetVolume(NewVolume)
        }

        VolumeDown() {
            return This.VolumeChange(-0.10)
        }

        VolumeUp() {
            return This.VolumeChange(0.10)
        }
    }
}


; ------------------------------------------------------------------------------
;                                   HOTKEYS
; ------------------------------------------------------------------------------

Kenku := KenkuRemote()

; Ctrl-Alt-[1,2,3]
^!1::Kenku.Playlist.PreviousTrack()
^!2::Kenku.Playlist.TogglePause()
^!3::Kenku.Playlist.NextTrack()

; Alt-[1,2,3]
!1::Kenku.Playlist.VolumeDown()
!2::Kenku.Playlist.ToggleMute()
!3::Kenku.Playlist.VolumeUp()

; Custom Playlists and Sounds
PLAYLIST_A := "b95afdf2-1c73-402d-ab3c-5789f416bc13"
PLAYLIST_B := "37d7dc72-3dc8-44f4-92bf-a01d56a74785"

^!4::Kenku.Playlist.Play(PLAYLIST_A)
^!5::Kenku.Playlist.Play(PLAYLIST_B)

SOUND_A := "7b928806-9ade-414e-9872-ffa8dca04282"
SOUND_B := "8e8c5d85-4ebf-455b-b9a4-b91cb132a0da"

^!6::Kenku.Soundboard.Play(SOUND_A)
^!7::Kenku.Soundboard.Stop(SOUND_A)

^!8::Kenku.Soundboard.Play(SOUND_B)
^!9::Kenku.Soundboard.Stop(SOUND_B)

^!0::Kenku.StopAll()
