package arctic;

import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.Arctic;
import arctic.ArcticMC;

/**
 * Make a dragable dialog out of an Arctic block.
 * 
 * Construct the dialog, then call open() to show the dialog.
 * It is important to call close() to remove the dialog again.
 * 
 * If you need a title bar and a close button, ArcticDialogUi is your friend.
 */
class ArcticDialog {
	/**
	 * Construct a dialog, but do not show it yet.
	 * The xPos and yPos are numbers between 0.0 and 1.0 which define where the dialog should
	 * appear on the stage. 0.0, 0.0 is in the upper left corner, while 1.0, 1.0 is in the
	 * lower right corner. The default position is in the middle of the screen (0.5, 0.5).
	 * The dialog is constructed in the dialog movieclip (from ArcticDialogManager).
	 */
	public function new(content : ArcticBlock, ?xPos : Float, ?yPos : Float, ?parentMc: ArcticMovieClip) {
		xPosition = if (xPos == null) 0.5 else xPos;
		yPosition = if (yPos == null) 0.5 else yPos;
		var slider = Arctic.makeSlider(0.0, 1.0, 0.0, 1.0, content, null, xPosition, yPosition, false);
		setPositionFn = slider.setPositionFn;
		contentBlock = slider.block;
		parentClip = if (parentMc == null) ArcticDialogManager.get().mc else parentMc;
		baseClip = null;
		dialogClip = null;
		arcticView = null;
	}
	
	/**
	 * This will show the dialog at the given position. If you call this on a dialog which
	 * is already visible, the dialog is moved to it's initial position on the stage,
	 * but the dialog contents are otherwise kept the same.
	 * This returns itself as a convenience, so that you can write
	 * 
	 *     var myDialog = new ArcticDialog("Dialog", block).show();
	 * 
	 * on one line to make and show a dialog.
	 */
	public function open() : ArcticDialog {
		if (baseClip == null) {
			baseClip = ArcticMC.create(parentClip);

			arcticView = new ArcticView(contentBlock, baseClip);
			dialogClip = arcticView.display(true);
			ArcticDialogManager.get().add(this);
		} else {
			updatePosition();
		}
		return this;
	}

	/// This will hide and destroy the dialog view. You can show the dialog again by calling open once more.
	public function close() {
		if (baseClip == null) {
			// Already hidden
			return;
		}
		arcticView.destroy();
		ArcticMC.remove(baseClip);
		baseClip = null;
		dialogClip = null;
		ArcticDialogManager.get().remove(this);
	}

	/// This can be used to move the dialog to a new position
	public function setPosition(x : Float, y : Float) {
		xPosition = x;
		yPosition = y;
		updatePosition();
	}
	
	private function updatePosition() {
		setPositionFn(xPosition, yPosition);
	}
	
	/// Used by ArcticDialogManager to test whether the mouse is inside an open dialog
	public function hitTest(x : Float, y : Float) : Bool {
		return dialogClip != null && ArcticMC.hitTest(dialogClip, x, y);
	}
	
	public function getArcticClip(id: String) : ArcticMovieClip {
		return arcticView.getRawMovieClip(id);
	}
	
	var contentBlock : ArcticBlock;
	var xPosition : Float;
	var yPosition : Float;
	var setPositionFn : Float -> Float -> Void;
	/// The clip where we will construct our view of the dialog
	var parentClip : ArcticMovieClip;
	/// The clip that contains the dialog, and only that
	public var baseClip : ArcticMovieClip;
	/// The root clip of the view, as returned by ArcticView
	var dialogClip : ArcticMovieClip;
	var arcticView : ArcticView;
}
