﻿#requires -Module EZOut
#                 https://github.com/StartAutomating/EZOut
#              OR Install-Module EZOut   
$myRoot = $MyInvocation.MyCommand.ScriptBlock.File | Split-Path
$myName = 'arm-ttk'


Write-FormatView -Action {
    $testOut = $_

    $h = $MyInvocation.HistoryId
    @(if ($global:_LastHistoryId -ne $h) {
        # New scoppe
        $global:_LastGroup = ''
        $global:_LastFile = ''
        $global:_LastHistoryId = $h
    }

    $CanUseColor = $host.UI.SupportsVirtualTerminal -and -not $ENV:AGENT_ID
    

    if ($global:_LastFile -ne $testOut.File.FullPath) {
        $msg = "Validating $($testOut.File.FullPath | Split-Path | split-Path -Leaf)\$($testOut.File.Name)"
        if ($CanUseColor) {
            . $SetOutputStyle -ForegroundColor Magenta        
            $msg + [Environment]::NewLine
            . $clearOutputStyle
        } else {
            Write-Host -ForegroundColor Magenta -NoNewline $msg
        }
        $global:_LastFile = $testOut.File.FullPath
    }

    if ($global:_LastGroup -ne $testOut.Group) {
        $global:_LastGroup = $testOut.Group
        if ($CanUseColor) {
            . $SetOutputStyle -ForegroundColor Magenta
            "  $($testOut.Group)" + [Environment]::NewLine
            . $clearoutputStyle
        } else {
            Write-Host "  $($testOut.Group)" -ForegroundColor Magenta
        }
    }
    $errorCount = $testOut.Errors.Count
    $warningCount = $testOut.Warnings.Count
    $foregroundColor = 'Green'
    $statusChar = '+'

    
    $errorLines = @(
        foreach ($_ in $testOut.Errors) {
            "$_"
        })
    $warningLines = @(
        foreach ($_ in $testOut.Warnings) {
            "$_"
        }
    )

    

    if ($errorCount) {
        $foregroundColor = if ($CanUseColor) { 'Error' } else { 'Red' }
        $statusChar = '-'        
    } elseif ($warningCount) {
        $foregroundColor = if ($CanUseColor) { 'Warning' } else { 'Yellow' } 
        $statusChar = '?'        
    }
    
    $statusLine = "    [$statusChar] $($testOut.Name) ($([Math]::Round($testOut.Timespan.TotalMilliseconds)) ms)"
    if ($CanUseColor) {
        . $setOutputStyle -ForegroundColor $foregroundColor
        $statusLine
        . $clearOutputStyle
    } else {
        Write-Host $statusLine -NoNewline -ForegroundColor $foregroundColor
    }

    $azoErrorStatus = if ($ENV:Agent_ID) { "##vso[task.logissue type=error;]"} else { '' }
    $azoWarnStatus  = if ($ENV:Agent_ID) { "##vso[task.logissue type=warning;]"} else { '' }
    $indent = 8
    if ($testOut.AllOutput) {
        if (-not $host.UI.SupportsVirtualTerminal) {
            Write-Host ' '
        } else {
            [Environment]::NewLine
        } 
        foreach ($line in $testOut.AllOutput) {
            if ($line -is [Management.Automation.ErrorRecord] -or $line -is [Exception]) {
                $msg = "$azoErrorStatus$(' ' * $indent)$line"
                if ($line.TargetObject -is [Text.RegularExpressions.Match]) {
                    $msg += (" Index:" + $line.TargetObject.Index)
                }

                if ($CanUseColor) {
                    . $setOutputStyle -ForegroundColor Error
                    $msg + [Environment]::NewLine
                    . $ClearOutputStyle
                } else {
                    Write-Host -ForegroundColor Red $msg
                }
            }
            elseif ($line -is [Management.Automation.WarningRecord]) {
                $msg = "$azoWarnStatus$(' ' * $indent)$line"
                if ($CanUseColor) {
                    . $setOutputStyle -ForegroundColor Warning
                    $msg + [Environment]::NewLine
                    . $clearOutputStyle
                } else {
                    Write-Host -ForegroundColor Yellow $msg 
                }
            }
            elseif ($line -is [string]) {
                $msg = "$(' ' * $indent)$line"
                if ($CanUseColor) {
                    $msg
                } else {
                    Write-Host $msg
                }
            }
            else {
                $line | 
                    Out-String -Width ($Host.UI.RawUI.BufferSize.Width - $indent) |
                    & { process {
                        if ($CanUseColor) {
                            "$(' ' * $indent)$_" + [Environment]::NewLine
                        } else {
                            Write-Host "$(' ' * $indent)$_"
                        }
                    } } 
            }
        }
    }) -join ''
} -TypeName 'Template.Validation.Test.Result' |
    Out-FormatData |
    Set-Content -Path (Join-Path $myRoot "$myName.format.ps1xml") -Encoding UTF8
