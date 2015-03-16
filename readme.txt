Arctic is a simple haXe GUI framework which allows you to create user
interfaces for flash applications. It is unique by supporting both Flash 7, 8
and Flash 9 targets using the same client code. It is licensed under the BSD
license, without the advertisement clause.

The user interface is constructed from ArcticBlocks which is a simple enum.
'Call-backs' are done using function arguments.

Layout is done using either stacks of columns, or stacks of lines. A special
Filler element is available which will expand to the width or height available. 
This can be used to implement things like centering and right alignment of user
interface blocks.

Arctic is relatively simple, so you should have little trouble understanding how it
is implemented, and thus it should be possible to extend it to cover your needs.

See the examples to learn how to build your own arctic views.

To install, run

  haxelib install arctic

Compile the simple demos in your haxe-X\lib\arctic\*\examples
directory, and launch ComponentTour8.swf (Flash 8) or ComponentTour9.swf (Flash 9) 
to try it.



The code is also available on Github:

https://github.com/alstrup/arctic


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
enum, and modify build accordingly in Arctic.hx.
