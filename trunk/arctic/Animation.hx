package arctic;

import arctic.ArcticBlock;

class Animation {
	/// Makes this block appear - by default it takes 1 second, and it fades alpha up
	static public function appear(block : ArcticBlock, ?time : Float, ?animation : Array<AnimateComponent>) {
		if (time == null) {
			time = 1.0;
		}
		if (animation == null) {
			animation = [ Alpha( line(0.0, 1.0) ) ];
		}
		var animator = new Animator( block );
		// We use a trick to know when the block is displayed: Use a CustomBlock for this
		var build = function(data : Int, mode : BuildMode, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) {
			if (mode == Create) {
				animator.animate(time, animation );
			}
			return { clip: parentMc, width: 0.0, height: 0.0, growHeight : false, growWidth : false };
		}
		return OnTop(Animate(animator), CustomBlock(null, build));
	}
	
	/// Make this block appear by growing from a point
	static public function grow(block : ArcticBlock, centerX : Float, centerY : Float, ?time : Float) {
		return appear(block, time, [ ScaleX(line(0.0, 1.0)), ScaleY(line(0.0, 1.0)), X(line(centerX, 0)), Y(line(centerY, 0))]);
	}
	
	/// Makes this block disappear - by default it takes 1 second, and it fades alpha down
	static public function disappear(block : ArcticBlock, ?time : Float) {
		return appear(block, time, [ Alpha( line(1.0, 0.0) ) ] );
	}
	
	/// A function for the animator that goes linearly
	static public function line(from : Float, to : Float) {
		var d = to - from;
		return function(t : Float) { return from + t * d; };
	}
}
