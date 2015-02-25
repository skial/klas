package uhx.macro;

import haxe.Json;
import haxe.macro.Printer;
import sys.io.File;
import sys.FileSystem;
import sys.io.Process;
import Type in StdType;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Compiler;

using Lambda;
using StringTools;
using sys.FileSystem;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.MacroStringTools;

/**
 * ...
 * @author Skial Bainn
 */

class KlasImp {
	
	public static var isSetup:Bool = false;
	
	public static function initalize() {
		if (isSetup == null || isSetup == false) {
			history = new StringMap();
			DEFAULTS = new StringMap();
			CLASS_META = new StringMap();
			FIELD_META = new StringMap();
			INLINE_META = new Map();
			ONCE = [];
			
			isSetup = true;
		}
	}
	
	public static var DEFAULTS:StringMap<ClassType->Array<Field>->Array<Field>>;
	public static var CLASS_META:StringMap<ClassType->Array<Field>->Array<Field>>;
	public static var FIELD_META:StringMap<ClassType->Field->Field>;	
	public static var INLINE_META:Map < EReg, ClassType-> Field->Field > ;
	public static var ONCE:Array<Void->Void>;
	
	private static var reTypes:Array<ClassType->Array<Field>->TypeDefinition> = [];
	
	public static function registerForReType(callback:ClassType->Array<Field>->TypeDefinition):Void {
		reTypes.push( callback );
	}
	
	public static var printer:Printer = new Printer();
	public static var history:StringMap<Array<String>>;
	
	public static function build():Array<Field> {
		var cls = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		
		// Populate history
		/*if (!history.exists( cls.pack.toDotPath( cls.name ) )) {
			history.set( cls.pack.toDotPath( cls.name ), [for (field in fields) field.name] );
		}*/
		
		initalize();
		if (cls.meta.has(':KLAS_SKIP')) return fields;
		
		// Call all callbacks.
		for (once in ONCE) once();
		ONCE = [];
		
		reTypes = [];
		
		/**
		 * Loop through any class metadata and pass along 
		 * the class and its fields to the matching handler.
		 * -----
		 * Each handler should decide if its needed to be run
		 * while in IDE display mode, `-D display`.
		 */
		
		for (key in CLASS_META.keys()) if (cls.meta.has( key )) {
			fields = CLASS_META.get( key )( cls, fields );
		}
		
		for (i in 0...fields.length) {
			
			var field = fields[i];
			
			// First check the field's metadata for matches. 
			// Passing along the class and matched field.
			for (key in FIELD_META.keys()) if (field.meta != null && field.meta.exists( function(m) return m.name == key )) {
				field = FIELD_META.get( key )( cls, field );
			}
			
			var printed = printer.printField( field );
			//trace( printed );
			// Now check the stringified field for matching inline metadata.
			// Passing along the class and matched field.
			for (key in INLINE_META.keys()) if (key.match( printed )) {
				field = INLINE_META.get( key )( cls, field );
			}
			
			fields[i] = field;
			
		}
		
		for (def in DEFAULTS) {
			fields = def( cls, fields );
		}
		
		// This is a horrible idea - I want to get rid of it. Still fun tho.
		// -----
		// Really sad that I have to destroy and rebuild a class just to get what I want...
		// All callbacks handle the rename hack. @:native('orginal.package.and.Name')
		// All retyped classes should not modify the fields further.
		for (callback in reTypes) {
			var td = callback( cls, fields );
			
			if (td == null) continue;
			
			switch( td.kind ) {
				case TDClass(c, _, _):
					trace( TPath( c ).toString() );
					try {
						Context.getType( TPath( c ).toString() );
					} catch (e:Dynamic) {
						POSTPONED.set( TPath( c ).toString(), td );
						LINEAGE.set( TPath( c ).toString(), td.pack.toDotPath( td.name ) );
						continue;
					}
					
				case _:
			}
			// Unfortuantly for this to work, all types must
			// be in referenced by their full path. So Array<MyClass>
			// must be Array<my.pack.to.MyClass>. This what the code
			// below does.
			/*for (field in td.fields) {
				switch (field.kind) {
					case FVar(t, e):
						trace( t );
						if (t != null) {
							t = t.qualify();
						} else if (e != null) {
							t = Context.toComplexType( Context.typeof( e ) );
						} else {
							trace( field.name );
						}
						field.kind = FVar(t, e);
						trace( t );
					case FProp(g, s, t, e):
						if (t != null) {
							t = t.qualify();
						} else if (e != null) {
							t = Context.toComplexType( Context.typeof( e ) );
						} else {
							trace( field.name );
						}
						field.kind = FProp(g, s, t, e);
						
					case FFun(method):
						for (arg in method.args) {
							if (arg.type != null) {
								arg.type = arg.type.qualify();
							}
						}
						
				}
			}*/
			buildLineage( td.pack.toDotPath( td.name ) );
			
			/*switch (td.kind) {
				case TDClass(s, i, b): i.remove( { name: 'Klas', pack: [], params: [] } );
				case _:
			}*/
			//trace( td.printTypeDefinition() );
			Compiler.exclude( cls.pack.toDotPath( cls.name ) );
			Context.defineType( td );
			//Context.getType( td.path() );
		}
		
		return fields;
	}
	
	private static var POSTPONED:StringMap<TypeDefinition> = new StringMap<TypeDefinition>();
	private static var LINEAGE:StringMap<String> = new StringMap<String>();
	
	private static function buildLineage(path:String) {
		//trace( path );
		for (k in LINEAGE.keys() ) trace( k, LINEAGE.get( k ) );
		for (k in POSTPONED.keys() ) trace( k, POSTPONED.get( k ) );
		if (LINEAGE.exists( path ) && POSTPONED.exists( path )) {
			
			var td = POSTPONED.get( path );
			buildLineage( td.pack.toDotPath( td.name ) );
			
			trace( td );
			//Compiler.exclude( path );
			Context.defineType( td );
			
		}
	}
	
}