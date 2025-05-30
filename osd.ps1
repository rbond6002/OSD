# OSD config

Write-Host -ForegroundColor Green "Starting OSDCloud lite touch (confirm erase disk)"

Start-OSDCloud -OSName 'Windows 11 24H2 x64' -OSLanguage en-us -OSEdition Education -OSActivation Volume -Restart

Read-Host -Prompt "Press Enter to exit"
