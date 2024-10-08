<#
  .SYNOPSIS
      Starship PowerShell Profile

  .DESCRIPTION
      Use this script to customize your own PowerShel

  .LINK
      https://starship.rs/
#>

Invoke-Expression (&starship init powershell)

# Load special features come from PSReadLine
if (Get-Module PSReadLine) {
    # Searching for commands with up/down arrow is really handy.  The
    # option "moves to end" is useful if you want the cursor at the end
    # of the line while cycling through history like it does w/o searching,
    # without that option, the cursor will remain at the position it was
    # when you used up arrow, which can be useful if you forget the exact
    # string you started the search on.
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    
    # Sometimes you enter a command but realize you forgot to do something else first.
    # This binding will let you save that command in the history so you can recall it,
    # but it doesn't actually execute.  It also clears the line with RevertLine so the
    # undo stack is reset - though redo will still reconstruct the command line.
    Set-PSReadLineKeyHandler -Key Alt+w `
                             -BriefDescription SaveInHistory `
                             -LongDescription "Save current line in history but do not execute" `
                             -ScriptBlock {
        param($key, $arg)
    
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    }

    # This key handler shows the entire or filtered history using Out-GridView. The
    # typed text is used as the substring pattern for filtering. A selected command
    # is inserted to the command line without invoking. Multiple command selection
    # is supported, e.g. selected by Ctrl + Click.
    # As another example, the module 'F7History' does something similar but uses the
    # console GUI instead of Out-GridView. Details about this module can be found at
    # PowerShell Gallery: https://www.powershellgallery.com/packages/F7History.
    Set-PSReadLineKeyHandler -Key F7 `
                             -BriefDescription History `
                             -LongDescription 'Show command history' `
                             -ScriptBlock {
        $pattern = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
        if ($pattern)
        {
            $pattern = [regex]::Escape($pattern)
        }
    
        $history = [System.Collections.ArrayList]@(
            $last = ''
            $lines = ''
            foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath))
            {
                if ($line.EndsWith('`'))
                {
                    $line = $line.Substring(0, $line.Length - 1)
                    $lines = if ($lines)
                    {
                        "$lines`n$line"
                    }
                    else
                    {
                        $line
                    }
                    continue
                }
    
                if ($lines)
                {
                    $line = "$lines`n$line"
                    $lines = ''
                }
    
                if (($line -cne $last) -and (!$pattern -or ($line -match $pattern)))
                {
                    $last = $line
                    $line
                }
            }
        )
        $history.Reverse()
    
        $command = $history | Out-GridView -Title History -PassThru
        if ($command)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
        }
    }

    # F1 for help on the command line - naturally
    Set-PSReadLineKeyHandler -Key F1 `
                             -BriefDescription CommandHelp `
                             -LongDescription "Open the help window for the current command" `
                             -ScriptBlock {
        param($key, $arg)
    
        $ast = $null
        $tokens = $null
        $errors = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
    
        $commandAst = $ast.FindAll( {
            $node = $args[0]
            $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.Extent.StartOffset -le $cursor -and
                $node.Extent.EndOffset -ge $cursor
            }, $true) | Select-Object -Last 1
    
        if ($commandAst -ne $null)
        {
            $commandName = $commandAst.GetCommandName()
            if ($commandName -ne $null)
            {
                $command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
                if ($command -is [System.Management.Automation.AliasInfo])
                {
                    $commandName = $command.ResolvedCommandName
                }
    
                if ($commandName -ne $null)
                {
                    Get-Help $commandName -ShowWindow
                }
            }
        }
    }
}
