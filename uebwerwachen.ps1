$sfolder = "c:\temp\test"
$timeout = 10
$FileSystemWatcher

$FileSystemWatcher = New-Object System.IO.FileSystemWatcher $sfolder

while ($true) {
    $result = $FileSystemWatcher.WaitForChanged('all', $timeout)
    if ($result.TimedOut -eq $false) {
        Write-Warning ('File {0} : {1}' -f $result.Changetype, $result.name)
}
}
Write-Host "Monitoring abgebrochen"

