package arctic;
import arctic.ArcticBlock;
import arctic.ArcticMC;
import haxe.Timer;

#if (flash9||neko)
import flash.geom.Matrix;
import flash.geom.Point;
import flash.display.DisplayObjectContainer;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.FocusEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.display.DisplayObject;
import flash.display.Bitmap;
import flash.display.Loader;
import flash.display.BitmapData;
#elseif flash
import flash.MovieClip;
import flash.MovieClipLoader;
import flash.TextField;
import flash.TextFormat;
import flash.Mouse;
#end

/// Information we need at runtime to implement updating
typedef BlockInfo = {
	// Dragable needs to know how much space is available in the containing block
	available : { width: Float, height : Float },
	// Dragable needs to know how much we have moved so far
	totalDx : Float,
	totalDy : Float,
	// Dragable needs to know how big the draggable area is
	childWidth : Float,
	childHeight : Float
}

typedef CellProperty = {
	width : Float,
	height : Float,
	x : Int,
	y : Int,
	rowSpan : Int,
	colSpan : Int, 
	topBorder : Int,
	rightBorder : Int,
	bottomBorder : Int,
	leftBorder : Int
}

/**
 * The main class in Arctic which builds a user interface from an ArcticBlock.
 * Construct the ArcticBlock representing your user interface and call
 * display() with a movieclip to construct it.
 * Building the user interface is a done in a depth first traversal of the
 * tree of blocks - see build. Some blocks might need to know the size of
 * their children to make layout themselves, which build can find out.
 */
class ArcticView {
	/**
	 * This prepares a user interface view of the given block on the given movieclip.
	 * Nothing is displayed. Call display() to make the user interface visible.
	 */ 
	public function new(gui0 : ArcticBlock, parent0 : ArcticMovieClip) {
		gui = gui0;
		parent = parent0;
		base = null;
		useStageSize = false;
		if (metricsCache == null) {
			metricsCache = new Hash<{ width: Float, height : Float } >();
		}
		size = null;
		pendingPictureRequests = 0;

		#if (flash9||neko)
			stageEventHandlers = [];
		#end

		#if flash9
		if (pictureCache == null) {
			pictureCache = new Hash();
		}
		#end
		#if debug
		trackMemory = false;
		#end
	}

	/// This is the block this view presents
	public var gui : ArcticBlock;
	/// The parent MovieClip which we put the view on
	public var parent : ArcticMovieClip;
	/// The root ArcticMovieClip we built for the view
	private var base : ArcticMovieClip;
	/// Whether or not we should track resizing of the Flash window
	private var useStageSize : Bool;
	/// If not using stage size, what size should we use when building?
	private var size : { width : Float, height : Float };
	
	/// This resizes the hosting movieclip to make room for our GUI block minimumsize, plus some extra space
	public function adjustToFit(extraWidth : Float, extraHeight : Float) : { width: Float, height : Float} {
		#if debug
		currentPath = "";
		currentBlockKind = "";
		#end
		var w = build(gui, parent, 0, 0, Metrics, 0);
		ArcticMC.setSize(parent, w.width + extraWidth, w.height + extraHeight);
		size = { width: w.width + extraWidth, height: w.height + extraHeight };
		return size;
	}

	/**
	 * Builds the user interface. If useStageSize is true the user interface will 
	 * automatically resize to the size of the stage. If not, the user interface will
	 * be sized according to the size of the parent movieclip. You can use
	 * adjustToFit() to resize the parent to the minimum space required for the
	 * block.
	 */
	public function display(useStageSize0 : Bool) : ArcticMovieClip {
		useStageSize = useStageSize0;
		if (useStageSize) {
			ArcticMC.stageSize(parent);
			size = ArcticMC.getStageSize(parent);
		} else {
			if (size == null) {
				size = ArcticMC.getSize(parent);
			}
		}
		
		refresh(true);

		if (useStageSize) {
			// Make sure we follow screen resizes
			#if flash9
				parent.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
				parent.stage.align = flash.display.StageAlign.TOP_LEFT;
				var t = this;
				addStageEventListener(parent, parent.stage, flash.events.Event.RESIZE, function( event : flash.events.Event ) { t.onResize();} ); 
			#elseif flash
				flash.Stage.addListener(this);
				flash.Stage.scaleMode = "noScale";
				flash.Stage.align = "TL";
			#end
		}
        return base;
	}
	
	#if (flash9||neko)
	/// We record all the event handlers we register so that we can clean them up again when destroyed
	private var stageEventHandlers : Array<{ obj: EventDispatcher, event : String, handler : Dynamic, ref : Dynamic } >;
	#end
	
	/**
	 * This removes and destroys the view. You have to use this to clean up
	 * properly.
	 */
	public function destroy() {
		remove();
		gui = null;
		ArcticMC.showMouse();
		
		#if (flash9||neko)
			for (e in stageEventHandlers) {
				e.obj.removeEventListener(e.event, e.handler);
			}
			stageEventHandlers = [];
		#end
		if (useStageSize) {
			#if flash9
			#elseif flash
				flash.Stage.removeListener(this);
			#end
		}
	}
	
	/// Our resize handler is called by Flash when the Flash movie is resized
	public function onResize() {
		if (true) {
			/// This is smart refresh, where we reuse MovieClips to reduce flicker
			size = ArcticMC.getStageSize(parent);
			#if debug
			currentPath = "";
			currentBlockKind = "";
			#end
			var result = build(gui, parent, size.width, size.height, Reuse, firstChild);
			base = result.clip;
		} else {
			/// This is dumb refresh, where we rebuilt everything from scratch
			if (base != null) {
				remove();
			}
			ArcticMC.stageSize(parent);
			refresh(true);
		}
	}

	/**
	* This will update the user interface. Useful if you have updated
	* the GUI using update() below. If you pass true, everything is built
	* from scratch.
	*/ 
	public function refresh(rebuild : Bool): {width: Float, height: Float, base: ArcticMovieClip} {
		if (rebuild && base != null) {
			remove();
		}
		if (rebuild) {
			idMovieClip = new Hash<ArcticMovieClip>();
			ArcticMC.showMouse();
			#if flash9
			firstChild = parent.numChildren;
			// remove stage listeners
			for (e in stageEventHandlers) {
				e.obj.removeEventListener(e.event, e.handler);
			}
			stageEventHandlers = [];
			#elseif flash
			firstChild = ArcticMC.getNextHighestDepth(parent);
			mouseWheelListeners = new Array<{ clip: ArcticMovieClip, listener: Dynamic } >();
			#end
		}
		#if debug
		currentPath = "";
		currentBlockKind = "";
		#end
		var result = build(gui, parent, size.width, size.height, if (rebuild) Create else Reuse, firstChild);
		base = result.clip;
		return {width: result.width, height: result.height, base: base};
	}
	/// What child number is the root block on the parent clip?
	private var firstChild : Int;
	
	/**
	* Get access to the raw movieclip for the named block.
	* Notice! This movieclip is destroyed on refresh, and thus you have to
	* do call this method again to do the special stuff you do again
	* on the new clip for the named block.
	*/
	public function getRawMovieClip(id : String) : ArcticMovieClip {
		if (idMovieClip != null) return idMovieClip.get(id);
		else return null;
	}
	
	/**
	 * Removes the visual element - notice, however that if useStage is true, 
	 * the view is reconstructed on resize. Use destroy() if you want to get 
	 * rid of this display for good
	 */
	private function remove() {
		if (base == null) {
			return;
		}
		#if flash9
		#elseif flash
			// Clean up mouse wheel listeners
			for (s in mouseWheelListeners) {
				flash.Mouse.removeListener(s.listener);
			}
			mouseWheelListeners = [];
		#end
		#if debug
		currentPath = "";
		currentBlockKind = "";
		#end
		var result = build(gui, parent, size.width, size.height, Destroy, firstChild);
		ArcticMC.remove(base);
		#if flash9
		#elseif flash
		ArcticMC.delete(parent, "c" + firstChild);
		#end
		idMovieClip = new Hash<ArcticMovieClip>();
		base = null;
	}

	/// And the movieclips for named ids here
	private var idMovieClip : Hash<ArcticMovieClip>;
	
	#if flash9
	#elseif flash
	private var mouseWheelListeners : Array< { clip: ArcticMovieClip, listener : Dynamic } >;
	#end

	/**
	 * This constructs or updates all the movieclips used to display the given block on the
	 * given movieclip. It will potentially fill out the available space passed. The
	 * childNo parameter is bookkeeping to who which sibling ArcticMovieClip corresponds to the
	 * root movieclip.
	 * We return the resulting root clip, along with the size of it. (We can not rely
	 * on Flash to tell the size, especially when scrollbars using Flash scrollRect
	 * feature are involved).
	 * The algorithm is a simple recursive depth first traversal of the blocks.
	 */
    public function build(gui : ArcticBlock, p : ArcticMovieClip, 
                    availableWidth : Float, availableHeight : Float, mode : BuildMode, childNo : Int) : Metrics {
#if false
		if (mode == Destroy) {
			if (nesting == null) {
				nesting = "";
			} else {
				nesting = nesting + "  ";
			}
			trace(nesting + currentPath + "Calling build ( " + availableWidth + "," + availableHeight + ", " + mode + ") on "+ gui);
		}
		var clip = doBuild(gui, p, availableWidth, availableHeight, mode, childNo);
		if (mode == Destroy) {
			trace(nesting + "built (" + availableWidth + "," + availableHeight + ", " + mode + "): (" 
				+ clip.width + "," + clip.height + " " + clip.growWidth + "," + clip.growHeight + ") on " + gui );
			if (nesting != null) {
				nesting = nesting.substr(0, nesting.length - 2);
			}
		}

		return clip;
	}
	
	public var debug : Bool;
	private var nesting : String;
	
	private function doBuild(gui : ArcticBlock, p : ArcticMovieClip, 
                    availableWidth : Float, availableHeight : Float, mode : BuildMode, childNo : Int) : Metrics {
#end
		#if debug
			if (gui == null) {
				currentBlockKind = "empty";
			} else {
				currentBlockKind = Type.enumConstructor(gui);
			}
			currentPath += "/" + currentBlockKind;
		#end

		if (gui == null) {
			/* This can happen (at least) because of the call
			   
						var result = build(mutableBlock.block, childClip, availableWidth, availableHeight, mode, 0);

			   in the case for Mutable.
			*/
			return { clip: null, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
		}
		switch (gui) {
		case Border(x, y, block):
			if (mode != Metrics && mode != Destroy) {
				if (availableWidth < 2 * x) {
					x = availableWidth / 2;
				}
				if (availableHeight < 2 * y) {
					y = availableHeight / 2;
				}
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, Math.max(0.0, availableWidth - 2 * x), Math.max(availableHeight - 2 * y, 0.0), mode, 0);
			child.width += 2 * x;
			child.height += 2 * y;
			if ((mode == Create || mode == Reuse) && child.clip != null) {
				ArcticMC.setXY(child.clip, x, y);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Frame(thickness, color, block, roundRadius, alpha, xspacing, yspacing):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);			
			if (xspacing == null) xspacing = 0;
			if (yspacing == null) yspacing = 0;
			var x = xspacing + thickness;
			var y = yspacing + thickness;
			if (x != 0 || y != 0) {
				block = Border(x + 0.5, y + 0.5, block);
			}
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if ((mode == Create || mode == Reuse) && thickness != 0) {
				var delta = thickness / 2;
				var g = ArcticMC.getGraphics(clip);
				g.clear();
				g.lineStyle(thickness, color, ArcticMC.convertAlpha(alpha));
				DrawUtils.drawRect(clip, delta, delta, child.width - thickness, child.height - thickness, roundRadius);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Filter(filter, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			#if flash6
			#elseif flash7
			#elseif flash // 8 & 9
			if (mode == Create) {
				/// We have to fix parameters that are "undefined"
				/// Since null == undefined, the following functions will change undefined to null
				/// Due to strong typing, we have a fix-up function for each parameter type. c is color, which can be Float or UInt depending on target
				var f = function (a) { return if (a == null) null else a; };
				var c = function (a) { return if (a == null) null else a; };
				var i = function (a) { return if (a == null) null else a; };
				var b = function (a) { return if (a == null) null else a; };
				var s = function (a) { return if (a == null) null else a; };
				var blt = function (type) {
					// make filters always use strings as the bitmap filter type, even
					// though flash9 changes to use an enum
					return
							#if flash9
								switch (type) {
									case "full": flash.filters.BitmapFilterType.INNER;
									case "inner": flash.filters.BitmapFilterType.INNER;
									case "outer": flash.filters.BitmapFilterType.OUTER;
									default: null;
								};
							#else
								type;
							#end
				}
				var myFilter : Dynamic;
				switch(filter) {
				case Bevel(distance, angle, highlightColor, highlightAlpha, shadowColor, shadowAlpha, blurX, blurY, strength, quality, type, knockout):
					myFilter = new flash.filters.BevelFilter(f(distance ), f(angle), c(highlightColor), f(highlightAlpha),
															 c(shadowColor), f(shadowAlpha), f(blurX), f(blurY), f(strength),
															 i(quality), blt(type), b(knockout));
				case Blur(blurX, blurY, quality):
					myFilter = new flash.filters.BlurFilter(f(blurX), f(blurY), i(quality));
				case ColorMatrix(matrix):
					myFilter = new flash.filters.ColorMatrixFilter(matrix);
				case Convolution(matrixX, matrixY, matrix, divisor, bias, preserveAlpha, clamp, color, alpha):
					myFilter = new flash.filters.ConvolutionFilter(f(matrixX), f(matrixY), matrix, f(divisor), f(bias), b(preserveAlpha), b(clamp), c(color), f(alpha));
#if flash9
				case DropShadow(distance, angle, color, alpha, blurX, blurY/*, strength, quality, inner, knockout, hideObject*/):
					myFilter = new flash.filters.DropShadowFilter(f(distance), f(angle), c(color), f(alpha), f(blurX), f(blurY));
#else
				case DropShadow(distance, angle, color, alpha /*, blurX, blurY, strength, quality, inner, knockout, hideObject*/):
					myFilter = new flash.filters.DropShadowFilter(f(distance), f(angle), c(color), f(alpha));
#end
				case Glow(color, alpha, blurX, blurY, strength, quality, inner, knockout):
					myFilter = new flash.filters.GlowFilter(c(color), f(alpha), f(blurX), f(blurY), f(strength), i(quality), b(inner), b(knockout));
				case GradientBevel(distance, angle, colors, alphas, ratios, blurX, blurY, strength, quality, type, knockout):
					myFilter = new flash.filters.GradientBevelFilter(f(distance), f(angle), colors, alphas, ratios, f(blurX),
																	 f(blurY), f(strength), i(quality), s(type), b(knockout));
				case GradientGlow(distance, angle, colors, alphas, ratios, blurX, blurY, strength, quality, type, knockout):
					myFilter = new flash.filters.GradientGlowFilter(f(distance), f(angle), colors, alphas, ratios, f(blurX),
																	f(blurY), f(strength), i(quality), blt(type), b(knockout));
				};
				// TODO: We do not support changing of Filter parameters in an update
				// We must use a temporary array (see documentation)
				var _filters = clip.filters;
				_filters.push(myFilter);
				clip.filters = _filters;
			}
			#end
			// Notice: We do not let the filter affect the size
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Background(color, block, alpha, roundRadius):
			if (mode == Metrics) {
				return build(block, null, availableWidth, availableHeight, mode, 0);
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Destroy) {
				// a fill will not be created if the color is equal to null
				var g = ArcticMC.getGraphics(clip);
				g.clear();
				if (color != null) {
					g.beginFill(color, ArcticMC.convertAlpha(alpha));
					DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
					g.endFill();
				}
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation, ratios):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics || mode == Destroy || colors == null || colors.length == 0) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			if (ratios == null) {
				ratios = [];
				var dt = 255 / (colors.length - 1);
				var r = 0.0;
				for (i in 0...colors.length) {
					ratios.push(Math.floor(r));
					r += dt;
				}
			}
			var alphas = [];
			for (i in 0...colors.length) {
				if (alpha == null) {
					alphas.push(ArcticMC.convertAlpha(100.0));
				} else {
					alphas.push(ArcticMC.convertAlpha(alpha[i]));
				}
			}
			if (rotation == null) rotation = 0;
			#if flash6
			var matrix = {matrixType:"box", x:child.width * xOffset, y:child.height * yOffset, w:child.width , h: child.height , r: rotation};
			#elseif flash7
			var matrix = {matrixType:"box", x:child.width * xOffset, y:child.height * yOffset, w:child.width , h: child.height , r: rotation};
			#elseif flash
			var matrix = new flash.geom.Matrix();
			matrix.createGradientBox(child.width, child.height, rotation, child.width * xOffset, child.height * yOffset);
			#end
			var g = ArcticMC.getGraphics(clip);
			g.clear();
			#if flash9
				var t = if (type == "linear") { flash.display.GradientType.LINEAR; } else flash.display.GradientType.RADIAL;
				g.beginGradientFill(t, colors, alphas, ratios, matrix);
			#elseif flash
				g.beginGradientFill(type, colors, alphas, ratios, matrix);
			#end
			DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
			g.endFill();
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Text(html, embeddedFont, wordWrap, selectable, format):
			if (wordWrap == null) {
				wordWrap = false;
			}
			if (mode == Metrics && !wordWrap && metricsCache.exists(html)) {
				var m = metricsCache.get(html);
				return { clip: null, width : m.width, height : m.height, growWidth : false, growHeight : false };
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Destroy) {
				return { clip: clip, width: 0.0, height: 0.0, growWidth: wordWrap, growHeight: false };
			}
			#if flash9
				var tf : flash.text.TextField = null;
				if (mode == Create || mode == Metrics) {
					tf = new flash.text.TextField();
					if (mode == Create) {
						ArcticMC.set(clip, "tf", tf);
					}
				} else if (mode == Reuse) {
					tf = ArcticMC.get(clip, "tf");
					if (tf == null) {
						return { clip: clip, width: 0.0, height: 0.0, growWidth: wordWrap, growHeight: false };						
					}
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				if (wordWrap) {
					tf.wordWrap = true;
					tf.width = availableWidth;
				}
				tf.autoSize = flash.text.TextFieldAutoSize.LEFT;
				tf.selectable = (true == selectable);
				tf.multiline = true;
				tf.htmlText = html;
				if (format != null)
					tf.setTextFormat(format);
				if (mode == Create) {
					clip.addChild(tf);
				}
			#elseif flash
				if (mode == Metrics) {
					clip = ArcticMC.create(parent);
				}
				var tf : flash.TextField;
				if (mode == Create || mode == Metrics) {
					tf = ArcticMC.createTextField(clip, 0, 0, if (wordWrap) availableWidth else 0, 100);
					ArcticMC.set(clip, "tf", tf);
				} else {
					tf = ArcticMC.get(clip, "tf");
					if (wordWrap) {
						tf._width = availableWidth;
					}
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				tf.autoSize = true;
				tf.html = true;
				tf.selectable = (true == selectable);
				tf.multiline = true;
				tf.htmlText = html;
				tf.wordWrap = wordWrap;
			#elseif neko
				var tf : neash.text.TextField = null;
				if (mode == Create || mode == Metrics) {
					tf = new neash.text.TextField();
				} else if (mode == Reuse) {
					tf = cast(clip.getChildAt(0), neash.text.TextField);
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				if (wordWrap) {
					tf.wordWrap = true;
					tf.width = availableWidth;
				}
				tf.autoSize = neash.text.TextFieldAutoSize.LEFT;
				tf.selectable = (true == selectable);
				tf.multiline = true;
				tf.htmlText = html;
				if (mode == Create) {
					clip.addChild(tf);
				}
			#end
			if ((Arctic.textSharpness != null || Arctic.textThickness != null) && (mode == Create || mode == Metrics)) {
				// we really need this in Metrics mode because it can make text wider
				ArcticMC.setTextRenderingQuality(tf, Arctic.textSharpness, Arctic.textGridFit, Arctic.textThickness);
			}
			var s = ArcticMC.getSize(clip);
			/* This stuff is useful, but breaks lots of layouts so we have to disable it and find some way to introduce it without breaking stuff:
			#if flash9
				if (wordWrap) {
					// If we are word wrapped and there is plenty of room in the width, we shrink ourselves accordingly
					if (s.width - tf.textWidth > 5) {
						tf.width = tf.textWidth + 5;
					}
					s = ArcticMC.getSize(clip);
				}
			#end
			*/
			if (mode == Metrics) {
				#if flash9
					s.width = tf.width;
					s.height = tf.height;
				#elseif flash
					clip.removeMovieClip();
				#end
				clip = null;
				// Cache the result
				if (!wordWrap) {
					metricsCache.set(html, s);
				}
			}
			return { clip: clip, width: s.width, height: s.height, growWidth: wordWrap, growHeight: false };

		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont, onInit, onInitEvents) :
			return buildTextInput(p, childNo, mode, availableWidth, availableHeight, html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont, onInit, onInitEvents);
		
		case Picture(url, w, h, scaling, resource, crop, cache, cbSizeDiff):
			if (mode == Metrics) {
				return { clip: null, width : w, height : h, growWidth : false, growHeight : false };
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var width = w;
			var height = h;
			var checkSizes = function (realWidth : Float, realHeight : Float) {
				if (cbSizeDiff != null && (realWidth != w || realHeight != h)) {
					cbSizeDiff(realWidth, realHeight);
				}
			}
			#if flash9
				if (mode == Create) {
					if (Type.resolveClass(url) != null) {
						var loader = flash.Lib.attach(url);
						clip.addChild(loader);
					} else {
						var cachedPicture:Dynamic = pictureCache.get(url);
						if (cachedPicture != null) {
							//trace("in cache:" + url, 0);
							try {
								var clone : BitmapData = cachedPicture.clone(); 
								var bmp:Bitmap = new Bitmap(clone);
								bmp.smoothing = true;
								
								clip.addChild(bmp);
								checkSizes(bmp.width, bmp.height);
							} catch( unknown : Dynamic ) {
								trace("Error during restoring image from cache : " + Std.string(unknown));
							}
						}
						else {
							// Count how many pictures we are loading
							pendingPictureRequests++;
							var loader = new flash.display.Loader();
							clip.addChild(loader);
							var dis = loader.contentLoaderInfo;
							var request = new flash.net.URLRequest(Arctic.baseurl + url);
						
							var me = this;
							dis.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function (event : flash.events.IOErrorEvent) {
								trace("[ERROR] IO Error with " + url + ": " + event.text);
								if (me.pictureLoadedFn != null) {
									me.pictureLoadedFn(--me.pendingPictureRequests);
								}
							});
							dis.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function (event : flash.events.SecurityErrorEvent) {
								trace("[ERROR] Security Error with " + url + ": " + event.text);						
							});
												
							dis.addEventListener(flash.events.Event.COMPLETE, function(event : flash.events.Event) {
								try {
									var loader : flash.display.Loader = event.target.loader;
									var content:Dynamic = loader.content;
									//trace(loader.content);
									if (Std.is(content, flash.display.Bitmap)) {
										//trace("isbmp", 0);
										// Bitmaps are not smoothed per default when loading. We take care of that here
										var image : flash.display.Bitmap = cast loader.content;
										width = image.width;
										height = image.height;
										image.smoothing = true;
										if (cache == true) {
											pictureCache.set(url, image.bitmapData);
										}
										if (scaling < 0) {
											var s = Math.min(w / width, h / height);
											clip.scaleX = s;
											clip.scaleY = s;
										} else {
											checkSizes(image.width, image.height);
										}
									} else {
										var className:String = untyped __global__["flash.utils.getQualifiedClassName"](content);
										if (className == "flash.display::AVM1Movie") {
											//trace("url:" + url + " is AVM1. Caching", 0);
											width = content.width;
											height = content.height;
											var transparent = true;
											var bmpData:BitmapData = new BitmapData(Std.int(width), Std.int(height), transparent, 0);
											bmpData.draw(content);
											if (cache == true){
												pictureCache.set(url, bmpData);
											}
											if (scaling < 0) {
												var s = Math.min(w / width, h / height);
												clip.scaleX = s;
												clip.scaleY = s;
											} else {
												checkSizes(width, height);
											}
										}
										//else {
											//trace("url:" + url + " is:" + className + " ignore", 0);
										//}
									}
									if (crop != null) {
										// Crop our clip in attempt to avoid spurious lines
										loader.scrollRect = new ArcticRectangle(crop, crop, loader.width - 2 * crop, loader.height - 2 * crop);
									}
									if (me.pictureLoadedFn != null) {
										me.pictureLoadedFn(--me.pendingPictureRequests);
									}
								} catch (e : Dynamic) {
									// When running locally, security errors can be called when we access the content
									// of loaded files, so in that case, we have lost, and can not use nice smoothing
								}
							}
							);
							loader.load(request);						
						}
					}
					var s = scaling;
					if (s >= 0) {
						clip.scaleX = s;
						clip.scaleY = s;
					}
				}
			#elseif flash
				var s = scaling * 100.0;
				if (resource) {
					var child;
					if (mode == Create) {
						var d = ArcticMC.getNextHighestDepth(clip);
						child = clip.attachMovie(Arctic.baseurl + url, "picture", d);
						ArcticMC.set(clip, "picture", child);
						child._xscale = s;
						child._yscale = s;
					}
				} else {
					if (mode == Create) {
						var loader = new flash.MovieClipLoader();
						var r = loader.loadClip(url, clip);
						clip._xscale = s;
						clip._yscale = s;
					}
				}
			#end
			return { clip: clip, width: w, height: h, growWidth: false, growHeight: false };

		case Button(block, hoverb, action, actionExt):
			return buildButton(p, childNo, mode, availableWidth, availableHeight, block, hoverb, action, actionExt);

		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var sel = build(selected, clip, availableWidth, availableHeight, mode, 0);
			var unsel = build(unselected, clip, availableWidth, availableHeight, mode, 1);
			if (mode != Metrics && mode != Destroy) {
				if (sel.clip == null || unsel.clip == null) {
					#if debug
					trace("Can not make ToggleButton of empty blocks");
					#end
				} else {
					#if flash9
						unsel.clip.buttonMode = true;
						sel.clip.buttonMode = true;
						if (mode == Create) {
							sel.clip.visible = initialState;
							unsel.clip.visible = !initialState;
							var setState = function (newState : Bool) { sel.clip.visible = newState; unsel.clip.visible = !newState; }; 
							if (null != onInit) {
								onInit(setState);
							}
							clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) {
									// TODO: In fact, we should check that the position at MOUSE_DOWN is on top of us as well
									if (null != onChange && clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true) && ArcticMC.isActive(clip)) {
										setState(!sel.clip.visible);
										onChange(sel.clip.visible);
									}
								});
						}
					#elseif flash
						if (mode == Create) {
							sel.clip._visible = initialState;
							unsel.clip._visible = !initialState;
							var setState = function (newState : Bool) { sel.clip._visible = newState; unsel.clip._visible = !newState; }; 
							if (null != onInit) {
								onInit(setState);
							}
							clip.onMouseUp = function() {
								if (null != onChange && clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true) && ArcticMC.isActive(clip)) {
									setState(!sel.clip._visible);
									onChange(sel.clip._visible);
								}
							};
						}
					#end
				}
			}
			return { clip: clip, width: Math.max(sel.width, unsel.width), height: Math.max(sel.height, unsel.height), growWidth: sel.growWidth, growHeight: sel.growHeight};

		case Mutable(mutableBlock):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode != Metrics) {
				mutableBlock.availableWidth = availableWidth;
				mutableBlock.availableHeight = availableHeight;
			}
			if (mode == Create) {
				var me = this;
				mutableBlock.arcticUpdater = function(oldBlock : ArcticBlock, block : ArcticBlock, w, h) : Void {
					if (me.gui == null) {
						return;
					}
					var oldClip = me.getOrMakeClip(clip, Destroy, 0);
 					if (oldBlock != null) {
						#if debug
						me.currentPath = "destroy Mutable/";
						me.currentBlockKind = "Mutable";
						#end
 						me.build(oldBlock, oldClip, w, h, Destroy, 0);
 					}
					if (oldClip != null) {
						ArcticMC.remove(oldClip);
					}
					// Hm, nothing to do
					if (block == null) {
						return;
					}
					#if debug
					me.currentPath = "update Mutable/";
					me.currentBlockKind = "Mutable";
					#end
					var childClip : ArcticMovieClip = me.getOrMakeClip(clip, Create, 0);
					me.build(mutableBlock.block, childClip, w, h, Create, 0);
				};
			} else if (mode == Destroy) {
				// Get rid of the old stuff
				mutableBlock.destroy();
				mutableBlock.arcticUpdater = null;
				// And then we stop!
				return { clip: clip, width : 0.0, height: 0.0, growWidth: false, growHeight: false };
			}
			var childClip : ArcticMovieClip = getOrMakeClip(clip, mode, 0);
			var result = build(mutableBlock.block, childClip, availableWidth, availableHeight, mode, 0);
			return { clip: clip, width : result.width, height: result.height, growWidth: result.growWidth, growHeight: result.growHeight };

		case Switch(blocks, current, onInit):
			var cur = 0;
			var children : Array<Metrics> = [];
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				cur = current;
				ArcticMC.set(clip, "current", cur);
			} else if (mode == Reuse) {
				cur = ArcticMC.get(clip, "current");
			} else if (mode == Destroy) {
				onInit(function(current : Int) {});
				ArcticMC.delete(clip, "current");
			}
			var width = 0.0;
			var height = 0.0;
			var growWidth = false;
			var growHeight = false;
			for (i in 0...blocks.length) {
				var b = blocks[i];
				var child = build(b, clip, availableWidth, availableHeight, mode, i);
				if (mode == Create) {
					children.push(child);
				}
				if (mode != Metrics && mode != Destroy) {
					ArcticMC.setVisible(child.clip, i == cur);
				}
				width = Math.max(child.width, width);
				height = Math.max(child.height, height);
				growWidth = growWidth || child.growWidth;
				growHeight = growHeight || child.growHeight;
			}
			if (mode == Create) {
				var switchFn = function (current : Int) {
					if (current != cur) {
						ArcticMC.setVisible(children[cur].clip, false);
						ArcticMC.setVisible(children[current].clip, true);
						cur = current;
						ArcticMC.set(clip, "current", cur);
					}
				}
				onInit(switchFn);
			}

			return { clip: clip, width: width, height: height, growWidth: growWidth, growHeight: growHeight };

		case Filler:
			return { clip: null, width: availableWidth, height: availableHeight, growWidth: true, growHeight: true };
		
		case Fixed(width, height):
			#if debug
				if (width == null || height == null || Math.isNaN(width) || Math.isNaN(height)) {
					trace("Broken Fixed(" + width + "," + height + ") block");
				}
			#end
			return { clip: null, width: width, height: height, growWidth: false, growHeight: false };

		case Align(xpos, ypos, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var width = availableWidth;
			var height = availableHeight;
            var child = build(block, clip, width, height, mode, 0);
			width = Math.max(width, child.width);
			if (xpos == -2) width = child.width;
			height = Math.max(height, child.height);
			if (ypos == -2) height = child.height;
			if (mode != Metrics && mode != Destroy && child.clip != null) {
				var x = 0.0;
				if (xpos >= 0.0 && availableWidth > child.width) {
					x = (availableWidth - child.width) * xpos;
				}
				var y = 0.0;
				if (ypos >= 0.0 && availableHeight > child.height) {
					y = (availableHeight - child.height) * ypos;
				}
				ArcticMC.setXY(child.clip, x, y);
			}
			return { clip: clip, width: width, height: height, growWidth: xpos != -1.0, growHeight: ypos != -1.0};

		case ConstrainWidth(minimumWidth, maximumWidth, block) :
			// Special case: Nested constraints can be optimised a lot!
			if (mode == Metrics && minimumWidth == maximumWidth) {
				switch (block) {
					case ConstrainHeight(minHeight, maxHeight, b):
						if (minHeight == maxHeight) {
							return { clip: null, width: minimumWidth, height: minHeight, growWidth: false, growHeight: false };
						}
					default:
				}
			}

            var child = build(block, p, Math.max( Math.abs(minimumWidth), Math.min(availableWidth, maximumWidth)), availableHeight, mode, childNo);
			if (minimumWidth >= 0 && child.width < minimumWidth) {
				child.width = minimumWidth;
			}
			if (child.width > maximumWidth) {
				child.width = maximumWidth;
			}
			return { clip: child.clip, width: child.width, height: child.height, growWidth: false, growHeight: child.growHeight };

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			// Special case: Nested constraints can be optimised a lot!
			if (mode == Metrics && minimumHeight == maximumHeight) {
				switch (block) {
					case ConstrainWidth(minWidth, maxWidth, b):
						if (minWidth == maxWidth) {
							return { clip: null, width: minWidth, height: minimumHeight, growWidth: false, growHeight: false };
						}
					default:
				}
			}
		
			var child = build(block, p, availableWidth, Math.max( Math.abs(minimumHeight), Math.min(availableHeight, maximumHeight)), mode, childNo);
			if (minimumHeight >= 0 && child.height < minimumHeight) {
				child.height = minimumHeight;
			}
			if (child.height > maximumHeight) {
				child.height = maximumHeight;
			}
			return { clip: child.clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: false };
		
		case Crop(x, y, width, height, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, childNo);
			var w = child.width;
			var h = child.height;
			if (width != null) w = width;
			if (height != null) h = height;
			if (mode == Create) {
				ArcticMC.setScrollRect(clip, new ArcticRectangle(x, y, width, height));
			}
			return { clip: clip, width: w, height: h, growWidth: false, growHeight: false };

		case ColumnStack(blocks, useIntegerFillings, rowAlign):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			// The number of children which wants to grow (including our own fillers)
			var numberOfWideChildren = 0;
			var childMetrics = [];			
			var width = 0.0;
			var maxHeight = 0.0;
			for (r in blocks) {
				// We want the minimum size, so do not give any extra width to this
				var cm = build(r, clip, 0, availableHeight, Metrics, 0);
				childMetrics.push(cm);
				if (cm.growWidth) {
					numberOfWideChildren++;
				}
				// A filler here should in itself not impact height growth in this situation
				if (r != Filler) {
					m.growHeight = m.growHeight || cm.growHeight;
					maxHeight = Math.max(maxHeight, cm.height);
				}
				width += cm.width;
			}
			if (m.growHeight) {
				maxHeight = Math.max(maxHeight, availableHeight);
			}

			// Next, determine how much space children get
            var freeSpace = availableWidth - width;
			var remainder = 0.0;
			
			if (freeSpace < 0) {
				// Hmm, we should do a scrollbar instead
				freeSpace = 0;
			}
			if (numberOfWideChildren > 0) {
				if (useIntegerFillings) {
					freeSpace = Math.round(freeSpace / numberOfWideChildren);
					remainder = availableWidth - width - (numberOfWideChildren * freeSpace);
				} else {
					freeSpace = freeSpace / numberOfWideChildren;
				}
				m.growWidth = true;
			} else {
				freeSpace = 0;
			}
			
			var noNeedForNewMetrics = mode == Metrics && availableHeight == maxHeight;

			var h = 0.0;
			var x = 0.0;
			var i = 0;
			var firstGrowWidthChild = true;
			var children = [];
			for (l in blocks) {
				var child;
				if (noNeedForNewMetrics && !childMetrics[i].growWidth) {
					child = childMetrics[i];
				} else {
					var w = childMetrics[i].width + if (childMetrics[i].growWidth) freeSpace else 0;
					h = Math.max(0, h);
					child = build(l, clip, w, maxHeight, mode, i);
				}
				children.push(child);
				
				if (mode != Metrics && mode != Destroy && child.clip != null) {
					ArcticMC.setXY(child.clip, x, null);
				}
				x += child.width;
				if (l != Filler) {
					h = Math.max(h, child.height);
				}
   				++i;
			}
			
			// Do the row alignment
			if (mode != Metrics && mode != Destroy && rowAlign != null) {
				for (c in children) {
					if (c.clip != null) {
						var yc = (h - c.height) * rowAlign;
						ArcticMC.setXY(c.clip, null, yc);
					}
				}
			}
			
					
			m.width = x;
			m.height = h;
			return m;

		case LineStack(blocks, ensureVisibleIndex, disableScrollbar, useIntegerFillings, lineAlign):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			// Get child 0
			var child = getOrMakeClip(clip, mode, 0);
			
			if (mode == Destroy) {
				Scrollbar.removeScrollbar(clip, child);
				var i = 0;
				for (l in blocks) {
					var line = build(l, child, 0, 0, mode, i);
					++i;
				}
				return m;
			}
			
			// The number of children which wants to grow (including our own fillers)
			var numberOfTallChildren = 0;
			var childMetrics = [];
			var minimumHeight = 0.0;
			var maxWidth = 0.0;
			for (r in blocks) {
				// We want the minimum size, so do not give any extra height to this
				var rm = build(r, clip, availableWidth, 0, Metrics, 0);
				childMetrics.push(rm);
				if (rm.growHeight) {
					numberOfTallChildren++;
				}
				minimumHeight += rm.height;
				// A filler here should in itself not impact width growth in this situation
				if (r != Filler) {
					m.growWidth = m.growWidth || rm.growWidth;
					maxWidth = Math.max(maxWidth, rm.width);
				}
			}
			
			if (m.growWidth) {
				maxWidth = Math.max(maxWidth, availableWidth);
			}
			// Next, determine how much space children get
            var freeSpace = availableHeight - minimumHeight;
			var freeSpacePerChild = 0.0;
			
			// This is logic to try to make it such that innermost children get scrollbars, rather than outermost
			if (freeSpace < 0) {
				// See if we can free space up by shrinking children enough
				var gh = 0.0;
				var shrinkable = 0;
				var cutoffHeight = 40;
				for (cm in childMetrics) {
					if (cm.growHeight && cm.height > cutoffHeight) {
						gh += (cm.height - cutoffHeight);
						shrinkable++;
					}
				}
				if (gh >= -freeSpace) {
					// We could use knapsack to reduce children instead
					var reductionPerGrowingChild = freeSpace / shrinkable;
					var remainder = 0.0;
					if (useIntegerFillings) {
						reductionPerGrowingChild = Math.round(reductionPerGrowingChild);
						remainder = freeSpace - (reductionPerGrowingChild * shrinkable);
					}
					var firstGrowHeightChild = true;
					for (cm in childMetrics) {
						if (cm.growHeight && cm.height > cutoffHeight) {
							cm.height += reductionPerGrowingChild;
							if (firstGrowHeightChild) {
								cm.height += remainder;
								firstGrowHeightChild = false;
							}
						}
					}
					freeSpace = 0;
				}
			}
			
			if (numberOfTallChildren > 0 && freeSpace > 0) {
				freeSpacePerChild = freeSpace / numberOfTallChildren;
			}

			var ensureY = 0.0;
			var w = 0.0;
			var y = 0.0;
			var i = 0;
            var children = [];
			
			var noNeedForNewMetrics = mode == Metrics && availableWidth == maxWidth;
			
			for (l in blocks) {
				var line;
				if (noNeedForNewMetrics && !childMetrics[i].growHeight) {
					line = childMetrics[i];
				} else {
					var h = childMetrics[i].height + if (childMetrics[i].growHeight) freeSpacePerChild else 0;
					h = Math.max(0, h);
					h = Math.min(availableHeight, h);
					line = build(l, child, maxWidth, h, mode, i);
				}
				if (mode != Metrics && mode != Destroy && line.clip != null) {
					ArcticMC.setXY(line.clip, null, y);
				}
				if (i == ensureVisibleIndex) {
					ensureY = y;
				}
                children.push(line);
				y += line.height;
				w = Math.max(w, line.width);
				// A filler here should in itself not impact width growth in this situation
				if (l != Filler) {
					m.growWidth = m.growWidth || line.growWidth;
				}
				m.growHeight = m.growHeight || line.growHeight;
   				++i;
			}
			if (i == ensureVisibleIndex) {
				ensureY = y;
			}
			
			// Do the line alignment
			if (mode != Metrics && mode != Destroy && lineAlign != null) {
				for (c in children) {
					if (c.clip != null) {
						var xc = (w - c.width) * lineAlign;
						ArcticMC.setXY(c.clip, xc, null);
					}
				}
			}
			
			if (disableScrollbar != false) {
				if (y - availableHeight >= 1 && availableHeight >= 34 && mode != Destroy) {
					// Scrollbar
					if (mode != Metrics) {
						Scrollbar.drawScrollBar(clip, child, w, availableHeight, y, ensureY);
					}
					w += Arctic.scrollbarWidth;
					y = availableHeight;
				} else {
					if (mode != Metrics) {
						Scrollbar.removeScrollbar(clip, child);
					}
				}
			}
			m.width = w;
			m.height = y;
			return m;
		
		case Wrap(blocks, maxWidth, xspacing, yspacing, eolFiller, lowerWidth, lineAlign, rowAlign, rowIndent):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			
			if (maxWidth == null) {
				maxWidth = availableWidth;
				m.growWidth = true;
			}
			
			if (lowerWidth == null) {
				lowerWidth = 0.45;
			}
			else if (lowerWidth < 0) {
				lowerWidth = 0;
			}
			else if (lowerWidth > 1) {
				lowerWidth = 1;
			}
			
			if (blocks.length == 0) {
				return m;
			}
		
			if (xspacing == null) {
				xspacing = 0;
			}
			if (yspacing == null) {
				yspacing = 0;
			}
			
			if (lineAlign == null) {
				lineAlign = 0;
			}
			
			if (rowAlign == null) {
				rowAlign = 0;
			}
			
			if (rowIndent == null) {
				rowIndent = 0;
			}
			
			var firstIndent = 0.0; // first line indentation
			var subsequentIndent = 0.0; // subsequent lines indentation
			if (rowIndent >= 0) {
				firstIndent = rowIndent;
			} else {
				subsequentIndent = rowIndent;
			}
			
			var children: Array<{block: ArcticBlock, m: Metrics}> = [];
			for (block in blocks) {
				// We want the minimum size, so do not give any extra width and height to this	
				var cm = build(block, clip, 0, 0, Metrics, 0);
				if (block != Filler) {
					m.growHeight = m.growHeight || cm.growHeight;
				}
				children.push({block: block, m: cm});
			}
			
			var newRow = function (indent : Float): { blocks: Array<{block: ArcticBlock, m: Metrics}>, maxHeight: Float, width: Float, indent: Float, numberOfWideChildren: Int, numberOfTallChildren: Int} { 
				return { blocks: [], maxHeight: 0.0, width: 0.0, indent : indent, numberOfWideChildren: 0, numberOfTallChildren: 0 };
			}
			
			var breakIntoRows = function (maxWidth) : Array<{ blocks: Array<{block: ArcticBlock, m: Metrics}>, maxHeight: Float, width: Float, indent: Float, numberOfWideChildren: Int, numberOfTallChildren: Int}> {
				// Break the elements into separate rows
				var rows = [newRow(firstIndent)];
				for (i in 0...children.length) {
					var cm = children[i].m;
					var block = children[i].block;
					
					var row = rows[rows.length - 1];
					row.blocks.push(children[i]);
					if (cm.growWidth) {
						row.numberOfWideChildren++;
					}
					if (cm.growHeight) {
						row.numberOfTallChildren++;
					}
					// ignore Fillers
					if (block != Filler) {
						row.width += ( row.blocks.length > 1 ? xspacing : row.indent ) + cm.width;
						row.maxHeight = Math.max(row.maxHeight, cm.height);
					}
					
					var next = i + 1;
					while (next < children.length && children[next].block == Filler) {
						next++;
					}
					if ( next < children.length && (row.width + xspacing + children[next].m.width) > maxWidth ) {
						rows.push(newRow(subsequentIndent));
					}
				}
				return rows;
			}
			
			var bestWidth = 
				if (true) {
					Layout.minimize(maxWidth * lowerWidth, maxWidth, 
						function(f) {
							var rows = breakIntoRows(f);
							var height = 0.0;
							for (r in rows) {
								height += r.maxHeight;
							}
							var cost = height * f;
							
							if (availableHeight > 0) {
								// Try to come up with a measure that gives a penalty for wrong aspect ratios
								// However, this penalty should not trumpf reduction of waste
								// Some aspect ratio difference penalty
								var aspectDiff = Math.min(2.0, 1.0 + Math.abs((availableWidth / availableHeight) - (f / height)));
								cost += (aspectDiff * 100 * 100);
							
								if (height > availableHeight) {
									// OK, we give a fixed penalty
									cost += 3000 * 1000;
									// and then based on how much we go outside
									var outside = height - availableHeight;
									cost += 10 * outside * f;
								}
							}
							
							//trace(f + " -> " + cost);
							return cost;
						}
					);
				} else {
					maxWidth;
				}
			;

			var rows = breakIntoRows(bestWidth);
			//trace(bestWidth);
			
			// Next, determine how much space children get		
			var numOfTallRows = 0;
			var rowsHeight = yspacing * (rows.length - 1);
			for (row in rows) {
				rowsHeight += row.maxHeight;
				if (row.numberOfTallChildren > 0) {
					numOfTallRows++;
				}
			}
			var freeHeight = availableHeight - rowsHeight;
			// TODO: handle (freeHeight < 0) case
			if (numOfTallRows > 0 && freeHeight > 0) {
				freeHeight = freeHeight / numOfTallRows;
				m.growHeight = true;
			} else {
				freeHeight = 0;
			}
			
			var needShift = mode != Metrics && mode != Destroy && rowAlign > 0;
			var shiftRows : List<Float -> Void> = new List<Float -> Void>();
			var y = 0.0;
			var i = 0;
			var width = 0.0;
			availableWidth = Math.min(availableWidth, bestWidth);
			for (row in rows) {
				var freeWidth = availableWidth - row.width;
				if (freeWidth < 0) {
					//TODO
					freeWidth = 0;
				} else if (row.numberOfWideChildren > 0) {
					freeWidth = freeWidth / row.numberOfWideChildren;
					m.growWidth = true;
				} else if (eolFiller != null) {
					freeWidth = Math.max(0, freeWidth - xspacing);
					var cm = { clip: null, width : 0.0, height : 0.0, growWidth : true, growHeight : false };
					row.blocks.push({block: eolFiller, m: cm});
				}
			
				var shiftRow : List<Float -> Void> = new List<Float -> Void>();
				var h = row.maxHeight + (row.numberOfTallChildren > 0 ? freeHeight : 0); 
				var x = row.indent;
				for (entry in row.blocks) {
					var w = entry.m.width + (entry.m.growWidth ? freeWidth : 0);
					var child = build(entry.block, clip, w, h, mode, i);
					if (mode != Metrics && mode != Destroy && child.clip != null) {
						var dy = (h - entry.m.height) * lineAlign;
						ArcticMC.setXY(child.clip, x, y + dy);
						if (mode == Reuse) {
							ArcticMC.setVisible(child.clip, true);
						}
						if (needShift) {
							shiftRow.add(function (dx) { ArcticMC.moveClip(child.clip, dx, 0); });
						}
					}
					if (entry.block != Filler) {
						x += child.width + (entry != row.blocks[row.blocks.length - 1] ? xspacing : 0);
					}
					++i;
				}
				y += h + yspacing;
				width = Math.max(width, x);
				if (needShift) {
					shiftRows.add(function (maxwidth) {
						for (shift in shiftRow) {
							shift((maxwidth - x)*rowAlign);
						}
					});
				}
			}
			
			if (needShift) {
				for (shift in shiftRows) {
					shift(width);
				}
			}
			
			if (mode == Reuse) {
				// Find and hide any left over fillers from earlier
/*				while (ArcticMC.has(clip, "c" + i)) {
					ArcticMC.setVisible(ArcticMC.get(clip, "c" + i), false);
					++i;
				}*/
			}

			m.width = width;
			m.height = y - yspacing;
			
			// trace(availableWidth + ',' + availableHeight + ' ' + m.width + ',' + m.height + ' ' + bestWidth);
			return m;
		
		case Grid(cells, disableScrollbar, oddRowColor, evenRowColor, borderSize, borderColor):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = getOrMakeClip(clip, mode, 0);

			var gridMetrics = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			var columnWidths = [];
			var lineHeights = [];
			var y = 0;
			for (line in cells) {
				var x = 0;
				var lineHeight = 0.0;
				for (block in line) {
					// We want the minimum size, so do not give any extra space to this
					var m = build(block, clip, 0, 0, Metrics, 0);
					if (columnWidths.length <= x) {
						columnWidths.push(m.width);
					} else {
						if (columnWidths[x] < m.width) {
							columnWidths[x] = m.width;
						}
					}
					lineHeight = Math.max(lineHeight, m.height);
					++x;
				}
				if (lineHeights.length <= y) {
					lineHeights.push(lineHeight);
				} else {
					if (lineHeights[y] < lineHeight) {
						lineHeights[y] = lineHeight;
					}
				}
				++y;
			}
			
			var i = 0;
			y = 0;
			var yc = 0.0;
			for (line in cells) {
				var x = 0;
				var xc = 0.0;
				for (block in line) {
					var b = build(block, child, columnWidths[x], lineHeights[y], mode, i);
					if (mode != Metrics && mode != Destroy && b.clip != null) {
						ArcticMC.setXY(b.clip, xc, yc);
					}
					xc += Math.max(b.width, columnWidths[x]);
					// extra height check (important for text fields with wordWrap=true)
					if (b.height > lineHeights[y]) {
						lineHeights[y] = b.height;
					}
					++x;
					++i;
				}
				var color = (y + 1) % 2 == 0 ? evenRowColor : oddRowColor;
				// a fill will not be created if the color is equal to null
				if (mode != Metrics && mode != Destroy && color != null) {
					var g = ArcticMC.getGraphics(child);
					g.beginFill(color);
					DrawUtils.drawRect(child, 0, yc, xc, lineHeights[y]);
					g.endFill();
				}
				yc += lineHeights[y];
				++y;
			}
			var width = 0.0;
			for (w in columnWidths) {
				width += w;
			}
			var height = 0.0;
			for (h in lineHeights) {
				height += h;
			}
			
			#if flash9
			if ((borderSize != null) && (borderColor!=null)) {
				if ((mode == Create) || (mode == Reuse)) {
					var g:flash.display.Graphics = child.graphics;
					g.clear();
					g.lineStyle(borderSize, borderColor, 1.0);
					var x = 0.0;
					var y = 0.0;
					for (w in columnWidths) {
						g.moveTo(x, 0);
						g.lineTo(x, height);
						x += w;
					}
					g.moveTo(x, 0);
					g.lineTo(x, height);
					
					for (h in lineHeights) {
						g.moveTo(0, y);
						g.lineTo(width, y);
						y += h;
					}
					g.moveTo(0, y);
					g.lineTo(width, y);
				}
			}
			#end
			
			if (disableScrollbar != true) {
				// TODO: draw horizontal scrollbar if (width > availableHeight) 
				// draw vertical scrollbar
				if (height - availableHeight >= 1 && availableHeight >= 34 && mode != Destroy) {
					if (mode != Metrics) {
						Scrollbar.drawScrollBar(clip, child, width, availableHeight, height, 0);
					}
					width += 17;
					height = availableHeight;
				} else {
					if (mode != Metrics) {
						Scrollbar.removeScrollbar(clip, child);
					}
				}	
			}
		
			return { clip: clip, width: width, height: height, growWidth: false, growHeight: false };

		case TableCell(block, rowSpan, colSpan, topBorder, rightBorder, bottomBorder, leftBorder): 
			//it shouldn't be called, may be it shouldn't be ArcticBlock at all
			return build(block, p, availableWidth, availableHeight, mode, childNo);
		
		case Table(cells, nRows, nCols, borderColor):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = getOrMakeClip(clip, mode, 0);
			
			var spacing = 2; //spacing between left/right border and cell block
			var totalSpacing = spacing * nCols + nCols;
			
			var cellIsEmpty = new Array<Array<Bool>>();
			for (j in 0...nCols) {
				var line = [];
				for (i in 0...nRows) {
					line.push(true);
				}
				cellIsEmpty.push(line);
			}
			
			var findUpperLeftEmptyCell = function() : { x : Int, y : Int } {
				for (i in 0...nRows) {
					for (j in 0...nCols) {
						if (cellIsEmpty[j][i]) {
							return { x : j, y : i };
						}
					}
				}
				return { x : -1, y : -1 };
			}
			
			var takeEmptyCells = function(x, y, rs, cs) {
				for (i in y...y+rs) {
					for (j in x...x+cs) {
						if (cellIsEmpty[j][i]) {
							cellIsEmpty[j][i] = false;
						}
						// else: cells will be overlapped, but this is caused by bad input
					}
				}
			}
			
			var cellProperties = new Array<CellProperty>();
			
			var minWidths = new Array<Float>(); 
			var maxWidths = new Array<Float>(); 
			
			for (i in 0...cells.length) {
				var cell = cells[i];
				var pos = findUpperLeftEmptyCell();
				//TODO: check for correctness
				
				var block = null;
				var cp : CellProperty = 
					  { width : 0.0, height : 0.0, x : pos.x, y : pos.y, rowSpan : 1, colSpan : 1,
						topBorder : 1, rightBorder : 1, bottomBorder : 1, leftBorder : 1 };
				
				switch (cell) {
					case TableCell(bl, rs, cs, tb, rb, bb, lb):
						block = bl;
						cp.rowSpan = (rs == null) ? cp.rowSpan : rs;
						cp.colSpan = (cs == null) ? cp.colSpan : cs;
						cp.topBorder = (tb == null) ? cp.topBorder : tb;
						cp.rightBorder = (rb == null) ? cp.rightBorder : rb;
						cp.bottomBorder = (bb == null) ? cp.bottomBorder : bb;
						cp.leftBorder = (lb == null) ? cp.leftBorder : lb;
					
					default:
						block = cell;
				}
				
				takeEmptyCells(cp.x, cp.y, cp.rowSpan, cp.colSpan);
				
				var infWidth = 10000.0;
				var min = build(block, clip, 0, 0, Metrics, 0);
				var max = build(block, clip, infWidth, 0, Metrics, 0);
				
				if ( max.width == infWidth ) //do not allow Fillers take full available width, i.e. in right alignment: block = ColumnStack([Filler, innerBlock])
					max.width = (max.height < 1e-6) ? min.width : min.width * min.height / max.height; //try to estimate the approximate width of the block
				
				minWidths.push(min.width);
				maxWidths.push(max.width);
				
				cellProperties.push(cp);
			}
			
			var calcWidths = function (columnWidths: Array<Float>) : Array<Float> {
				var widths = [0.0];
				
				for (i in 1...nCols+1) {
					var width = 0.0;
					for (j in 0...cellProperties.length) { 
						var cp = cellProperties[j];
						
						if (cp.x + cp.colSpan == i) { // if block ends in i-th column
							var previous = i - cp.colSpan; // in 0...i range
							previous = (previous < 0) ? 0 : previous; // just to be sure crash wouldn't happen
							var w = columnWidths[j] + widths[previous];
							width = (w > width) ? w : width;
						}
					}
					
					widths.push(width);
				}
				
				return widths;
			}
			
			//array of the min widths of table columns
			var columnMinWidths = calcWidths(minWidths); 
			var tableMinWidth = columnMinWidths[columnMinWidths.length - 1];
			
			var columnMaxWidths = calcWidths(maxWidths);
			var tableMaxWidth = columnMaxWidths[columnMaxWidths.length - 1];
			
			var freeWidth = availableWidth - totalSpacing - tableMinWidth;
									
			var coefficients : Array<Float> = [];
			
			if ( tableMaxWidth > ( availableWidth - totalSpacing ) )
			{
				var tableMaxWidths : Array<Float> = []; //two-dimential array of the max widths of table cells
				for ( i in 1...nRows + 1 ) {
					tableMaxWidths.push(0.0);
					
					var rowIdx = (i - 1) * (nCols + 1);
					
					//calc widths for row
					for ( j in 1...nCols + 1 ) {
						var width = 0.0;
						for ( k in 0...cellProperties.length ) {
							var cp = cellProperties[k];
							
							if ( cp.y + cp.rowSpan == i && cp.x + cp.colSpan == j ) {
								var previous = j - cp.colSpan; // in 0...i range
								previous = (previous < 0) ? 0 : previous; // just to be sure crash wouldn't happen
								width = ( maxWidths[k] - minWidths[k] ) + tableMaxWidths[rowIdx + previous];
							}
						}
						
						tableMaxWidths.push(width);
					}
					
					//if colSpan > 1 distribute sum widths between the cells
					for ( j in 1...nCols + 1 ) {
						for ( k in 0...cellProperties.length ) {
							var cp = cellProperties[k];

							if ( cp.colSpan > 1 && j >= cp.x && j <= cp.x + cp.colSpan ) {
								var cellWidths = tableMaxWidths[rowIdx + cp.x + cp.colSpan];
								
								tableMaxWidths[rowIdx + j] = (j - cp.x) * cellWidths / cp.colSpan;
							}
						}
					}
				}

				var sum = 0.0;
				for ( j in 1...nCols + 1) {
					var max = 0.0;
					
					for ( i in 0...nRows ) {
						var idx = i * (nCols + 1) + j;
						var width = tableMaxWidths[idx] - tableMaxWidths[idx - 1];
						
						max = Math.max(max, width);
					}
					
					coefficients.push(max);
					sum += max;
				}
							
				//normalize
				for ( i in 0...coefficients.length ) {
					if ( sum != 0 )
						coefficients[i] = coefficients[i] / sum;
				}
				
			}

			//calculate actual widths for columns and calculate new Metrics for this widths
			for (i in 0...cells.length) {
				var cell = cells[i];
				var cp = cellProperties[i];
				
				var block = null;
				//TODO: remove this?
				switch (cell) {
					case TableCell(bl, rs, cs, tb, rb, bb, lb):
						block = bl;
					default:
						block = cell;
				}
				
				var minWidth = columnMinWidths[cp.x + cp.colSpan] - columnMinWidths[cp.x];
				
				var width = 0.0;
				if ( tableMaxWidth > (availableWidth - totalSpacing) ) {
					var k = 0.0;
					for ( j in (cp.x)...(cp.x + cp.colSpan) ) {
						k += coefficients[j];
					}
					
					width = minWidth + k * freeWidth;
				} else {
					width = columnMaxWidths[cp.x + cp.colSpan] - columnMaxWidths[cp.x];
				}
				
				var m = build(block, clip, width, 0, Metrics, 0);
				
				cp.width  = m.width;
				cp.height = m.height;
			}
						
			//cals column widths
			var columnWidths = [0.0];
			for (i in 1...nCols+1) {
				var width = 0.0;
				for (cp in cellProperties) { 
					if (cp.x + cp.colSpan == i) { // if block ends in i-th column
						var previous = i - cp.colSpan; // in 0...i range
						previous = (previous < 0) ? 0 : previous; // just to be sure crash wouldn't happen
						var w = cp.width + columnWidths[previous];
						width = (w > width) ? w : width;
						width += 2 * spacing + 1; //left, right spacing and border
					}
				}
				columnWidths.push(width);
			}
			
			//calc row heights
			var lineHeights = [0.0];
			for (j in 1...nRows+1) {
				var height = 0.0;
				for (cp in cellProperties) { 
					if (cp.y + cp.rowSpan == j) { // if block ends in j-th row
						var previous = j - cp.rowSpan; // in 0...j range
						previous = (previous < 0 || previous >= j) ? 0 : previous; // just to be sure crash wouldn't happen
						var h = cp.height + lineHeights[previous];
						height = (h > height) ? h : height;
					}
				}
				lineHeights.push(height);
			}
			
			for (i in 0...cells.length) {
				var cell = cells[i];
				var cp = cellProperties[i];
				
				var block = null;
				//TODO: remove this?
				switch (cell) {
					case TableCell(bl, rs, cs, tb, rb, bb, lb):
						block = bl;
					default:
						block = cell;
				}
				
				var w = columnWidths[cp.x + cp.colSpan] - columnWidths[cp.x] - 2 * spacing; //width - leftSpacing - rightSpacing
				var h = lineHeights[cp.y + cp.rowSpan] - lineHeights[cp.y];
				var b = build(block, child, w, h, mode, i);
				if (mode != Metrics && mode != Destroy && b.clip != null) {
					ArcticMC.setXY(b.clip, columnWidths[cp.x] + spacing, lineHeights[cp.y]);
				}
				// extra height check (important for text fields with wordWrap=true)
				//TODO: do smth with it
				//if (b.height > lineHeights[y]) {
				//	lineHeights[y] = b.height;
				//}
			}
			
			#if flash9
			if (borderColor!=null) {
				if ((mode == Create) || (mode == Reuse)) {
					var g:flash.display.Graphics = child.graphics;
					g.clear();
					
					var drawLine = function(x1, y1, x2, y2, type) {
						switch (type) {
							case 0: 
								return;
							case 1: 
								g.moveTo(x1, y1);
								g.lineTo(x2, y2);
							case 2:
								var dx = (y1 != y2) ? 1 : 0;
								var dy = (x1 != x2) ? 1 : 0;
								g.moveTo(x1 - dx, y1 - dy);
								g.lineTo(x2 - dx, y2 - dy);
								g.moveTo(x1 + dx, y1 + dy);
								g.lineTo(x2 + dx, y2 + dy);
							default:
								return;
						}
					}
					
					g.lineStyle(1, borderColor, 1.0);
					
					for (i in 0...cellProperties.length) {
						var cp = cellProperties[i];
						
						var x1 = columnWidths[cp.x];
						var y1 = lineHeights[cp.y];
						var x2 = columnWidths[cp.x + cp.colSpan];
						var y2 = lineHeights[cp.y + cp.rowSpan];
						
						drawLine(x1, y1, x2, y1, cp.topBorder);
						drawLine(x2, y1, x2, y2, cp.rightBorder);
						drawLine(x2, y2, x1, y2, cp.bottomBorder);
						drawLine(x1, y2, x1, y1, cp.leftBorder);
					}
				}
			}
			#end
			
			return { clip: clip, width: columnWidths[nCols], height: lineHeights[nRows], growWidth: false, growHeight: false };
		
		case ScrollBar(block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
            var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			var height = child.height;
			if (mode == Destroy) {
				Scrollbar.removeScrollbar(clip, child.clip);
			} else if (mode != Metrics) {
				if (availableHeight < height) {
					Scrollbar.drawScrollBar(clip, child.clip, child.width, availableHeight, child.height, 0);
					height = availableHeight;
				} else {
					Scrollbar.removeScrollbar(clip, child.clip);
				}
			}
			return { clip: clip, width: child.width, height: height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag):
			return buildDragable(p, childNo, mode, availableWidth, availableHeight, stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag);

		case Cursor(block, cursor, keepNormalCursor, showFullCursor) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			if (child.clip == null && mode != Destroy) {
				#if debug
				trace("Can not make cursor of empty block");
				#end
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var me = this;
			var cursorMc = ArcticMC.get(clip, "cursor");
			
			if (mode == Destroy) {
				removeStageEventListeners(clip);
				if (cursorMc != null) {
					#if flash9
					// Since cursors are constructed lazily, we have to search for our child 
					// because other Cursors might have gone before us changing the child numbering
					for (i in 0...parent.numChildren) {
						var c : Dynamic = parent.getChildAt(i);
						if (c == cursorMc.clip) {
							build(cursor, parent, 0, 0, mode, i);
							break;
						}
					}
					#end
					ArcticMC.remove(cursorMc.clip);
					ArcticMC.delete(clip, "cursor");
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			// We need to construct the cursor lazily because we want it to come on top of everything
			var cursorMcFn = function(n) { return me.build(cursor, me.parent, 0, 0, Create, n);};
			var keep = if (keepNormalCursor == null) true else keepNormalCursor;
			
			if (showFullCursor == null) showFullCursor = false;
			var shiftX = 0.0;
			var shiftY = 0.0;
			// process all top nested Offsets for better calculating cursor position with showFullCursor turned on
			// e.g. Offset(dx, dy, Offset(ddx, ddy, some_block)) will be replaced with some_block,
			// shiftX will be equal dx + ddx, shiftY will be equal dy + ddy
			while (true) {
				switch (cursor) {
					case Offset(dx, dy, block) :
						shiftX += dx;
						shiftY += dy;
						cursor = block;
					default:
						break;
				}
			}
			
			var getClipX = function (cursor : arctic.ArcticMovieClip) : Float {
				var mouseX = 0.0;
				#if flash9
					mouseX = me.parent.mouseX;
				#elseif flash
					mouseX = me.parent._xmouse;
				#end

				var cursorSize = ArcticMC.getSize(cursor);
				var baseSize = ArcticMC.getSize(me.base);
				var baseXY = ArcticMC.getXY(me.base);
				
				// if cursor block should fully be seen and it doesn't fit width of base clip
				// (i.e. cursor juts out on the right side of base clip) then lets try to move it a bit left
				// but so its left-upper corner is still visible
				if (showFullCursor && mouseX + shiftX + cursorSize.width > baseSize.width + baseXY.x) { 
					if (baseSize.width + baseXY.x - cursorSize.width > 0) {
						return baseSize.width + baseXY.x - cursorSize.width;
					} else {
						return 0;
					}
				} else {
					return mouseX + shiftX;
				}
			}
			var getClipY = function (cursor : arctic.ArcticMovieClip) : Float {
				var mouseY = 0.0;
				#if flash9
					mouseY = me.parent.mouseY;
				#elseif flash
					mouseY = me.parent._ymouse;
				#end

				var cursorSize = ArcticMC.getSize(cursor);
				var baseSize = ArcticMC.getSize(me.base);
				var baseXY = ArcticMC.getXY(me.base);

				// if cursor block should fully be seen and it doesn't fit height of base clip
				// (i.e. cursor juts out on the bottom side of base clip) then lets try to move it a bit up
				// but so its left-upper corner is still visible
				if (showFullCursor && mouseY + shiftY + cursorSize.height > baseSize.height + baseXY.y) { 
					if (baseSize.height + baseXY.y - cursorSize.height > 0) {
						return baseSize.height + baseXY.y - cursorSize.height;
					} else {
						return 0;
					}
				} else {
					return mouseY + shiftY;
				}
			}

			#if flash9
				var onMove = function (s) {
					//trace("on move");
					if (!ArcticMC.isActive(child.clip)) {
						// disable cursor if base block is not active
						if (cursorMc != null && cursorMc.clip != null) {
							cursorMc.clip.visible = false;
						}
						return;
					}
					
					var hit = child.clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true);
					
					// If we are covered by a dialog, we disable the cursor.
					if (hit && !ArcticDialogManager.get().dialogCovers(child.clip)) {
						ArcticMC.showMouse(keep);
						cursorMc = ArcticMC.get(clip, "cursor");
						if (cursorMc == null) {
							// Since we are constructed lazily, we have to find out what child number we are
							var no = me.parent.numChildren;
							cursorMc = cursorMcFn(no);
							cursorMcFn = null;
							ArcticMC.set(clip, "cursor", cursorMc);
						}
						if (cursorMc.clip == null) {
							return;
						}
						cursorMc.clip.visible = true;
						
						// cursor shouldn't catch mouse events
						cursorMc.clip.mouseEnabled = false;
						cursorMc.clip.mouseChildren = false; 
						
						cursorMc.clip.x = getClipX(cursorMc.clip);
						cursorMc.clip.y = getClipY(cursorMc.clip);
						return;
					} else {
						if (cursorMc != null && cursorMc.clip != null) {
							cursorMc.clip.visible = false;
						}
						ArcticMC.showMouse();
					}
				};
				if (mode == Create) {
					addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_MOVE, onMove);
					addStageEventListener( clip, clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
							if (cursorMc != null && cursorMc.clip != null) {
								cursorMc.clip.visible = false;
							}
							ArcticMC.showMouse();
						}
					);
				}
				//trace("explicit call");
				// onMove(null);
			#elseif flash
				
				var onMove = function() {
							if (!ArcticMC.isActive(child.clip)) {
								return;
							}
							if (child.clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
								if (cursorMc == null) {
									cursorMc = cursorMcFn(childNo);
									cursorMcFn = null;
								}
								cursorMc.clip._visible = true;
								cursorMc.clip._x = getClipX(cursorMc.clip);
								cursorMc.clip._y = getClipY(cursorMc.clip);
								ArcticMC.showMouse(keep);
								return;
							} else {
								if (cursorMc != null) {
									cursorMc.clip._visible = false;
								}
								ArcticMC.showMouse();
							}
						};
				if (mode == Create) {
					if (clip.onMouseMove == null) {
						clip.onMouseMove = onMove;
					}
					if (clip.onRollOut == null) {
						clip.onRollOut = function() { 
							// TODO: We need to notify the children here as well, because Flash
							// does not propagate events down. This means that highlighters on
							// buttons are not turned off if they have a tooltip on them
							if (cursorMc != null) {
								cursorMc.clip._visible = false;
							}
							ArcticMC.showMouse();
						};
					}
				}
				onMove();
			#end
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Offset(dx, dy, block) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create && child.clip != null) {
				ArcticMC.moveClip(child.clip, dx, dy);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			
		case OnTop(base, overlay) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(base, clip, availableWidth, availableHeight, mode, 0);
			var over = build(overlay, clip, availableWidth, availableHeight, mode, 1);
			return { clip: clip, width: Math.max(child.width, over.width), height: Math.max(child.height, over.height),
					growWidth: child.growWidth || over.growWidth, growHeight: child.growHeight || over.growHeight };
		#if flash9
		case OnTopView(base, overlay) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(base, clip, availableWidth, availableHeight, mode, 0);
			
			if (mode == Metrics) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			
			if (mode == Destroy) {
				var overlayMc = ArcticMC.get(clip, "overlay");
				if (overlayMc != null) {
					for (i in 0...parent.numChildren) {
						var c : Dynamic = this.parent.getChildAt(i);
						if (c == overlayMc.clip) {
							build(overlay, this.parent, 0, 0, mode, i);
							break;
						}
					}
					ArcticMC.remove(overlayMc.clip);
					ArcticMC.delete(clip, "overlay");
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var me = this;
			var register = function (e:Dynamic) {
				var overlayMc = me.build(overlay, me.parent, 0, 0, mode, 0);
				ArcticMC.set(clip, "overlay", overlayMc);
				var r = child.clip.getBounds(me.parent);
				overlayMc.clip.x = r.left;
				overlayMc.clip.y = r.top;
				clip.removeEventListener(Event.ENTER_FRAME, ArcticMC.get(clip, "onframe"));
			}
			ArcticMC.set(clip, "onframe", register);
						
			clip.addEventListener(Event.ENTER_FRAME, register);
			
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		#end
		
		case Id(id, block) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Destroy) {
				idMovieClip.remove(id);
			} else if (mode == Create) {
				idMovieClip.set(id, child.clip);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case CustomBlock(data, buildFun):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				var result = buildFun(data, mode, clip, availableWidth, availableHeight, null);
				ArcticMC.set(clip, "customClip", result.clip);
				return result;
			} else if (mode == Reuse || mode == Destroy) {
				var dclip = ArcticMC.get(clip, "customClip");
				if (mode == Destroy) {
					ArcticMC.delete(clip, "customClip");
				}
				var r = buildFun(data, mode, clip, availableWidth, availableHeight, dclip);
				if (r == null) {
					return { clip: null, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
				}
				return r;
			} else {
				return buildFun(data, mode, null, availableWidth, availableHeight, null);
			}
		
		case MouseWheel(block, onMouseWheel):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				// To support empty children, we ensure that we have the right size
				ArcticMC.setSize(clip, child.width, child.height);
				#if flash9
					addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_WHEEL,
						function (s) {
							// We do not respect alpha for mouse wheel detection
							if (ArcticMC.isActive(clip) && clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, false)) {
								onMouseWheel(s.delta);
							}
						}
					);
				#elseif flash
					var mouseWheelListener = { 
						onMouseDown : function() {},
						onMouseMove : function() {},
						onMouseUp : function() {},
						onMouseWheel : function ( delta : Float, target ) {
							// We do not respect alpha for mouse wheel detection
							if (ArcticMC.isActive(clip) && clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false)) {
								onMouseWheel(delta);
							}
						}
					};
					flash.Mouse.addListener(mouseWheelListener);
					// We record this one so we can remove it again later
					mouseWheelListeners.push({ clip: clip, listener: mouseWheelListener } );
				#end
			} else if (mode == Destroy) {
				removeStageEventListeners(clip);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Mask(block, mask) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			var mask = build(mask, clip, availableWidth, availableHeight, mode, 1);
			if (mode == Create) {
				#if flash9
					child.clip.mask = mask.clip;
				#elseif flash
					child.clip.setMask(mask.clip);
				#end
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Scale(block, maxScale, alignX, alignY, childGrowth):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			
			if (childGrowth == null) childGrowth = 0.0;
			
			var metricsChild = build(block, clip, availableWidth * childGrowth, availableHeight * childGrowth, Metrics, 0);
			var growWidth = true;
			var growHeight = true;
			
			if (metricsChild.growHeight != metricsChild.growWidth) {
				growWidth = metricsChild.growWidth;
				growHeight = metricsChild.growHeight;
			}
			
			var scale : Null<Float> = null;
			if (metricsChild.width != 0) {
				if (availableWidth != 0) {
					var scaleX = availableWidth / metricsChild.width;
					scale = scaleX;
				}
			}
			if (metricsChild.height != 0) {
				if (availableHeight != 0) {
					var scaleY = availableHeight / metricsChild.height;
					if (scale != null) {
						scale = Math.min(scale, scaleY);
					} else {
						scale = scaleY;
					}
				}
			}
			if (scale == null) {
				scale = 1.0;
			}
			
			if (maxScale != null) {
				if (scale > maxScale) {
					scale = maxScale;
					growWidth = false;
					growHeight = false;
				} else {
					if (availableWidth >= metricsChild.width*maxScale && !metricsChild.growWidth)
						growWidth = false;
					if (availableHeight >= metricsChild.height*maxScale && !metricsChild.growHeight)
						growHeight = false;
				}
			}
			
			var excessWidth = availableWidth * childGrowth;
			var excessHeight = availableHeight * childGrowth;
			if (growWidth) {
				excessWidth = availableWidth / scale;
			}
			if (growHeight) {
				excessHeight = availableHeight / scale;
			}
			//trace(availableWidth + "," + availableHeight + " " + metricsChild.width + "," + metricsChild.height + " " + scale + " " + excessWidth + "," + excessHeight);
			var child = build(block, clip, excessWidth, excessHeight, mode, 0);
			if (mode != Metrics && mode != Destroy) {
				ArcticMC.setScaleXY(child.clip, scale, scale);
				if ((alignX != null && alignX != -1.0) || (alignY != null && alignY != -1.0)) {
					var x = 0.0;
					var y = 0.0;
					if (alignX != null && alignX != -1.0 && availableWidth > child.width*scale) {
						x = (availableWidth - child.width*scale) * alignX;
					}
					if (alignY != null && alignY != -1.0 && availableHeight > child.height*scale) {
						y = (availableHeight - child.height*scale) * alignY;
					}
					ArcticMC.setXY(child.clip, x, y);
				}
			}
			return { clip: clip, width: if (growWidth) availableWidth else scale * child.width, height: if (growHeight) availableHeight else scale * child.height, growWidth: growWidth, growHeight: growHeight };
		
		case Transform(block, scaleX, scaleY):
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Metrics && mode != Destroy) {
				ArcticMC.setScaleXY(child.clip, scaleX, scaleY);
			}
			return { clip: clip, width: child.width * scaleX, height: child.height * scaleY, growWidth: child.growWidth, growHeight: child.growHeight };

		#if flash9
		case Rotate(block, angle, keepOrigin):
		
			if (keepOrigin) {
				var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
				var child = build(block, clip, availableWidth, availableHeight, mode, 0);
				if (mode != Destroy && child.clip != null) {
					child.clip.rotation = angle;
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight};
			}
				
			var childW:Float = 0;
			var childH:Float = 0;
			var minx:Float = 0;
			var miny:Float = 0;
			var maxx:Float = 0;
			var maxy:Float = 0;
			var ca:Float = 0;
			var sa:Float = 0;
			
			if (mode != Destroy) {
				ca = Math.cos(angle*Math.PI/180.0);
				sa = Math.sin(angle*Math.PI/180.0);
				var d:Float = 1.0/(ca * ca - sa * sa); 
				childW = d * (Math.abs(ca * availableWidth) - Math.abs(sa * availableHeight));
				childH = d * (Math.abs(ca * availableHeight) - Math.abs(sa * availableWidth));
			}
			
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, childW, childH, mode, 0);
		
			if (mode != Destroy) {
				var w:Float = child.width;
				var h:Float = child.height;
				if ((ca >= 0) && (sa >= 0)) {
					minx = -h * sa;
					miny = 0;
					maxx = w * ca;
					maxy = w * sa + h * ca;
				} else if ((ca <= 0) && (sa >= 0)) {
					minx = w * ca - h * sa;
					miny = h * ca;
					maxx = 0;
					maxy = w * sa;
				} else if ((ca <= 0) && (sa <= 0)) {
					minx = w * ca;
					miny = w * sa + h * ca;
					maxx = -h * sa;
					maxy = 0;
				} else if ((ca >= 0) && (sa <= 0)) {
					minx = 0;
					miny = w * sa;
					maxx = w * ca - h * sa;
					maxy = h * ca;
				}
				if (child.clip != null) {
					child.clip.rotation = angle;
					child.clip.x = -minx;
					child.clip.y = -miny;
				}
			}
		return { clip: clip, width: maxx - minx, height: maxy-miny, growWidth: child.growWidth, growHeight: child.growHeight};
		#end
		
		case Animate(animator):
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(animator.block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				animator.registerClip(clip);
			} else if (mode == Destroy) {
				animator.destroy();
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Cached(block):
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			#if flash9
			if (mode == Create) {
				var visitor:Array<ArcticMovieClip->Void> = [];
				var visit = function (mc:Dynamic) { mc.cacheAsBitmap = true; if (Reflect.hasField(mc, "numChildren") && (ArcticMC.get(mc, "nocache") == null))for (i in 0...mc.numChildren) visitor[0](mc.getChildAt(i)); }
				visitor.push(visit);
				visit(clip);
			} 
			#end
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case UnCached(block):
			//trace("uncached met", 0);
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				ArcticMC.set(clip, "nocache", true);
			} 
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case DebugBlock(id, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			trace("Calling build ( " + availableWidth + "," + availableHeight + ", " + mode + ") on "+ id);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			trace("built (" + availableWidth + "," + availableHeight + ", " + mode + "): (" 
				+ child.width + "," + child.height + " " + child.growWidth + "," + child.growHeight + ") on " + id );
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		}
	}
	
	private function buildTextInput(p, childNo, mode, availableWidth : Null<Float>, availableHeight : Null<Float>, html, width : Null<Float>, height : Null<Float>, validator, style, maxChars : Null<Int>, numeric : Null<Bool>, bgColor : Null<Int>, focus : Null<Bool>, embeddedFont, onInit, onInitEvents) {
		if (mode == Metrics) {
			return { clip: null, width : null != width ? width : availableWidth, height : null != height ? height : availableHeight, 
				growWidth : null == width, growHeight : null == height };
		}
		var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
		if (mode == Create) {
			ActiveClips.get().add(clip);
		} else if (mode == Destroy) {
			ActiveClips.get().remove(clip);
			// Should we clear out event handlers as well?
			return { clip: clip, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
		}
		#if (flash9 || neko)
			var txtInput : flash.text.TextField;
			if (mode == Create) {
				txtInput = new flash.text.TextField();
			} else {
				var t : Dynamic = clip.getChildAt(0);
				txtInput = t;
			}
			if (embeddedFont) {
				txtInput.embedFonts = true;
			}
			if (null != width) {
				txtInput.width = width;
			}
			if (null != height) {
				txtInput.height = height;
			}
		#elseif flash
			var txtInput : flash.TextField;
			if (mode == Create) {
				txtInput = ArcticMC.createTextField(clip, 0, 0, width, height);
				ArcticMC.set(clip, "ti", txtInput);
			} else {
				txtInput = ArcticMC.get(clip, "ti");
			}
			txtInput.html = true;
		#end

		if (embeddedFont) {
			txtInput.embedFonts = true;
		}
		txtInput.tabEnabled = true;
		if (null != width && null != height) {
		} else {
			#if flash9
			txtInput.autoSize = flash.text.TextFieldAutoSize.LEFT; // "left";	
			#else
			txtInput.autoSize = "left";
			#end
			txtInput.wordWrap = (null != width); // wordWrap is the same as fixed width
			txtInput.multiline = (null == height); // multiline allows growing in height
		}
		if (null != maxChars) {
			txtInput.maxChars = maxChars;
		}
		if (null != bgColor) {
			txtInput.background = true;
			txtInput.backgroundColor = bgColor;
		}
		if (mode == Create) {
			var validate = function() {
				if (validator == null) {
					return;
				}
				var isValid: Null<Bool> = validator(txtInput.text);
				if (isValid == true) {
					txtInput.background = (null != bgColor);
					if (txtInput.background) {
						txtInput.backgroundColor = bgColor;
					}
				} else if (isValid == false) {
					txtInput.background = true;
					txtInput.backgroundColor = 0xff0000;
				} // don't change background if isValid == null
			}
			// Setting additional txtInput properties from the style object
			var fields = Reflect.fields(style);
			for (i in 0...fields.length){
				Reflect.setField(txtInput, fields[i], Reflect.field(style,fields[i]));
			}
			txtInput.htmlText = html;
			// Retreive the format of the initial text
			var txtFormat = null;
			if (txtInput.text.length > 0) {
				txtFormat = txtInput.getTextFormat(0,1);
			}
			if (null != numeric && numeric) {
				txtInput.restrict = "0-9\\-\\.";
				if (txtFormat != null) {
					#if flash9
					txtFormat.align = flash.text.TextFormatAlign.RIGHT; // "right";
					#else
					txtFormat.align = "right";
					#end
				}
			}
			var lastWidth = ArcticMC.getTextFieldWidth(txtInput);
			var lastHeight = ArcticMC.getTextFieldHeight(txtInput);
			var sizeChanged = function () {
				if (null == width && lastWidth != ArcticMC.getTextFieldWidth(txtInput)) {
					lastWidth = ArcticMC.getTextFieldWidth(txtInput);
					return true;
				}
				if (null == height && lastHeight != ArcticMC.getTextFieldHeight(txtInput)) {
					lastHeight = ArcticMC.getTextFieldHeight(txtInput);
					return true;
				}
				return false;
			}
			#if flash9
				if (txtFormat != null) {
					txtInput.defaultTextFormat = txtFormat;
				}
				if (txtInput.text == " ") {
					txtInput.text = "";
				} else {
					// Set the text again to enforce the formatting
					txtInput.htmlText = html;
				}
				var me = this;
				var listener = (null != width && null != height) ? function (e) { validate(); }
					: function (e) { if (sizeChanged()) me.refresh(false); validate(); };
				txtInput.addEventListener(flash.events.Event.CHANGE, listener);
				clip.addChild(txtInput);
				txtInput.type = TextFieldType.INPUT;
			#elseif flash
				txtInput.setNewTextFormat(txtFormat);
				// Set the text again to enforce the formatting
				txtInput.htmlText = html;
				var me = this;
				var listener = {
					// TODO : Don't know why 'onKillFocus' event is not working.  'onChanged' will be annoying.
					onChanged : (null != width && null != height) ? function (txtFld : TextField) {	validate();	}
						: function (txtFld: TextField) { if (sizeChanged()) me.refresh(false); validate(); }
				};
				txtInput.addListener(listener);
				txtInput.type = "input";
			#end
		}
		if (mode == Create) {
			// Setting focus on txtInput 
			#if (flash9 || neko)
				if (focus != null && focus) {
					clip.stage.focus = txtInput;
					if (txtInput.text != " ") {
						txtInput.setSelection(0, txtInput.length);
					} else {
						txtInput.setSelection(1, 1);
					}
				}
			#elseif flash
				if (focus != null && focus) {
					flash.Selection.setFocus(txtInput);
				}
			#end

			if (onInit != null) {
				var textFn = function(status: TextInputModel) : TextInputModel {
					if (null != status) {
						if (status.html != null) {
							txtInput.htmlText = status.html;
						} else if (status.text != null) {
							txtInput.text = status.text;
						}
						if (status.focus == true) {
							#if (flash9 || neko)
								clip.stage.focus = txtInput;
								if (null == status.selStart || null == status.selEnd) {
									txtInput.setSelection(0, txtInput.length);
								}
							#elseif flash
								flash.Selection.setFocus(txtInput);
							#end
						}
						if (null != status.selStart && null != status.selEnd) {
							#if (flash9 || neko)
							txtInput.setSelection(status.selStart, status.selEnd);
							#elseif flash
							flash.Selection.setSelection(status.selStart, status.selEnd);
							#end
						} else if (null != status.cursorPos) {
							#if (flash9 || neko)
							txtInput.setSelection(status.cursorPos, status.cursorPos);
							#elseif flash
							flash.Selection.setSelection(status.cursorPos, status.cursorPos);
							#end
						}
						if (status.disabled == true) {
							#if (flash9 || neko)
							txtInput.type = TextFieldType.DYNAMIC;
							#elseif flash
							txtInput.type = "dynamic";
							#end
						} else {
							#if (flash9 || neko)
							txtInput.type = TextFieldType.INPUT;
							#elseif flash
							txtInput.type = "input";
							#end
						}
					}
					
					#if (flash9 || neko)
						var focus = clip.stage.focus == txtInput;
						// temp variables to work around bugs in Null<Int> -> Int conversion
						var selStart: Null<Int> = txtInput.selectionBeginIndex;
						var selEnd: Null<Int> = txtInput.selectionEndIndex;
						var cursorPos: Null<Int> = txtInput.caretIndex;
						
						var cursorX:Null<Float> = 0;
						var bounds = txtInput.getCharBoundaries(txtInput.caretIndex);
						if (bounds != null)
							cursorX = bounds.left;
						else { 
							bounds = txtInput.getCharBoundaries(txtInput.caretIndex - 1);
							if (bounds != null)
								cursorX = bounds.left;
						}
						return { html: txtInput.htmlText, text: txtInput.text, focus: focus, selStart: focus ? selStart : null, selEnd: focus ? selEnd : null, 
								 cursorPos: focus ? cursorPos : null, disabled: txtInput.type != TextFieldType.INPUT, cursorX: cursorX }
					#elseif flash
						var hasFocus = flash.Selection.getFocus() == txtInput._target;
						return { html: txtInput.htmlText, text: txtInput.text, focus: hasFocus, selStart: hasFocus ? flash.Selection.getBeginIndex() : null,
								 selEnd: hasFocus ? flash.Selection.getEndIndex() : null, cursorPos: hasFocus ? flash.Selection.getCaretIndex() : null, 
								 disabled: txtInput.type != "input", cursorX: null }
					#end

				}
				onInit(textFn);
			}
		
			if (onInitEvents != null) {
				var eventsFn = function (events: TextInputEvents): Void {
					#if flash9
					addOptionalEventListener(txtInput, flash.events.Event.CHANGE, events.onChange, function (e) { events.onChange(); });
					addOptionalEventListener(txtInput, flash.events.FocusEvent.FOCUS_IN, events.onSetFocus, function (e) {
						if (e.target == txtInput) events.onSetFocus();
					});
					addOptionalEventListener(txtInput, flash.events.FocusEvent.FOCUS_OUT, events.onKillFocus, function (e) {
						if (e.target == txtInput) events.onKillFocus();
					});
					addOptionalEventListener(txtInput, flash.events.MouseEvent.MOUSE_DOWN, events.onPress, function (e) {
						events.onPress();
					});
					addOptionalEventListener(txtInput, flash.events.MouseEvent.MOUSE_UP, events.onRelease, function (e) {
						events.onRelease();
					});
					addOptionalEventListener(txtInput, flash.events.KeyboardEvent.KEY_DOWN, events.onKeyDown, function (e) {
						events.onKeyDown(e.charCode);
					});
					addOptionalEventListener(txtInput, flash.events.KeyboardEvent.KEY_UP, events.onKeyUp, function (e) {
						events.onKeyUp(e.charCode);
					});
					var prevCaretPos = [txtInput.caretIndex];
					addOptionalEventListener(txtInput, Event.ENTER_FRAME, events.onCaretPosChanged, function (e) {
						if (prevCaretPos[0] != txtInput.caretIndex) {
							prevCaretPos[0] = txtInput.caretIndex;
							events.onCaretPosChanged();
						}
					});
					
					#elseif flash
					var buildhandler = function (handler: Void -> Void) { 
						return function () {
							if (clip._xmouse >= txtInput._x && clip._xmouse < txtInput._x + txtInput._width && clip._ymouse >= txtInput._y && clip._ymouse < txtInput._y + txtInput._height) {
								handler();
							}
						}
					}
					
					txtInput.onChanged = null != events.onChange ? function (tf) { events.onChange(); } : txtInput.onChanged;
					txtInput.onSetFocus = null != events.onSetFocus ? function (tf) { events.onSetFocus(); } : txtInput.onSetFocus;
					txtInput.onKillFocus = null != events.onKillFocus ? function (tf) { events.onKillFocus(); } : txtInput.onKillFocus;
					
					clip.onMouseDown = null != events.onPress ? buildhandler(events.onPress) : clip.onMouseDown;
					clip.onMouseUp = null != events.onRelease ? buildhandler(events.onRelease) : clip.onMouseUp;
					#end
				}
				
				onInitEvents(eventsFn);
			}
		}

		var s = ArcticMC.getSize(clip);
		return { clip: clip, width: s.width, height: s.height, growWidth: null == width, growHeight: null == height };
	}

	private function buildButton(p, childNo, mode, availableWidth, availableHeight, block, hoverb, action, actionExt) {
		if (mode == Metrics) {
			var child = build(block, null, availableWidth, availableHeight, Metrics, 0);
			if (hoverb == null) {
				return { clip: null, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var hover = build(hoverb, null, availableWidth, availableHeight, Metrics, 1);
			return { clip: null, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
		}
		var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
		var child = build(block, clip, availableWidth, availableHeight, mode, 0);
		if (child.clip == null && mode != Destroy) {
			#if debug
			trace("Can not make button of empty clip");
			#end
			return { clip: null, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		}
		var hover = null;
		if (hoverb != null) {
			hover = build(hoverb, clip, availableWidth, availableHeight, mode, 1);
		}
		// TODO: It would be nice if this hovered if the cursor was on this button, but we are not in the correct
		// position yet, so we can't do this yet! The parent would have to position us first, which is a change
		// for another day.
		
		var hasHover = hover != null && hover.clip != null;
		if (mode == Destroy) {
			removeStageEventListeners(clip);
			if (!hasHover) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			} else {
				return { clip: clip, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
			}
		}

		ArcticMC.setVisible(child.clip, true);
		if (hasHover) {
			ArcticMC.setVisible(hover.clip, false);
		}
		#if (flash9||neko)
			child.clip.buttonMode = true;
			child.clip.mouseChildren = false;
			if (hasHover) {
				hover.clip.buttonMode = true;
				hover.clip.mouseChildren = false;
			}
			if (mode == Create) {
				var mouseDownInsideReceived = false;
				
				#if arcticevidence
				var aem = ArcticEvidenceManager.get();
				var abId = ArcticEvidenceManager.idFromArctic(block);
				#end
				if (action != null) {
					#if arcticevidence
					var eventName = "buttonclick";
					aem.registerReplayer(eventName, abId, action);
					#end
					clip.addEventListener(MouseEvent.MOUSE_UP, function(s) { 
							if (!mouseDownInsideReceived) {
								// We ignore this
								return;
							}
							var m = ArcticMC.getMouseXY();
							// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
							// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
							if (ArcticMC.isActive(clip) && clip.hitTestPoint(m.x, m.y, true)) {
								#if arcticevidence
								aem.recordEvent(eventName, abId, []);
								#end
								action(); 
							}
							mouseDownInsideReceived = false;
						} ); 
				}
				if (actionExt != null) {
					#if arcticevidence
					var eventName = "buttonclickxyup";
					aem.registerReplayer(eventName, abId, actionExt);
					#end
					addStageEventListener( clip, clip.stage, MouseEvent.MOUSE_UP, function(s) { 
							if (ArcticMC.isActive(clip)) {
								// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
								// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
								var m = ArcticMC.getMouseXY();
								#if arcticevidence
								aem.recordEvent(eventName, abId, 
												[clip.mouseX, clip.mouseY, false,
												 clip.hitTestPoint(m.x, m.y, true)]);
								#end
								actionExt(clip.mouseX, clip.mouseY, false,
										  clip.hitTestPoint(m.x, m.y, true));
							}
						} );
					#if arcticevidence
					var eventName = "buttonclickxydown";
					aem.registerReplayer(eventName, abId, actionExt);
					#end
				}
				addStageEventListener( clip, clip.stage, MouseEvent.MOUSE_DOWN, function(s) { 
						if (ArcticMC.isActive(clip)) {
							var m = ArcticMC.getMouseXY();
							mouseDownInsideReceived = clip.hitTestPoint(m.x, m.y, true);
							// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
							// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
							#if arcticevidence
							aem.recordEvent(eventName, abId, 
											[clip.mouseX, clip.mouseY, true,
											 clip.hitTestPoint(m.x, m.y, true)]);
							#end
							if (actionExt != null) {
								actionExt(clip.mouseX, clip.mouseY, true, mouseDownInsideReceived);
							}
						}
					} );
				if (hasHover) {
					addStageEventListener( clip, clip.stage, MouseEvent.MOUSE_MOVE, function (s) {
							var m = ArcticMC.getMouseXY();
							// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
							if (clip.hitTestPoint(m.x, m.y, true) && ArcticMC.isActive(clip)) {
								child.clip.visible = false;
								hover.clip.visible = true;
							} else {
								child.clip.visible = true;
								hover.clip.visible = false;
							}
						} );
					addStageEventListener( clip, clip.stage, Event.MOUSE_LEAVE, function() {
						child.clip.visible = true;
						hover.clip.visible = false;
					});
				}
			}
		#elseif flash
			if (mode == Create) {
				if (action != null || actionExt != null) {
					clip.onMouseUp = function () {
						// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
						if (ArcticMC.isActive(clip)) {
							var hit = clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true);
							if (action != null && hit) {
								action();
							}
							if (actionExt != null) {
								actionExt(clip._xmouse, clip._ymouse, false, hit);
							}
						}
					}
				}
				if (actionExt != null) {
					clip.onMouseDown = function () {
						if (ArcticMC.isActive(clip)) {
							// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
							actionExt(clip._xmouse, clip._ymouse, true, clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true));
						}
					}
				}
				if (hasHover) {
					clip.onMouseMove = function() {
						// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
						var mouseInside = child.clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true) && ArcticMC.isActive(clip);
						if (mouseInside) {
							child.clip._visible = false;
							hover.clip._visible = true;
						} else {
							child.clip._visible = true;
							hover.clip._visible = false;
						}
					};
					hover.clip.onRollOut = function() { 
						child.clip._visible = true;
						hover.clip._visible = false;
					};
				}
			}
		#end
		if (!hasHover) {
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		}
		return { clip: clip, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
	}

	private function buildDragable(p, childNo, mode, availableWidth, availableHeight, stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag) {
		
		var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
		
		var child = build(block, clip, availableWidth, availableHeight, mode, 0);
		
		if (mode != Metrics && mode != Destroy) {
			if (child.clip == null) {
				#if debug
				trace("Can not make dragable with empty block");
				#end
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
		}

		var dragClip = clip; 
		if (mode == Create) {
			ActiveClips.get().add(dragClip);
		} else if (mode == Destroy) {
			ActiveClips.get().remove(dragClip);
		}

		var width = child.width;
		var height = child.height;
		if (stayWithin) {
			if (sideMotion) {
				child.growWidth = true;
				child.width = Math.max(child.width, availableWidth);
			}
			if (upDownMotion) {
				child.growHeight = true;
				child.height = Math.max(child.height, availableHeight);
			}
		}
		
		if (mode == Metrics) {
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		}
		
		var info : BlockInfo = null;
		if (mode == Create) {
			info = {
				available: { width: availableWidth, height: availableHeight },
				totalDx: 0.0,
				totalDy: 0.0,
				childWidth: width,
				childHeight: height
			};
			setBlockInfo(dragClip, info);
		} else if (mode == Reuse) {
			info = getBlockInfo(dragClip);
			info.available = { width: availableWidth, height: availableHeight };
			info.childWidth = width;
			info.childHeight = height;
		}
		var me = this;
		var setPosition = function (x : Float, y : Float) {
			var info = me.getBlockInfo(dragClip);
			if (stayWithin) {
				x = Math.min(info.available.width - info.childWidth, x);
				y = Math.min(info.available.height - info.childHeight, y);
			}
			ArcticMC.setXY(dragClip, x, y);
			info.totalDx = x;
			info.totalDy = y;
		}; 
		
		if (mode != Create) {
			if (mode == Destroy) {
				removeStageEventListeners(clip);
			} else if (mode == Reuse && null != onInit) {
				var dragInfo = { 
					x : info.totalDx, 
					y : info.totalDy,
					width : info.childWidth,
					height : info.childHeight,
					totalWidth : info.available.width - info.childWidth, 
					totalHeight : info.available.height - info.childHeight 
				};
				onInit(dragInfo, setPosition);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		}
		
		var dragX = -1.0;
		var dragY = -1.0;
		
		var doDrag = function (dx : Float, dy : Float) {
			var info = me.getBlockInfo(dragClip);
			if (!sideMotion) {
				dx = 0;
			}
			if (!upDownMotion) {
				dy = 0;
			}
			var motion = false;
			if (sideMotion) {
				while (Math.abs(dx) > 0) {
					var newTotalDx = info.totalDx + dx;
					if (!stayWithin || (newTotalDx >= 0 && newTotalDx <= info.available.width - info.childWidth)) {
						ArcticMC.moveClip(dragClip, dx, 0);
						info.totalDx = newTotalDx;
						motion = true;
						break;
					}
					// We just try a smaller drag
					if (dx > 0) {
						dx--;
					} else {
						dx++;
					}
				}
			}
			if (upDownMotion) {
				while (Math.abs(dy) > 0) {
					var newTotalDy = info.totalDy + dy;
					if (!stayWithin || (newTotalDy >= 0 && newTotalDy <= info.available.height - info.childHeight)) {
						ArcticMC.moveClip(dragClip, 0, dy);
						info.totalDy = newTotalDy;
						motion = true;
						break;
					}
					// We just try a smaller drag
					if (dy > 0) {
						dy--;
					} else {
						dy++;
					}
				}
			}
			if (motion) {
				if (onDrag != null) {
					var dragInfo = { 
						x : info.totalDx, 
						y : info.totalDy, 
						width : info.childWidth,
						height : info.childHeight,
						totalWidth : info.available.width - info.childWidth, 
						totalHeight : info.available.height - info.childHeight 
					};
					onDrag(dragInfo);
				}
			}
		}
		
		#if flash9
			var firstTime = true;
			var mouseMove = function(s) {
				if (clip == null || !clip.visible || clip.stage == null) {
					return;
				}
				var dx = clip.stage.mouseX - dragX;
				var dy = clip.stage.mouseY - dragY;
				
				// Make a correction for scaling
				var zero = new Point(0, 0);
				zero = clip.localToGlobal(zero);
				var p = new Point(1, 1);
				p = clip.localToGlobal(p);
				p = p.subtract(zero);
				
				doDrag(dx / p.x, dy / p.y);
				dragX = clip.stage.mouseX;
				dragY = clip.stage.mouseY;
			}
			var mouseUp = 
				function(s) {
					if (dragX == -1) {
						return;
					}
					if (clip != null && clip.stage != null) {
						me.removeStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
					}
					dragX = -1;
					dragY = -1;
					if (onStopDrag != null) {
						onStopDrag();
					}
				};
			clip.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, 
				function (s) { 
					if (ActiveClips.get().getActiveClip() == dragClip) {
						dragX = clip.stage.mouseX;
						dragY = clip.stage.mouseY;
						me.addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
						if (firstTime) {
							me.addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_UP, mouseUp );
							firstTime = false;
						}
					}
				}
			);
		#elseif flash
			clip.onMouseDown = function() {
				if (ActiveClips.get().getActiveClip() == dragClip) {
					dragX = flash.Lib.current._xmouse;
					dragY = flash.Lib.current._ymouse;
					if (clip.onMouseMove == null) {
						clip.onMouseMove = function() {
							if (!clip._visible) {
								return;
							}
							var dx = flash.Lib.current._xmouse - dragX;
							var dy = flash.Lib.current._ymouse - dragY;
							doDrag(dx, dy);
							dragX = flash.Lib.current._xmouse;
							dragY = flash.Lib.current._ymouse;
						};
					}
					if (clip.onMouseUp == null) {
						clip.onMouseUp = function() {
							if (onStopDrag != null) {
								onStopDrag();
							}
							clip.onMouseMove = null;
							clip.onMouseUp = null;
						};
					}
				}
			};
		#end

		if (null != onInit) {
			var dragInfo = { 
				x : info.totalDx, 
				y : info.totalDy, 
				width : info.childWidth,
				height : info.childHeight,
				totalWidth : info.available.width - info.childWidth, 
				totalHeight : info.available.height - info.childHeight 
			};
			onInit(dragInfo, setPosition);
		}
		return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
	}
		
	/// For text elements, we cache the sizes
	static private var metricsCache : Hash< { width: Float, height : Float } >;

	/// Count of how many pictures are loaded
	public var pendingPictureRequests : Int;
	/// Callback for when picture is loaded
	public var pictureLoadedFn : Int -> Void;

	
	#if debug
	var currentBlockKind : String;
	var currentPath : String;
	public var trackMemory : Bool;
	#end
	
	/**
	 * Creates a clip (if construct is true) as childNo, otherwise gets existing movieclip at that point.
	 */ 
	private function getOrMakeClip(p : ArcticMovieClip, buildMode : BuildMode, childNo : Int) : ArcticMovieClip {
		if (buildMode == Metrics || p == null) {
			return null;
		}
		if (buildMode == Create) {
			#if flash6
				var d = ArcticMC.getNextHighestDepth(p);
				p.createEmptyMovieClip("c" + childNo, d);
				var clip = Reflect.field(p, "c" + childNo);
				ArcticMC.set(p, "c" + childNo, clip);
			#elseif flash7
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				ArcticMC.set(p, "c" + childNo, clip);
			#elseif flash8
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				ArcticMC.set(p, "c" + childNo, clip);
			#elseif (flash9 || neko)
				var clip = new ArcticMovieClip();
				#if debug
				if (p.numChildren > childNo) {
					trace("p already has " + p.numChildren + " children, so adding as " + childNo + " makes no sense");
				}
				if (trackMemory) {
					// MemoryProfiling.track(clip, currentBlockKind);
				}
				#end
				p.addChild(clip);
				if (p != parent) {
					ArcticMC.set(p, "c" + childNo, clip);
				}
			#end
			clip.tabEnabled = false;
			return clip;
		}
		// Reuse/Destroy case
		#if (flash9 || neko)
			if (p != parent) {
				if (ArcticMC.has(p, "c" + childNo)) {
					return ArcticMC.get(p, "c" + childNo);
				}
				if (buildMode == Destroy) {
					#if debug
					trace("Crap! Can leak active clips");
					#end
					return null;
				}
#if debug
				trace("getOrMakeClip() unexpected fallback 1." + buildMode);
#end
				return getOrMakeClip(p, Create, childNo);
			}
			if (childNo >= p.numChildren) {
				if (buildMode == Destroy) {
					return null;
				}
				// Fallback - should never happen
#if debug
				trace("getOrMakeClip() unexpected fallback 2.");
#end
				return getOrMakeClip(p, Create, childNo);
			} else {
				var d : Dynamic = p.getChildAt(childNo);
				/*
				#if debug
				if (Type.getClassName(Type.getClass(d)).indexOf('text') != -1) {
					// If you get this trace...
					trace("Child is not as expected! Probably you have put an ArcticView on the root MovieClip and haXe trace has reordered it away.");
					/// ...change
					//    view = new ArcticView(gui, arctic.ArcticMC.getCurrentClip());
					// to
					//    var baseclip = arctic.ArcticMC.create(arctic.ArcticMC.getCurrentClip());
					//    view = new ArcticView(gui, baseclip);
					if (buildMode == Destroy) {
						return null;
					}
					// We just try our luck here:
					d = p.getChildAt(childNo - 1);
				}
				#end
				*/

				#if flash9
				if (Type.getClassName(Type.getClass(d)) == 'flash.text.TextField') {
					d = d.parent;
				}
				#end
				return d;
			}
		#elseif flash
			if (ArcticMC.has(p, "c" + childNo)) {
				return ArcticMC.get(p, "c" + childNo);
			}
			// Fallback - should never happen
			return getOrMakeClip(p, Create, childNo);
		#end
	}
	
	#if flash9
	/// A nice helper function to initialize optional event handlers
	private static function addOptionalEventListener<Handler>(target: EventDispatcher, type: String, handler: Handler, 
		flashHandler: /*flash.events.Event*/Dynamic -> Void) {
		if (null != handler) {
			target.addEventListener(type, flashHandler);
		}
	}
	#end

	/// Get to the book keeping details of the given clip
	private function getBlockInfo(clip : ArcticMovieClip) : BlockInfo {
		return ArcticMC.get(clip, "arcticInfo");
	}
	
	/// Set the book keeping details for this clip
	private function setBlockInfo(clip : ArcticMovieClip, info : BlockInfo) {
		ArcticMC.set(clip, "arcticInfo", info);
	}
	
	#if (flash9||neko)
	private function addStageEventListener(refObj : Dynamic, d : EventDispatcher, event : String, handler : Dynamic) {
		if (d == null) return;
		d.addEventListener(event, handler);
		stageEventHandlers.push( { obj: d, event: event, handler: handler, ref: refObj });
	}
	private function removeStageEventListeners(refObj : Dynamic) {
		var i : Int = stageEventHandlers.length;
		while (i > 0) {
			i--;
			if (stageEventHandlers[i].ref == refObj) {
				stageEventHandlers[i].obj.removeEventListener(stageEventHandlers[i].event, stageEventHandlers[i].handler);
				stageEventHandlers.splice(i, 1);
			}
		}
	}
	private function removeStageEventListener(refObj : Dynamic, d : EventDispatcher, event : String, handler : Dynamic) {
		d.removeEventListener(event, handler);
		var i : Int = stageEventHandlers.length;
		while (i > 0) {
			i--;
			if (stageEventHandlers[i].ref == refObj && stageEventHandlers[i].obj == d &&
				stageEventHandlers[i].event == event && stageEventHandlers[i].handler == handler) {
				stageEventHandlers.splice(i, 1);
			}
		}
	}
	#else
	private function removeStageEventListeners(refObj : Dynamic) {
	}
	private function removeStageEventListener(refObj : Dynamic, d : Dynamic, event : String, handler : Dynamic) {
	}
	#end
	
	#if flash9
	// Hash of all pictures
	private static var pictureCache: Hash<BitmapData>;
	
	// returns image sizes as parameters for cb function
	public static function getImageSizes(url : String, cb : Float -> Float -> Void) {
		var cachedPicture:Dynamic = pictureCache.get(url);
		if (cachedPicture != null) {
			try {
				var clone : BitmapData = cachedPicture.clone(); 
				var bmp:Bitmap = new Bitmap(clone);
				bmp.smoothing = true;
				cb(bmp.width, bmp.height);
			} catch( unknown : Dynamic ) {
				trace("Error during restoring image from cache : " + Std.string(unknown));
			}
		} else {
			var loader = new flash.display.Loader();
			var dis = loader.contentLoaderInfo;
			var request = new flash.net.URLRequest(Arctic.baseurl + url);
			
			dis.addEventListener(
				flash.events.Event.COMPLETE,
				function(event : flash.events.Event) {
					try {
						var loader : flash.display.Loader = event.target.loader;
						var content:Dynamic = loader.content;
						if (Std.is(content, flash.display.Bitmap)) {
							var image : flash.display.Bitmap = cast loader.content;
							image.smoothing = true;
							pictureCache.set(url, image.bitmapData);
							cb(image.width, image.height);
						} else {
							var className:String = untyped __global__["flash.utils.getQualifiedClassName"](content);
							if (className == "flash.display::AVM1Movie") {
								var width = content.width;
								var height = content.height;
								var transparent = true;
								var bmpData:BitmapData = new BitmapData(width, height, transparent, 0);
								bmpData.draw(content);
								pictureCache.set(url, bmpData);
								cb(width, height);
							}
						}
					} catch (e : Dynamic) {
						// When running locally, security errors can be called when we access the content
						// of loaded files, so in that case, we have lost, and can not use nice smoothing
					}
				}
			);
			dis.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function (event : flash.events.IOErrorEvent) {
				trace("[ERROR] IO Error with " + url + ": " + event.text);
			});
			dis.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function (event : flash.events.SecurityErrorEvent) {
				trace("[ERROR] Security Error with " + url + ": " + event.text);						
			});
			loader.load(request);
		}
	}
	#end
}

class ActiveClips {
	// We are a singleton
	static private var instance : ActiveClips;
	static public function get() : ActiveClips {
		if (null == instance) {
			instance = new ActiveClips();
		}
		return instance;
	}
	private function new() {
		activeClips = [];
	}
	
	/// Get the topmost active clip under the mouse
	public function getActiveClip() : ArcticMovieClip {
		#if flash9
			var x = flash.Lib.current.mouseX;
			var y = flash.Lib.current.mouseY;
		#elseif flash
			var x = flash.Lib.current._xmouse;
			var y = flash.Lib.current._ymouse;
		#end
		// bottom-up traverse: from children to parent
		var i = activeClips.length - 1;
		while (i >= 0) {
			var clip = activeClips[i];
            
            if (!ArcticMC.isActive(clip)) {
                i--;
                continue;
            }
			#if flash9
				if (clip.hitTestPoint(x, y, false)) {
					return clip;
				}
			#elseif flash
				if (clip.hitTest(x, y, false) && ArcticMC.isActive(clip)) {
					return clip;
				}
			#end
			i--;
		}
		return null;
	}
	
	// remove clip and all its children from the activeClips	
	public function remove(mc: ArcticMovieClip): Bool {
		if (mc == null) {
			return false;
		}
		
		var contains = function (clip: ArcticMovieClip) {
			#if (flash9||neko)
				return mc == clip || mc.contains(clip);
			#elseif flash	
				return mc == clip || StringTools.startsWith(clip._target, mc._target + "/");
			#end
		}
		
		var i = 0;
		var del = false;
		while (i < activeClips.length) {
			if (contains(activeClips[i])) {
				activeClips.splice(i, 1);
				del = true;
			} else {
				i++;
			}
		}
		return del;
	}
	
	// add movie clip in smart way - according to its z-order
	public function add(mc: ArcticMovieClip) {
		if (mc == null) {
			return;
		}
		
		var i = findInsertIndex(mc);
		if (i != null) {
			activeClips.insert(i, mc);	
		}
	}
	
	private function findInsertIndex(mc: ArcticMovieClip): Null<Int> {
		#if flash9
		if (mc.stage == null) {
			// the display object is not added to the display list
			return null;
		}
		#end
		
		var start = 0;
		var end = activeClips.length - 1;
		while (start <= end) {
			var i = Math.floor((end + start) / 2);
			var res = compare(mc, activeClips[i]);
			if (res == 0) {
				// return i;
				// the array contains this clip already
				// should not happen
				return null;
			} 
			if (res > 0) {
				// this clip is higher
				start = i + 1;
			} else {
				end = i - 1;
			}
		}
		return start;
	}
	
	#if (flash9||neko)
	static private function buildPath(mc: ArcticMovieClip): Array<DisplayObjectContainer> {
		var path = new Array<DisplayObjectContainer>();
		var parent: DisplayObjectContainer = mc;
		while (parent != null) {
			path.unshift(parent);
			parent = parent.parent;
		}
		return path;
	}
	#end
	
	public static function compare(mc1: ArcticMovieClip, mc2: ArcticMovieClip): Int {
		if (mc1 == mc2) {
			return 0;
		}
	#if (flash9||neko)
		var path1 = buildPath(mc1);
		var path2 = buildPath(mc2);
	#elseif flash	
		var path1 = mc1._target.split("/");
		var path2 = mc2._target.split("/");
	#end
		// find the Least Common Ancestor (it can be root)
		var length = Std.int(Math.min(path1.length, path2.length));
		var diffIndex = 0;
		while (diffIndex < length && path1[diffIndex] == path2[diffIndex]) {
			diffIndex++;
		}
		if (diffIndex == length || diffIndex == 0) {
			// one clip is a parent of another
			return path1.length < path2.length ? -1 : 1;
		}
	#if (flash9||neko)
		var lca = path1[diffIndex - 1];
		var childNo1 = lca.getChildIndex(path1[diffIndex]);
		var childNo2 = lca.getChildIndex(path2[diffIndex]);
	#elseif flash
		// we use ["c" + childNo] notation
		// (should be faster than evaluating depth of the 'fork')
		var childNo1 = Std.parseInt(path1[diffIndex].substr(1));
		var childNo2 = Std.parseInt(path2[diffIndex].substr(1));
	#end
		return childNo1 < childNo2 ? -1 : 1;
	}

	// Here, we record all MovieClips that compete for mouse drags
	public var activeClips : Array<ArcticMovieClip>;
}
