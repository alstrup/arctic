package arctic;

import arctic.ArcticUi;
import arctic.ArcticBlock;
import arctic.ArcticState;

/**
 * A titled dialog with a nice frame and a close button.
 * If you don't need the frame and the title, see ArcticDialog.
 */
class ArcticDialogUi extends ArcticDialog {
	public static var backgroundColor = 0xF5F5F5;
	public static var borderColor = 0xC1D8F2;
	public static var roundRadius: Float = 5;
	public static var dialogShadow = 0x777777;
	public static var buttonsTextColor = "#15428B";
	public static var buttonsHoveredColor = 0xFFF5C1;
	public static var buttonsHoveredFrameColor = 0xC2A978;

	/**
	 * Construct a dialog block with a title bar and a close button.
	 */
	public function new(title0 : String, content: ArcticBlock, ?xPos: Float, ?yPos: Float, ?mc : ArcticMovieClip) {
		// Construct the frame with title
		titleState = new ArcticState<String>(title0, function (title : String) {
			return Arctic.makeText(title, null, buttonsTextColor);
		});
		
		var gui = makeFrame( 
			Grid( [
				[ Background(borderColor, ColumnStack([Filler, titleState.block, Filler, Border(2, 2, makeButton(" X ", 7.0, close)) ])) ],
				[ content ]
			])
		);
		super(gui, xPos, yPos, mc);
	}

	/// The title of the dialog can be updated and queried here
	public var title(getTitle, setTitle) : String;
	
	/// Make a nice button
	private static function makeButton(text, size : Float, onClick : Void -> Void) {
		var t = Arctic.makeText(text, size, buttonsTextColor);
		var normal = makeRect( t, borderColor, borderColor, 1.0, 2.0 );
		var hovered = makeRect( t, buttonsHoveredColor, buttonsHoveredFrameColor, 1.0, 2.0 );	
		return Button(normal, hovered, onClick);
	}

	/// Make a rectangle with a frame
	private static function makeRect(block: ArcticBlock, ?color: Int, ?borderColor: Int, ?padding: Float, ?roundRadius: Float): ArcticBlock {
		if (padding != null && padding != 0) {
			block = Border(padding, padding, block);
		}
		return Frame( 1, borderColor, Background(color, block, null, roundRadius), roundRadius);
	}
	
	/// Make the dialog frame
	private static function makeFrame(content: ArcticBlock): ArcticBlock {
		content = makeRect(content, backgroundColor, borderColor, 0.0, roundRadius);
		return Filter( DropShadow( 3, 45, dialogShadow, 0.5 ), content );
	}

	/// Implementation details here
	public function getTitle() : String { return titleState.state; }
	public function setTitle(s : String) {
		titleState.state = s;
		arcticView.refresh(false);
		return s;
	}
	private var titleState : ArcticState<String>;

	
}
