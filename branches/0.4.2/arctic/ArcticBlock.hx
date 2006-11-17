package arctic;

#if flash9
typedef ArcticMovieClip = flash.display.MovieClip
#else flash
typedef ArcticMovieClip = flash.MovieClip
#end

/// The structure used by CustomBlocks to tell arctic of dimensions and requested resizing behaviour
typedef Metrics = { width : Float, height : Float, growWidth : Bool, growHeight : Bool }

/**
 * Arctic is an embedded Domain Specific Language for making user interfaces.
 * A user interface is built from ArcticBlocks.
 */
enum ArcticBlock {
	/// Draw a solid background behind the given block. Alpha is an optional transparency from 0 to 100.
	Background(color : Int, block : ArcticBlock, ?alpha : Float, ?roundRadius : Float);

	/// Draw a gradient background behind the given block.
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>, ?roundRadius : Float);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/// A text (in the subset of HTML which Flash understands)
	Text(html : String);

	/**
	 * An input text.  Text Font/Size/Color can be specified along with initial text content in the subset of HTML which Flash understands.
	 * The validator callback is called on each change in Flash 8, but only on loss of focus in Flash 9. You can use this callback to
	 * extract the contents of the text input.
	 */
	TextInput(html : String, width : Float, height : Float, ?validator : String -> Bool, ?maxChars : Int, ?numeric : Bool, ?bgColor : Int);

	/// A static picture loaded from a URL. It is your responsibility to set the scaling such that the picture has the stated size
	Picture(url : String, width : Float, height : Float, scaling : Float);

	/**
	 * A button - when mouse is above, we change to hover look. Notice block and hover should have the exact same size.
	 */
	Button(block : ArcticBlock, hover : ArcticBlock, onClick : Void -> Void);

	/**
	 * Toggle button (selected/unselected).
	 * Though technically the ArcticBlock can be of any type, the most appropriate ones are Text & Picture.
	 * Notice that the selected and unselected blocks should have the exact same size, because we do not
	 * do a relayout when the state is changed. The onInit method is called when the view is constructed
	 * with the state we have. This can be used to implement connected radio button groups - like the factory
	 * Arctic.makeRadioButtonGroup does.
	 */ 
	ToggleButton(selected : ArcticBlock, unselected : ArcticBlock, initialState : Bool, onChange : Bool -> Void, ?onInit : (Bool -> Void) -> Void);

    /**
     * The ArcticBlock will be constraint to the dimensions given - by clipping or extending
     */
    ConstrainWidth(minimumWidth : Float, maximumWidth : Float, block : ArcticBlock); 

    /**
     * The ArcticBlock will be constraint to the dimensions given - by clipping or extending
     */
    ConstrainHeight(minimumHeight : Float, maximumHeight : Float, block : ArcticBlock);

	/**
	 * Filler is greedy empty space, that eats space when put in a LineStack or ColumnStack.
	 * This can be used to implement left alignment, centering, and similar strategies.
	 */
	Filler;

	/**
	 * Columns are blocks put next to each other horizontally. The height is the maximum
	 * height of the blocks.
	 */
	ColumnStack(columns : Array< ArcticBlock > );

	/**
	 * A bunch of blocks stacked on top of each other. The width is the maximum width
	 * of the blocks. If you want to make sure a specific block is visible, pass the
	 * index number of the block in the array as second parameter.
	 */
	LineStack(blocks : Array<ArcticBlock>, ?ensureVisibleIndex : Int);
	
	/**
	 * A 2-d grid of block.
	 */
	Grid(blocks: Array<Array<ArcticBlock>>);

	/// Wrap the block in a window of the given size, and add a scrollbar if necessary
    ScrollBar(block : ArcticBlock, fixedWidth : Float, fixedHeight : Float);

	/**
	 * Make a block dragable by the mouse in the given directions.
	 * If stayWithinSize is true, the movement is constrained to the available area
	 * of the block (and this block becomes size greedy in the directions we allow motion in).
	 * This block can be used to make many things, including dialogs. Use the wrapper 
	 * Arctic.makeDragable if you want to preserve the drag distance across resizes.
	 */
	Dragable(stayWithinBlock : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, block : ArcticBlock, 
			onDrag : Float -> Float -> Void, ?onInit : (Float -> Float -> Void) -> Void);

	/**
	 * Set the cursor shape to a block when the mouse is within the given block.
	 * If you want the cursor block to be in ADDITION to the normal cursor, set
	 * keepNormalCursor to true. Per default, the normal cursor is hidden when
	 * the custom cursor is visible.
	 */
	Cursor(block : ArcticBlock, cursor : ArcticBlock, ?keepNormalCursor : Bool);

	/**
	 * Translate a block in some direction - notice layout does not take this into account.
	 */
	Offset(xOffset : Float, yOffset : Float, block : ArcticBlock);

	/**
	 * Place a block on top of another block (overlay).
	 */
	OnTop(base : ArcticBlock, overlay : ArcticBlock);

	/**
	 * Name this block so that we can get to it, and update it.
	 */
	Id(name : String, block : ArcticBlock);

	/**
	 * A custom block. This is an escape mechanism which allows you to extend Arctic
	 * with your own basic blocks. Parameters:
	 * 
	 *  data: an optional payload.
	 *  calcMetricsFunc: a function which has to calculate the metrics of the block.
	 *       This is the size of the block, and bools defining whether the block
	 *       wants to grow in width and/or height. If you leave this empty, Arctic
	 *       will use the buildFunc to find out the size (by creating the clip and
	 *       removing it again).
	 *  buildFunc: This is called with the optional data payload as first parameter,
	 *       the MovieClip where the block should be put or drawn, and the available height
	 *       and width for the element. It should return the resulting display
	 *       object (movie clip).
	 * 
	 * Notice that you have to build the custom blocks such that their work with
	 * both Flash 8 and 9.
	 * Notice that calcMetrics should match the size of the clip that buildFunc creates.
	 * If they do not, the layout might be broken.
	 */
	CustomBlock( data : Dynamic, 
				calcMetricsFunc : Dynamic -> Metrics, 
				buildFunc : Dynamic -> ArcticMovieClip -> Float -> Float -> ArcticMovieClip
				);

}
