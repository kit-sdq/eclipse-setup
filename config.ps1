$config = Get-Content -Raw -Path config.json | ConvertFrom-Json
$projects = $config.projects
$metamodelpositions = $config.metamodelpositions
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

function KeyStrokesForMetamodels {
    param([int[]]$indices)
    #[System.Windows.Forms.SendKeys]::SendWait("^{F7}{UP}{UP}{UP}{UP}")
    [System.Windows.Forms.SendKeys]::SendWait("%-c")
    Start-Sleep 5
    [System.Windows.Forms.SendKeys]::SendWait("{UP}{UP}{UP}{UP}")
    Start-Sleep 5
    for ($i = 0; $i -le $indices[$indices.Count-1]; $i++) {
        if($indices -contains $i) {
            [System.Windows.Forms.SendKeys]::SendWait("~{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}~{DOWN}+{F10}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}~")
            Start-Sleep 5
            [System.Windows.Forms.SendKeys]::SendWait("~")
            Start-Sleep 5
            [System.Windows.Forms.SendKeys]::SendWait("~")
            Start-Sleep 5
            [System.Windows.Forms.SendKeys]::SendWait("~")
            Start-Sleep 10
            [System.Windows.Forms.SendKeys]::SendWait("{TAB}{TAB}{TAB}{TAB}{TAB}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}")
        } else {
            [System.Windows.Forms.SendKeys]::SendWait("{DOWN}")
        }
    }
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

KeyStrokesForMetamodels $metamodelpositions


Write-Host "Finished"