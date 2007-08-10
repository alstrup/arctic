package arctic;

import arctic.ArcticMC;
import arctic.ArcticBlock;

class Scrollbar {
	/**
	 * Draw a vertical scrollbar in parent MovieClip such that clip is the content that the scrollbar
	 * controls. availableWidth & availableHeight is the amount of space the content area
	 * is, and realHeight is how high the total clip is. ensureYVisible is the top position we
	 * should show.
	 */
    public static function drawScrollBar(parent : ArcticMovieClip, clip : ArcticMovieClip, availableWidth : Float,
                                                         availableHeight : Float, realHeight : Float, ensureYVisible : Float) {

		var scrollbarWidth = 17;
															 
		 if (Reflect.hasField(parent, "scrollbar")) {
			// Reuse is for wimps: We just nuke the old one and recreate
			var scrollView : ArcticView = Reflect.field(parent, "scrollbar");
			scrollView.destroy();
		}
		// trace("Scrollbar at " + availableWidth + " with height " + availableHeight + " out of " + realHeight + " viewing " + ensureYVisible);

		var currentY = ensureYVisible;

		var update = function() {
			currentY = Math.min(currentY, realHeight - availableHeight);
			currentY = Math.max(0, currentY);
			ArcticMC.setScrollRect( clip, new ArcticRectangle( 0, currentY, availableWidth, availableHeight ) );
		}
		
		var onScroll = function(x, y) {
			currentY = y;
			update();
		};
		
		var onUp = function() {
			currentY -= 10;
			update();
			// TODO: Move slider handle
		}
		
		var onDown = function() {
			currentY += 10;
			update();
			// TODO: Move slider handle
		}

		
		var buttonHeight = scrollbarWidth - 4;
		var sliderHeight = availableHeight - 2 * scrollbarWidth + 3;
		var handleSize = Math.max(buttonHeight, sliderHeight * (availableHeight / realHeight));
		
		var makeButton = function(block, fn) : ArcticBlock {
			return Button(
						Filter(
							Bevel(1, 45, 0xcad8f9, 100, 0x7da0d4, 100, 2, 2, 1, 1, "inner", false),
							GradientBackground("linear", [0xe1eafe, 0xb9cbf3], 0, 0, block, null, 3, Math.PI / 2)
						),
						Filter(
							Bevel(1, 45, 0x97aee0, 100, 0x7da0d4, 100, 2, 2, 1, 1, "inner", false),
							GradientBackground("linear", [0xe5f6ff, 0xb9dafb], 0, 0, block, null, 3, Math.PI / 2)
						),
						fn
					);
		}
		
		var slider;
		if (availableHeight > 3 * buttonHeight + 10) {
			var handleBlock =
				Filter(
					Bevel(1, 45, 0xe6eefc, 100, 0xb0c4f2, 100, 2, 2, 1, 1, "inner", false),
					GradientBackground("linear", [0xc8d6fb, 0xb9cbf3], 0, 0, 
						Offset(3, 0,
							LineStack([
								Fixed(buttonHeight, handleSize / 2 - 3), 
								Background(0xeef4fe, Fixed(buttonHeight - 6, 1)),
								Background(0x8cb0f8, Fixed(buttonHeight - 6, 1)),
								Background(0xeef4fe, Fixed(buttonHeight - 6, 1)),
								Background(0x8cb0f8, Fixed(buttonHeight - 6, 1)),
								Background(0xeef4fe, Fixed(buttonHeight - 6, 1)),
								Background(0x8cb0f8, Fixed(buttonHeight - 6, 1)),
								Fixed(buttonHeight, handleSize / 2 - 3)
							])
						),
						null, 3, Math.PI / 2)
				);
			slider = ConstrainHeight(sliderHeight, sliderHeight,
						OnTop(
							ColumnStack([ 
								Background(0x000000, Fixed(availableWidth + 2, sliderHeight), 0),
								GradientBackground("linear", [0xfefefb, 0xf3f1ec], 0, 0, 
									Fixed(buttonHeight, sliderHeight),
									null, null, 0)
							]), 
							Arctic.makeSlider(0, 0, 0, realHeight - availableHeight, 
								ColumnStack([ Background(0x000000, Fixed(availableWidth + 2, handleSize),0), handleBlock ] ), 
								onScroll, null, ensureYVisible)
						)
					);
		} else {
			// No slider
			slider = Fixed(0, sliderHeight);
		}
		;

		var scrollbar = 
			OnTop(
				Offset(availableWidth, 0, 
					Frame(
						Frame(
							LineStack( [
								makeButton(Fixed(buttonHeight, buttonHeight), onUp),
								Fixed(0, sliderHeight),
								makeButton(Fixed(buttonHeight, buttonHeight), onDown)
							] ), 1, 0xffffff
						), 1, 0xeeede5
					)
				),
				Offset(0, buttonHeight + 2, slider)
			)
			;

		update();

		var view = new ArcticView(scrollbar, parent);
		view.adjustToFit(0, 0);
		var mc = view.display(false);
		Reflect.setField(parent, "scrollbar", view);
		return;
	}

	static public function removeScrollbar(parent : ArcticMovieClip, clip : ArcticMovieClip) {
		if (Reflect.hasField(parent, "scrollbar")) {
			var scrollView : ArcticView = Reflect.field(parent, "scrollbar");
			scrollView.destroy();
			Reflect.deleteField(parent, "scrollbar");
			ArcticMC.setScrollRect(clip, null);
		}
	}
}
