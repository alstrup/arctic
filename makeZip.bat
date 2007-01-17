del arctic.zip

SET ZIP="c:\program files\7-zip\7z.exe"
IF NOT EXIST %ZIP% SET ZIP="c:\programmer\7-zip\7z.exe"

%ZIP% a -tzip -r -x!.svn -x!launch*.bat -x!makeZip.bat arctic.zip *.*
