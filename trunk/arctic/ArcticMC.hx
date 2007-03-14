package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.geom.Rectangle;
#else flash
import flash.geom.Rectangle;
import flash.Mouse;
#end

/**
 * A class which makes it simpler to make Flash 8 / 9 compatible code.
 */
class ArcticMC {
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

	static public function remove(m : ArcticMovieClip) {
	#if flash9
		m.parent.removeChild(m);
	#else flash
		m.removeMovieClip();
	#end
	}
	
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

	static public function getGraphics(m : ArcticMovieClip) {
		#if flash9
			return m.graphics;
		#else flash
			return m;
		#end
	}
	
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
	
	/// Converts an alpha from 0 to 100 to the correct range depending on the flash target
	static public function getAlpha(a : Float) : Float {
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
	
	/// Returns true when the clip is visible and enabled
	static public function isActive(clip: ArcticMovieClip) : Bool {
		if (clip == null) return false;
		
		// TODO: This could integrate with DialogManager later to check if we should respond or not
		
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
