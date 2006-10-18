package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.display.MovieClip;
import flash.geom.Rectangle;
import flash.text.TextFormat;
#else true
import flash.MovieClip;
import flash.geom.Rectangle;
import flash.TextFormat;
#end

typedef Metrics = { width : Float, height : Float, growWidth : Bool, growHeight : Bool }

class Arctic {
	public function new(gui0 : ArcticBlock) {
		gui = gui0;
		parent = null;
		base = null;
	}

	public var gui : ArcticBlock;
	public var parent : MovieClip;
	private var base : MovieClip;

	public function display(p : MovieClip, useStageSize : Bool) : MovieClip {
		if (useStageSize) {
			stageSize(p);
		}
		parent = p;
		refresh();

		if (useStageSize) {
			// Make sure we follow screen resizes
			#if flash9
				p.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
				p.stage.align = flash.display.StageAlign.TOP_LEFT;
				var t = this;
				var resizeHandler = function( event : flash.events.Event ) { t.onResize();}; 
				p.stage.addEventListener( flash.events.Event.RESIZE, resizeHandler ); 
			#else flash
				flash.Stage.scaleMode = "noScale";
				flash.Stage.addListener(this);
			#end
		}
        return base;
	}

	public function onResize() {
		stageSize(parent);
		refresh();
	}

	public function refresh() {
		if (base != null) {
			remove();
		}
		#if flash9
			base = build(gui, parent, parent.width, parent.height);
		#else flash
			base = build(gui, parent, parent._width, parent._height);
		#end
	}

	public function remove() {
		#if flash9
			parent.removeChild(base);
		#else flash
			base.removeMovieClip();
		#end
		base = null;
	}

    public function build(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float) : MovieClip {
		#if flash9
			var clip = new MovieClip();
			p.addChild(clip);
		#else flash
			var d = p.getNextHighestDepth();
			var clip = p.createEmptyMovieClip("c" + d, d);
		#end
		clip.tabEnabled = false;
		
		switch (gui) {
		case Border(x, y, block):
			var child = build(block, clip, availableWidth - 2 * x, availableHeight - 2 * y);
			#if flash9
				child.x = x;
				child.y = y;
				setSize(clip, child.width + 2 * x, child.height + 2 * y);
			#else flash
				child._x = x;
				child._y = y;
				setSize(clip, child._width + 2 * x, child._height + 2 * y);
			#end
			return clip;

		case Background(color, block):
			var child = build(block, clip, availableWidth, availableHeight);
			#if flash9
				clip.graphics.beginFill(color);
				clip.graphics.moveTo(0,0);
				clip.graphics.lineTo(child.width, 0);
				clip.graphics.lineTo(child.width, child.height);
				clip.graphics.lineTo(0, child.height);
				clip.graphics.lineTo(0, 0);
				clip.graphics.endFill();
			#else flash
				clip.beginFill(color);
				clip.moveTo(0,0);
				clip.lineTo(child._width, 0);
				clip.lineTo(child._width, child._height);
				clip.lineTo(0, child._height);
				clip.lineTo(0, 0);
				clip.endFill();
			#end
			return clip;

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha):
			var child = build(block, clip, availableWidth, availableHeight);
			#if flash9
				var matrix = new  flash.geom.Matrix();
				matrix.createGradientBox(child.width, child.height, 0, child.width * xOffset, child.height * yOffset);
				clip.graphics.beginGradientFill(flash.display.GradientType.RADIAL, colors, [100.0, 100.0], [0.0, 255.0], matrix);
				clip.graphics.moveTo(0,0);
				clip.graphics.lineTo(child.width, 0);
				clip.graphics.lineTo(child.width, child.height);
				clip.graphics.lineTo(0, child.height);
				clip.graphics.lineTo(0, 0);
				clip.graphics.endFill();
			#else flash
				var matrix = {	a:child._width, b:0, c:0, 
								d:0, e:child._height, f: 0, 
								g:child._width * xOffset, h:child._height * yOffset, i:0}; // Center
				clip.beginGradientFill(type, colors, [100.0, 100.0], [0.0, 255.0], matrix);
				
				clip.moveTo(0,0);
				clip.lineTo(child._width, 0);
				clip.lineTo(child._width, child._height);
				clip.lineTo(0, child._height);
				clip.lineTo(0, 0);
				clip.endFill();
			#end
			return clip;

		case Text(html):
			#if flash9
				var tf = new flash.text.TextField();
				tf.autoSize = flash.text.TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
				clip.addChild(tf);
			#else flash
				var tf = clip.createTextField("tf", clip.getNextHighestDepth(), 0, 0, 100, 100);
				tf.autoSize = true;
				tf.html = true;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
			#end
			return clip;

		case Picture(url, w, h, scaling):
			#if flash9
				var loader = new flash.display.Loader();
				var request = new flash.net.URLRequest(url);
				loader.load(request);
				clip.addChild(loader);
				var s = scaling;
				clip.scaleX = s;
				clip.scaleY = s;
			#else flash
				var loader = new flash.MovieClipLoader();
				loader.loadClip(url, clip);
				var s = scaling * 100.0;
				clip._xscale = s;
				clip._yscale = s;
			#end
			setSize(clip, w / scaling, h / scaling);
			return clip;

		case Button(block, action):
			#if flash9
				var child = build(block, clip, availableWidth, availableHeight);
				child.addEventListener( flash.events.MouseEvent.MOUSE_UP, function (s) { action(); } ); 
				child.addEventListener( flash.events.MouseEvent.MOUSE_OVER, 
					function (s) { 
						// Maybe we should have different blocks, and switch between them on hover and click's rather than this hard-coded behaviour
						clip.opaqueBackground = 0x333333;
					}
				);
				child.addEventListener( flash.events.MouseEvent.MOUSE_OUT, 
					function (s) { 
						// Maybe we should have different blocks, and switch between them on hover and click's rather than this hard-coded behaviour
						clip.opaqueBackground = null;
					}
				);
			#else flash
				var child = build(block, clip, availableWidth, availableHeight);
				clip.onRelease = action;
				clip.onMouseMove = function() {
					var mouseInside = clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false);
					if (mouseInside) {
						// Maybe we should have different blocks, and switch between them on hover and click's rather than this hard-coded behaviour
						clip.opaqueBackground = 0x333333;
					} else {
						clip.opaqueBackground = null;
					}
				};
			#end
			return clip;

		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			#if flash9
				var sel = build(selected, clip, availableWidth, availableHeight);
				var unsel = build(unselected, clip, availableWidth, availableHeight);
				sel.visible = initialState;
				unsel.visible = !initialState;
				var setState = function (newState : Bool) { sel.visible = newState; unsel.visible = !newState; }; 
				if (null != onInit) {
					onInit(setState);
				}
				clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) {
						if (null != onChange) {
							setState(!sel.visible);
							onChange(sel.visible);
						}
					});
			#else flash
				var sel = build(selected, clip, availableWidth, availableHeight);
				var unsel = build(unselected, clip, availableWidth, availableHeight);
				sel._visible = initialState;
				unsel._visible = !initialState;
				var setState = function (newState : Bool) { sel._visible = newState; unsel._visible = !newState; }; 
				if (null != onInit) {
					onInit(setState);
				}
				clip.onPress = function() {
					if (null != onChange) {
						setState(!sel._visible);
						onChange(sel._visible);
					}
				};
			#end
			return clip;

		case ToggleButtonGroup(buttons, onSelect):
			var stateChooser = [];
			var onInitHandler = function (setState) { stateChooser.push(setState); };
			var blocks = [];
			// Construct the ToggleButton again to make it work as a group
			for (button in buttons) {
				switch(button) {
					case ToggleButton(selected, unselected, initialState, onChange, onInit):
						// In case of ToggleButtonGroup onChange has to be null.
						blocks.push(ToggleButton(selected, unselected, false, null, onInitHandler));
					default:
				}
			}
			var onSelectHandler = function (index : Int) {
				for (i in 0...stateChooser.length) {
					if (i != index) {
						stateChooser[i](false);
					} else {
						stateChooser[i](true);
					}
				}
				onSelect(index);
			}
			var group = build(SelectList(blocks, onSelectHandler), clip, availableWidth, availableHeight);
			return clip;

/*		case TextInput(id, contents, listener, width, height, maxChars, restrict, format):
			#if flash9
				// TODO
			#else flash
				var txtInput = clip.createTextField(id, clip.getNextHighestDepth(), 0, 0, width, height);
				if (null != format) {
					txtInput.setNewTextFormat(format);
				}
				if (null != maxChars) {
					txtInput.maxChars = maxChars;
				}
				if (null != restrict) {
					txtInput.restrict = restrict;
				}
				txtInput.text = contents;
				txtInput.addListener(listener);
				txtInput.type = "input";
				txtInput.border = true;
			#end
*/
		case Filler:
			return clip;

        case ConstrainWidth(minimumWidth, maximumWidth, block) :
            var child = build(block, clip, Math.max( minimumWidth, Math.min(availableWidth, maximumWidth) ), availableHeight);
			#if flash9
				if (child.width < minimumWidth) {
					child.width = minimumWidth;
				}
				if (child.width > maximumWidth) {
					child.width = maximumWidth;
				}
			#else flash
				if (child._width < minimumWidth) {
					child._width = minimumWidth;
				}
				if (child._width > maximumWidth) {
					child._width = maximumWidth;
				}
			#end
            return clip;

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var child = build(block, clip, availableWidth, Math.max( minimumHeight, Math.min(availableHeight, maximumHeight) ) );
			#if flash9
				if (child.height < minimumHeight) {
				   child.height = minimumHeight;
				}
				if (child.height > maximumHeight) {
				   child.height = maximumHeight;
				}
			#else flash
				if (child._height < minimumHeight) {
				   child._height = minimumHeight;
				}
				if (child._height > maximumHeight) {
				   child._height = maximumHeight;
				}
			#end
            return clip;

		case ColumnStack(columns):
			// First, see how many fillers we have ourselves
            var numberOfFillers = 0;
			var childMetrics = [];
			var width = 0.0;
			for (c in columns) {
				if (c == Filler) {
                  numberOfFillers++; 
				}
				var m = calcMetrics(c);
				childMetrics.push(m);
				width += m.width;
			}
			
			// Next, determine how much space children get
            var freeSpace = availableWidth - width;

			var x = 0.0;
			var i = 0;
            var children = [];
            for (c in columns) {
                var child = build(c, clip, freeSpace + childMetrics[i].width, availableHeight);
				#if flash9
					child.x = x;
				#else flash
					child._x = x;
				#end
                children.push(child);
				#if flash9
					x += child.width;
				#else flash
					x += child._width;
				#end
				++i;
            }
            if (numberOfFillers > 0) { 
                var availableSpaceForFillers = availableWidth - x;
                var spaceForEachFiller = Math.max(0, availableSpaceForFillers / numberOfFillers);
                var shift = 0.0;
                x = 0.0;
                for (i in 0...columns.length) { 
					if (columns[i] == Filler) {
						shift += spaceForEachFiller;
						setSize(children[i], spaceForEachFiller, 0);
						x += shift;
					} else {
						#if flash9
							children[i].x += shift;
							x += children[i].width;
						#else flash
						   children[i]._x += shift;
						   x += children[i]._width;
						#end
					}
                }
            }
			return clip;

		case LineStack(blocks):
			// First, see how many fillers we have ourselves
            var numberOfFillers = 0;
			var childMetrics = [];
			var height = 0.0;
			for (r in blocks) {
				if (r == Filler) {
                  numberOfFillers++; 
				}
				var m = calcMetrics(r);
				childMetrics.push(m);
				height += m.height;
			}

			// Next, determine how much space children get
            var freeSpace = availableHeight - height;

			var y = 0.0;
			var i = 0;
            var children = [];
			for (l in blocks) {
                var child = build(l, clip, availableWidth, freeSpace + childMetrics[i].height);
				#if flash9
					child.y = y;
				#else flash
					child._y = y;
				#end
                children.push(child);
				#if flash9
					y += child.height;
				#else flash
					y += child._height;
				#end
				++i;
			}
            if (numberOfFillers > 0) { 
                var availableSpaceForFillers = availableHeight - y;
                var spaceForEachFiller = availableSpaceForFillers / numberOfFillers;
                var shift = 0.0;
                y = 0.0;
                for (i in 0...blocks.length) {
					if (blocks[i] == Filler) {
                       shift += spaceForEachFiller;
					   setSize(children[i], 0, spaceForEachFiller);
                       y += shift;
					} else {
						#if flash9
							children[i].y += shift;
							y += children[i].height;
						#else flash
							children[i]._y += shift;
							y += children[i]._height;
						#end
					}
                }
            }

			return clip;

		case SelectList(lines, onClick):
			// First, see how many fillers we have ourselves
            var numberOfFillers = 0;
			var childMetrics = [];
			var height = 0.0;
			for (r in lines) {
				if (r == Filler) {
                  numberOfFillers++; 
				}
				var m = calcMetrics(r);
				childMetrics.push(m);
				height += m.height;
			}

			// Next, determine how much space children get
            var freeSpace = availableHeight - height;

			var y = 0.0;
			var i = 0;
            var children = [];
            var selectListWidth = availableWidth - 10;
			#if flash9
				var childClip = new MovieClip();
				clip.addChild(childClip);
			#else flash
				var depth = clip.getNextHighestDepth();
				var childClip = clip.createEmptyMovieClip("c" + depth, depth);
			#end
			for (l in lines) {
                var child = build(l, childClip, selectListWidth, freeSpace + childMetrics[i].height);
				#if flash9
					child.y = y;
					var li = i;
					// TODO: For some reason, this closure does not work - it always returns the last value
					var f = function(s) { onClick(li); };
					child.addEventListener(flash.events.MouseEvent.MOUSE_UP, f);
				#else flash
					child._y = y;
					var li = i;
					child.onRelease = function() { onClick(li); };
				#end
                children.push(child);
				#if flash9
					y += child.height;
				#else flash
					y += child._height;
				#end
				++i;
			}

            if ( (numberOfFillers > 0) && (y < availableHeight)) { 
                var availableSpaceForFillers = availableHeight - y;
                var spaceForEachFiller = availableSpaceForFillers / numberOfFillers;
                var shift = 0.0;
                y = 0.0;
                for (i in 0...lines.length) {
					if (lines[i] == Filler) {
						shift += spaceForEachFiller;
						setSize(children[i], 0, spaceForEachFiller);
						y += shift;
					} else {
						#if flash9
							children[i].y += shift;
							y += children[i].height;
						#else flash
							children[i]._y += shift;
							y += children[i]._height;
						#end
                   }
                }
             }
            
            drawScrollBar (childClip);
			return clip;
		}
		return clip;
	}

	
	private function calcMetrics(c : ArcticBlock) : Metrics {
		switch (c) {
		case Border(x, y, block):
			var m = calcMetrics(block);
			m.width += 2 * x;
			m.height += 2 * y;
			return m;
		case Background(color, block):
			return calcMetrics(block);
		case GradientBackground(type, colors, xOffset, yOffset, block, alpha):
			return calcMetrics(block);
		case Text(html):
			// Fall-through to creation
		case Picture(url, w, h, scaling):
			return { width : w, height : h, growWidth : false, growHeight : false };
		case Button(block, action):
			return calcMetrics(block);
		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			return calcMetrics(selected);
		case ToggleButtonGroup(buttons, onSelect):
			return calcMetrics(SelectList(buttons, onSelect));
		case Filler:
			return { width : 0.0, height : 0.0, growWidth : true, growHeight : true };
        case ConstrainWidth(minimumWidth, maximumWidth, block) :
			var m = calcMetrics(block);
			m.width = Math.min(minimumWidth, Math.max(maximumWidth, m.width));
			m.growWidth = false;
			return m;
        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var m = calcMetrics(block);
			m.height = Math.min(minimumHeight, Math.max(maximumHeight, m.height));
			m.growHeight = false;
			return m;
/*		case TextInput(id, contents, listener, width, height, maxChars, restrict, format):
			return { width : width, height : height, growWidth : false, growHeight : false };
*/
		case ColumnStack(columns):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in columns) {
				var cm = calcMetrics(c);
				m.width += cm.width;
				m.height = Math.max(cm.height, m.height);
				m.growWidth = m.growWidth || cm.growWidth;
				if (c != Filler) {
					m.growHeight = m.growHeight || cm.growHeight;
				}
			}
			return m;
		case LineStack(blocks):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in blocks) {
				var cm = calcMetrics(c);
				m.width = Math.max(cm.width, m.width);
				m.height += cm.height;
				if (c != Filler) {
					m.growWidth = m.growWidth || cm.growWidth;
				}
				m.growHeight = m.growHeight || cm.growHeight;
			}
			return m;
		case SelectList(lines, onClick):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in lines) {
				var cm = calcMetrics(c);
				m.width = Math.max(cm.width, m.width);
				m.height += cm.height;
				if (c != Filler) {
					m.growWidth = m.growWidth || cm.growWidth;
				}
				m.growHeight = m.growHeight || cm.growHeight;
			}
			return m;
		}
		
		// The sad fall-back scenario: Create the fucker and ask it, and then destroy it again
		#if flash9
			var tempMovie = new MovieClip();
			parent.addChild(tempMovie);
			var mc = build(c, tempMovie, 0, 0);
			var m = { width : mc.width, height : mc.height, growWidth: false, growHeight: false };
			parent.removeChild(tempMovie);
		#else flash
			var d = parent.getNextHighestDepth();
			var tempMovie = parent.createEmptyMovieClip("c" + d, d);
			var mc = build(c, tempMovie, 0, 0);
			var m = { width : mc._width, height : mc._height, growWidth: false, growHeight: false };
			mc.removeMovieClip();
		#end
		return m;
	}
	
	/// A helper function which forces a movieclip to have a certain size
	static public function setSize(clip : MovieClip, width : Float, height : Float) {
		#if flash9
			// Set the size
			clip.graphics.clear();
			clip.graphics.moveTo(0,0);
			clip.graphics.lineTo(width, height);
		#else flash
			// Set the size
			clip.clear();
			clip.moveTo(0,0);
			clip.lineTo(width, height);
		#end
	}
	
	/// A helper function which sets the size of the clip to the size of the stage
	static public function stageSize(clip : MovieClip) {
		#if flash9
			setSize(clip, clip.stage.stageWidth, clip.stage.stageHeight);
		#else flash
			setSize(clip, flash.Stage.width, flash.Stage.height);
		#end
	}
	
    // This method draws a scrollbar given a movie clip. 
    // This movieclips should have a parent, which will also be the parent of the scroll bar 
    // rendered.
    // This can be seperated out and written as a seperate class - ideally it should use ArcticBlocks to construct itself
    private function drawScrollBar(clip : MovieClip) {
		#if flash9
			// TODO
		#else flash
            var parent = clip._parent;
      		var depth = parent.getNextHighestDepth();
	    	var upperChild = parent.createEmptyMovieClip("c" + depth, depth);
		    upperChild.tabEnabled = true;

            depth = parent.getNextHighestDepth();
	    	var lowerChild = parent.createEmptyMovieClip("c" + depth, depth);
		    lowerChild.tabEnabled = true;

            var clipRect = new Rectangle<Float>(clip._x, clip._y, 
                                                     clip._width, clip._height);
            clip.scrollRect = clipRect;
            lowerChild.beginFill(0xFFFFFF);

            var width = clip._width + 1;
            var height = clip._height - 20;
            //Drawing lower white square 
            lowerChild.moveTo(width, clip._y + height );
            lowerChild.lineTo(width, clip._y + height );
            lowerChild.lineTo(width + 12, clip._y + height);
            lowerChild.lineTo(width + 12, clip._y + height + 10);
            lowerChild.lineTo(width, clip._y + height + 10);
            lowerChild.endFill();
    
            //Drawing lower scrollbar triangle
            lowerChild.beginFill(0x000000);
            lowerChild.moveTo(width + 2 , clip._y + height + 2 );
            lowerChild.lineTo(width + 2, clip._y + height + 2 );
            lowerChild.lineTo(width + 2 + 8, clip._y + height + 2 );
            lowerChild.lineTo(width + 2 + 4, clip._y + height + 5 );
            lowerChild.endFill();

            //Lower scroll bar listener Listener 
            lowerChild.onPress=function() {
                 if ((clipRect.y + 10) < clip._height) {
                     clipRect.y += 10;
                     }
                 clip.scrollRect = clipRect;
            };

            height = clip._y + 4;
            //Drawing upper white squate
            upperChild.beginFill(0xFFFFFF);
            upperChild.moveTo(width,  height );
            upperChild.lineTo(width,  height );
            upperChild.lineTo(width + 12,  height);
            upperChild.lineTo(width + 12,  height + 10);
            upperChild.lineTo(width, height + 10);
            upperChild.endFill();

            height +=  4;
            //Drawing upper scrollbar triangle
            upperChild.beginFill(0x000000);
            upperChild.moveTo(width + 2 ,height + 2 );
            upperChild.lineTo(width + 2, height + 2);
            upperChild.lineTo(width + 2 + 8, height + 2);
            upperChild.lineTo(width + 2 + 4, height - 2 );
            upperChild.endFill();
            upperChild.onPress=function() {
                 if (clipRect.y > 0) {
                    clipRect.y -=10;
                    clip.scrollRect = clipRect;
                 }
            };
		#end
    }
}
