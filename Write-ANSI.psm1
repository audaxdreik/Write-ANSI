# easy reference ANSI escape sequence
$E = [char](0x1B)

class ANSIString {

    hidden [string]$Content
    hidden  [int32]$Length # the length of the string as it would appear in the console

    # constructors
    ANSIString () {}

    ANSIString ([string]$Content) {

        $this.Content = $Content
        $this.Length  = ($Content -replace "$([char](0x1B)).*?m").Length

    }

    [string] ToString() {

        return $this.Content

    }

}

<#
.SYNOPSIS
    Easily translate ANSI 256 color escape sequences.
.DESCRIPTION
    Replaces '[[m' notated string pieces with the appropriately formatted ESC[38;5;#m or ESC[48;5;#m ANSI escape
    sequences. Foreground [[#m, background [[;#m, foreground and background [[#;#m, and reset [[m sequences can be
    defined from the Xterm 256 color chart.

    Each sequence will cumulatively apply or overwrite the desired change until completely reset with [[m ( ESC[0m, not
    to be confused with [[0m which translates to ESC[38;5;0m or black foreground text ).

    Accepts color range 0-255 for both foreground and background. Background colors should be preceded by a single
    semicolon ';' character and never any spaces. Improper sequences will not be digested. The trailing 'm' is optional 
    and only strictly required when needed for disambiguation such as in the example "[[20m5 errors" which could
    otherwise improperly evaluate to the string " errors" with 205 foreground text.

    ESC[0m is automatically applied at the end of every message in order to keep any previously set escape sequences
    from bleeding into other output or your console prompt.
.PARAMETER Message
    The message for which ANSI formatted escape sequences will be replaced. Will replace any pieces notated in the form
    of [[#m with the appropriate 256 color ANSI escape sequence.
.EXAMPLE
    PS C:\> Write-ANSI -Message '[[208mHello, world!'

    Prints "Hello, world!" to the screen in orange text.
.EXAMPLE
    PS C:\> Write-ANSI -Message '[[;160WARNING![[ user not found!'

    Prints "WARNING!" to the screen using color code 160 (bright orange/red) as the background and whatever foreground
    color was previously specified or in use by the console. The text is then reset to the default foreground and
    background colors before printing the rest of the string.
.EXAMPLE
    PS C:\> Write-ANSI -Message '[[118;128mHello, world!'

    Prints "Hello, world!" to the screen with bright green foreground text and purple background.
.NOTES
    Requires Windows 10 Creators Update or custom console such as ConEmu to properly display ANSI sequences.
#>
function Write-ANSI {
    [CmdletBinding()]
    [OutputType([ANSIString])]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            Position = 0,
            HelpMessage = 'message containing [[# ANSI escape')]
        [string]$Message
    )

    Begin { }

    Process {

        # extract each '[[' notated escape sequence
        $ANSICodePieces = ([regex]::Matches($Message, '\[\[((\d{1,3})?(;\d{1,3})?)?m?')).Value

        # analyze each code piece in turn and replace it in the original Message
        foreach ($acp in $ANSICodePieces) {

            switch -regex ($acp) {
                '^\[\[m?$' {
                    # reset block, '[[' or '[[m'
                    $ANSIColorCode = "$E[0m"
                }
                '^\[\[;([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])m?$' {
                    # background color block, '[[;#' or '[[;#m'
                    $ANSIColorCode = "$E[48;5;$($acp -replace '\[\[;|m')m"
                }
                '^\[\[([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5]);([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])m?$' {
                    # foreground and background color block, '[[#;#' or '[[#;#m'
                    # -split drops semicolon leaving '[[#' and '#' or '#m' pieces
                    $colorCodes = $acp -split ';'
                    $ANSIColorCode = "$E[38;5;$($colorCodes[0] -replace '\[')m$E[48;5;$($colorCodes[1] -replace 'm')m"
                }
                '^\[\[([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])m?$' {
                    # foreground color block, '[[#' or '[[#m'
                    $ANSIColorCode = "$E[38;5;$($acp -replace '\[|m')m"
                }
                default {
                    Write-Verbose -Message "unsupported ANSI color code block: $acp"
                    <#
                        in this case, $ANSIColorCode is not initilized and snips the entire unsupported code from the
                        resultant string when the -replace below is evaluated
                    #>
                }
            }

            # replace the notated piece with the actual ANSI code in original message string
            $Message = $Message.Replace($acp, $ANSIColorCode)

        }

        # reset the color at the end of every message regardless, otherwise prompt or other output could become tainted
        $Message += "$E[0m"

        # wrap the message in our custom class so we can easily access the adjusted length
        Write-Output -InputObject ([ANSIString]::New($Message))

    }

    End { }

}

<#
.SYNOPSIS
    Displays a quick reference of available 256 ANSI colors.
.DESCRIPTION
    Outputs a full color table from 0-255 of the available colors that can be used with Write-ANSI.
.EXAMPLE
    PS C:\> Show-ANSI256Table

    The only possible way to use this function, prints out the table.
.NOTES
    Or check https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg
#>
function Show-ANSI256Table {
    [CmdletBinding()]
    param ()

    # break into 16 rows of 16 colors each
    $colorBlocks = 0 .. 15

    foreach ($colorBlock in $colorBlocks) {

        # calculate beginning and end of each row of color codes
        $colors = ($colorBlock * 16) .. ($colorBlock * 16 + 15)

        $outputString = ""
        foreach ($color in $colors) {

            # format a nice ANSI code string representation and append it
            $outputString += "[[;$($color)m$(([string]$color).PadLeft(3, '0'))"

        }

        # write the entire row to screen
        Write-ANSI -Message $outputString

    }

}

Export-ModuleMember -Function Write-ANSI
Export-ModuleMember -Function Show-ANSI256Table
Export-ModuleMember -Variable E