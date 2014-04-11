# Klas

Klas gives you more control on the order build macros are run. With Klas you only
have to add `implements Klas` to your class and any build macro that self registars
with Klas can be accessed through macro metadata.

## Installation

1. klas:
	+ git - `haxelib git klas https://github.com/skial/klas master src`
	+ zip:
		* download - `https://github.com/skial/klas/archive/master.zip`
		* install - `haxelib local master.zip`
		
## Setup

Add `implements Klas` to any class. Make sure `-lib klas` is in your `.hxml` build
file.

## Register a build macro with Klas

To add your build macro to Klas you need to do two thing.s

1.	Add the following `initialize` method to your build macro.

	```Haxe
	private static function initialize() {
		try {
			KlasImp.initalize();
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `you.macro.Class.build()` method.
		}
	}
	```
	
2.	You should also provide a normal entry point for people not using Klas, who will
	be using `@:autoBuild` or `@:build` metadata.
3. 	If your build macro doesnt already have an `extraParams.hxml` file, create one
	in the root of your macro library.
4.	Add `--macro path.to.your.Class.initialize()` to your `.hxml` build file.
5.	Any one using Klas and your macro library, with all the correct `-lib` 
	entries should automatically bootstrap themselves into Klas.
	
## Klas hooks

Klas provides the following hooks/variables you can register with.

1. 	The `ONCE` array will run your callback the first time Klas is initialized.
2. 	The `DEFAULTS` string map allows you to register your callback which will be run for
	each class that `implements Klas`. Your handler should be of the type `Void->Void`.
3.	The `CLASS_META` string map allows you to register your interest in classes that have a 
	specific meta tag attached to them. Your handler should be of the type 
	`ClassType->Array<Field>->Array<Field>`.
4.	The `FIELD_META` string map allows you to register your interest in methods and variables
	that have a specific meta tag attached to them. Your handler should be of the type
	`ClassType->Field->Field`.
5.	The `INLINE_META` ereg map allows you to register your interest in methods that contain an
	inline meta tag, eg `var a = @:metadata 100;` Your handler should be of the type
	`ClassType->Field->Field`.
	
You would place the hook after the line `KlasImp.initalize();` in your `initialize` method.

The following `initialize`, `build` and `handler` methods are taken from [Wait.hx].

```Haxe
	private static function initialize() {
		try {
			KlasImp.initalize();
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
