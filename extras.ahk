; This file contains some random scrap notes I was working with during development.
; It's mostly things I didn't end up using, but felt bad deleting entirely without
; at least committing them first.

; It's probably safe to delete this whole file.


; https://www.autohotkey.com/boards/viewtopic.php?t=107697
JSON_parse(str) {
    htmlfile := ComObject('htmlfile')
    htmlfile.write('<meta http-equiv="X-UA-Compatible" content="IE=edge">')
    return htmlfile.parentWindow.JSON.parse(str)
}

; ; Convert a Map of query param to a single string representing the query params.
; ; Ex. Map("key", "value", "key2", "value2") => "?key=value&key2=value2"
; BuildQueryParams(params) {
;     if params.count == 0
;         return ""

;     i := 0
;     query_str := "?"

;     for key, value in params
;         query_str := query_str . key . "=" . value

;         ; If there is another param coming, join them with &
;         i++
;         if i < params.count
;             query_str := query_str . "&"
;     return query_str
; }



; ; Sync HTTP

; whr := ComObject("WinHttp.WinHttpRequest.5.1")
; whr.Open("GET", "https://www.autohotkey.com/download/2.0/version.txt", true)
; whr.Send()
; ; Using 'true' above and the call below allows the script to remain responsive.
; whr.WaitForResponse()
; version := whr.ResponseText
; MsgBox version


; ; Async HTTP

; req := ComObject("Msxml2.XMLHTTP")
; ; Open a request with async enabled.
; req.open("GET", "https://www.autohotkey.com/download/2.0/version.txt", true)
; ; Set our callback function.
; req.onreadystatechange := Ready
; ; Send the request.  Ready() will be called when it's complete.
; req.send()
; /*
; ; If you're going to wait, there's no need for onreadystatechange.
; ; Setting async=true and waiting like this allows the script to remain
; ; responsive while the download is taking place, whereas async=false
; ; will make the script unresponsive.
; while req.readyState != 4
;     sleep 100
; */
; Persistent

; Ready() {
;     if (req.readyState != 4)  ; Not done yet.
;         return
;     if (req.status == 200) ; OK.
;         MsgBox "Latest AutoHotkey version: " req.responseText
;     else
;         MsgBox "Status " req.status,, 16
;     ExitApp
; }