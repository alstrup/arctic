package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.display.MovieClip;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.events.FocusEvent;
#else true
import flash.MovieClip;
import flash.geom.Rectangle;
import flash.TextField;
import flash.TextFormat;
#end

typedef Metrics = { width : Float, height : Float, growWidth : Bool, growHeight : Bool }

typedef ScrollMetrics = { startX : Float, startY : Float, 
                         endY : Float, scrollHeight : Float, toScroll : Float, 
                         clipHeight : Float }

class Arctic {

	public function new(gui0 : ArcticBlock) {
		gui = gui0;
		parent = null;
		base = null;
	}

	public var gui : ArcticBlock;
	public var parent : MovieClip;
	private var base : MovieClip;
    
    //Increasing this value will reduce the speed of the scroll bar and viceversa
    static  private var SCROLL_DELAY : Int = 100;

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
				var sel = build(selected, clip, availableWidth, availableHeight);
				var unsel = build(unselected, clip, availableWidth, availableHeight);
			#if flash9
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

		case TextInput(html, width, height, validator, maxChars, numeric, bgColor) :
			#if flash9
				var txtInput = new flash.text.TextField();
				txtInput.width = width;
				txtInput.height = height;
				if (null != numeric && numeric) { 
					txtInput.restrict = "0-9";
					var txtFormat = txtInput.defaultTextFormat;
					txtFormat.align = "right";
					txtInput.defaultTextFormat = txtFormat;
				}
			#else flash
				var txtInput = clip.createTextField("ti", clip.getNextHighestDepth(), 0, 0, width, height);
				if (null != numeric && numeric) { 
					txtInput.restrict = "0-9";
					var txtFormat = txtInput.getTextFormat();
					txtFormat.align = "right";
					txtInput.setNewTextFormat(txtFormat);
				}
			#end
				setSize(clip, width, height);
				if (null != maxChars) {
					txtInput.maxChars = maxChars;
				}
				if (null != bgColor) {
					txtInput.background = true;
					txtInput.backgroundColor = bgColor;
				}
				txtInput.border = true;
				var validate = function() {
					var isValid = validator(txtInput.text);
					if (isValid) {
						txtInput.background = (null != bgColor);
						if (txtInput.background) {
							txtInput.backgroundColor = bgColor;
						}
					} else {
						txtInput.background = true;
						txtInput.backgroundColor = 0xff0000;
					}
				}
			#if flash9
				txtInput.htmlText = html;
				var listener = function (e:FocusEvent) { validate(); };
				txtInput.addEventListener(FocusEvent.FOCUS_OUT , listener);
				txtInput.type = TextFieldType.INPUT;
				clip.addChild(txtInput);
			#else flash
				txtInput.html = true;
				txtInput.htmlText = html;
				var listener = {
					// TODO : Don't know why 'onKillFocus' event is not working.  'onChanged' will be annoying.
					onChanged : function (txtFld : TextField) {	validate();	}
				};
				txtInput.addListener(listener);
				txtInput.type = "input";
			#end
			return clip;

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
                switch (l) {
                    case SelectList(lines, onClick):
                            y += freeSpace + childMetrics[i].height;        
                    default :
                            #if flash9
					            y += child.height;
            				#else flash
			            		y += child._height;
            				#end
                }
   				++i;
			}
            if (numberOfFillers > 0) { 
                var availableSpaceForFillers = availableHeight - y;
                var spaceForEachFiller = availableSpaceForFillers / numberOfFillers;
                var shift = 0.0;
                y = 0.0;
                for (i in 0...blocks.length) {
                    switch (blocks[i]) {        
                        case Filler: 
                            shift += spaceForEachFiller;
                            setSize(children[i], 0, spaceForEachFiller);
                            y += shift;
                        case SelectList(lines, onClick):
                            #if flash9
                                children[i].y += shift;
                            #else flash
                                children[i]._y += shift;
                            #end
                            y += freeSpace + childMetrics[i].height;        
                        default :
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
            
            drawScrollBar (childClip, availableWidth, availableHeight);
			return clip;

		case ScrollBar(block, availableWidth, availableHeight):
            var child = build(block, clip, availableWidth, availableHeight);            
            drawScrollBar(child, availableWidth, availableHeight);
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
		case TextInput(html, width, height, validator, maxChars, numeric, bgColor):
			return { width : width, height : height, growWidth : false, growHeight : false };
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
		    case ScrollBar(block, availableWidth, availableHeight):
                var cm = calcMetrics(block);
                if (cm.height > availableHeight) {
                    cm.height = availableHeight;
                }

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
    private function drawScrollBar(clip : MovieClip, availableWidth : Float,
                                                         availableHeight : Float) {
        #if flash9 
            drawScrollBarForFlash9(clip, availableWidth, availableHeight);
        #else flash
            if (clip._height <= availableHeight) {
                return;
            }
            var parent = clip._parent;
            var d = parent.getNextHighestDepth();
            var scrollBar = parent.createEmptyMovieClip("c" + d, d);
            var clipRect = new Rectangle<Float>(0, 0 , 
                                                   availableWidth, availableHeight);
            clip.scrollRect = clipRect;
            var squareHeight = 10;

            d = scrollBar.getNextHighestDepth();
            var upperChild = scrollBar.createEmptyMovieClip("scrollBarUpperChild" + d, d);

            // Upper scroll bar handle
            //Drawing upper white squate    
            upperChild.beginFill(0x000000);
            upperChild.moveTo(0,  0 );
            upperChild.lineTo(0,  0 );
            upperChild.lineTo(12, 0 );
            upperChild.lineTo(12, squareHeight );
            upperChild.lineTo(0, squareHeight );
            upperChild.endFill();
            
            var height =  7;

            //Drawing upper scrollbar triangle
            upperChild.beginFill(0xFFFFFF);
            upperChild.moveTo(2 , height );
            upperChild.lineTo(2 , height );
            upperChild.lineTo(2 + 8 , height );
            upperChild.lineTo(2 + 4 , height - 4 );
            upperChild.endFill();

            var scrollHeight = availableHeight - (squareHeight * 2);

            d = scrollBar.getNextHighestDepth();
            var scrollOutline = scrollBar.createEmptyMovieClip("scrollBarOutline" + d, d);
            
            drawLine(scrollOutline, 0, 0, 0.2, scrollHeight, 0x000000);
            drawLine(scrollOutline, 10, 0, 0.3, scrollHeight, 0x000000);

            scrollOutline._y = upperChild._height;

            d = scrollBar.getNextHighestDepth();
            var scrollHand = scrollBar.createEmptyMovieClip("scrollHand" + d, d);
            var scrollHandHeight = 10;
            drawLine(scrollHand, 0, 0, 8, scrollHandHeight - 0.5, 0x000000);
  
            var scrollMet = { startX : 0.0, startY : 0.0, endY : 0.0, 
                            scrollHeight : 0.0, toScroll : 0.0, clipHeight : 0.0 };
            scrollMet.startX = 1.3;
            scrollMet.startY = upperChild._height + 0.5;
            scrollMet.scrollHeight = scrollHeight - scrollHandHeight - 1;
            scrollMet.toScroll = (clip._height / scrollMet.scrollHeight);
            scrollMet.clipHeight = clip._height;
            scrollMet.endY = scrollMet.startY + scrollMet.scrollHeight - 0.5;

            scrollHand._y = upperChild._height + 0.5;
            scrollHand._x = 1.3;

            d = scrollBar.getNextHighestDepth();
            var lowerChild = scrollBar.createEmptyMovieClip("scrollBarLowerChild" + d, d);

            lowerChild.beginFill(0x000000);

            //Drawing lower white square 
            lowerChild.moveTo(0, 0 );
            lowerChild.lineTo(0, 0 );
            lowerChild.lineTo(12, 0);
            lowerChild.lineTo(12, squareHeight);
            lowerChild.lineTo(0,  squareHeight);
            lowerChild.endFill();
            
            height = 3;
            //Drawing lower scrollbar triangle
            lowerChild.beginFill(0xFFFFFF);
            lowerChild.moveTo(2 , height );
            lowerChild.lineTo(2, height );
            lowerChild.lineTo(2 + 8, height );
            lowerChild.lineTo(2 + 4, height + 4 );
            lowerChild.endFill();
            //lowerChild._x = 10;
            lowerChild._y = availableHeight - 10 ;

            var dragged = false;
            scrollBar.onMouseDown = function () {
                var mouseInside = scrollHand.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);
                
                var inScrollOutline = scrollOutline.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);
                var inLowerChild = lowerChild.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);
                var inUpperChild = upperChild.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);

                if (mouseInside) {
                    scrollHand.startDrag(false , scrollMet.startX , 
                                                    scrollMet.startY ,
                                                    scrollMet.startX , 
                                                    scrollHeight );
                    dragged = true;
                    Reflect.setField(Bool, "dragging", true);
                    scrollTimer(clip, scrollHand, clipRect, scrollMet);
                } else if (inScrollOutline) {
                    var scrollToY = flash.Lib.current._ymouse;
                    scrollToY = scrollToY - 139;//scrollBar._y;
                    scrollToY = scrollBar._ymouse;
                    var startY = scrollMet.startY;
                    if (scrollToY < startY ) {
                        scrollToY = scrollMet.startY;
                    } else if (scrollToY >= scrollMet.endY) {
                        scrollToY = scrollMet.endY;
                    }
                    scrollHand._y = scrollToY;
                    scroll(clip, scrollHand, clipRect, scrollMet);
                } else if ( inLowerChild) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, true);
                } else if (inUpperChild) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, false);
                }
            }

            scrollBar.onMouseUp = function() {
                var dragged = Reflect.field(Bool, "dragging");
                if (dragged) {
                    scrollHand.stopDrag();                
                    Reflect.setField(Bool, "dragging", false);
                }
                var scrollPressed = Reflect.field(Bool, "scrollPressed");
                if (scrollPressed) {
                    Reflect.setField(Bool, "scrollPressed", false);
                }            
            }

            scrollBar._x = availableWidth - 2;
            scrollBar._y = clip._y;
        #end
       }


    #if flash9
       static public function scrollTimer(clip : MovieClip, scrollHand : MovieClip, 
                            rect : Rectangle, scrollMet : ScrollMetrics) {          
    #else flash
       static public function scrollTimer(clip : MovieClip, scrollHand : MovieClip, 
                        rect : Rectangle<Float>, scrollMet : ScrollMetrics) {
    #end
            var interval = new haxe.Timer(100);                
            interval.run = function () {
                var dragged = Reflect.field(Bool, "dragging");
                scroll(clip, scrollHand, rect, scrollMet);
                if ( !dragged ) {
                    interval.stop();
                }
            }
        }


    #if flash9
        static private function scrollByOne(clip : MovieClip, 
                             scrollHand : MovieClip, rect : Rectangle, 
                             scrollMet : ScrollMetrics, scrollDown : Bool) {
            var interval = new haxe.Timer(15);                
            interval.run = function () {
                var scrollPressed = Reflect.field(Bool, "scrollPressed");
                if (scrollDown) {
                    if ( (scrollHand.y + 1) <= scrollMet.endY ) {
                          scrollHand.y++;
                    }
                } else {
                    if ( (scrollHand.y - 1 ) >= scrollMet.startY ) {
                          scrollHand.y--;
                    }
                }

   #else flash
        static private function scrollByOne(clip : MovieClip, scrollHand : MovieClip, 
                      rect : Rectangle < Float >, scrollMet : ScrollMetrics,                                                                     scrollDown : Bool) {
            var interval = new haxe.Timer(15);                
            interval.run = function () {
                var scrollPressed = Reflect.field(Bool, "scrollPressed");
                if (scrollDown) {
                    if ( (scrollHand._y + 1) <= scrollMet.endY ) {
                          scrollHand._y++;
                    }
                } else {
                    if ( (scrollHand._y - 1 ) >= scrollMet.startY ) {
                          scrollHand._y--;
                    }
                }
    #end
                scroll(clip, scrollHand, rect, scrollMet);
                if ( !scrollPressed ) {
                    interval.stop();
                }
            }
        }



    #if flash9
        static private function scroll(clip : MovieClip, scrollHand : MovieClip, 
                rect : Rectangle, scrollMet : ScrollMetrics ) {   
             if ( (scrollHand.y >= scrollMet.startY )  && (scrollHand.y <= scrollMet.endY)) {
                var diff = scrollHand.y - scrollMet.startY;

    #else flash
        static private function scroll(clip : MovieClip, scrollHand : MovieClip, 
                    rect : Rectangle < Float >, scrollMet : ScrollMetrics) {
             if ( (scrollHand._y >= scrollMet.startY )  && (scrollHand._y <= scrollMet.endY)) {
                var diff = scrollHand._y - scrollMet.startY;
    #end
                var increment = scrollMet.toScroll * diff;
                if (increment < (scrollMet.clipHeight - 10) ) {
                    rect.y = increment;
                    clip.scrollRect = rect;
                } else {
                    rect.y = scrollMet.clipHeight - 10;
                    clip.scrollRect = rect;
                }
            }
        }


    #if flash9
        static private function drawLine(clip : MovieClip, startX : Float, 
              startY : Float, lineWidth : Float , lineHeight : Float, rgb : Int) { 

            clip.graphics.beginFill(rgb);
            clip.graphics.moveTo(startX + 0.2,  startY );
            clip.graphics.lineTo(startX + 0.2,  startY );
            clip.graphics.lineTo(startX + 0.2 + lineWidth, startY );
            clip.graphics.lineTo(startX + 0.2 + lineWidth, startY + lineHeight );
            clip.graphics.lineTo(startX + 0.2, startY + lineHeight );
            clip.graphics.endFill();
        }
    #else flash
        static private function drawLine(clip : MovieClip, startX : Float, 
              startY : Float, lineWidth : Float , lineHeight : Float, rgb : Int) { 
            
            //Drawing lower scrollbar triangle
            clip.beginFill(rgb);
            clip.moveTo(startX + 0.2,  startY );
            clip.lineTo(startX + 0.2,  startY );
            clip.lineTo(startX + 0.2 + lineWidth, startY );
            clip.lineTo(startX + 0.2 + lineWidth, startY + lineHeight );
            clip.lineTo(startX + 0.2, startY + lineHeight );
            clip.endFill();

        }
    #end

    #if flash9 
        private function drawScrollBarForFlash9(clip : MovieClip, availableWidth : Float,
                                                         availableHeight : Float) {
            if (clip.height <= availableHeight) {
                return;
            }
            var parent = clip.parent;
            var scrollBar = new MovieClip();
            parent.addChild(scrollBar);
            var clipRect = new Rectangle(0, 0 , availableWidth, availableHeight);
            clip.scrollRect = clipRect;
            var squareHeight = 10;

            var upperChild = new MovieClip();
            scrollBar.addChild(upperChild);

            // Upper scroll bar handle
            //Drawing upper white squate    
            upperChild.graphics.beginFill(0x000000);
            upperChild.graphics.moveTo(0,  0 );
            upperChild.graphics.lineTo(0,  0 );
            upperChild.graphics.lineTo(12, 0 );
            upperChild.graphics.lineTo(12, squareHeight );
            upperChild.graphics.lineTo(0, squareHeight );
            upperChild.graphics.endFill();
            
            var height =  7;

            //Drawing upper scrollbar triangle
            upperChild.graphics.beginFill(0xFFFFFF);
            upperChild.graphics.moveTo(2 , height );
            upperChild.graphics.lineTo(2 , height );
            upperChild.graphics.lineTo(2 + 8 , height );
            upperChild.graphics.lineTo(2 + 4 , height - 4 );
            upperChild.graphics.endFill();

            var scrollHeight = availableHeight - (squareHeight * 2);

            var scrollOutline = new MovieClip();
            scrollBar.addChild(scrollOutline);
            
//            drawLine(scrollOutline, 0, 0, 0.2, scrollHeight, 0x000000);
//            drawLine(scrollOutline, 10, 0, 0.3, scrollHeight, 0x000000);
            
            drawLine(scrollOutline, 0, 0, 10, scrollHeight, 0xFFFFFF);
            scrollOutline.y = upperChild.height;

            var scrollHand = new MovieClip();
            scrollBar.addChild(scrollHand);
            var scrollHandHeight = 10;
            drawLine(scrollHand, 0, 0, 8, scrollHandHeight - 0.5, 0x000000);
  
            var scrollMet = { startX : 0.0, startY : 0.0, endY : 0.0, 
                            scrollHeight : 0.0, toScroll : 0.0, clipHeight : 0.0 };
            scrollMet.startX = 1.2;
            scrollMet.startY = upperChild.height + 0.5;
            scrollMet.scrollHeight = scrollHeight - scrollHandHeight - 1;
            scrollMet.toScroll = (clip.height / scrollMet.scrollHeight);
            scrollMet.clipHeight = clip.height;
            scrollMet.endY = scrollMet.startY + scrollMet.scrollHeight - 0.5;

            scrollHand.y = upperChild.height + 0.5;
            scrollHand.x = 1.2;

            var lowerChild = new MovieClip();
            scrollBar.addChild(lowerChild);


            lowerChild.graphics.beginFill(0x000000);

            //Drawing lower white square 
            lowerChild.graphics.moveTo(0, 0 );
            lowerChild.graphics.lineTo(0, 0 );
            lowerChild.graphics.lineTo(12, 0);
            lowerChild.graphics.lineTo(12, squareHeight);
            lowerChild.graphics.lineTo(0,  squareHeight);
            lowerChild.graphics.endFill();
            
            height = 3;
            //Drawing lower scrollbar triangle
            lowerChild.graphics.beginFill(0xFFFFFF);
            lowerChild.graphics.moveTo(2 , height );
            lowerChild.graphics.lineTo(2, height );
            lowerChild.graphics.lineTo(2 + 8, height );
            lowerChild.graphics.lineTo(2 + 4, height + 4 );
            lowerChild.graphics.endFill();
            //lowerChild._x = 10;
            lowerChild.y = availableHeight - 10 ;

    		scrollHand.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    scrollHand.startDrag(false , new Rectangle(
                                                    scrollMet.startX , 
                                                    scrollMet.startY ,
                                                    scrollMet.startX , 
                                            scrollMet.scrollHeight) );
                    Reflect.setField(Bool, "dragging", true);
                    scrollTimer(clip, scrollHand, clipRect, scrollMet);
                 } ); 


    		scrollHand.addEventListener(
                flash.events.MouseEvent.MOUSE_UP, 
                function (s) {
                    var dragged = Reflect.field(Bool, "dragging");
                    if (dragged) {
                        scrollHand.stopDrag();                
                        Reflect.setField(Bool, "dragging", false);
                    }
                 } ); 


    		scrollOutline.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    trace("in scroll outline");
                    //var scrollToY = scrollBar._ymouse;
                     var scrollToY = s.localY;
                    var startY = scrollMet.startY;
                    if (scrollToY < startY ) {
                        scrollToY = scrollMet.startY;
                    } else if (scrollToY >= scrollMet.endY) {
                        scrollToY = scrollMet.endY;
                    }
                    scrollHand.y = scrollToY;
                    scroll(clip, scrollHand, clipRect, scrollMet);
                 } ); 



    		lowerChild.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, true);
                } ); 


    		lowerChild.addEventListener(
                flash.events.MouseEvent.MOUSE_UP, 
                function (s) {
                    var scrollPressed = Reflect.field(Bool, "scrollPressed");
                    if (scrollPressed) {
                        Reflect.setField(Bool, "scrollPressed", false);
                    }            
                 } ); 

    		upperChild.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, false);
                } ); 


    		upperChild.addEventListener(
                flash.events.MouseEvent.MOUSE_UP, 
                function (s) {
                    var scrollPressed = Reflect.field(Bool, "scrollPressed");
                    if (scrollPressed) {
                        Reflect.setField(Bool, "scrollPressed", false);
                    }            
                 } ); 


            scrollBar.x = availableWidth - 2;
            scrollBar.y = clip.y;

       }
        #end


}
