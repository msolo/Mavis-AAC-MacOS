set timeoutSeconds to 2.0

tell application "System Settings"
  delay 0.25

  -- Make a selection from the popupbutton.
  set uiScript to "click pop up button 2 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window \"Live Speech\" of application process \"System Settings\""
  my doWithTimeout(uiScript, timeoutSeconds)

  -- Manage Voices…
  delay 0.25
  set uiScript to "click menu item \"Manage Voices…\" of menu 1 of pop up button 2 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window \"Live Speech\" of application process \"System Settings\""
  --  set uiScript to "click menu item 42 of menu 1 of pop up button 2 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window \"Live Speech\" of application process \"System Settings\""
  my doWithTimeout(uiScript, timeoutSeconds)

end tell

on doWithTimeout(uiScript, timeoutSeconds)
  set endDate to (current date) + timeoutSeconds
  repeat
    try
      run script "tell application \"System Events\"
" & uiScript & "
end tell"
      exit repeat
    on error errorMessage
      if ((current date) > endDate) then
        error "Can not " & uiScript
      end if
    end try
  end repeat
end doWithTimeout
