' ============================================================================
' VBScript Windows Product Key Grabber - pcHealth (LEGACY EDITION)
' ============================================================================
'
' This is the OLD SCHOOL version for ancient systems from the MBR/BIOS era.
' If you're running Windows 11, you probably want KeyGrabber.ps1 instead!
'
' Fun fact: This VBS script is older than UEFI firmware. It only knows about
' the registry method - no fancy OA3/UEFI key extraction here!
'
' Recommended for: Legacy systems (Windows 7/8/10) from the BIOS/MBR era.
' ============================================================================

Option Explicit

' -------------------------------
' 1. Create Shell Object and Define Registry Path
' -------------------------------
Dim objShell, regPath, currentBuild, ProductName, ProductID, ProductKey, ProductData
Set objShell = CreateObject("WScript.Shell")
regPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\"

' -------------------------------
' 2. Read Current Build Number from Registry
' -------------------------------
currentBuild = CLng(objShell.RegRead(regPath & "CurrentBuild"))

' -------------------------------
' 3. Determine OS Name Based on Build Number
' -------------------------------
If currentBuild >= 22000 Then
    ProductName = "Windows 11 " & objShell.RegRead(regPath & "EditionID")
Else
    ProductName = objShell.RegRead(regPath & "ProductName")
End If

' -------------------------------
' 4. Read Product ID from Registry
' -------------------------------
ProductID = "Product ID: " & objShell.RegRead(regPath & "ProductID")

' -------------------------------
' 5. Read Digital Product ID and Convert to Readable Key
' -------------------------------
ProductKey = "Installed Key: " & ConvertToKey(objShell.RegRead(regPath & "DigitalProductId"))

' -------------------------------
' 6. Combine Product Information into One String
' -------------------------------
ProductData = "Windows Version: " & ProductName & vbNewLine & ProductID & vbNewLine & ProductKey

' -------------------------------
' 7. Prompt User to Save the Key to a File
' -------------------------------
If vbYes = MsgBox(ProductData & vbNewLine & vbNewLine & "Save your key to a file?", vbYesNo + vbQuestion, "pcHealth | Windows Key Grabber") Then
   Save ProductData
End If

' -------------------------------
' Function: ConvertToKey
' Converts the binary DigitalProductId into a human-readable product key
' Now includes Windows 8+ N-character encoding support
' -------------------------------
Function ConvertToKey(Key)
    Const KeyOffset = 52
    Dim Maps, i, j, r, KeyOutput, keyBytes(14), isWin8Plus, nIndex, firstChar, tempKey

    ' Extract key bytes (15 bytes from offset 52-66)
    For i = 0 To 14
        keyBytes(i) = Key(KeyOffset + i)
    Next

    Maps = "BCDFGHJKMPQRTVWXY2346789"

    ' Check for Windows 8+ key (has special N-character encoding)
    isWin8Plus = (keyBytes(14) \ 8) And 1
    keyBytes(14) = (keyBytes(14) And 247) Or ((isWin8Plus And 2) * 4)

    KeyOutput = ""

    ' Decode the key using Base24 algorithm
    For i = 24 To 0 Step -1
        r = 0

        For j = 14 To 0 Step -1
            ' Multiply by 256 and add current byte (FIXED: was XOR)
            r = (r * 256) + keyBytes(j)
            keyBytes(j) = Int(r / 24)
            r = r Mod 24
        Next

        KeyOutput = Mid(Maps, r + 1, 1) & KeyOutput
    Next

    ' Insert 'N' for Windows 8+ keys
    If isWin8Plus = 1 Then
        firstChar = Left(KeyOutput, 1)
        nIndex = InStr(Maps, firstChar) - 1
        tempKey = Right(KeyOutput, Len(KeyOutput) - 1)
        KeyOutput = Left(tempKey, nIndex) & "N" & Right(tempKey, Len(tempKey) - nIndex)
    End If

    ' Format with dashes
    Dim formattedKey, charPos
    formattedKey = ""
    For charPos = 1 To 25
        formattedKey = formattedKey & Mid(KeyOutput, charPos, 1)
        If (charPos Mod 5) = 0 And charPos < 25 Then
            formattedKey = formattedKey & "-"
        End If
    Next

    ConvertToKey = formattedKey
End Function

' -------------------------------
' Function: Save
' Saves the provided data to a text file on the user's desktop
' -------------------------------
Function Save(Data)
    Dim fso, fName, txt, objShell, UserName
    Set objShell = CreateObject("WScript.Shell")
    ' Get the current user name from environment variables
    UserName = objShell.ExpandEnvironmentStrings("%UserName%")
    ' Define the file path on the desktop
    fName = "C:\Users\" & UserName & "\Desktop\KeyGrabber - pcHealth.txt"
    Set fso = CreateObject("Scripting.FileSystemObject")
    ' Create the text file and write the data into it
    Set txt = fso.CreateTextFile(fName)
    txt.WriteLine Data
    txt.Close
End Function
