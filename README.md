# Klas

Klas gives you more control on the order build macros are run. With Klas you only
have to add `implements Klas` to your class and any build macro that self registers
with Klas can be accessed with metadata.

<table>
	<tr>
		<td><a href="#installation">Installation</a></td>
		<td><a href="#setup">Setup</a></td>
		<td><a href="#register-a-build-macro-with-klas">Register w/ Klas</a></td>
		<td><a href="#build-hooks">Build Hooks</a></td>
		<td><a href="#build-order">Build Order</a></td>
		<td><a href="#example">Example</a></td>
		<td><a href="#libraries-using-klas">Libs using Klas</a></td>
	</tr>
</table>

## Installation

With haxelib git.
	
```hxml
haxelib git klas https://github.com/skial/klas master src
```

With haxelib local.
	
```hxml
# Download the archive.
https://github.com/skial/klas/archive/master.zip

# Install archive contents.
haxelib local master.zip
```

## Setup

Add `implements Klas` to any class. Make sure `-lib klas` is in your `.hxml` build
file.

## Register a build macro with Klas

To add your build macro to Klas you need to do two things.

1.	Add the following `initialize` method to your build macro.

	```Haxe
	private static function initialize() {
		try {
			KlasImp.initialize();
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `your.macro.Class.build()` method.
		}
	}
	```
	
2.	You should also provide a normal entry point for people not using Klas, who will
	be using the `@:autoBuild` or `@:build` metadata.
3. 	If your build macro does not already have an `extraParams.hxml` file, create one
	in the root of your library.
4.	Add `--macro path.to.your.Class.initialize()` to your `extraParams.hxml` file.
5.	Anyone using Klas and your macro library, with all the correct `-lib` 
	entries will automatically bootstrap themselves into Klas.
	
## Build hooks

Klas provides the following hooks/variables you can register with. You would place
the hook after the line `KlasImp.initialize();` in your `initialize` method.

1.	The `INFO` string map allows your to register a callback which allows you to
	inspect the the `Type` and its build fields if the `Type` has any. It is
	recommended that you __don't__ modify the build fields during this point. The
	string map key should be the path to the type you are interest in and your
	handler type should be `Array<Type->Array<Field>->Void>`.
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.INFO.set( 'path.to.your.Type', ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
	You can request to inspect a type by calling `uhx.macro.KlasImp.inspect('path.to.your.Type', Your.callback)`
	which will run `Your.callback` once the `Type` has been processed by Klas. Your 
	callback should have the type of `Type->Array<Field>->Void`.

1. 	The `ONCE` array will run your callback the first time Klas is initialized. Your
	handler should be of the type `Void->Void`.
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.ONCE.push( ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
2. 	The `DEFAULTS` string map allows you to register your callback which will be run for
	each class that `implements Klas`. Your handler should be of the type 
	`ClassType->Array<Field>->Array<Field>`. The string map key should be unique, 
	it is recommended to use your library path as the key.
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.DEFAULTS.set( 'path.to.your.Cls', ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
3.	The `CLASS_META` string map allows you to register your interest in classes that have a 
	specific metadata attached to them. Your handler should be of the type 
	`ClassType->Array<Field>->Array<Field>`.
	```Haxe
	package path.to.your;
	
	@:metadata('value1', 'value2') class Cls {
		
	}
	```
	
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.CLASS_META.set( ':metadata', ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
4.	The `FIELD_META` string map allows you to register your interest in methods and variables
	that have a specific meta tag attached to them. Your handler should be of the type
	`ClassType->Field->Field`.
	```Haxe
	package path.to.your;
	
	class Cls {
		
		@:metadata public static var hello = 'hello';
		@:metadata public static function main() {}
		
	}
	```
	
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.FIELD_META.set( ':metadata', ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
5.	The `INLINE_META` EReg map allows you to register your interest in methods that contain
	inline metadata. Your handler should be of the type `ClassType->Field->Field`.
	```Haxe
	package path.to.your;
	
	class Cls {
		
		public function new() {}
		
		public function setup():Void {
			var a = @:metadata 100;
		}
		
	}
	```
	
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.INLINE_META.set( ~/@:metadata\s/, ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
6.	The `RETYPE` string map allows you to register a handler which will return a rebuilt type.
	Your handler should be of the type `ClassType->Array<Field>->Null<TypeDefinition>`.
	To trigger a retype, you have to call `uhx.macro.KlasImp.retype('your.Class', ':metadata')`. 
	This should only be called during the macro context.
	```Haxe
	// Hooking into Klas.
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.RETYPE.set( ':metadata', ClsMacro.handler );
		} catch (e:Dynamic) { 
			
		}
	}
	```
	
	```Haxe
	// Triggering a retype.
	private static macro function hello_world():ExprOf<String> {
		uhx.macro.KlasImp.retype('path.to.your.Cls', ':metadata');
		return macro 'Hello World';
	}
	```

## Build order

1.	`INFO`
1.	`ONCE`
2.	`CLASS_META`
3.	`FIELD_META`
4.	`INLINE_META`
5.	`DEFAULTS`
6.	`RETYPE`

The `INFO` hook _might_ be processed before all other hooks.

`RETYPE` will only run after `DEFAULTS` if any pending calls to `uhx.macro.KlasImp.retype` exist.
Otherwise it runs whenever it is called with `uhx.macro.KlasImp.retype`.

## Example

The following `initialize`, `build` and `handler` methods are taken from [Wait.hx].

```Haxe
	private static function initialize() {
		try {
			KlasImp.initialize();
			KlasImp.INLINE_META.set( ~/@:wait\s/, Wait.handler );
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.macro.Wait.build()` method.
		}
	}
	
	public static function build():Array<Field> {
		var cls = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		
		for (i in 0...fields.length) {
			fields[i] = handler( cls, fields[i] );
		}
		
		return fields;
	}
	
	public static function handler(cls:ClassType, field:Field):Field {
		switch(field.kind) {
			case FFun(method) if (method.expr != null): loop( method.expr );
			case _:
		}
		
		return field;
	}
```

[wait.hx]: https://github.com/skial/wait/blob/master/src/uhx/macro/Wait.hx "Wait.hx"

	
## Libraries Using Klas

1.	[yield](https://github.com/skial/yield)
2.	[wait](https://github.com/skial/wait)
3.	[cmd](https://github.com/skial/cmd)
4.	[named](https://github.com/skial/named)
5.	[seri](https://github.com/skial/seri)
6.	[3rd_klas](https://github.com/skial/3rd_klas)