package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.geom.Rectangle;
typedef ArcticRectangle = Rectangle

#else flash
import flash.geom.Rectangle;

typedef ArcticRectangle = Rectangle<Float>

import flash.Mouse;
#end



/**
 * A class which makes it simpler to make Flash 8 / 9 compatible code.
 */
class ArcticMC {
	/// Create a new clip on the given parent
	static public function create(parent : ArcticMovieClip) : ArcticMovieClip {
		#if flash9
			var clip = new ArcticMovieClip();
			parent.addChild(clip);
			return clip;
		#else flash
			var d = parent.getNextHighestDepth();
			return parent.createEmptyMovieClip("c" + d, d);
		#end
	}

	/// Remove this clip from it's parent
	static public function remove(m : ArcticMovieClip) {
	#if flash9
		m.parent.removeChild(m);
	#else flash
		m.removeMovieClip();
	#end
	}

	/**
	 * Set the position of the clip. x and/or y can be null, in which case
	 * that position is not changed.
	 */
	static public function setXY(m : ArcticMovieClip, x : Float, y : Float) {
		if (x != null) {
			#if flash9
				m.x = x;
			#else flash
				m._x = x;
			#end
		}
		if (y != null) {
			#if flash9
				m.y = y;
			#else flash
				m._y = y;
			#end
		}
	}
	
	/// Get scaling of clip in X and Y directions. Original size (no scaling) is 1.
	static public function getScaleXY(m : ArcticMovieClip) : { x : Float, y : Float } {
		#if flash9
			return { x: m.scaleX, y: m.scaleY };
		#else flash
			return { x: m._xscale / 100.0, y: m._yscale / 100.0 };
		#end
	}

	/**
	 * Set the scaling of the clip. scaleX and/or scaleY can be null, in which case
	 * that scaling is not changed. Original size is 1.
	 */
	static public function setScaleXY(m : ArcticMovieClip, x : Float, y : Float) {
		if (x != null) {
			#if flash9
				m.scaleX = x;
			#else flash
				m._xscale = x * 100.0;
			#end
		}
		if (y != null) {
			#if flash9
				m.scaleY = y;
			#else flash
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
		#if flash9
			return m.hitTestPoint(x, y, true);
		#else flash
			return m.hitTest(x, y, true);
		#end
	}

	/**
	 * Get the object on which graphics should be drawn.
	 * I.e. clear(), moveTo(x,y), lineTo(x,y) and so on are
	 * done on this object.
	 */
	static public function getGraphics(m : ArcticMovieClip) {
		#if flash9
			return m.graphics;
		#else flash
			return m;
		#end
	}
	
	static public function getVisible(m : ArcticMovieClip) : Bool {
		#if flash9
			return m.visible;
		#else flash
			return m._visible;
		#end
	}

	/**
	 * Changes visiblity of a clip.
	 */
	static public function setVisible(m : ArcticMovieClip, v : Bool) {
		#if flash9
			if (m.visible != v) {
				m.visible = v;
			}
		#else flash
			if (m._visible != v) {
				m._visible = v;
			}
		#end
	}
	
	/// Sets the alpha value of a clip to a value between 0 and 100
	static public function setAlpha(m : ArcticMovieClip, alpha : Float) {
		#if flash9
			m.alpha = convertAlpha(alpha);
		#else flash
			m._alpha = convertAlpha(alpha);
		#end
	}
	
	/// Converts an alpha value from 0 to 100 range to the correct range depending on the flash target
	static public function convertAlpha(a : Float) : Float {
		#if flash9
			if (a == null) 
				return 1.0;
			return a / 100.0;
		#else flash
			if (a == null)
				return 100.0;
			return a;
		#end
	}

	/**
	 * A helper function which forces a movieclip to have at least a certain size.
	 * Notice, that this will never shrink a movieclip. Use clipSize for that.
	 * Notice also that it clears out any graphics that might exist in the clip.
	 */
	static public function setSize(clip : ArcticMovieClip, width : Float, height : Float) {
		if (clip == null) {
			return;
		}
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
	
	/// Will force a MovieClip to have a certain size - by clipping or enlarging
	static public function clipSize(clip : ArcticMovieClip, width : Float, height : Float) {
		setSize(clip, width, height);
		#if flash9
			if (clip.width > width || clip.height > height) {
				// We need to make it smaller - do a scrollRect
				clip.scrollRect = new Rectangle(0.0, 0.0, width, height);
				return;
			}
		#else flash
			if (clip._width > width || clip._height > height) {
				// We need to make it smaller - do a scrollRect
				clip.scrollRect = new Rectangle<Float>(0.0, 0.0, width, height);
				return;
			}
		#end
	}

	/// Get the size of a MovieClip, respecting clipping
	static public function getSize(clip : ArcticMovieClip) : { width : Float, height : Float } {
		if (clip == null) {
			return { width : 0.0, height : 0.0 };
		}
		if (clip.scrollRect != null) {
			return { width : clip.scrollRect.width, height : clip.scrollRect.height };
		}
		#if flash9
			return { width: clip.width, height : clip.height };
		#else flash
			return { width: clip._width, height : clip._height };
		#end
	}
	
	/// A helper function which sets the size of the clip to the size of the stage
	static public function stageSize(clip : ArcticMovieClip) {
		#if flash9
			setSize(clip, clip.stage.stageWidth, clip.stage.stageHeight);
		#else flash
			setSize(clip, flash.Stage.width, flash.Stage.height);
		#end
	}
	
	/// How big is the stage? I.e. the Flash movie in itself. Pass any visible movieclip
	static public function getStageSize(clip : ArcticMovieClip) : { width : Float, height : Float } {
		#if flash9
			return { width: cast(clip.stage.stageWidth, Float), height: cast(clip.stage.stageHeight, Float) };
		#else flash
			return { width: flash.Stage.width, height: flash.Stage.height };
		#end
	}

	/// Move a movieclip
	static public function moveClip(clip : ArcticMovieClip, dx : Float, dy : Float) {
		#if flash9
			clip.x += dx;
			clip.y += dy;
		#else flash
			clip._x += dx;
			clip._y += dy;
		#end
	}
	
	/**
	 * Get the mouse position in coordinates of the passing movieclip. If
	 * none are passed, stage position is returned.
	 */
	static public function getMouseXY(?m : ArcticMovieClip) : { x: Float, y : Float } {
		if (m == null) {
			m = flash.Lib.current;
		}
		#if flash9
			return { x: m.mouseX, y: m.mouseY };
		#else flash
			return { x: m._xmouse, y: m._ymouse };
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
		#else flash
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
			active = clip.visible && clip.enabled;
			var parent = clip.parent;
			while (null != parent && active) {
				active = active && parent.visible && parent.mouseEnabled;
				parent = parent.parent;
			}	
		#else flash
			var parent = clip;
			while (null != parent && active) {
				active = active && parent._visible && parent.enabled;
				parent = parent._parent;
			}
		#end
		
		return active;
	}
}
