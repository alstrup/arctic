package arctic;

/**
 * Arctic is an embedded Domain Specific Language for making user interfaces.
 * A user interface is built from ArcticBlocks.
 */
enum ArcticBlock {
	/// A solid background
	Background(color : Int, block : ArcticBlock, ?alpha : Float, ?roundRadius : Float);

	/// A gradient background
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>, ?roundRadius : Float);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/// A text (in the subset of HTML which Flash understands)
	Text(html : String);

	/**
	 * An input text.  Text Font/Size/Color can be specified along with initial text content in the subset of HTML which Flash understands.
	 */
	TextInput(html : String, width : Float, height : Float, validator : String -> Bool, ?maxChars : Int, ?numeric : Bool, ?bgColor : Int);

	/// A static picture
	Picture(url : String, width : Float, height : Float, scaling : Float);

	/**
	 * A button - when mouse is above, we change to hover look. Notice block and hover should have the exact same size.
	 */
	Button(block : ArcticBlock, hover : ArcticBlock, onClick : Void -> Void);

	/**
	 * Toggle button(selected/unselected)
	 * Though technically the ArcticBlock can be of any type, the most appropriate ones are Text & Picture.
	 * Notice that the selected and unselected blocks should have the exact same size, because we do not
	 * do a relayout when the state is changed.
	 */ 
	ToggleButton(selected : ArcticBlock, unselected : ArcticBlock, initialState : Bool, onChange : Bool -> Void, ?onInit : (Bool -> Void) -> Void);

    /**
     * The ArcticBlock will be constraint to the dimensions given
     */
    ConstrainWidth(minimumWidth : Float, maximumWidth : Float, block : ArcticBlock); 

    /**
     * The ArcticBlock will be constraint to the dimensions given
     */
    ConstrainHeight(minimumHeight : Float, maximumHeight : Float, block : ArcticBlock);

	/**
	 * Filler is empty space, that eats space when put in a stack or list of some kind
	 */
	Filler;

	/**
	 * Columns are blocks put next to each other horizontally
	 */
	ColumnStack(columns : Array< ArcticBlock > );

	/**
	 * A bunch of blocks stacked on top of each other.
	 */
	LineStack(blocks : Array<ArcticBlock>);

    ScrollBar(block : ArcticBlock, availableWidth : Float, availableHeight : Float);
}
