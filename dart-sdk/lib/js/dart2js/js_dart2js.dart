// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Support for interoperating with JavaScript.
 * 
 * This library provides access to JavaScript objects from Dart, allowing
 * Dart code to get and set properties, and call methods of JavaScript objects
 * and invoke JavaScript functions. The library takes care of converting
 * between Dart and JavaScript objects where possible, or providing proxies if
 * conversion isn't possible.
 *
 * This library does not yet make Dart objects usable from JavaScript, their
 * methods and proeprties are not accessible, though it does allow Dart
 * functions to be passed into and called from JavaScript.
 *
 * [JsObject] is the core type and represents a proxy of a JavaScript object.
 * JsObject gives access to the underlying JavaScript objects properties and
 * methods. `JsObject`s can be acquired by calls to JavaScript, or they can be
 * created from proxies to JavaScript constructors.
 *
 * The top-level getter [context] provides a [JsObject] that represents the
 * global object in JavaScript, usually `window`.
 *
 * The following example shows an alert dialog via a JavaScript call to the
 * global function `alert()`:
 *
 *     import 'dart:js';
 *     
 *     main() => context.callMethod('alert', ['Hello from Dart!']);
 *
 * This example shows how to create a [JsObject] from a JavaScript constructor
 * and access its properties:
 *
 *     import 'dart:js';
 *     
 *     main() {
 *       var object = new JsObject(context['Object']);
 *       object['greeting'] = 'Hello';
 *       object['greet'] = (name) => "${object['greeting']} $name";
 *       var message = object.callMethod('greet', ['JavaScript']);
 *       context['console'].callMethod('log', [message]);
 *     }
 *
 * ## Proxying and Automatic Conversion
 * 
 * When setting properties on a JsObject or passing arguments to a Javascript
 * method or function, Dart objects are automatically converted or proxied to
 * JavaScript objects. When accessing JavaScript properties, or when a Dart
 * closure is invoked from JavaScript, the JavaScript objects are also
 * converted to Dart.
 *
 * Functions and closures are proxied in such a way that they are callable. A
 * Dart closure assigned to a JavaScript property is proxied by a function in
 * JavaScript. A JavaScript function accessed from Dart is proxied by a
 * [JsFunction], which has a [apply] method to invoke it.
 *
 * The following types are transferred directly and not proxied:
 *
 * * "Basic" types: `null`, `bool`, `num`, `String`, `DateTime`
 * * `Blob`
 * * `KeyRange`
 * * `ImageData`
 * * `TypedData`, including its subclasses like `Int32List`, but _not_
 *   `ByteBuffer`
 * * `Node`
 *
 * ## Converting collections with JsObject.jsify()
 *
 * To create a JavaScript collection from a Dart collection use the
 * [JsObject.jsify] constructor, which converts Dart [Map]s and [Iterable]s
 * into JavaScript Objects and Arrays.
 *
 * The following expression creats a new JavaScript object with the properties
 * `a` and `b` defined:
 *
 *     var jsMap = new JsObject.jsify({'a': 1, 'b': 2});
 * 
 * This expression creates a JavaScript array:
 *
 *     var jsArray = new JsObject.jsify([1, 2, 3]);
 */
library dart.js;

import 'dart:html' show Blob, ImageData, Node;
import 'dart:collection' show HashMap;
import 'dart:indexed_db' show KeyRange;
import 'dart:typed_data' show TypedData;

import 'dart:_foreign_helper' show JS, DART_CLOSURE_TO_JS;
import 'dart:_interceptors' show JavaScriptObject, UnknownJavaScriptObject;
import 'dart:_js_helper' show Primitives, convertDartClosureToJS;

final JsObject context = new JsObject._fromJs(Primitives.computeGlobalThis());

_convertDartFunction(Function f, {bool captureThis: false}) {
  return JS('',
    'function(_call, f, captureThis) {'
      'return function() {'
        'return _call(f, captureThis, this, '
            'Array.prototype.slice.apply(arguments));'
      '}'
    '}(#, #, #)', DART_CLOSURE_TO_JS(_callDartFunction), f, captureThis);
}

_callDartFunction(callback, bool captureThis, self, List arguments) {
  if (captureThis) {
    arguments = [self]..addAll(arguments);
  }
  var dartArgs = arguments.map(_convertToDart).toList();
  return _convertToJS(Function.apply(callback, dartArgs));
}

/**
 * Proxies a JavaScript object to Dart.
 *
 * The properties of the JavaScript object are accessible via the `[]` and
 * `[]=` operators. Methods are callable via [callMethod].
 */
class JsObject {
  // The wrapped JS object.
  final dynamic _jsObject;

  JsObject._fromJs(this._jsObject) {
    assert(_jsObject != null);
    // Remember this proxy for the JS object
    _getDartProxy(_jsObject, _DART_OBJECT_PROPERTY_NAME, (o) => this);
  }

  /**
   * Constructs a new JavaScript object from [constructor] and returns a proxy
   * to it.
   */
  factory JsObject(JsFunction constructor, [List arguments]) {
    var constr = _convertToJS(constructor);
    if (arguments == null) {
      return new JsObject._fromJs(JS('', 'new #()', constr));
    }
    // The following code solves the problem of invoking a JavaScript
    // constructor with an unknown number arguments.
    // First bind the constructor to the argument list using bind.apply().
    // The first argument to bind() is the binding of 'this', so add 'null' to
    // the arguments list passed to apply().
    // After that, use the JavaScript 'new' operator which overrides any binding
    // of 'this' with the new instance.
    var args = [null]..addAll(arguments.map(_convertToJS));
    var factoryFunction = JS('', '#.bind.apply(#, #)', constr, constr, args);
    // Without this line, calling factoryFunction as a constructor throws
    JS('String', 'String(#)', factoryFunction);
    // This could return an UnknownJavaScriptObject, or a native
    // object for which there is an interceptor
    var jsObj = JS('JavaScriptObject', 'new #()', factoryFunction);
    return new JsObject._fromJs(jsObj);
  }

  /**
   * Constructs a [JsObject] that proxies a native Dart object; _for expert use
   * only_.
   *
   * Use this constructor only if you wish to get access to JavaScript
   * properties attached to a browser host object, such as a Node or Blob, that
   * is normally automatically converted into a native Dart object.
   * 
   * An exception will be thrown if [object] either is `null` or has the type
   * `bool`, `num`, or `String`.
   */
  factory JsObject.fromBrowserObject(object) {
    if (object is num || object is String || object is bool || object == null) {
      throw new ArgumentError(
        "object cannot be a num, string, bool, or null");
    }
    return new JsObject._fromJs(_convertToJS(object));
  }

  /**
   * Recursively converts a JSON-like collection of Dart objects to a
   * collection of JavaScript objects and returns a [JsObject] proxy to it.
   *
   * [object] must be a [Map] or [Iterable], the contents of which are also
   * converted. Maps and Iterables are copied to a new JavaScript object.
   * Primitives and other transferrable values are directly converted to their
   * JavaScript type, and all other objects are proxied.
   */
  factory JsObject.jsify(object) {
    if ((object is! Map) && (object is! Iterable)) {
      throw new ArgumentError("object must be a Map or Iterable");
    }
    return new JsObject._fromJs(_convertDataTree(object));
  }

  static _convertDataTree(data) {
    var _convertedObjects = new HashMap.identity();

    _convert(o) {
      if (_convertedObjects.containsKey(o)) {
        return _convertedObjects[o];
      }
      if (o is Map) {
        final convertedMap = JS('=Object', '{}');
        _convertedObjects[o] = convertedMap;
        for (var key in o.keys) {
          JS('=Object', '#[#]=#', convertedMap, key, _convert(o[key]));
        }
        return convertedMap;
      } else if (o is Iterable) {
        var convertedList = [];
        _convertedObjects[o] = convertedList;
        convertedList.addAll(o.map(_convert));
        return convertedList;
      } else {
        return _convertToJS(o);
      }
    }

    return _convert(data);
  }

  /**
   * Returns the value associated with [property] from the proxied JavaScript
   * object.
   *
   * The type of [property] must be either [String] or [num].
   */
  dynamic operator[](property) {
    if (property is! String && property is! num) {
      throw new ArgumentError("property is not a String or num");
    }
    return _convertToDart(JS('', '#[#]', _jsObject, property));
  }
  
  /**
   * Sets the value associated with [property] on the proxied JavaScript
   * object.
   *
   * The type of [property] must be either [String] or [num].
   */
  operator[]=(property, value) {
    if (property is! String && property is! num) {
      throw new ArgumentError("property is not a String or num");
    }
    JS('', '#[#]=#', _jsObject, property, _convertToJS(value));
  }

  int get hashCode => 0;

  bool operator==(other) => other is JsObject &&
      JS('bool', '# === #', _jsObject, other._jsObject);

  /**
   * Returns `true` if the JavaScript object contains the specified property
   * either directly or though its prototype chain.
   *
   * This is the equivalent of the `in` operator in JavaScript.
   */
  bool hasProperty(property) {
    if (property is! String && property is! num) {
      throw new ArgumentError("property is not a String or num");
    }
    return JS('bool', '# in #', property, _jsObject);
  }

  /**
   * Removes [property] from the JavaScript object.
   *
   * This is the equivalent of the `delete` operator in JavaScript.
   */
  void deleteProperty(property) {
    if (property is! String && property is! num) {
      throw new ArgumentError("property is not a String or num");
    }
    JS('bool', 'delete #[#]', _jsObject, property);
  }

  /**
   * Returns `true` if the JavaScript object has [type] in its prototype chain.
   *
   * This is the equivalent of the `instanceof` operator in JavaScript.
   */
  bool instanceof(JsFunction type) {
    return JS('bool', '# instanceof #', _jsObject, _convertToJS(type));
  }

  /**
   * Returns the result of the JavaScript objects `toString` method.
   */
  String toString() {
    try {
      return JS('String', 'String(#)', _jsObject);
    } catch(e) {
      return super.toString();
    }
  }

  /**
   * Calls [method] on the JavaScript object with the arguments [args] and
   * returns the result.
   *
   * The type of [method] must be either [String] or [num].
   */
  dynamic callMethod(method, [List args]) {
    if (method is! String && method is! num) {
      throw new ArgumentError("method is not a String or num");
    }
    return _convertToDart(JS('', '#[#].apply(#, #)', _jsObject, method,
        _jsObject,
        args == null ? null : args.map(_convertToJS).toList()));
  }
}

/**
 * Proxies a JavaScript Function object.
 */
class JsFunction extends JsObject {

  /**
   * Returns a [JsFunction] that captures its 'this' binding and calls [f]
   * with the value of this passed as the first argument.
   */
  factory JsFunction.withThis(Function f) {
    var jsFunc = _convertDartFunction(f, captureThis: true);
    return new JsFunction._fromJs(jsFunc);
  }

  JsFunction._fromJs(jsObject) : super._fromJs(jsObject);

  /**
   * Invokes the JavaScript function with arguments [args]. If [thisArg] is
   * supplied it is the value of `this` for the invocation.
   */
  dynamic apply(List args, { thisArg }) =>
      _convertToDart(JS('', '#.apply(#, #)', _jsObject,
          _convertToJS(thisArg),
          args == null ? null : args.map(_convertToJS).toList()));
}

// property added to a Dart object referencing its JS-side DartObject proxy
const _DART_OBJECT_PROPERTY_NAME = r'_$dart_dartObject';
const _DART_CLOSURE_PROPERTY_NAME = r'_$dart_dartClosure';

// property added to a JS object referencing its Dart-side JsObject proxy
const _JS_OBJECT_PROPERTY_NAME = r'_$dart_jsObject';
const _JS_FUNCTION_PROPERTY_NAME = r'$dart_jsFunction';

bool _defineProperty(o, String name, value) {
  if (JS('bool', 'Object.isExtensible(#)', o)) {
    try {
      JS('void', 'Object.defineProperty(#, #, { value: #})', o, name, value);
      return true;
    } catch(e) {
      // object is native and lies about being extensible
      // see https://bugzilla.mozilla.org/show_bug.cgi?id=775185
    }
  }
  return false;
}

dynamic _convertToJS(dynamic o) {
  if (o == null) {
    return null;
  } else if (o is String || o is num || o is bool
    || o is Blob || o is KeyRange || o is ImageData || o is Node 
    || o is TypedData) {
    return o;
  } else if (o is DateTime) {
    return Primitives.lazyAsJsDate(o);
  } else if (o is JsObject) {
    return o._jsObject;
  } else if (o is Function) {
    return _getJsProxy(o, _JS_FUNCTION_PROPERTY_NAME, (o) {
      var jsFunction = _convertDartFunction(o);
      // set a property on the JS closure referencing the Dart closure
      _defineProperty(jsFunction, _DART_CLOSURE_PROPERTY_NAME, o);
      return jsFunction;
    });
  } else {
    return _getJsProxy(o, _JS_OBJECT_PROPERTY_NAME,
        (o) => JS('', 'new DartObject(#)', o));
  }
}

Object _getJsProxy(o, String propertyName, createProxy(o)) {
  var jsProxy = JS('', '#[#]', o, propertyName);
  if (jsProxy == null) {
    jsProxy = createProxy(o);
    _defineProperty(o, propertyName, jsProxy);
  }
  return jsProxy;
}

// converts a Dart object to a reference to a native JS object
// which might be a DartObject JS->Dart proxy
Object _convertToDart(o) {
  if (JS('bool', '# == null', o) ||
      JS('bool', 'typeof # == "string"', o) ||
      JS('bool', 'typeof # == "number"', o) ||
      JS('bool', 'typeof # == "boolean"', o)) {
    return o;
  } else if (o is Blob || o is KeyRange || o is ImageData || o is Node
    || o is TypedData) {
    return JS('Blob|KeyRange|ImageData|Node|TypedData', '#', o);
  } else if (JS('bool', '# instanceof Date', o)) {
    var ms = JS('num', '#.getMilliseconds()', o);
    return new DateTime.fromMillisecondsSinceEpoch(ms);
  } else if (JS('bool', 'typeof # == "function"', o)) {
    return _getDartProxy(o, _DART_CLOSURE_PROPERTY_NAME,
        (o) => new JsFunction._fromJs(o));
  } else if (JS('bool', '#.constructor === DartObject', o)) {
    return JS('', '#.o', o);
  } else {
    return _getDartProxy(o, _DART_OBJECT_PROPERTY_NAME,
        (o) => new JsObject._fromJs(o));
  }
}

Object _getDartProxy(o, String propertyName, createProxy(o)) {
  var dartProxy = JS('', '#[#]', o, propertyName);
  if (dartProxy == null) {
    dartProxy = createProxy(o);
    _defineProperty(o, propertyName, dartProxy);
  }
  return dartProxy;
}
