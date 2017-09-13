# PowerShell Module: Write-ANSI

Explain the general idea of the project.

## Design Choices

Go into more detail on why I made some of the decisions I did, including the replacement patterns.

### Prerequisites

* **PowerShell 5**: to support the use of the custom [ANSIString] class
* **Windows 10 Creators Update** or alternative console such as **ConEmu**: to support ANSI escape sequences

Forking the code to remove the custom ANSIString class and using an alternative console could expand the potential audience for this to include older versions of PowerShell and Windows 7.

## General Usage

Some quick examples?

## Limitations and Restrictions

### Breaking out of Different Streams

ANSI sequences will be translated whenever they are printed to the console which means you are capable of doing color output on all streams including Error, Warning, and Verbose. Be warned however that when the reset sequence is naturally appended to the end of every string from the Write-ANSI commandlet, it will reset to the default foreground and background color of the console and not the default color of the current stream. Note the following problematic usage,

```powershell
Write-Verbose -Message "unable to find $(Write-ANSI -Message "[[208$user") in directory" -Verbose
```

The expected result would be to see the string 'VERBOSE: unable to find [some_user] in directory' in the standard yellow of Write-Verbose with only '[some_user]' printed in orange. Instead what you will see is that 'VERBOSE: unable to find ' is printed in yellow, '[some_user]' is printed in orange, and ' in directory' is printed in the default console color, usually white or light gray (as per your own settings).

To address this, it's recommended to pass the whole string to the Write-ANSI commandlet and manually reset to yellow (11) where desired,

```powershell
Write-Verbose -Message (Write-ANSI -Message "unable to find [[208$user[[11 in directory") -Verbose
```

The same would of course apply to the Error stream using red (9).

### The Case for Wrapping to the ANSIString Class

Consider the following code which attempts to print a banner across the width of the console. In this example, assume the ANSIString class is not being used and a simple string is being returned, the Length of which is much greater than the actual displayed length due to the inclusion of many invisible ANSI sequence characters,

```powershell
$bufferWidth = (Get-Host).UI.RawUI.BufferSize.Width
$dateString  = Write-ANSI -Message "[[79;110[$(Get-Date)]"
# literal $dateString: '^[38;5;79m^[48;5;110m[01/01/1990 12:00:00]^[0m'

('-' * 10) + $dateString + ('-' * ($bufferWidth - (10 + $dateString.Length)))
```

The actual length of $dateString is **46** characters once all ANSI sequences have been properly translated. The visible display length of the string however is only **21**, for a total difference of **25**. The banner which should span the width of the console window comes up 25 characters short of doing so.

This could be rectified with,

```powershell
('-' * 10) + $dateString + ('-' * ($bufferWidth - (10 + ($dateString -replace "$([char](0x1B)).*?m").Length)))
```

but that becomes cumbersome to apply in any graphically rich undertaking.

Instead I've somewhat clumsily wrapped the String class so that the Length property behaves more as expected by doing the above replacement at the time of class instantiation. String is a 'sealed class', so I couldn't make ANSIString inherit from it directly. Instead, if you want to abstract the properties or methods of the String class, just access the Content property first,

```powershell
$result = Write-ANSI -Message "[[208hello"

$result.Length         # returns adjusted length of the string, 5, 'hello'
$result.Content.Length # returns the full length of the string, 20, '^[38;5;208mhello^[0m'

# adjusts the Content of the ANSIString by exposing the string class Replace method
# though best practice is to do all string manipulation first, otherwise you may break the translated ANSI sequences!
$result.Content = $result.Content.Replace("-")
```

Finally, by setting all the properties to hidden, ToString() is called automatically when it drops out of the pipeline. Otherwise you'd end up with a labeled table of the Content and Length properties which is not what we want.