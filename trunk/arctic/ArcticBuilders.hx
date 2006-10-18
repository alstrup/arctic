package arctic;

import arctic.ArcticBlock;

class ArcticBuilders {
	static public function makeDateView(date : Date) : ArcticBlock {
		var months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];
		var days = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];
		var day = days[Math.floor(3 + date.getTime() / (1000 * 60 * 60 * 24)) % 7];
		var text = "<font color='#000000' face='arial'><p align='center'><b>" + months[date.getMonth()]
				+ "</b><br><p align='center'><b><font size='32'>" + date.getDate() + "</font></b>"
				+ "<br><p align='center'><b>" + day + "</b></font>";
		return Background(0x000000, Border(1, 1, Background(0xFFFCA9, ConstrainWidth(75, 75, ConstrainHeight(75, 75, Text(text))))));
	}
}
