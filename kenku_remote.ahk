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

        Repeat(repeat := "playlist") {
            return This.RestClient.Put("/playlist/playback/repeat", Map("repeat", repeat))
        }

        RepeatTrack() {
            return This.RepeatPlaylist("track")
        }

        Unrepeat() {
            return This.RepeatPlaylist("off")
        }

    }
}


; ------------------------------------------------------------------------------
;                                   HOTKEYS
; ------------------------------------------------------------------------------

; ; Functions to support:
; - fade in playlist A, B, C, ...
; - play this song only (???)
; - loop current song
; - skip to next song
; - pause / play
; - fade out & stop

Kenku := KenkuRemote()

; Ctrl-Alt-[1,2,3,4]
^!1::Kenku.Playlist.PreviousTrack()
^!2::Kenku.Playlist.Pause()
^!3::Kenku.Playlist.Unpause()
^!4::Kenku.Playlist.NextTrack()
