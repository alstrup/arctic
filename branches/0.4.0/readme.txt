Arctic is a simple haXe GUI framework which allows you to create user
interfaces for flash applications. It is unique by supporting both Flash 8
and Flash 9 targets using the same client code. It is licensed under the BSD
license.

The user interface is constructed from ArcticBlocks which is a simple enum.
'Call-backs' are done using function arguments.

Layout is done using either stacks of columns, or stacks of lines. A special
Filler element is available which will expand to the width or height available. 
This can be used to implement things like centering and right alignment of user
interface blocks.

Arctic is currently best suited for fairly static user interfaces, since
there is no partial refresh support yet, meaning that changes in the user
interface will require a full refresh.

Arctic is so simple that you should have little trouble understanding how it
is implemented, and thus it should be easy to extend it to cover your needs.

See the example to learn how to build your own arctic views,

To install, run

  haxelib install arctic

Compile the simple demo in your haxe-1.08\lib\arctic\*\examples
directory, and launch arctic.swf (Flash 8) or arctic9.swf (Flash 9) to try it.


The code is also available as a Google project:

http://code.google.com/p/arctic/

Send me your google id if you would like to have access to Google project.


If you'd like to extend Arctic, there are three different approaches possible:

The first approach is to make a builder: This builds a component by combining 
it from the basic blocks, just like lego. This is often a nice way to do it 
(because it's target independent), and this approach will allow you to keep 
your own private components separate from arctic. There are a few builders 
so far, but the plan is to extend the list with a calendar widget, and what 
else comes up.
Please submit the builders you make, if you think they are generally useful.

The second approach is to use the CustomBlock. This allows you to wrap any existing 
MovieClips you might have, and mix them into Arctic.

The final approach is to make new basic blocks. This is done by extending the ArcticBlock
enum, and modify build and calc_metrics accordingly in Arctic.hx. This might be
relevant if you need new layout behaviours.


Regards,

Asger Ottar Alstrup
asger@area9.dk
