tell application "System Events"
    -- Get the application named Y
    set appProcess to application process "Mavis AAC"

    -- Find the window named X
    set targetWindow to (first window of appProcess whose name is "Mavis AAC SharePlay")

    -- Get the zoom button (the green maximize button)
    set zoomButton to button 2 of targetWindow

    -- Perform the 'showMenu' action on the zoom button
    perform action "AXShowMenu" of zoomButton

    key code 126
    key code 126
    keystroke return
end tell

-- https://en.wikibooks.org/wiki/AppleScript_Programming/System_Events
