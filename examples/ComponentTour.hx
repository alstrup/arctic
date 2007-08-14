import arctic.Arctic;
import arctic.ArcticView;
import arctic.ArcticBlock;

/**
 * This example provides a tour of most of the components in Arctic
 */
class ComponentTour {
	static public function main() {
		new ComponentTour();
	}
	
	public function new() {
		var selected = 0;
		components = [ 
			[ "<font color='#c0c0c0'>Background(0xc0c0ff</font>, Fixed(200, 200)<font color='#c0c0c0'>)</font>", Background(0xc0c0ff, Fixed(200, 200)) ],
			[ "Background(0x8080ff, <font color='#c0c0c0'>Fixed(200, 200)</font>, null, 10)", Background(0x8080ff, Fixed(200, 200), null, 10) ],
			[ "GradientBackground( \"linear\", [ 0xc0c0ff, 0x8080ff], 0.0, 0.0, <font color='#c0c0c0'>Fixed( 200, 200 )</font>, null, 10, 45 )", GradientBackground( "linear", [ 0xc0c0ff, 0x8080ff], 0.0, 0.0, Fixed( 200, 200 ), null, 10, 45 ) ],
			[ "<font color='#c0c0c0'>Background(0xc0c0ff,</font> Border( 5, 5, <font color='#c0c0c0'>Background(0x8080ff, Fixed( 190, 190 ) )</font> ) <font color='#c0c0c0'>)</font>", Background(0xc0c0ff, Border( 5, 5, Background(0x8080ff, Fixed( 190, 190 ) ) ) ) ],
			[ "Text(\"A text\")", Text("A text") ],
			[ "Arctic.makeText(\"A text\", 20)", Arctic.makeText("A text", 20) ],
			[ "TextInput(\"A text input\", 200, 20, null, null, null, null, 0xc0c0ff, true)", TextInput("A text input", 200, 20, null, null, null, null, 0xc0c0ff, true) ],
			[ "Picture(\"images/head2.jpg\", 80, 100, 1.0)", Picture("images/head2.jpg", 80, 100, 1.0) ],
			[ "Button(<font color='#c0c0c0'>Text(\"A button\")</font>, <font color='#c0c0c0'>Background( 0xc0c0ff, Text(\"A button\") )</font>, null)", Button( Text("A button"), Background( 0xc0c0ff, Text("A button") ), null) ],
			[ "Arctic.makeSimpleButton(\"A button\", null, 20)", Arctic.makeSimpleButton("A button", null, 20) ],
			[ "Arctic.makeCheckbox(<font color='#c0c0c0'>Text(\"A checkbox\")</font>)", Arctic.makeCheckbox(Text("A checkbox")) ],
			[ "Arctic.makeTextChoice([ \"1\", \"2\", \"3\"], null).block", Arctic.makeTextChoice([ "1", "2", "3"], null).block ],
			[ "Arctic.makeDateView(<font color='#c0c0c0'>Date.now()</font>)", Arctic.makeDateView(Date.now()) ],
			[ "Arctic.makeTooltip(<font color='#c0c0c0'>Text(\"Hide\")</font>, \"...and seek\")", Arctic.makeTooltip(Text("Hide"), "...and seek") ],
			[ "Arctic.makeDragable(true, true, true, <font color='#c0c0c0'>Text(\"Drag me\")</font>).block", Arctic.makeDragable(true, true, true, Text("Drag me")).block ],
			[ "Arctic.makeSlider(0, 100, 0, 100, <font color='#c0c0c0'>Text(\"Slide me\")</font>).block", Arctic.makeSlider(0, 100, 0, 100, Text("Slide me"), null).block ],
			[ "Filter(DropShadow(2, 45, 0x000000, 10), <font color='#c0c0c0'>Text(\"Shadow\")</font>)", Filter(DropShadow(2, 45, 0x000000, 100), Text("Shadow")) ],
			[ "Frame(5, 0x8080ff, <font color='#c0c0c0'>Text(\"Frame\")</font>, 20, null, 10, 10)", Frame(5, 0x8080ff, Text("Frame"), 20, null, 10, 10) ],
			[ "Cursor(<font color='#c0c0c0'>Text(\"See\")</font>, <font color='#c0c0c0'>Text(\"A custom cursor!\")</font>, false)", Cursor(Text("See"), Text("A custom cursor!"), false) ],
			[ "Offset(50, 50, <font color='#c0c0c0'>Background(0xc0c0ff, Fixed(200, 200) )</font> )", Offset(50, 50, Background(0xc0c0ff, Fixed(200, 200) ) ) ],
			[ "OnTop(Text(\"Text\"), Text(\"////////\") )", OnTop(Text("Text"), Text("////////") ) ],
/*		
			// TODO: Make examples for
			"ConstrainWidth",
			"ConstrainHeight",
			"Filler",
			"ColumnStack",
			"LineStack",
			"Grid",
			"ScrollBar",
			"Id",
			"CustomBlock",
			"Mutable",
			"Arctic.makeRadioButtonGroup"
*/
		];
		
		var componentTexts = [];
		for (c in components) {
			componentTexts.push(c[0]);
		}
		var menu = Arctic.makeTextChoice(componentTexts, chooseComponent, selected);
		
		var code = components[selected];
		preview = new MutableBlock(code[1]);
		var screen = 
			Border( 5, 5,
				Frame( 2, 0x000000, Background(0xf0f0ff, Border( 10, 10,
					ColumnStack( [ 
						LineStack( [
							Arctic.makeText("Select a component to preview:"),
							menu.block,
							Arctic.makeText("<br/>Read ArcticBlock.hx and Arctic.hx for more info."),
							Filler
						]),
						Fixed(10, 10),
						LineStack( [
							Arctic.makeText("Preview:"),
							Fixed(5, 5),
							Frame( 2, 0x000000, Background( 0xffffff, Border( 5, 5, Mutable(preview) ), null, 10), 5, null, 0, 0)
						]),
						Filler
					] )
				), null, 10),
				10, null, 0, 0)
			);

		// Then construct the arctic view object
		arcticView = new ArcticView( screen, flash.Lib.current );
		// And finally display on the given movieclip
		var root = arcticView.display(true);
	}
	public function chooseComponent(selected : Int, text : String) {
		// Change the preview block
		preview.block = components[selected][1];
		// This forces a relayout of the other components
		arcticView.refresh(false);
	}
	public var arcticView : ArcticView;
	private var preview : MutableBlock;
	private var components : Array<Dynamic>; 
}
