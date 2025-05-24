// Constants
const String defaultDelimiter = '/';
String noopValue(String value) => value;
final RegExp idStart = RegExp(
  r'^[$_\p{ID_Start}]$',
  unicode: true,
);
final RegExp idContinue = RegExp(
  r'^[$\u200c\u200d\p{ID_Continue}]$',
  unicode: true,
);
var DEBUG_URL = 'https://git.new/pathToRegexpError'; // For error messages

// Type Aliases
typedef Encode = String Function(String value);
typedef Decode = String Function(String value);

// Options Classes
class ParseOptions {
  final Encode? encodePath;

  ParseOptions({this.encodePath});
}

class PathToRegexpOptions {
  final bool? end;
  final bool? trailing;
  final bool? sensitive;
  final String? delimiter;

  PathToRegexpOptions({
    this.end,
    this.trailing,
    this.sensitive,
    this.delimiter,
  });
}

class MatchOptions implements PathToRegexpOptions {
  @override
  final bool? end;
  @override
  final bool? trailing;
  @override
  final bool? sensitive;
  @override
  final String? delimiter;
  final dynamic decode; // Can be Decode function or `false`

  MatchOptions({
    this.end,
    this.trailing,
    this.sensitive,
    this.delimiter,
    this.decode,
  });
}

class CompileOptions {
  final dynamic encode; // Can be Encode function or `false`
  final String? delimiter;

  CompileOptions({this.encode, this.delimiter});
}

// Token Types Enum
enum TokenType {
  openBrace, // {
  closeBrace, // }
  wildcard,
  param,
  char,
  escaped,
  end,
  openParen, // (
  closeParen, // )
  openBracket, // [
  closeBracket, // ]
  plus,
  question,
  bang,
}

// LexToken Class
class LexToken {
  final TokenType type;
  final int index;
  final String value;

  LexToken({required this.type, required this.index, required this.value});

  @override
  String toString() => 'LexToken(type: $type, index: $index, value: "$value")';
}

final Map<String, TokenType> simpleTokens = {
  '{': TokenType.openBrace,
  '}': TokenType.closeBrace,
  '(': TokenType.openParen,
  ')': TokenType.closeParen,
  '[': TokenType.openBracket,
  ']': TokenType.closeBracket,
  '+': TokenType.plus,
  '?': TokenType.question,
  '!': TokenType.bang,
};

// Escape Functions
String escapeText(String str) {
  return str.replaceAllMapped(
      RegExp(r'[{}()\[\]+?!:*]'), (match) => '\\${match[0]}');
}

String escape(String str) {
  return str.replaceAllMapped(
      RegExp(r'[.+*?^${}()[\]|/\\]'), (match) => '\\${match[0]}');
}

/// Tokenize input string.
Iterable<LexToken> lexer(String str) sync* {
  final List<String> chars = str.split('');
  int i = 0;

  String name() {
    String value = "";
    final int initialI = i;

    // Check for ID_START and ID_CONTINUE for unquoted names
    // `i` is already positioned at the character *after* ':' or '*'
    if (i < chars.length && idStart.test(chars[i])) {
      value += chars[i];
      i++; // Consume the first character of the name
      while (i < chars.length && idContinue.test(chars[i])) {
        value += chars[i];
        i++; // Consume subsequent characters of the name
      }
    } else if (i < chars.length && chars[i] == '"') {
      int pos = i;
      i++; // Move past the opening quote

      while (i < chars.length) {
        if (chars[i] == '"') {
          i++;
          pos = 0; // Mark as successfully terminated
          break;
        }

        if (chars[i] == "\\") {
          if (i + 1 < chars.length) {
            value += chars[i + 1];
            i++; // Move past the escaped character
          } else {
            throw TypeError('Unterminated escape sequence at ${i}: $DEBUG_URL');
          }
        } else {
          value += chars[i];
        }
        i++;
      }

      if (pos != 0) {
        throw TypeError('Unterminated quote at ${pos}: $DEBUG_URL');
      }
    } else {
      // If we are at ':' or '*' and the next char doesn't start an ID,
      // or if it's not a quoted string, it's an error.
      // The `initialI` here refers to the index of ':' or '*'
      throw TypeError('Missing parameter name at ${initialI}: $DEBUG_URL');
    }

    if (value.isEmpty) {
      throw TypeError('Missing parameter name at ${initialI}: $DEBUG_URL');
    }

    return value;
  }

  while (i < chars.length) {
    final String charValue = chars[i];
    final int tokenIndex = i; // Store the starting index for the current token

    // Using a switch statement for better readability with the enum
    switch (charValue) {
      case "{":
        yield LexToken(
            type: TokenType.openBrace, index: tokenIndex, value: charValue);
        i++;
        break;
      case "}":
        yield LexToken(
            type: TokenType.closeBrace, index: tokenIndex, value: charValue);
        i++;
        break;
      case "(":
        yield LexToken(
            type: TokenType.openParen, index: tokenIndex, value: charValue);
        i++;
        break;
      case ")":
        yield LexToken(
            type: TokenType.closeParen, index: tokenIndex, value: charValue);
        i++;
        break;
      case "[":
        yield LexToken(
            type: TokenType.openBracket, index: tokenIndex, value: charValue);
        i++;
        break;
      case "]":
        yield LexToken(
            type: TokenType.closeBracket, index: tokenIndex, value: charValue);
        i++;
        break;
      case "+":
        yield LexToken(
            type: TokenType.plus, index: tokenIndex, value: charValue);
        i++;
        break;
      case "?":
        yield LexToken(
            type: TokenType.question, index: tokenIndex, value: charValue);
        i++;
        break;
      case "!":
        yield LexToken(
            type: TokenType.bang, index: tokenIndex, value: charValue);
        i++;
        break;
      case "\\":
        i++; // Move past the backslash
        if (i < chars.length) {
          yield LexToken(
              type: TokenType.escaped, index: tokenIndex, value: chars[i]);
          i++; // Move past the escaped character
        } else {
          throw TypeError(
              'Unexpected end of input after escape character at ${tokenIndex}: $DEBUG_URL');
        }
        break;
      case ":":
        i++; // Move past the ":"
        final String paramName = name();
        yield LexToken(
            type: TokenType.param, index: tokenIndex, value: paramName);
        // `name()` already advanced `i` past the name.
        break;
      case "*":
        i++; // Move past the "*"
        final String wildcardName = name();
        yield LexToken(
            type: TokenType.wildcard, index: tokenIndex, value: wildcardName);
        // `name()` already advanced `i` past the name.
        break;
      default:
        yield LexToken(
            type: TokenType.char, index: tokenIndex, value: charValue);
        i++;
        break;
    }
  }

  yield LexToken(type: TokenType.end, index: i, value: "");
}

class TypeError implements Exception {
  final String message;

  TypeError(this.message);

  @override
  String toString() => 'TypeError: $message ($DEBUG_URL)';
}

// Define SIMPLE_TOKENS (example, adjust based on your actual JS definition)
const Map<String, String> SIMPLE_TOKENS = {
  "/": "SLASH",
  "(": "OPEN",
  ")": "CLOSE",
  "?": "QUESTION",
  "+": "PLUS",
};

// Iter Class
class Iter {
  LexToken? _peekedToken;
  final Iterator<LexToken> _tokensIterator;

  Iter(Iterable<LexToken> tokens) : _tokensIterator = tokens.iterator;

  LexToken peek() {
    if (_peekedToken == null) {
      if (_tokensIterator.moveNext()) {
        _peekedToken = _tokensIterator.current;
      } else {
        // Should ideally not happen if lexer always yields END and then stops.
        // If this is reached, it means peek() was called after END was consumed.
        throw StateError(
            'Cannot peek on exhausted token stream. Lexer did not provide END or it was consumed.');
      }
    }
    return _peekedToken!;
  }

  String? tryConsume(TokenType type) {
    final currentToken = peek();
    if (currentToken.type != type) return null;
    _peekedToken = null; // Reset peeked token after consumption
    return currentToken.value;
  }

  String consume(TokenType type) {
    final value = tryConsume(type);
    if (value != null) return value;
    final nextToken = peek();
    throw FormatException(
        'Unexpected ${nextToken.type} at ${nextToken.index}, expected $type ($DEBUG_URL)');
  }

  String text() {
    StringBuffer result = StringBuffer();
    String? value;
    while (true) {
      value = tryConsume(TokenType.char);
      if (value != null) {
        result.write(value);
        continue;
      }
      value = tryConsume(TokenType.escaped);
      if (value != null) {
        result.write(value);
        continue;
      }
      break;
    }
    return result.toString();
  }
}

// Token Interface and Implementations
abstract class Token {
  const Token();
}

abstract class KeyToken extends Token {
  String get name;
}

class TextToken extends Token {
  final String value;
  TextToken({required this.value});
  @override
  String toString() => 'TextToken(value: "$value")';
}

class ParameterToken extends KeyToken {
  @override
  final String name;
  ParameterToken({required this.name});
  @override
  String toString() => 'ParameterToken(name: "$name")';
}

class WildcardToken extends KeyToken {
  @override
  final String name;
  WildcardToken({required this.name});
  @override
  String toString() => 'WildcardToken(name: "$name")';
}

class GroupToken extends Token {
  final List<Token> tokens;
  GroupToken({required this.tokens});
  @override
  String toString() => 'GroupToken(tokens: $tokens)';
}

typedef Keys = List<KeyToken>;

// TokenData Class
class TokenData {
  final List<Token> tokens;
  TokenData(this.tokens);
}

// Parse Function
TokenData parse(String str, [ParseOptions? options]) {
  final encodePath = options?.encodePath ?? noopValue;
  final it = Iter(lexer(str));

  List<Token> consumeInternal(TokenType endType) {
    final List<Token> tokens = [];
    while (true) {
      final pathText = it.text();
      if (pathText.isNotEmpty) {
        tokens.add(TextToken(value: encodePath(pathText)));
      }

      String? paramName = it.tryConsume(TokenType.param);
      if (paramName != null) {
        tokens.add(ParameterToken(name: paramName));
        continue;
      }

      String? wildcardName = it.tryConsume(TokenType.wildcard);
      if (wildcardName != null) {
        tokens.add(WildcardToken(name: wildcardName));
        continue;
      }

      String? openBrace = it.tryConsume(TokenType.openBrace);
      if (openBrace != null) {
        tokens.add(GroupToken(tokens: consumeInternal(TokenType.closeBrace)));
        continue;
      }

      it.consume(endType);
      return tokens;
    }
  }

  final tokens = consumeInternal(TokenType.end);
  return TokenData(tokens);
}

// ParamData and PathFunction types
typedef ParamData
    = Map<String, dynamic>; // Values can be String or List<String>
typedef PathFunction<P extends ParamData> = String Function([P? data]);

List<dynamic> Function(ParamData) _tokenToFunction(
  Token token,
  String delimiter,
  Encode actualEncodeFunction,
  bool encodeWasOriginallyFalse,
) {
  if (token is TextToken) return (ParamData data) => [token.value];

  if (token is GroupToken) {
    final fn = _tokensToFunction(token.tokens, delimiter, actualEncodeFunction,
        encodeWasOriginallyFalse);
    return (ParamData data) {
      final result = fn(data);
      final String value = result[0] as String;
      // All other elements in result are missing parameters.
      final bool missingParamsInGroup = result.length > 1 &&
          result.sublist(1).any((m) => m != null && m != "");

      if (!missingParamsInGroup && value.isNotEmpty) return [value];
      if (!missingParamsInGroup && value.isEmpty && token.tokens.isEmpty)
        return [value]; // Empty group "{}" case
      return [
        ""
      ]; // If group has missing params or resolves to empty undesirably.
    };
  }

  final keyToken = token as KeyToken;

  if (keyToken is WildcardToken && !encodeWasOriginallyFalse) {
    return (ParamData data) {
      final dynamic value = data[keyToken.name];
      if (value == null) return ["", keyToken.name];

      if (value is! List || value.isEmpty) {
        throw FormatException(
            'Expected "${keyToken.name}" to be a non-empty array');
      }

      return [
        value.map((item) {
          if (item is! String) {
            final itemIndex = value.indexOf(item);
            throw FormatException(
                'Expected "${keyToken.name}/$itemIndex" to be a string');
          }
          return actualEncodeFunction(item);
        }).join(delimiter)
      ];
    };
  }

  return (ParamData data) {
    final dynamic value = data[keyToken.name];
    if (value == null) return ["", keyToken.name];

    if (value is! String) {
      throw FormatException('Expected "${keyToken.name}" to be a string');
    }
    return [actualEncodeFunction(value)];
  };
}

List<dynamic> Function(ParamData) _tokensToFunction(
  List<Token> tokens,
  String delimiter,
  Encode encodeFunction,
  bool encodeDisabled,
) {
  final encoders = tokens
      .map((token) =>
          _tokenToFunction(token, delimiter, encodeFunction, encodeDisabled))
      .toList();

  return (ParamData data) {
    final List<dynamic> result = [
      ""
    ]; // First element is path string, rest are missing params
    StringBuffer pathBuffer = StringBuffer();

    for (final encoder in encoders) {
      final List<dynamic> encodeResult = encoder(data);
      pathBuffer.write(encodeResult[0] as String);
      if (encodeResult.length > 1) {
        result.addAll(encodeResult
            .sublist(1)
            .where((item) => item != null && item != ""));
      }
    }
    result[0] = pathBuffer.toString();
    return result;
  };
}

// Compile Function
PathFunction<P> compile<P extends ParamData>(Object path, // String or TokenData
    [CompileOptions? compileOptions,
    ParseOptions? parseOptions]) {
  final String effectiveDelimiter =
      compileOptions?.delimiter ?? defaultDelimiter;

  Encode effectiveEncodeFn;
  bool encodeWasFalse = false;

  if (compileOptions?.encode == false) {
    effectiveEncodeFn = noopValue;
    encodeWasFalse = true;
  } else if (compileOptions?.encode is Encode) {
    effectiveEncodeFn = compileOptions!.encode as Encode;
  } else {
    effectiveEncodeFn = Uri.encodeComponent; // Default
  }

  final TokenData data = path is TokenData
      ? path
      : parse(path as String, parseOptions ?? ParseOptions());
  final pathBuilderFn = _tokensToFunction(
      data.tokens, effectiveDelimiter, effectiveEncodeFn, encodeWasFalse);

  return ([P? params]) {
    final p = params ?? <String, dynamic>{} as P;
    final result = pathBuilderFn(p);
    final String pathString = result[0] as String;
    final List<String> missing = result.sublist(1).whereType<String>().toList();

    if (missing.isNotEmpty) {
      throw FormatException(
          'Missing parameters: ${missing.join(", ")} ($DEBUG_URL)');
    }
    return pathString;
  };
}

// MatchResult, Match, MatchFunction types
class MatchResult<P extends ParamData> {
  final String path;
  final P params;
  MatchResult({required this.path, required this.params});
}

typedef MatchFunction<P extends ParamData> = MatchResult<P>? Function(
    String path);

// Path type for function signatures is `Object`
// (String, TokenData, or List of these)

class RegexpResult {
  final RegExp regexp;
  final Keys keys;
  RegexpResult({required this.regexp, required this.keys});
}

// pathToRegexp, flat, flatten, toRegExp, negate functions
typedef FlattenedToken = Token; // TextToken, ParameterToken, or WildcardToken

Iterable<List<FlattenedToken>> _flatten(
    List<Token> tokens, int index, List<FlattenedToken> init) sync* {
  if (index == tokens.length) {
    yield List<FlattenedToken>.from(init); // Yield a copy
    return;
  }

  final token = tokens[index];
  List<FlattenedToken> initForFinalRecursiveCall;

  if (token is GroupToken) {
    for (final List<FlattenedToken> seq
        in _flatten(token.tokens, 0, List<FlattenedToken>.from(init))) {
      yield* _flatten(tokens, index + 1, seq);
    }
    initForFinalRecursiveCall =
        init; // Use original init for the "final" call path
  } else {
    final List<FlattenedToken> newInit = List<FlattenedToken>.from(init);
    if (token is TextToken ||
        token is ParameterToken ||
        token is WildcardToken) {
      newInit.add(token);
    }
    initForFinalRecursiveCall = newInit; // Use modified init
  }
  yield* _flatten(tokens, index + 1, initForFinalRecursiveCall);
}

Iterable<List<FlattenedToken>> _flat(
    Object pathOrPaths, ParseOptions options) sync* {
  if (pathOrPaths is List) {
    for (final p in pathOrPaths) {
      yield* _flat(p, options);
    }
    return;
  }

  final TokenData data = pathOrPaths is TokenData
      ? pathOrPaths
      : parse(pathOrPaths as String, options);
  yield* _flatten(data.tokens, 0, []);
}

String _negate(String delimiter, String backtrack) {
  final escDelimiter = escape(delimiter);
  final escBacktrack = escape(backtrack);

  if (backtrack.length < 2) {
    if (delimiter.length < 2) {
      return '[^${escape(delimiter + backtrack)}]';
    }
    return '(?:(?!$escDelimiter)[^$escBacktrack])';
  }
  if (delimiter.length < 2) {
    return '(?:(?!$escBacktrack)[^$escDelimiter])';
  }
  return '(?:(?!$escBacktrack|$escDelimiter)[\\s\\S])';
}

String _toRegExp(List<FlattenedToken> tokens, String delimiter, Keys keys) {
  StringBuffer result = StringBuffer();
  String backtrack = "";
  bool isSafeSegmentParam = true;

  for (final token in tokens) {
    if (token is TextToken) {
      result.write(escape(token.value));
      backtrack += token.value;
      isSafeSegmentParam =
          isSafeSegmentParam || token.value.contains(delimiter);
      continue;
    }

    final keyToken = token as KeyToken;
    if (!isSafeSegmentParam && backtrack.isEmpty) {
      throw FormatException(
          'Missing text after "${keyToken.name}" ($DEBUG_URL)');
    }

    if (keyToken is ParameterToken) {
      result.write(
          '(${_negate(delimiter, isSafeSegmentParam ? "" : backtrack)}+)');
    } else {
      // WildcardToken
      result.write(r'([\s\S]+)');
    }

    keys.add(keyToken);
    backtrack = "";
    isSafeSegmentParam = false;
  }
  return result.toString();
}

RegexpResult pathToRegexp(Object path, // String, TokenData, or List of these
    [PathToRegexpOptions? ptro,
    ParseOptions? po]) {
  final effectivePtro = ptro ?? PathToRegexpOptions();
  final effectivePo = po ?? ParseOptions();

  final String delimiter = effectivePtro.delimiter ?? defaultDelimiter;
  final bool end = effectivePtro.end ?? true;
  final bool sensitive = effectivePtro.sensitive ?? false;
  final bool trailing = effectivePtro.trailing ?? true;

  final Keys keys = [];
  final List<String> sources = [];

  for (final List<FlattenedToken> seq in _flat(path, effectivePo)) {
    sources.add(_toRegExp(seq, delimiter, keys));
  }

  String pattern = '^(?:${sources.join("|")})';
  if (trailing) pattern += '(?:${escape(delimiter)})?';
  pattern += end ? r'$' : '(?=${escape(delimiter)}|\$)';

  final RegExp regexp =
      RegExp(pattern, caseSensitive: sensitive, unicode: true);
  return RegexpResult(regexp: regexp, keys: keys);
}

MatchFunction<P> match<P extends ParamData>(Object pathOrPaths,
    [MatchOptions? matchOptions, ParseOptions? parseOptions]) {
  final effectiveMatchOpts = matchOptions ?? MatchOptions();
  final effectiveParseOpts = parseOptions ?? ParseOptions();

  Decode effectiveDecodeFn;
  bool decodeOptionIsFalse = false;

  if (effectiveMatchOpts.decode == false) {
    effectiveDecodeFn = noopValue;
    decodeOptionIsFalse = true;
  } else if (effectiveMatchOpts.decode is Decode) {
    effectiveDecodeFn = effectiveMatchOpts.decode as Decode;
  } else {
    effectiveDecodeFn = Uri.decodeComponent;
  }

  final String delimiter = effectiveMatchOpts.delimiter ?? defaultDelimiter;

  final PathToRegexpOptions ptro = PathToRegexpOptions(
    end: effectiveMatchOpts.end,
    trailing: effectiveMatchOpts.trailing,
    sensitive: effectiveMatchOpts.sensitive,
    delimiter: delimiter,
  );

  final RegexpResult regexpResult =
      pathToRegexp(pathOrPaths, ptro, effectiveParseOpts);
  final RegExp regexp = regexpResult.regexp;
  final Keys keys = regexpResult.keys;

  final List<Function> decoders = keys.map((key) {
    if (decodeOptionIsFalse) return noopValue;
    if (key is ParameterToken) return effectiveDecodeFn;
    return (String value) =>
        value.split(delimiter).map((s) => effectiveDecodeFn(s)).toList();
  }).toList();

  return (String input) {
    final RegExpMatch? m = regexp.firstMatch(input);
    if (m == null) return null;

    final String matchedPath = m[0]!;
    final P params = <String, dynamic>{} as P;

    for (int i = 0; i < keys.length; i++) {
      // RegExp match groups are 1-indexed for captured groups. m[0] is full match.
      // keys are 0-indexed.
      final String? groupValue =
          (i + 1 < m.groupCount + 1) ? m.group(i + 1) : null;
      if (groupValue == null) continue;

      final KeyToken key = keys[i];
      final Function decoder = decoders[i];
      (params as Map<String, dynamic>)[key.name] = decoder(groupValue);
    }
    return MatchResult<P>(path: matchedPath, params: params);
  };
}

// Stringify Functions
bool _isNameSafe(String name) {
  // Simplified check: if it doesn't contain characters that would break parsing
  // or require quoting, consider it safe. This is a broader interpretation
  // than the original JS which relies on Unicode property escapes.
  if (name.isEmpty) return false;
  // Check for common problematic characters or if it looks like a quoted string already
  if (RegExp(r'["\\\s{}:*+?()[\]!]').hasMatch(name) ||
      name.startsWith('"') ||
      name.endsWith('"')) {
    return false;
  }
  // Further check if it might be purely numeric, which often needs quoting in paths
  if (RegExp(r'^\d+$').hasMatch(name)) return false;
  return true;
}

bool _isNextNameSafe(Token? token) {
  if (token == null || token is! TextToken) return true;
  if (token.value.isEmpty) return true;
  return !idContinue.hasMatch(token.value[0]); // Simplified idContinue
}

String stringify(TokenData data) {
  String stringifyTokenInternal(Token token, int index, List<Token> allTokens) {
    if (token is TextToken)
      return token.value; // Changed: Don't escape text tokens
    if (token is GroupToken) {
      return '{${token.tokens.asMap().entries.map((e) => stringifyTokenInternal(e.value, e.key, token.tokens)).join("")}}';
    }

    final keyToken = token as KeyToken;
    final Token? nextToken =
        (index + 1 < allTokens.length) ? allTokens[index + 1] : null;

    final bool isSafe =
        _isNameSafe(keyToken.name) && _isNextNameSafe(nextToken);
    // For a true equivalent of JSON.stringify(name) for unsafe names:
    // final String key = isSafe ? keyToken.name : jsonEncode(keyToken.name);
    // Using a simpler version here for brevity, but jsonEncode is more robust.
    final String key = isSafe
        ? keyToken.name
        : '"${keyToken.name.replaceAllMapped(RegExp(r'"|\\'), (m) => '\\${m[0]}')}"';

    if (keyToken is ParameterToken) return ':$key';
    if (keyToken is WildcardToken) return '*$key';
    throw FormatException('Unexpected token: $token ($DEBUG_URL)');
  }

  return data.tokens.asMap().entries.map((entry) {
    return stringifyTokenInternal(entry.value, entry.key, data.tokens);
  }).join('');
}

extension on RegExp {
  bool test(String input) {
    return this.hasMatch(input);
  }
}
