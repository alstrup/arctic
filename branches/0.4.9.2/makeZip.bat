del arctic.zip
rem "c:\program files\7-zip\7z.exe" a -r -x arctic.zip -x .svn arctic.zip *.*

"c:\program files\7-zip\7z.exe" a -tzip -r -x!.svn -x!launch*.bat -x!makeZip.bat arctic.zip *.*
