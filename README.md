# What this offers

1. 

String is a 'sealed class', we can't make ANSIString inherit from it. Instead, if you want to abstract the properties or methods of the string class, just access the Content property first,

```powershell
$result = Write-ANSI -Message "[[208hello"

$result.Length         # returns adjusted length of the string, 5
$result.Content.Length # returns the full length of the string, 20, ANSI sequences and all
$result.Content = $result.Content.Replace("-") # adjusts the Content of the ANSIString by exposing the string class Replace method
```

By setting all the properties to hidden, ToString() is called automatically when it drops out of the pipeline. Otherwise you end up with a labeled table which is not what we want.