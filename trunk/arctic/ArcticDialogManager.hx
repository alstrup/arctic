package arctic;

import arctic.Arctic;
import arctic.ArcticMC;
import arctic.ArcticView;
import arctic.ArcticBlock;

/**
 * Manages all open dialogs.  Provides a service to check whether the mouse is inside a
 * dialog or not, & thus used to send mouse clicks where they belong (e.g.,
 * to the dialog or to somewhere else).  
 * 
 * At this point, dialogs will not respect other dialogs.  Someone must 
 * implement that dialogs ignore clicks not for them using z-ordering.
 */
class ArcticDialogManager {
	// We are a singleton
	static private var instance : ArcticDialogManager;
	static public function get() : ArcticDialogManager {
		if (null == instance) {
			instance = new ArcticDialogManager();
		}
		return instance;
	}

	public function new() {
		currentDialogs = [];
		mc = ArcticMC.getCurrentClip();
		displayNotificationFn = null;
	}
	
	/**
	 * You can call this to initialize the dialog manager with your own parent clip where dialogs should be build on.
	 * You can also supply a function which will be called whenever a dialog appears, or all dialogs disappear.
	 */
	public function init(mc0 : ArcticMovieClip, ?displayNotifier : Bool -> Void) {
		mc = mc0;
		displayNotificationFn = displayNotifier;
	}

	/// Is mouse inside one of my dialogs?
	public function inside() : Bool {
		var mouse = ArcticMC.getMouseXY();
		for (d in currentDialogs) {
			if (d.hitTest(mouse.x, mouse.y)) {
				return true;
			}
		}
		return false;
	}

	public function dialogCovers(mc : ArcticMovieClip) : Bool {
		var mouse = ArcticMC.getMouseXY();
		for (d in currentDialogs) {
			if (d.hitTest(mouse.x, mouse.y)) {
				var delta = ActiveClips.compare(d.baseClip, mc);
				if (delta > 0) {
					return true;
				}
			}
		}
		return false;
	}
	
	// ArcticDialogs register themselves here when they are shown - don't call manually
	public function add(d : ArcticDialog) {
		currentDialogs.push(d);
		if (displayNotificationFn != null) {
			displayNotificationFn(true);
		}
	}
	
	// ArcticDialogs unregister themselves when they are hidden - don't call manually
	public function remove(d : ArcticDialog) {
		currentDialogs.remove(d);
		if (displayNotificationFn != null) {
			displayNotificationFn(currentDialogs.length > 0);
		}
	}
	
	/// What dialogs are visible right now?
	private var currentDialogs : Array<ArcticDialog>;

	// Layer for dialogs
	public var mc : ArcticMovieClip;
	
	/// An optional function that is called with true whenever a dialog is shown, and with false when *all* dialogs are hidden. 
	public var displayNotificationFn : Bool -> Void;
}
