// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Patch library for dart:mirrors.

import 'dart:_js_mirrors' as js;

patch class MirrorSystem {
  patch static String getName(Symbol symbol) => js.getName(symbol);

  patch static Symbol getSymbol(String name, [LibraryMirror library]) {
    throw new UnimplementedError("MirrorSystem.getSymbol not implemented");
  }
}

patch MirrorSystem currentMirrorSystem() => js.currentJsMirrorSystem;

patch Future<MirrorSystem> mirrorSystemOf(SendPort port) {
  throw new UnsupportedError("MirrorSystem not implemented");
}

patch InstanceMirror reflect(Object reflectee) => js.reflect(reflectee);

patch ClassMirror reflectClass(Type key) {
  if (key is! Type || key == dynamic) {
    throw new ArgumentError('$key does not denote a class');
  }
  TypeMirror tm = reflectType(key);
  if (tm is! ClassMirror) {
    throw new ArgumentError("$key does not denote a class");
  }
  return (tm as ClassMirror).originalDeclaration;
}

patch TypeMirror reflectType(Type key) => js.reflectType(key);
