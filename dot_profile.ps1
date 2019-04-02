<#
  .SYNOPSIS
      Cmder PowerShell Profile

  .DESCRIPTION
      Use this script to customize your own PowerShell edition of Cmder

  .LINK
      https://github.com/bliker/cmder
#>
Import-Module posh-git
# Set up a Cmder prompt, adding the git prompt parts inside git repos
if (Get-Module posh-git) {
    function prompt {
        $GitPromptSettings.DefaultPromptPrefix.Text = '`n'
        $GitPromptSettings.DefaultPromptPath.ForegroundColor = 'Blue'
        $GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'
        & $GitPromptScriptBlock
    }
}

# Load special features come from PSReadLine
if (Get-Module PSReadLine) {
    Set-PSReadlineOption -BellStyle None
    Set-PSReadlineOption -HistoryNoDuplicates
    Set-PSReadlineKeyHandler -Chord UpArrow -Function HistorySearchBackward
    Set-PSReadlineKeyHandler -Chord DownArrow -Function HistorySearchForward

    # Sometimes you enter a command but realize you forgot to do something else first.
    # This binding will let you save that command in the history so you can recall it,
    # but it doesn't actually execute.  It also clears the line with RevertLine so the
    # undo stack is reset - though redo will still reconstruct the command line.
    Set-PSReadlineKeyHandler -Chord Alt+s `
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

    # F1 for help on the command line - naturally
    Set-PSReadlineKeyHandler -Chord F1 `
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
                    Get-Help -Name $commandName
                }
            }
        }
    }
}

function mk ($src) {
  New-Item -ItemType Directory -Path $src
  Set-Location $src
}

function ln ($src, $target) {
  New-Item -ItemType SymbolicLink -Path $src -Value $target
}

function serialize($a, $escape) {
	if($a -is [string] -and $a -match '\s') { return "'$a'" }
	if($a -is [array]) {
		return $a | ForEach-Object { (serialize $_ $escape) -join ', ' }
	}
	if($escape) { return $a -replace '[>&]', '`$0' }
	return $a
}

function sudo () {
  $PsBoundParameters
  $a = if ($args[0] -eq '!!') {
    Get-History -Count 1 | Select-Object -ExpandProperty CommandLine
  } else {
    serialize $args $true
  }

  $src = 'using System.Runtime.InteropServices;
    public class Kernel {
      [DllImport("kernel32.dll", SetLastError = true)]
      public static extern bool AttachConsole(uint dwProcessId);
      [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
      public static extern bool FreeConsole();
    }'

  $Kernel = Add-Type $src -PassThru
  $Kernel::FreeConsole()
  $Kernel::AttachConsole($pid)

  $Title = $Host.UI.RawUI.WindowTitle
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "powershell.exe"
  $psi.Arguments = "-noprofile $a`nexit `$lastexitcode"
  $psi.UseShellExecute = $false
  $psi.WorkingDirectory = serialize (Convert-Path $pwd)
  $psi.Verb = 'runAs'
  $psi.CreateNoWindow = $true
  $psi.WindowStyle = 'hidden'
  $Process = New-Object System.Diagnostics.Process
  $Process.StartInfo = $psi
  [void]$Process.Start()
  $Process.WaitForExit()
  $Host.UI.RawUI.WindowTitle = $Title
}
