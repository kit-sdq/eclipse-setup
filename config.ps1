$config = Get-Content -Raw -Path config.json | ConvertFrom-Json
$projects = $config.projects
$git = "git"

function ConvertToKeyStrokes {
    param([int[]]$indices)
    $return = "{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}{ENTER}+{TAB}+{TAB}"
    for ($i = 0; $i -le $indices[$indices.Count-1]; $i++) {
        $a = $indices -contains $i
        if($indices -contains $i) {
            $return += " {DOWN}"
        } else {
            $return += "{DOWN}"
        }
    }
    $return += "{TAB}{TAB}{TAB}{ENTER}"
    return $return
}

# Import project with the gui wizard (because no shell interaction option is available)
add-type -AssemblyName microsoft.VisualBasic
add-type -AssemblyName System.Windows.Forms
$runindex = $true
foreach($project in $projects){
    $projectplugins = $project.projectplugins
    $folder = $project.url -replace '.*/'
    $folder = $folder -replace '.git'
    $localfolder = "$git/$folder"
    
    eclipse/eclipse.exe $localfolder
    Start-Sleep 5
    if($runindex) {
        Start-Sleep 5
        [Microsoft.VisualBasic.Interaction]::AppActivate("Eclipse IDE Launcher")
        Start-Sleep 5
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        $runindex = $false
    }
    Start-Sleep 40            

    # only select the plugins to be imported
    $config = ConvertToKeyStrokes $projectplugins
    [Microsoft.VisualBasic.Interaction]::AppActivate("workspace - Eclipse IDE")
    Start-Sleep 5
    [System.Windows.Forms.SendKeys]::SendWait($config)
    Start-Sleep 20
}
Write-Host "Finished"