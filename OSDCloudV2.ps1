$ErrorActionPreference = 'Stop'

Deploy-OSDCloud `
    -CLI `
    -OperatingSystem 'Windows 11 26H2' `
    -OSEdition 'Education' `
    -OSActivation 'Volume' `
    -OSLanguageCode 'en-us'

Restart-Computer -Force
