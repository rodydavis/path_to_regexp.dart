import 'package:path_to_regexp/path_to_regexp.dart';
import 'package:test/test.dart';

void main() {
  group('parse', () {
    test('should parse /', () {
      final result = parse('/');
      expect(result.tokens.length, 1);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
    });

    test('should parse /:test', () {
      final result = parse('/:test');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, 'test');
    });

    test('should parse /:"0"', () {
      final result = parse('/:"0"');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, '0');
    });

    test('should parse /:_', () {
      final result = parse('/:_');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, '_');
    });

    test('should parse /:café', () {
      final result = parse('/:café');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, 'café');
    });

    test('should parse /:"123"', () {
      final result = parse('/:"123"');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, '123');
    });

    test('should parse /:"1\\"\\2\\"3"', () {
      final result = parse(r'/:"1\"\2\"3"');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, '1"2"3');
    });

    test('should parse /*path', () {
      final result = parse('/*path');
      expect(result.tokens.length, 2);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<WildcardToken>());
      expect((result.tokens[1] as WildcardToken).name, 'path');
    });

    test('should parse /:"test"stuff', () {
      final result = parse('/:"test"stuff');
      expect(result.tokens.length, 3);
      expect(result.tokens[0], isA<TextToken>());
      expect((result.tokens[0] as TextToken).value, '/');
      expect(result.tokens[1], isA<ParameterToken>());
      expect((result.tokens[1] as ParameterToken).name, 'test');
      expect(result.tokens[2], isA<TextToken>());
      expect((result.tokens[2] as TextToken).value, 'stuff');
    });
  });

  group('stringify', () {
    test('should stringify /', () {
      final data = TokenData([TextToken(value: '/')]);
      expect(stringify(data), '/');
    });

    test('should stringify /:test', () {
      final data = TokenData([
        TextToken(value: '/'),
        ParameterToken(name: 'test'),
      ]);
      expect(stringify(data), '/:test');
    });

    test('should stringify /:café', () {
      final data = TokenData([
        TextToken(value: '/'),
        ParameterToken(name: 'café'),
      ]);
      expect(stringify(data), '/:café');
    });

    test('should stringify /:"0"', () {
      final data = TokenData([
        TextToken(value: '/'),
        ParameterToken(name: '0'),
      ]);
      expect(stringify(data), '/:"0"');
    });

    test('should stringify /*test', () {
      final data = TokenData([
        TextToken(value: '/'),
        WildcardToken(name: 'test'),
      ]);
      expect(stringify(data), '/*test');
    });

    test('should stringify /*"0"', () {
      final data = TokenData([
        TextToken(value: '/'),
        WildcardToken(name: '0'),
      ]);
      expect(stringify(data), '/*"0"');
    });

    test('should stringify /users{/:id}/delete', () {
      final data = TokenData([
        TextToken(value: '/users'),
        GroupToken(tokens: [
          TextToken(value: '/'),
          ParameterToken(name: 'id'),
        ]),
        TextToken(value: '/delete'),
      ]);
      expect(stringify(data), '/users{/:id}/delete');
    });

    test('should stringify /\:\+\?\*', () {
      final data = TokenData([TextToken(value: '/:+?*')]);
      expect(stringify(data), '/\:\+\?\*');
    });

    test('should stringify /:"test"stuff', () {
      final data = TokenData([
        TextToken(value: '/'),
        ParameterToken(name: 'test'),
        TextToken(value: 'stuff'),
      ]);
      expect(stringify(data), '/:"test"stuff');
    });
  });

  group('compile', () {
    test('should compile /', () {
      final fn = compile('/');
      expect(fn(), '/');
      expect(fn({}), '/');
      expect(fn({'id': '123'}), '/');
    });

    test('should compile /test', () {
      final fn = compile('/test');
      expect(fn(), '/test');
      expect(fn({}), '/test');
      expect(fn({'id': '123'}), '/test');
    });

    test('should compile /test/', () {
      final fn = compile('/test/');
      expect(fn(), '/test/');
      expect(fn({}), '/test/');
      expect(fn({'id': '123'}), '/test/');
    });

    test('should compile /:"0"', () {
      final fn = compile('/:"0"');
      expect(() => fn(), throwsA(isA<FormatException>()));
      expect(() => fn({}), throwsA(isA<FormatException>()));
      expect(fn({'0': '123'}), '/123');
    });

    test('should compile /:test', () {
      final fn = compile('/:test');
      expect(() => fn(), throwsA(isA<FormatException>()));
      expect(() => fn({}), throwsA(isA<FormatException>()));
      expect(fn({'test': '123'}), '/123');
      expect(fn({'test': '123/xyz'}), '/123%2Fxyz');
    });

    test('should compile /:test with encode false', () {
      final fn = compile('/:test', CompileOptions(encode: false));
      expect(() => fn(), throwsA(isA<FormatException>()));
      expect(() => fn({}), throwsA(isA<FormatException>()));
      expect(fn({'test': '123'}), '/123');
      expect(fn({'test': '123/xyz'}), '/123/xyz');
    });

    test('should compile /:test with custom encode', () {
      final fn = compile('/:test', CompileOptions(encode: (value) => 'static'));
      expect(() => fn(), throwsA(isA<FormatException>()));
      expect(() => fn({}), throwsA(isA<FormatException>()));
      expect(fn({'test': '123'}), '/static');
      expect(fn({'test': '123/xyz'}), '/static');
    });

    test('should compile {/:test} with encode false', () {
      final fn = compile('{/:test}', CompileOptions(encode: false));
      expect(fn(), '');
      expect(fn({}), '');
      expect(fn({'test': null}), '');
      expect(fn({'test': '123'}), '/123');
      expect(fn({'test': '123/xyz'}), '/123/xyz');
    });

    test('should compile /*test', () {
      final fn = compile('/*test');
      expect(() => fn(), throwsA(isA<FormatException>()));
      expect(() => fn({}), throwsA(isA<FormatException>()));
      expect(() => fn({'test': []}), throwsA(isA<FormatException>()));
      expect(fn({'test': ['123']}), '/123');
      expect(fn({'test': ['123', 'xyz']}), '/123/xyz');
    });

    test('should compile /*test with encode false', () {
      final fn = compile('/*test', CompileOptions(encode: false));
      expect(fn({'test': '123'}), '/123');
      expect(fn({'test': '123/xyz'}), '/123/xyz');
    });
  });
}
