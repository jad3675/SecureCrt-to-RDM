# Get the username of the current user
$currentUsername = $env:USERNAME
 
# Construct the default sessions path using the current username
$defaultSessionsPath = "C:\Users\$currentUsername\appdata\roaming\vandyke\config\sessions"
 
# Prompt user for sessions folder path if not found
do {
    if (Test-Path $defaultSessionsPath) {
        $sessionsPath = $defaultSessionsPath
        break
    } else {
        Write-Host "Sessions folder not found at the default location: $defaultSessionsPath"
        $sessionsPath = Read-Host "Please enter the path to the sessions folder:"
    }
} while (-not (Test-Path $sessionsPath))
 
# Prompt user for the location to dump the CSV file, defaulting to the current directory
$defaultOutputLocation = (Get-Location).Path
$outputLocation = Read-Host "Enter the location to save the CSV file (default: $defaultOutputLocation)"
if ([string]::IsNullOrWhiteSpace($outputLocation)) {
    $outputLocation = $defaultOutputLocation
}
 
# Output CSV file name
$outputCSV = Join-Path -Path $outputLocation -ChildPath "rdm_import.csv"
 
# Array to store session data
$sessionsData = @()
 
# Function to extract session info from a session file
function Extract-SessionInfo {
    param (
        [string]$sessionFile,
        [string]$sessionName,
        [string]$group
    )
    $sessionInfo = New-Object PSObject -Property @{
        'Host' = ""
        'Name' = $sessionName  # Set session name to file name
        'Group' = $group -replace "/", "\"  # Replace forward slashes with backslashes
        'Username' = ""
        'ConnectionType' = "SSH Shell"
    }
 
    try {
        $sessionContent = Get-Content $sessionFile
        foreach ($line in $sessionContent) {
            if ($line -match '^S:"(Username|Password|Login Script V3|LogonDomain|Description|Comment|Hostname)"=(.+)$') {
                $key = $matches[1]
                $value = $matches[2].TrimStart('"').TrimEnd('"')
                switch ($key) {
                    "Hostname" { $sessionInfo.Host = $value }
                    "Username" { $sessionInfo.Username = $value }
                }
            }
        }
    } catch {
        Write-Host "Error reading session file $sessionFile"
    }
    return $sessionInfo
}
 
# Iterate through session files and extract session info
Get-ChildItem -Path $sessionsPath -Filter "*.ini" -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($sessionsPath.Length + 1)  # Get relative path to the session file
    $group = [System.IO.Path]::GetDirectoryName($relativePath).Replace("\", "/")  # Get group from parent directory
    $sessionName = $_.BaseName  # Get file name without extension as session name
    $sessionData = Extract-SessionInfo $_.FullName $sessionName $group
    if ($sessionData -ne $null) {
        $sessionsData += $sessionData
    }
}
 
# Write session data to CSV file with columns in the specified order
$sessionsData | Select-Object @{Name='Host'; Expression={$_.Host}}, @{Name='Name'; Expression={$_.Name}}, @{Name='Group'; Expression={$_.Group}}, @{Name='Username'; Expression={$_.Username}}, @{Name='ConnectionType'; Expression={$_.ConnectionType}} | Export-Csv -Path $outputCSV -NoTypeInformation
