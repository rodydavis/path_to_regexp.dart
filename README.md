# path_to_regexp_dart

> A Dart port of the popular JavaScript `path-to-regexp` library. Turn a path string such as `/user/:name` into a regular expression.

This is a pure Dart package.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  path_to_regexp: ^latest # Replace with the latest version
```

Then, run `dart pub get` or `flutter pub get`.

## Usage

Import the package:

```dart
import 'package:path_to_regexp/path_to_regexp.dart';
```

### Core Functions:

*   **`parse(String path, [ParseOptions? options])`**: Parses a path string into a list of tokens.
*   **`compile<P extends ParamData>(Object pathOrTokens, [CompileOptions? options])`**: Compiles a path string or tokens into a function that can generate paths.
*   **`pathToRegexp(Object pathOrTokens, [PathToRegexpOptions? options])`**: Converts a path string or tokens into a `RegExp` and a list of parameter keys.
*   **`match<P extends ParamData>(Object pathOrPaths, [MatchOptions? options])`**: Creates a function to match paths against a compiled pattern.
*   **`stringify(TokenData data)`**: Transforms `TokenData` (a sequence of tokens) back into a Path-to-RegExp string.


### Parameters

Parameters match arbitrary strings in a path by matching up to the end of the segment, or up to any proceeding tokens. They are defined by prefixing a colon to the parameter name (`:foo`). Parameter names can use any valid Dart identifier, or be double quoted to use other characters (`:"param-name"`).

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final matcher = match('/:foo/:bar');
  final result = matcher('/test/route');

  if (result != null) {
    print('Path: ${result.path}'); // Path: /test/route
    print('Params: ${result.params}'); // Params: {foo: test, bar: route}
  }
}
```

### Wildcard

Wildcard parameters match one or more characters across multiple segments. They are defined the same way as regular parameters, but are prefixed with an asterisk (`*foo`).

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final matcher = match('/*splat');
  final result = matcher('/bar/baz');

  if (result != null) {
    print('Path: ${result.path}'); // Path: /bar/baz
    print('Params: ${result.params}'); // Params: {splat: [bar, baz]}
  }
}
```

### Optional

Braces can be used to define parts of the path that are optional.

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final matcher = match('/users{/:id}/delete');

  var result = matcher('/users/delete');
  if (result != null) {
    print('Path: ${result.path}'); // Path: /users/delete
    print('Params: ${result.params}'); // Params: {}
  }

  result = matcher('/users/123/delete');
  if (result != null) {
    print('Path: ${result.path}'); // Path: /users/123/delete
    print('Params: ${result.params}'); // Params: {id: 123}
  }
}
```

## Match

The `match` function returns a function for matching strings against a path:

-   **`pathOrPaths`**: `String`, `TokenData`, or `List` of these.
-   **`options`** _(optional)_: `MatchOptions`
    -   **`decode`**: `Decode` function for decoding strings to params, or `false` to disable all processing. (default: `Uri.decodeComponent`)
    -   **`sensitive`**: `bool` - Regexp will be case sensitive. (default: `false`)
    -   **`trailing`**: `bool` - Allows optional trailing delimiter to match. (default: `true`)
    -   **`end`**: `bool` - Validate the match reaches the end of the string. (default: `true`)
    -   **`delimiter`**: `String` - The default delimiter for segments. (default: `'/'`)


```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final matcher = match('/foo/:bar');
  final result = matcher('/foo/baz');
  if (result != null) {
    print(result.params['bar']); // baz
  }
}
```

**Please note:** `path_to_regexp` is intended for ordered data (e.g. paths, hosts). It cannot handle arbitrarily ordered data (e.g. query strings, URL fragments, JSON, etc).

## PathToRegexp

The `pathToRegexp` function returns a `RegexpResult` containing the `RegExp` for matching strings against paths, and a list of `KeyToken`s for understanding the `RegExp.allMatches` results.

-   **`path`**: `String`, `TokenData`, or `List` of these.
-   **`options`** _(optional)_: `PathToRegexpOptions`
    -   **`sensitive`**: `bool` - Regexp will be case sensitive. (default: `false`)
    -   **`trailing`**: `bool` - Allows optional trailing delimiter to match. (default: `true`)
    -   **`end`**: `bool` - Validate the match reaches the end of the string. (default: `true`)
    -   **`delimiter`**: `String` - The default delimiter for segments. (default: `'/'`)


```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final result = pathToRegexp('/foo/:bar');
  final regExp = result.regExp;
  final keys = result.keys;

  final match = regExp.firstMatch('/foo/123');
  if (match != null) {
    print(match.group(0)); // /foo/123
    print(match.group(1)); // 123
    print(keys[0].name);   // bar
  }
}
```

## Compile ("Reverse" Path-To-RegExp)

The `compile` function will return a function for transforming parameters (`ParamData`) into a valid path:

-   **`path`**: `String` or `TokenData`.
-   **`options`** _(optional)_: `CompileOptions`
    -   **`encode`**: `Encode` function for encoding input strings for output into the path, or `false` to disable entirely. (default: `Uri.encodeComponent`)
    -   **`delimiter`**: `String` - The default delimiter for segments. (default: `'/'`)

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final toPath = compile('/user/:id');

  print(toPath({'id': 'name'})); // /user/name
  print(toPath({'id': 'café'})); // /user/caf%C3%A9

  final toPathRepeated = compile('/*segment');
  print(toPathRepeated({'segment': ['foo']})); // /foo
  print(toPathRepeated({'segment': ['a', 'b', 'c']})); // /a/b/c

  // When disabling `encode`, you need to make sure inputs are encoded correctly.
  final toPathRaw = compile('/user/:id', CompileOptions(encode: false));
  print(toPathRaw({'id': '%3A%2F'})); // /user/%3A%2F
}
```

## Stringify

Transform `TokenData` (a sequence of tokens) back into a Path-to-RegExp string.

-   **`data`**: A `TokenData` instance

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final data = TokenData([
    TextToken(value: '/'),
    ParameterToken(name: 'foo'),
  ]);

  final path = stringify(data);
  print(path); // /:foo
}
```

## Developers

### Parse

The `parse` function accepts a string and returns `TokenData`, which can be used with `match` and `compile`.

-   **`path`**: A string.
-   **`options`** _(optional)_: `ParseOptions`
    -   **`encodePath`**: An `Encode` function for encoding input strings. (default: `(value) => value`)

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final tokenData = parse('/:foo/:bar');
  // tokenData.tokens will contain a list of TextToken and ParameterToken
  print(tokenData.tokens);
  // Example: [TextToken(value: "/"), ParameterToken(name: "foo"), TextToken(value: "/"), ParameterToken(name: "bar")]
}
```

### Tokens

`TokenData` is a sequence of tokens. The primary token types are:
*   `TextToken({required String value})`
*   `ParameterToken({required String name})`
*   `WildcardToken({required String name})`
*   `GroupToken({required List<Token> tokens})` (represents an optional group)


### Custom path with Tokens

In some applications, you may not be able to use the `path-to-regexp` string syntax directly, but still want to use this library for `match` and `compile`.

```dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  final tokens = [
    TextToken(value: '/'),
    ParameterToken(name: 'foo'),
  ];
  final pathData = TokenData(tokens);
  final matcher = match(pathData);

  final result = matcher('/test');
  if (result != null) {
    print('Path: ${result.path}'); // Path: /test
    print('Index: ${result.index}'); // Index: 0
    print('Params: ${result.params}'); // Params: {foo: test}
  }
}
```

## Running Examples

You can find more examples in the `test/path_to_regexp_test.dart` file. To run a simple example, create a Dart file (e.g., `example/main.dart`):

```dart
// example/main.dart
import 'package:path_to_regexp/path_to_regexp.dart';

void main() {
  // Example from "Parameters" section
  final paramsMatcher = match('/:foo/:bar');
  final paramsResult = paramsMatcher('/test/route');
  if (paramsResult != null) {
    print('Parameters Example:');
    print('  Path: ${paramsResult.path}');
    print('  Params: ${paramsResult.params}');
  }

  // Example from "Compile" section
  final toPath = compile('/user/:id');
  print('\nCompile Example:');
  print('  Path for id "name": ${toPath({'id': 'name'})}');
  print('  Path for id "café": ${toPath({'id': 'café'})}');

  // Example from "PathToRegexp" section
  final regexpResult = pathToRegexp('/product/:id');
  final regExp = regexpResult.regExp;
  final keys = regexpResult.keys;
  final productMatch = regExp.firstMatch('/product/123');
  if (productMatch != null) {
    print('\nPathToRegexp Example:');
    print('  Full match: ${productMatch.group(0)}');
    print('  Group 1 (id): ${productMatch.group(1)}');
    if (keys.isNotEmpty) {
      print('  Key name for group 1: ${keys[0].name}');
    }
  }
}
```
Then run it from your terminal:
```bash
dart run example/main.dart
```

## Errors

The library will throw a `TypeError` for issues like unterminated quotes or missing parameter names. The error message includes a `DEBUG_URL` (`https://git.new/pathToRegexpError`) for more context, though this URL might be more relevant to the original JS library.

### Common Issues (adapted from JS version)

*   **Unexpected `?` or `+`**: In past JS releases, `?`, `*`, and `+` were used for optional/repeating parameters. This Dart version (like modern `path-to-regexp`) uses different syntax:
    *   For optional (`?`), use an empty segment in a group such as `/:file{.:ext}`.
    *   For repeating (`+`), only wildcard matching is supported, such as `/*path`.
    *   For optional repeating (`*`), use a group and a wildcard parameter such as `/files{/*path}`.
*   **Unexpected `(`, `)`, `[`, `]`, etc.**: These characters are reserved. To use them literally, escape them with a backslash, e.g., `'\(`.
*   **Missing parameter name**: Parameter names must be provided after `:` or `*`. If you need a parameter name that isn't a valid Dart identifier (e.g., starts with a number), wrap it in double quotes: `:"my-name"` or `*:"my-wildcard"`.
*   **Unterminated quote**: If you use double quotes for parameter names, ensure they are properly closed.

