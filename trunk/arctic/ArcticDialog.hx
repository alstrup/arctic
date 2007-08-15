package arctic;

import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.Arctic;
import arctic.ArcticMC;

/**
 * Make a dragable dialog out of an Arctic block.
 * Construct the dialog, then call show() to show the dialog.
 * It is important to call hide() to remove the dialog again.
 */
class ArcticDialog {
	/**
	 * Construct a dialog, but do not show it yet. The title parameter is currently unused,
	 * but in the future it might be used for something.
	 * The xPos and yPos are numbers between 0.0 and 1.0 which define where the dialog should
	 * appear on the stage. 0.0, 0.0 is in the upper left corner, while 1.0, 1.0 is in the
	 * lower right corner. The default position is in the middle of the screen (0.5, 0.5).
	 * The dialog is constructed in the dialog movieclip (from ArcticDialogManager).
	 */
	public function new(title0 : String, content : ArcticBlock, ?xPos : Float, ?yPos : Float) {
		title = title0;
		contentBlock = Arctic.makeDragable(false, true, true, content).block;
		xPosition = if (xPos == null) 0.5 else xPos;
		yPosition = if (yPos == null) 0.5 else yPos;
		//contentBlock = Arctic.makeSlider(0, 1, 0, 1, content, null, xPosition, yPosition, false);
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
	public function show(?parent : ArcticMovieClip) : ArcticDialog {
		if (baseClip == null) {
			if (parent == null) {
				parent = ArcticDialogManager.get().mc;
			}
			baseClip = ArcticMC.create(parent);

			arcticView = new ArcticView(contentBlock, baseClip);
			arcticView.adjustToFit(0, 0);
			dialogClip = arcticView.display(false);
			ArcticDialogManager.get().add(this);
		}
		updatePosition();
		return this;
	}

	/// This will hide and destroy the dialog view. You can show the dialog again by calling show once more.
	public function hide() {
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
		var stageSize = ArcticMC.getStageSize(baseClip);
		var clipSize = ArcticMC.getSize(baseClip);
		var maxX = stageSize.width - clipSize.width; 
		var maxY = stageSize.height - clipSize.height;
		ArcticMC.setXY(baseClip, xPosition * maxX, yPosition * maxY);
	}
	
	/// Used by ArcticDialogManager to test whether the mouse is inside an open dialog
	public function hitTest(x : Float, y : Float) : Bool {
		return dialogClip != null && ArcticMC.hitTest(dialogClip, x, y);
	}

	var title : String;
	var contentBlock : ArcticBlock;
	var xPosition : Float;
	var yPosition : Float;
	var baseClip : ArcticMovieClip;
	var dialogClip : ArcticMovieClip;
	var arcticView : ArcticView;
}
