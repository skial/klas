package uhx.macro.klas;

import haxe.macro.Type;
import haxe.macro.Expr;

/**
 * @author Skial Bainn
 */

typedef TypeInfo = {
	var type:Type;
	var fields:Array<Field>;
	var current:TypePath;
	var original:TypePath;
}