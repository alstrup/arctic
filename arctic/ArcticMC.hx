package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.geom.Rectangle;
import flash.geom.Point;
typedef ArcticRectangle = Rectangle
typedef ArcticPoint = Point
typedef ArcticTextField = flash.text.TextField
typedef ArcticTextFormat = flash.text.TextFormat
typedef ArcticDisplayObjectContainer = flash.display.DisplayObjectContainer
typedef ArcticSprite = flash.display.Sprite
#elseif flash8
import flash.geom.Rectangle;
import flash.geom.Point;
typedef ArcticRectangle = Rectangle<Float>
typedef ArcticPoint = Point<Float>
typedef ArcticTextField = flash.TextField
typedef ArcticTextFormat = flash.TextFormat
typedef ArcticDisplayObjectContainer = ArcticMovieClip
typedef ArcticSprite = ArcticMovieClip
import flash.Mouse;

#elseif flash7

class ArcticRectangle {
	public function new(left0 : Float, top0 : Float, width0 : Float, height0 : Float) {
		left = left0;
		top = top0;
		width = width0;
		height = height0;
	}
	public function intersects(r : ArcticRectangle) : Bool {
		var rangeOverlap = function (a1 : Float, a2 : Float, b1 : Float, b2 : Float) : Bool {
			if (a2 < b1) return false;
			if (a1 > b2) return false;
			return true;
		}
		// Rectangles intersect if both X and Y ranges overlap
		return rangeOverlap(left, left + width, r.left, r.left + r.width)
			&& rangeOverlap(top, top + height, r.top, r.top + r.height);
	}
	public function containsPoint(p : ArcticPoint) : Bool {
		var pointIn = function (a1 : Float, a2 : Float, p : Float) : Bool {
			if (a1 < p) return false;
			if (a2 > p) return false;
			return true;
		}
		return pointIn(left, left + width, p.x) && pointIn(top, top + height, p.y);
	}
	public var left : Float;
	public var top : Float;
	public var width : Float;
	public var height : Float;
	
	public var right(getRight, setRight): Float;
	public var bottom(getBottom, setBottom): Float;
	
	function getRight(): Float {
		return left + width;
	}
	
	function setRight(v: Float): Float {
		width = v - left;
		return getRight();
	}
	
	function getBottom(): Float {
		return top + height;
	}
	
	function setBottom(v: Float): Float {
		height = v - top;
		return getBottom();
	}
}

class ArcticPoint {
	public function new(x0 : Float, y0 : Float) {
		x = x0;
		y = y0;
	}
	static public function distance(p1 : ArcticPoint, p2 : ArcticPoint) : Float {
		return Math.sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y));
	}
	public var x : Float;
	public var y : Float;
}

typedef ArcticTextField = flash.TextField
typedef ArcticTextFormat = flash.TextFormat
typedef ArcticDisplayObjectContainer = ArcticMovieClip
typedef ArcticSprite = ArcticMovieClip

import flash.Mouse;

#elseif neko

import neash.geom.Rectangle;
import neash.geom.Point;
typedef ArcticRectangle = Rectangle
typedef ArcticPoint = Point
typedef ArcticTextField = neash.text.TextField
typedef ArcticTextFormat = neash.text.TextFormat
typedef ArcticDisplayObjectContainer = neash.display.DisplayObjectContainer
typedef ArcticSprite = neash.display.Sprite;
#end

/**
 * A class which makes it simpler to make Flash 8 / 9 compatible code.
 */
class ArcticMC {
	// counter to assign unique names to mc's
	private static var name_counter = 0;
	// hash to keep custom properties for sprites in f9
	private static var hash = new Hash<Hash<Dynamic>>();

	static public function getCurrentClip() : ArcticMovieClip {
		#if flash
		return flash.Lib.current;
		#elseif neko
		return neash.Lib.current;
		#end
	}
	
	/// Create a new clip on the given parent
	static public function create(parent : ArcticDisplayObjectContainer) : ArcticMovieClip {
		#if (flash9 || neko)
			var clip = new ArcticMovieClip();
			parent.addChild(clip);
			return clip;
		#elseif flash6
			var d = ArcticMC.getNextHighestDepth(parent);
			parent.createEmptyMovieClip("c" + d, d);
			return Reflect.field(parent, "c" + d);
		#elseif flash7
			var d = parent.getNextHighestDepth();
			return parent.createEmptyMovieClip("c" + d, d);
		#elseif flash8
			var d = parent.getNextHighestDepth();
			return parent.createEmptyMovieClip("c" + d, d);
		#end
	}

	/// Remove this clip from it's parent
	static public function remove(m : ArcticMovieClip) {
	#if (flash9 || neko)
		// We have to remove any properties on this clip, to prevent leaks
		removeProperties(m);
		m.parent.removeChild(m);
	#elseif flash
		m.removeMovieClip();
	#end
	}
	
	#if (flash9 || neko)
	static public function removeProperties(m : flash.display.DisplayObjectContainer) {
		hash.remove(m.name);
		for (i in 0...m.numChildren) {
			var obj = m.getChildAt(i);
			if (Std.is(obj, ArcticMovieClip)){
				var mc : ArcticMovieClip= cast(obj, ArcticMovieClip);
				removeProperties(mc);
			}
		}
	}
	#end

	/// Get position of the clip
	static public function getXY(m : ArcticMovieClip) : { x : Float, y : Float } {
		#if (flash9 || neko)
			return { x: m.x, y: m.y };
		#elseif flash
			return { x: m._x, y: m._y };
		#end
	}

	/**
	 * Set the position of the clip. x and/or y can be null, in which case
	 * that position is not changed.
	 */
	static public function setXY(m : ArcticMovieClip, x : Null<Float>, y : Null<Float>) {
		if (x != null) {
			#if (flash9 || neko)
				m.x = x;
			#elseif flash
				m._x = x;
			#end
		}
		if (y != null) {
			#if (flash9 || neko)
				m.y = y;
			#elseif flash
				m._y = y;
			#end
		}
	}
	
	/// Get scaling of clip in X and Y directions. Original size (no scaling) is 1.
	static public function getScaleXY(m : ArcticMovieClip) : { x : Float, y : Float } {
		#if (flash9 || neko)
			return { x: m.scaleX, y: m.scaleY };
		#elseif flash
			return { x: m._xscale / 100.0, y: m._yscale / 100.0 };
		#end
	}

	/**
	 * Set the scaling of the clip. scaleX and/or scaleY can be null, in which case
	 * that scaling is not changed. Original size is 1.
	 */
	static public function setScaleXY(m : ArcticMovieClip, x : Null<Float>, y : Null<Float>) {
		if (x != null) {
			#if (flash9 || neko)
				m.scaleX = x;
			#elseif flash
				m._xscale = x * 100.0;
			#end
		}
		if (y != null) {
			#if (flash9 || neko)
				m.scaleY = y;
			#elseif flash
				m._yscale = y * 100.0;
			#end
		}
	}

	/**
	 * Test whether the point is in the given clip. Notice! Pixels with an alpha
	 * channel of 0 are hit! Only exception is vector-based graphics where it
	 * correctly detects misses.
	 */
	static public function hitTest(m : ArcticMovieClip, x : Float, y : Float) {
		#if (flash9 || neko)
			return m.hitTestPoint(x, y, true);
		#elseif flash
			return m.hitTest(x, y, true);
		#end
	}

	/**
	 * Get the object on which graphics should be drawn.
	 * I.e. clear(), moveTo(x,y), lineTo(x,y) and so on are
	 * done on this object.
	 */
	static public function getGraphics(m : ArcticSprite) {
		#if (flash9 || neko)
			return m.graphics;
		#elseif flash
			return m;
		#end
	}
	
	static public function getVisible(m : ArcticMovieClip) : Bool {
		#if (flash9 || neko)
			return m.visible;
		#elseif flash
			return m._visible;
		#end
	}

	/**
	 * Changes visiblity of a clip.
	 */
	static public function setVisible(m : ArcticMovieClip, v : Bool) {
		if (m == null) return;
		#if (flash9 || neko)
			if (m.visible != v) {
				m.visible = v;
			}
		#elseif flash
			if (m._visible != v) {
				m._visible = v;
			}
		#end
	}

	static public function isEnabled(m : ArcticMovieClip) : Bool {
		#if (flash9 || neko)
			return m.mouseEnabled;
		#elseif flash
			return m.enabled;
		#end
	}

	static public function setEnabled(m : ArcticMovieClip, v : Bool) {
		#if (flash9 || neko)
			if (m.mouseEnabled != v) {
				m.mouseEnabled = v;
			}
		#elseif flash
			if (m.enabled != v) {
				m.enabled = v;
			}
		#end
	}
	
	/// Gets the alpha value of a clip, between 0 and 100
	static public function getAlpha(m : ArcticMovieClip) : Float {
		#if (flash9 || neko)
			return m.alpha * 100.0;
		#elseif flash
			return m._alpha;
		#end
	}

	/// Sets the alpha value of a clip to a value between 0 and 100
	static public function setAlpha(m : ArcticMovieClip, alpha : Float) {
		#if (flash9 || neko)
			m.alpha = convertAlpha(alpha);
		#elseif flash
			m._alpha = convertAlpha(alpha);
		#end
	}
	
	/// Converts an alpha value from 0 to 100 range to the correct range depending on the flash target
	static public function convertAlpha(a : Null<Float>) : Float {
		#if (flash9 || neko)
			if (a == null) 
				return 1.0;
			return a / 100.0;
		#elseif flash
			if (a == null)
				return 100.0;
			return a;
		#end
	}

	/**
	 * A helper function which forces a movieclip to have at least a certain size.
	 * Notice, that this will never shrink a movieclip. Use clipSize for that.
	 * Notice also that it clears out any graphics that might exist in the clip.
	 * Also notice that this is an expensive thing to do!
	 */
	static public function setSize(clip : ArcticMovieClip, width : Float, height : Float) {
		if (clip == null) {
			return;
		}
		#if (flash9 || neko)
			// Set the size
			clip.graphics.clear();
			clip.graphics.moveTo(0,0);
			clip.graphics.lineTo(width, height);
		#elseif flash
			// Set the size
			clip.clear();
			clip.moveTo(0,0);
			clip.lineTo(width, height);
		#end
	}
	
	/// Will force a MovieClip to have a certain size - by clipping or enlarging
	static public function clipSize(clip : ArcticMovieClip, width : Float, height : Float) {
		setSize(clip, width, height);
		var size = getSize(clip);
		if (size.width > width || size.height > height) {
			// We need to make it smaller - do a scrollRect
			ArcticMC.setScrollRect(clip, new ArcticRectangle(0.0, 0.0, width, height));
			return;
		}
	}

	/// Get the size of a MovieClip, respecting clipping
	static public function getSize(clip : ArcticMovieClip) : { width : Float, height : Float } {
		if (clip == null) {
			return { width : 0.0, height : 0.0 };
		}
		var scrollRect = ArcticMC.getScrollRect(clip);
		if (scrollRect != null) {
			return { width : scrollRect.width, height : scrollRect.height };
		}
		#if (flash9 || neko)
			return { width: clip.width, height : clip.height };
		#elseif flash
			return { width: clip._width, height : clip._height };
		#end
	}
	
	static public function setScrollRect(clip : ArcticMovieClip, rect : ArcticRectangle) {
		#if flash6
		// TODO: Use setMask
		#elseif flash7
		Reflect.setField(clip, "scrollRect", rect);
		var maskClip = Reflect.field(clip, "scrollMask");
		if (rect == null) {
			if (maskClip == null) {
				return;
			}
			remove(maskClip);
			Reflect.setField(clip, "scrollMask", null);
			return;
		}
		if (maskClip == null) {
			maskClip = create(clip);
			Reflect.setField(clip, "scrollMask", maskClip);
		}
		var g = ArcticMC.getGraphics(maskClip);
		g.clear();
		g.beginFill(0xffffff);
		DrawUtils.drawRect(maskClip, rect.left, rect.top, rect.width, rect.height);
		g.endFill();
		clip.setMask(maskClip);
		ArcticMC.setXY(clip, -rect.left, -rect.top);
		
		#elseif flash8
		clip.scrollRect = rect;
		#elseif (flash9 || neko)
		clip.scrollRect = rect;
		#end
	}
	
	static public function getScrollRect(clip : ArcticMovieClip) : ArcticRectangle {
		#if flash6
		// TODO: Scrollrect for Flash 6
		return null;
		#elseif flash7
		return Reflect.field(clip, "scrollRect");
		#elseif flash8
		return clip.scrollRect;
		#elseif (flash9 || neko)
		return clip.scrollRect;
		#end
	}
	
	/// A helper function which sets the size of the clip to the size of the stage
	static public function stageSize(clip : ArcticMovieClip) {
		#if (flash9 || neko)
			setSize(clip, clip.stage.stageWidth, clip.stage.stageHeight);
		#elseif flash
			setSize(clip, flash.Stage.width, flash.Stage.height);
		#end
	}
	
	/// How big is the stage? I.e. the Flash movie in itself. Pass any visible movieclip
	static public function getStageSize(clip : ArcticMovieClip) : { width : Float, height : Float } {
		#if (flash9 || neko)
			return { width: cast(clip.stage.stageWidth, Float), height: cast(clip.stage.stageHeight, Float) };
		#elseif flash
			return { width: flash.Stage.width, height: flash.Stage.height };
		#end
	}

	/// Move a movieclip
	static public function moveClip(clip : ArcticMovieClip, dx : Float, dy : Float) {
		#if (flash9 || neko)
			clip.x += dx;
			clip.y += dy;
		#elseif flash
			clip._x += dx;
			clip._y += dy;
		#end
	}
	
	/**
	 * Get the mouse position in coordinates of the passing movieclip. If
	 * none are passed, stage position is returned.
	 */
	static public function getMouseXY(?m : ArcticMovieClip) : { x: Float, y : Float } {
		#if flash
			#if flash9
				if (null != m) {
					return { x: m.mouseX, y: m.mouseY };
				} else {
					var stage = flash.Lib.current.stage;
					return { x: stage.mouseX, y: stage.mouseY };
				}
			#elseif flash
				if (m == null) {
					m = flash.Lib.current;
				}

				return { x: m._xmouse, y: m._ymouse };
			#end
		#elseif neko
			if (m == null) {
				m = neash.Lib.current;
			}
			return { x: m.mouseX, y: m.mouseY };
		#end
	}
	
	/// Turn the normal cursor on or off
	static public function showMouse(?show : Bool) {
		#if flash9
			if (show == null || show) {
				flash.ui.Mouse.show();
			} else {
				flash.ui.Mouse.hide();
			}
		#elseif flash
			if (show == null || show) {
				flash.Mouse.show();
			} else {
				flash.Mouse.hide();
			}
		#end
	}
	
	/// Returns true when the clip is visible and enabled (also considering parents)
	static public function isActive(clip: ArcticMovieClip) : Bool {
		if (clip == null) return false;
		
		// TODO: This could integrate with a DialogManager later to check if we should respond or not
		
		var active = true;
		#if flash9
			active = clip.visible && clip.mouseEnabled;
			var parent = clip.parent;
			while (null != parent && active) {
				active = active && parent.visible && parent.mouseEnabled;
				parent = parent.parent;
			}
		#elseif flash
			var parent = clip;
			while (null != parent && active) {
				active = active && parent._visible && parent.enabled;
				var scrollRect = getScrollRect(parent);
				if (parent != clip && scrollRect != null) {
					var bounds = clip.getBounds(parent);
					var xOffset = (bounds.xMax - bounds.xMin) * 0.25; // 25% of the clip width
					var yOffset = (bounds.yMax - bounds.yMin) * 0.25; // 25% of the clip height
					if (bounds.xMin + xOffset < scrollRect.left || bounds.yMin + yOffset < scrollRect.top || 
						bounds.xMax - xOffset > scrollRect.right || bounds.yMax - yOffset > scrollRect.bottom) {
						// more than 25% of the clip is invisible (because of scrolling)
						active = false;
					}
				}
				parent = parent._parent;
			}
		#end
		
		return active;
	}
	
	static public function setBitmapCache(mc : ArcticMovieClip, cacheAsBitmap : Bool) {
		#if flash8
		mc.cacheAsBitmap = cacheAsBitmap;
		#elseif flash9
		mc.cacheAsBitmap = cacheAsBitmap;
		#end
	}
	
	static public function createTextField(parent : ArcticMovieClip, x : Float, y : Float, width : Float, height : Float) : ArcticTextField {
		#if flash6
		var d = ArcticMC.getNextHighestDepth(parent);
		parent.createTextField("tf" + d, d, x, y, width, height);
		return Reflect.field(parent, "tf" + d);
		#elseif flash7
		var d = parent.getNextHighestDepth();
		parent.createTextField("tf" + d, d, x, y, width, height);
		return Reflect.field(parent, "tf" + d);
		#elseif flash8
		var d = parent.getNextHighestDepth();
		return parent.createTextField("tf" + d, d, x, y, width, height);
		#elseif (flash9 || neko)
		var tf = new ArcticTextField();
		tf.x = x;
		tf.y = y;
		tf.width = width;
		tf.height = height;
		parent.addChild(tf);
		return tf;
		#end
	}

	/// Set the text rendering quality. If sharpness is null, normal rendering is used. gridFit parameter: 0 is none, 1 is pixel, 2 is subpixel
	static public function setTextRenderingQuality(tf : ArcticTextField, sharpness : Null<Float>, ?gridFit : Int) {
		#if flash8
		if (sharpness != null) {
			tf.sharpness = sharpness;
			tf.antiAliasType = "advanced";
			tf.gridFitType = if (gridFit == 1) { "pixel"; } else if (gridFit == 2) { "subpixel"; } else { "none"; };
		} else {
			tf.antiAliasType = "normal";
		}
		#elseif flash9
		if (sharpness != null) {
			tf.sharpness = sharpness;
			tf.antiAliasType = flash.text.AntiAliasType.ADVANCED;
			tf.gridFitType = if (gridFit == 1) { flash.text.GridFitType.PIXEL; } 
							else if (gridFit == 2) { flash.text.GridFitType.SUBPIXEL; } else { flash.text.GridFitType.NONE; };
		}
		#end
	}

	#if flash9
	#elseif flash
	static public function getNextHighestDepth(clip : ArcticDisplayObjectContainer) : Int {
		#if flash6
			var depth = 0;
			for (f in Reflect.fields(clip)) {
				var field = Reflect.field(clip, f);
				if (Reflect.hasField(field, "getDepth")) {
					var newDepth = Reflect.callMethod(field, "getDepth", null);
					if (newDepth > depth) {
						depth = newDepth;
					}
				}
			}
			return depth+1;
		#elseif flash
			return clip.getNextHighestDepth();
		#end
	}
	#end
	
	static public function getTextFieldWidth(field: ArcticTextField): Float {
		#if (flash9 || neko)
		return field.width;
		#elseif flash
		return field._width;
		#end
	}
	
	static public function getTextFieldHeight(field: ArcticTextField): Float {
		#if (flash9 || neko)
		return field.height;
		#elseif flash
		return field._height;
		#end
	}
	
	static public function setDefaultTextFormat(tf : ArcticTextField, textFormat: ArcticTextFormat) {
		#if (flash9 || neko)
		return tf.defaultTextFormat = textFormat;
		#elseif flash
		return tf.setNewTextFormat(textFormat);
		#end
	}
	
	static public function setTextFieldSize(tf : ArcticTextField, width: Null<Float>, height: Null<Float>) {
		if (width != null) {
			#if (flash9 || neko)
				tf.width = width;
			#elseif flash
				tf._width = width;
			#end
		}
		if (height != null) {
			#if (flash9 || neko)
				tf.height = height;
			#elseif flash
				tf._height = height;
			#end
		}
	}
	
	static public function getParent(mc : ArcticMovieClip): ArcticDisplayObjectContainer {
		#if (flash9 || neko)
		return mc.parent;
		#elseif flash
		return mc._parent;
		#end
	}
	
	static public function bringToFront(mc : ArcticMovieClip) {
		#if flash9
		return mc.parent.setChildIndex(mc, mc.parent.numChildren - 1);
		#elseif flash
		return mc.swapDepths(getNextHighestDepth(mc._parent) - 1);
		#end
	}

	static private function getNextName(): String {
		return "_arctic_mc_" + (name_counter++);
	}

	#if flash9
	static private inline function ensureNamedClip(mc: ArcticMovieClip) {
		if (StringUtils.emptyString(mc.name)) {
			mc.name = getNextName();
		}
	}

	static private inline function getOrCreateProps(mc: ArcticMovieClip): Hash<Dynamic> {
		var h = hash.get(mc.name);
		if (null == h) {
			h = new Hash<Dynamic>();
			hash.set(mc.name, h);
		} 

		return h;
	}

	static private inline function getProps(mc: ArcticMovieClip): Hash<Dynamic> {
		return StringUtils.emptyString(mc.name) ? null : hash.get(mc.name);
	}
	#end

	static public inline function set(mc: ArcticMovieClip, name: String, value: Dynamic) {
		#if flash9
		ensureNamedClip(mc);
		var props = getOrCreateProps(mc);
		props.set(name, value);
		#else
		Reflect.setField(mc, name, value);
		#end
	}

	static public inline function get(mc: ArcticMovieClip, name: String): Dynamic {
		#if flash9
		var props = getProps(mc);
		return null != props ? props.get(name) : null;
		#else
		return Reflect.field(mc, name);
		#end
	}

	static public inline function has(mc: ArcticMovieClip, name: String): Bool {
		#if flash9
		var props = getProps(mc);
		return null != props && props.exists(name);
		#else
		return Reflect.hasField(mc, name);
		#end
	}

	static public inline function delete(mc: ArcticMovieClip, name: String) {
		#if flash9
		var props = getProps(mc);
		if (null != props) {
			props.remove(name);
		}
		#else
		Reflect.deleteField(mc, name);
		#end
	}
}
