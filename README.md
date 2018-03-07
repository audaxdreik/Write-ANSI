# ANSI 256 Color for PowerShell

Allows you to easily insert shorthand ANSI 256 color escape sequences into a string object.

## Description

Now that the Windows console natively supports ANSI escape sequences (see Prerequisites) it's time to make use of them! But entering in syntactically correct sequences can be cumbersome, *especially* for color sequences. By focusing strictly on the 256 color escape sequences of ANSI I've created a shorthand that utilizes the same basic form of the sequence without all the extra characters. A sequence is initiated with '[[' and can contain a foreground, background, or foreground & background number from 0-255. The sequence terminator, 'm' is only required when the proceding string would ambiguously interpret with the escape code.

Assuming '^' = `[char](0x1B)`

* Foreground, **^[38;5;208m** becomes **[[208**
* Background, **^[48;5;110m** becomes **[[;110**
* Foreground & Background, **^[38;5;196me[48;5;32m** becomes **[[196;32**
* Reset, **^[0m** becomes **[[** (not to be confused with [[0 which is ^[38;5;0m or black foreground text)

## Prerequisites

* **PowerShell 5**: to support the use of the custom [ANSIString] class
* **Windows 10 Creators Update** or alternative console such as **ConEmu**: to support ANSI escape sequences

Forking the code to remove the custom ANSIString class and using an alternative console could expand the potential audience for this to include older versions of PowerShell and Windows 7.

## Installing

Simply copy \Write-ANSI into your module path and run `Import-Module -Name Write-ANSI`

## Examples

### General Usage

``` powershell
Show-ANSI256Table
```
Prints a colorful table to the console for easy reference.

``` powershell
Write-ANSI -Message '[[208mHello, world!'
```
Sets only the foreground text to color 208 (orange). Uses 'm' character to explicitly close the sequence.

``` powershell
Write-ANSI -Message '[[;160WARNING![[ user not found!'
```
Sets only the background text to color 160 (bright red) and leaves whatever foreground text color was previously set or in use by the console. Resets both the background and foreground color to the console default after printing 'WARNING!'. Both notations omit the 'm' character leaving the closing sequence implied.

``` powershell
Write-ANSI -Message '[[118;128mHello, world!'
```
Sets the foreground text to color 118 (neon green) and the background text to color 128 (purple). Uses 'm' character to explicitly close the sequence.

``` powershell
Write-Information -MessageData (Write-ANSI -Message '[[208mHello, world!') -InformationAction Continue
```
Print colorful messages to your console without cluttering the output stream.

### Breaking Out of Streams

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

## Discussion

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

## Versioning

[SemVer](http://semver.org/) style versioning will be applied to help ensure this code can be used in production with reasonable guarantees against breaking changes.

## Authors

* **Audax Dreik** - *Initial work, 1.0.0 release* - 🦒

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
