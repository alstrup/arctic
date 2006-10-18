package arctic;

/**
 * Arctic is an embedded Domain Specific Language for making user interfaces.
 * A user interface is built from ArcticBlocks.
 */
enum ArcticBlock {
	/// A solid background
	Background(color : Int, block : ArcticBlock);

	/// A gradient background
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/// A text (in the subset of HTML which Flash understands)
	Text(html : String);

	/// A static picture
	Picture(url : String, width : Float, height : Float, scaling : Float);

	/// A button
	Button(block : ArcticBlock, action : Void -> Void);

	/**
	 * Toggle button(selected/unselected)
	 * Though technically the ArcticBlock can be of any type, the most appropriate ones are Text & Picture.
	 * Notice that the selected and unselected blocks should have the exact same size, because we do not
	 * a relayout when the state is changed.
	 */ 
	ToggleButton(selected : ArcticBlock, unselected : ArcticBlock, initialState : Bool, onChange : Bool -> Void, ?onInit : (Bool -> Void) -> Void);

	/**
	 * Group of ToggleButtons on which only one of will be in a selected state at any point of time.
	 * ONLY ToggleButton is supported in the blocks
	 */
	ToggleButtonGroup(buttons : Array<ArcticBlock>, onSelect : Int -> Void);

	/**
	 * An input text - TODO: This has to change interface to be platform independent. It can not rely on types like TextFormat
	 */
//	TextInput(id : String, contents : String, listener : Dynamic, width : Int, height : Int, ?maxChars : Int, ?restrict : String, ?format : TextFormat );

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
	 * Columns are blocks put next to each other horizontally (should align when put in a list).
	 */
	ColumnStack(columns : Array< ArcticBlock > );

	/**
	 * A bunch of blocks stacked on top of each other.
	 */
	LineStack(blocks : Array<ArcticBlock>);

	/**
	 * A bunch of lines, put in a list where each item is stacked on top of each other.
	 * If there is not enough room on the screen for all items, we will show a scroll-bar.
	 */ 
	SelectList(lines : Array<ArcticBlock>, onClick : Int -> Void);
}
