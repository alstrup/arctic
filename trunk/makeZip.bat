del arctic.zip

cd examples
haxe DevArcticExamples.hxml
haxe Bugs.hxml
haxe DialogsExamples.hxml
cd ..

SET ZIP="c:\program files\7-zip\7z.exe"
IF NOT EXIST %ZIP% SET ZIP="c:\programmer\7-zip\7z.exe"

%ZIP% a -tzip -r -x!.svn -x!*.bat -x!makeZip.bat arctic.zip *.*

haxelib submit arctic.zip
