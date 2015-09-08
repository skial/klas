package uhx.macro;

import haxe.Json;
import Type in StdType;
import haxe.ds.StringMap;

#if macro
import sys.io.File;
import sys.FileSystem;
import sys.io.Process;
import msignal.Signal;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Compiler;
import uhx.macro.klas.Signal;
import uhx.macro.klas.RVSlot;
import uhx.macro.klas.RVSignal;
import uhx.macro.klas.TypeInfo;

using Lambda;
using StringTools;
using sys.io.File;
using haxe.io.Path;
using sys.FileSystem;
using uhx.macro.KlasImp;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.MacroStringTools;
#end

/**
 * ...
 * @author Skial Bainn
 */

@:KLAS_SKIP class KlasImp {
	
	#if macro
	private static var isSetup:Bool = false;
	private static var postProcess:Bool = false;
	
	public static function initialize() {
		if (isSetup == null || isSetup == false) {
			// Initialize public hooks.
			info = new StringMap();
			rebuild = new StringMap();
			anyEnum = new RVSignal();
			anyClass = new RVSignal();
			inlineMetadata = new Map();
			allMetadata = new RVSignal();
			enumMetadata = new StringMap();
			classMetadata = new StringMap();
			fieldMetadata = new StringMap();
			
			// Initialize internal variables.
			history = new StringMap();
			pendingInfo = new StringMap();
			
			onRebuild = new Signal1();
			printer = new Printer();
			
			if (!Context.defined('display') && !Context.defined('klas_rebuild')) {
				rebuildDirectory = '${Sys.getCwd()}/'.normalize();
				
				// Create `Sys.getCwd()/klas/gen/` if it does not exist.
				for (directory in ['klas', 'gen']) if (!(rebuildDirectory = '$rebuildDirectory/$directory/'.normalize()).exists()) {
					rebuildDirectory.createDirectory();
					
				}
				
				// Remove any previous files from the `klas/gen` directory.
				// Attempting to remove a directory throws an error.
				for (file in recurse( rebuildDirectory )) file.deleteFile();
				
				// Setup to recompile with modified classes.
				Context.onAfterGenerate( compileAgain );
				
			}
			
			isSetup = true;
		}
	}
	
	public static function addGlobalMetadata(pathFilter:String, meta:String, ?recursive:Bool = true, ?toTypes:Bool = true, ?toFields:Bool = false) {
		Compiler.addGlobalMetadata( pathFilter, meta, recursive, toTypes, toFields );
	}
	
	/**
	 * A callback which will be run on every class encountered.
	 */
	public static var allMetadata:RVSignal<ClassType, Array<Field>>;
	
	public static var anyClass:RVSignal<ClassType, Array<Field>>;
	public static var anyEnum:RVSignal<EnumType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a class.
	 */
	public static var classMetadata:Signal<String, ClassType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a enum.
	 */
	public static var enumMetadata:Signal<String, EnumType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a abstract.
	 */
	public static var abstractMetadata:Signal<String, AbstractType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a typedef.
	 */
	public static var typedefMetadata:Signal<String, AnonType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a field.
	 */
	public static var fieldMetadata:Signal<String, ClassType, Field>;
	
	/**
	 * A callback which will be run only when a field has inline
	 * metadata matching the regular expression.
	 */
	public static var inlineMetadata:Signal<EReg, ClassType, Field>;
	
	/**
	 * A simple counter used in the naming of new `TypeDefinition`.
	 */
	private static var counter:Int = 0;
	
	/**
	 * A list of metadata paired with a handler method returning a 
	 * rebuilt class.
	 */
	public static var rebuild:StringMap<ClassType->Array<Field>->Null<TypeDefinition>>;
	
	public static var rebuildDirectory:String;
	
	/**
	 * A signal you can register with to get notified when types are rebuilt.
	 */
	public static var onRebuild:Signal1<TypeInfo>;
	
	/**
	 * A map of callbacks that are interested in information for a
	 * perticular type.
	 */
	public static var info:StringMap<Array<Type->Array<Field>->Void>>;
	
	/**
	 * Holds paths, which are the key, with an array of callbacks
	 * wanting to inspect `Type` and `Array<Field>`. You should not
	 * modify any of the `Field`.
	 */
	private static var pendingInfo:StringMap<Array<Type->Array<Field>->Void>>;
	
	/**
	 * Used to turn `Expr` and `TypeDefinition` into readable Haxe code.
	 */
	public static var printer:Printer;
	
	/**
	 * Holds a list of types and their fields internally if global build has 
	 * been forced on all types.
	 */
	private static var history:StringMap<TypeInfo>;
	
	/**
	 * Called by KlasImp's `extraParams.hxml` file for globally applied
	 * metadata.
	 */
	@:noCompletion
	public static function inspection():Array<Field> {
		initialize();
		
		if (!Context.defined('display')) {
			populateHistory( Context.getLocalType(), Context.getBuildFields() );
			processHistory();
		}
		
		return Context.getBuildFields();
	}
	
	/**
	 * Collect information on the current type.
	 */
	private static function populateHistory(type:Type, fields:Array<Field>):Void {
		if (!Context.defined('display') && type != null && !history.exists( type.toString() )) {
			var parts = type.toString().split('.');
			var typePath = { name: parts.pop(), pack: parts };
			history.set( type.toString(), new TypeInfo( type, fields, typePath, typePath ) );
			
		}
	}
	
	/**
	 * Processes any methods interested in a specific `Type`.
	 */
	private static function processHistory():Void {
		var _history = null;
		
		if (!Context.defined('display')) for (key in info.keys()) if (history.exists( key )) {
			_history = history.get( key );
			
			// Process any pending calls.
			if (pendingInfo.exists( key )) {
				for (cb in pendingInfo.get( key )) {
					cb( _history.type, _history.fields );
				}
				
				pendingInfo.remove( key );
				
			}
			
			for (cb in info.get( key )) cb( _history.type, _history.fields );
			
			// All callbacks have been called, clear from the map.
			info.remove( key );
		}
	}
	
	@:noCompletion
	public static function handler(?isGlobal:Bool = false):Array<Field> {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();
		
		// The following breaks afew classes... TODO FIX
		//var moduleTypes = try Context.getModule( type.toString() ) catch (e:Dynamic) [];
		
		return type == null ? fields : process( type, fields );
	}
	
	private static function process(type:Type, fields:Array<Field>):Array<Field> {
		initialize();
		
		populateHistory( type, fields );
		processHistory();
		
		var underlying:Null<Dynamic> = null;
		
		/**
		 * Process matchting metadata signals.
		 */
		switch (type) {
			case TEnum(_.get() => t, _) if (enumMetadata.numListeners > 0 && !t.skip()):
				underlying = t;
				
				for (key in enumMetadata.keys()) if (t.meta.has( key )) {
					fields = enumMetadata.dispatch( key, t, fields );
				}
				
			case TInst(_.get() => t, _) if (classMetadata.numListeners > 0 && !t.skip()):
				underlying = t;
				
				for (key in classMetadata.keys()) if (t.meta.has( key )) {
					fields = classMetadata.dispatch( key, t, fields );
				}
				
			//case TAbstract(_.get() => t, _) if (!t.skip()):
				
				
			case _:
				
		}
		
		if (fieldMetadata.numListeners > 0 ) for (i in 0...fields.length) {
			
			var field = fields[i];
			
			// First check the field's metadata for matches. 
			// Passing along the class and matched field.
			for (key in fieldMetadata.keys()) if (field.meta != null && field.meta.exists( function(m) return m.name == key )) {
				field = fieldMetadata.dispatch( key, underlying, field );
				
			}
			
			if (inlineMetadata.numListeners > 0) {
				var printed = printer.printField( field );
				//trace( printed );
				// Now check the stringified field for matching inline metadata.
				// Passing along the class and matched field.
				for (key in inlineMetadata.keys()) if (key.match( printed )) {
					field = inlineMetadata.dispatch( key, underlying, field );
				}
			}
			
			fields[i] = field;
			
		}
		
		/**
		 * Process the `any*` signals last.
		 */
		switch (type) {
			case TEnum(_.get() => t, _) if (!t.skip()):
				fields = anyEnum.dispatch( t, fields );
				
			case TInst(_.get() => t, _) if (!t.skip()):
				fields = anyClass.dispatch( t, fields );
				fields = allMetadata.dispatch( t, fields );
				
			//case TAbstract(_.get() => t, _) if (!t.skip() && t.meta.get().length > 0):
				
				
			case _:
				
		}
		
		return fields;
	}
	
	private static function skip(type:BaseType):Bool {
		return type.meta.has( ':KLAS_SKIP' );
	}
	
	/**
	 * Starts the process of rebuilding a Class and its fields. Returns information
	 * if the rebuilt type was successfull, `null` otherwise.
	 */
	@:access(haxe.macro.TypeTools)
	public static function triggerRebuild(path:String, metadata:String):Null<TypeInfo> {
		var result = null;
		
		if (!Context.defined('display') && !Context.defined('klas_rebuild')) {
			if (rebuild.exists( metadata ) && history.exists( path )) {
				// Fetch the previous class and fields.
				var cache = history.get( path );
				var clsName = cache.original.pack.toDotPath( cache.original.name );
				
				if (cache.type.match(TInst(_, _)) && cache.fields != null) {
					var directory = rebuildDirectory;
					var cls = cache.type.getClass();
					
					// Check that the selected class has the required `metadata`.
					if (!cls.meta.has( metadata )) return result;
					
					// Pass `cls` and `fields` to the retype handler to get a `typedefinition` back.
					var td = rebuild.get( metadata )( cls, cache.fields );
					
					if (td == null) return result;
					
					var tdName = td.pack.toDotPath( td.name );
					
					// Remove any KlasImp applied metadata.
					for (meta in td.meta) if (meta.name == ':build') {
						switch (meta.params[0]) {
							case macro uhx.macro.KlasImp.inspection():
								td.meta.remove( meta );
								
							case _:
								
						}
						
					}
					
					// Create the package for this type in the Klas generated class path.
					for (path in td.pack) if (!(directory = '$directory/$path'.normalize()).exists()) {
						directory.createDirectory();
						
					}
					
					// Save the rebuilt type.
					var file = '$directory/${cls.name}.hx'.normalize();
					var output = file.write(false);
					output.writeString( printer.printTypeDefinition( td, true ) );
					output.flush();
					output.close();
					
					// Cache the "rebuilt" fields in case of another "rebuild".
					cache.fields = td.fields;
					// Update the current name
					cache.current = { name: td.name, pack: td.pack };
					
					history.set( path, cache );
					
					result = cache;
					postProcess = true;
					onRebuild.dispatch( cache );
					
				}
				
			}
			
		}
		
		processHistory();
		
		return result;
	}
	
	/**
	 * Calls the `callback` for the specific `path` allowing you to
	 * look at a Type and its fields. Returns `true` if it ran your
	 * `callback` now or `false` if it cached your `callback`.
	 */
	public static function inspect(path:String, callback:Type->Array<Field>->Void):Bool {
		var result = false;
		var _history = null;
		
		if (history.exists( path )) {
			_history = history.get( path );
			
			// Process any pending calls.
			if (pendingInfo.exists( path )) {
				for (cb in pendingInfo.get( path )) {
					cb( _history.type, _history.fields );
				}
				
				pendingInfo.remove( path );
				
			}
			
			callback( _history.type, _history.fields );
			result = true;
			
		} else {
			var callbacks = pendingInfo.exists( path ) ? pendingInfo.get( path ) : [];
			callbacks.push( callback );
			
			pendingInfo.set( path, callbacks );
			
		}
		
		processHistory();
		
		return result;
	}
	
	private static function metadataFilter(meta:MetadataEntry, tag:String, pack:String):Bool {
		return meta.name == tag && printer.printExprs( meta.params, '.' ).indexOf( pack ) > -1;
	}
	
	/**
	 * Return a list of files contained within the `path`.
	 */
	private static function recurse(path:String) {
		var results = [];
		path = path.normalize();
		if (path.isDirectory()) for (directory in path.readDirectory()) {
			var current = '$path/$directory/'.normalize();
			if (current.isDirectory()) {
				results = results.concat( recurse( current ) );
			} else {
				results.push( current );
			}
		}
		
		return results;
	}
	
	private static inline function log(value:String):Void {
		#if klas_verbose
		Sys.println( value );
		#end
	}
	
	/**
	 * Run the Haxe compiler _again_, but pointing to the rebuilt modules
	 * directory which overrides the user's classes.
	 */
	private static function compileAgain():Void {
		if (!Context.defined('display') && !Context.defined('klas_rebuild') && postProcess) {
			Sys.println('----- Rerunning Haxe with your rebuilt types -----');
			var process = new Process('haxe', Sys.args().concat( ['-cp', rebuildDirectory, '-D', 'klas_rebuild'] ) );
			process.exitCode();
			Sys.print( process.stdout.readAll() );
			Sys.print( process.stderr.readAll() );
			Sys.println('----- Finished -----');
			process.close();
			
		}
	}
	#end
	
}