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
		var scrollbarWidth = 17; // How wide the scrollbar is
		var buttonMovement = 15; // How many pixels we move when a scrollbar button is clicked

		var currentY = ensureYVisible;
		if (Reflect.hasField(parent, "scrollbar")) {
			// Reuse is for wimps: We just nuke the old one and recreate
			
			// TODO: We should capture the current value of the old scrollbar, and use that as currentY scaled to new coordinate system
			
			var scrollView : ArcticView = Reflect.field(parent, "scrollbar");
			scrollView.destroy();
		}

		// This updates the scroll-rect to show what we need
		var update = function() {
			currentY = Math.min(currentY, realHeight - availableHeight);
			currentY = Math.max(0, currentY);
			ArcticMC.setScrollRect( clip, new ArcticRectangle( 0, currentY, availableWidth, availableHeight ) );
		}

		// Called by the slider when handle is dragged
		var onScroll = function(x, y) {
			currentY = y;
			update();
		};

		var slider : { block : ArcticBlock, setPositionFn : Float -> Float -> Void };
		// Called when up is clicked
		var onUp = function() {
			currentY = Math.max(0, currentY - buttonMovement);
			slider.setPositionFn(0, currentY);
			update();
		}
		
		// Called when down is clicked
		var onDown = function() {
			currentY = Math.min(realHeight, currentY + buttonMovement);
			slider.setPositionFn(0, currentY);
			update();
		}
		
		// Metrics
		var buttonHeight = scrollbarWidth - 4;
		var sliderHeight = availableHeight - 2 * scrollbarWidth + 4;
		var handleSize = Math.max(buttonHeight, sliderHeight * (availableHeight / realHeight));
		
		// Design the slider part
		var sliderBlock;
		if (availableHeight > 3 * buttonHeight + 10) {
			var b = buttonHeight * 0.3;
			var handleBlock =
				Filter(
					Bevel(1, 45, 0xe6eefc, 100, 0xb0c4f2, 100, 2, 2, 1, 1, "inner", false),
					GradientBackground("linear", [0xc8d6fb, 0xb9cbf3], 0, 0, 
						Offset(b, 0,
							LineStack([
								Fixed(buttonHeight, handleSize / 2 - 3), 
								Background(0xeef4fe, Fixed(buttonHeight - 2 * b, 1)),
								Background(0x8cb0f8, Fixed(buttonHeight - 2 * b, 1)),
								Background(0xeef4fe, Fixed(buttonHeight - 2 * b, 1)),
								Background(0x8cb0f8, Fixed(buttonHeight - 2 * b, 1)),
								Background(0xeef4fe, Fixed(buttonHeight - 2 * b, 1)),
								Background(0x8cb0f8, Fixed(buttonHeight - 2 * b, 1)),
								Fixed(buttonHeight, handleSize / 2 - 3)
							])
						),
						null, 3, Math.PI / 2)
				);
			
			slider = Arctic.makeSlider(0, 0, 0, realHeight - availableHeight, 
							ColumnStack([ Background(0x000000, Fixed(availableWidth + 2, handleSize),0), handleBlock ] ), 
							onScroll, null, currentY, true);
		
			sliderBlock = ConstrainHeight(sliderHeight, sliderHeight,
						OnTop(
							ColumnStack([ 
								Background(0x000000, Fixed(availableWidth + 2, sliderHeight), 0),
								GradientBackground("linear", [0xfefefb, 0xf3f1ec], 0, 0, 
									Fixed(buttonHeight, sliderHeight),
									null, null, 0)
							]), 
							slider.block
						)
					);
		} else {
			// No slider
			sliderBlock = Fixed(0, sliderHeight);
		}

		// The final scrollbar is composed
		var scrollbar = 
			OnTop(
				// The buttons
				Offset(availableWidth, 0, 
					Frame(
						Frame(
							LineStack( [
								makeButton(buttonHeight, true, onUp),
								Fixed(0, sliderHeight),
								makeButton(buttonHeight, false, onDown)
							] ), 1, 0xffffff
						), 1, 0xeeede5
					)
				),
				// The slider area
				Offset(0, buttonHeight + 2, sliderBlock)
			)
			;

		update();

		var view = new ArcticView(scrollbar, parent);
		view.adjustToFit(0, 0);
		var mc = view.display(false);
		Reflect.setField(parent, "scrollbar", view);
		return;
	}

	/// Get rid of the scrollbar
	static public function removeScrollbar(parent : ArcticMovieClip, clip : ArcticMovieClip) {
		if (Reflect.hasField(parent, "scrollbar")) {
			var scrollView : ArcticView = Reflect.field(parent, "scrollbar");
			scrollView.destroy();
			Reflect.deleteField(parent, "scrollbar");
			ArcticMC.setScrollRect(clip, null);
		}
	}
	
	/// Make a scrollbar button of the given size - if up is false, the pointing points down 
	static private function makeButton(size : Float, up : Bool, fn : Void -> Void) : ArcticBlock {
		var arrow1 = makeArrow(size, up, 0x4D6185);
		var arrow2 = makeArrow(size, up, 0x2C364A);
		return Button(
					Filter(
						Bevel(1, 45, 0xcad8f9, 100, 0x7da0d4, 100, 2, 2, 1, 1, "inner", false),
						GradientBackground("linear", [0xe1eafe, 0xb9cbf3], 0, 0, arrow1, null, 3, Math.PI / 2)
					),
					Filter(
						Bevel(1, 45, 0x97aee0, 100, 0x7da0d4, 100, 2, 2, 1, 1, "inner", false),
						GradientBackground("linear", [0xe5f6ff, 0xb9dafb], 0, 0, arrow2, null, 3, Math.PI / 2)
					),
					fn
				);
	}
	
	/// A nice arrow of a given size, pointing up or down, with a colour
	static private function makeArrow(size : Float, up : Bool, colour : Int) : ArcticBlock {
		// Callback fn for the CustomBlock to draw Radio button
		var build = function(state : Bool, mode : BuildMode, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) {
			if (mode != Metrics) {
				var b = size * 0.35;
				var g = ArcticMC.getGraphics(parentMc);
				g.lineStyle(2, colour);
				if (up) {
					g.moveTo(b, size - b);
					g.lineTo(size / 2, b);
					g.lineTo(size - b, size - b);
				} else {
					g.moveTo(b, b);
					g.lineTo(size / 2, size - b);
					g.lineTo(size - b, b);
				}
			}
			return { clip: parentMc, width: size, height: size, growWidth : false, growHeight : false };
		}
		return CustomBlock(up, build);
	}
}
