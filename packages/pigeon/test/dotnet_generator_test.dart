// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pigeon/src/ast.dart';
import 'package:pigeon/src/dotnet/dotnet_generator.dart';
import 'package:test/test.dart';

const String defaultPackageName = 'test_package';

final Class emptyClass = Class(
  name: 'className',
  fields: <NamedType>[
    NamedType(
      name: 'namedTypeName',
      type: const TypeDeclaration(baseName: 'baseName', isNullable: false),
    ),
  ],
);

void main() {
  test('gen one class', () {
    final Class classDefinition = Class(
      name: 'Foobar',
      fields: <NamedType>[
        NamedType(
          type: const TypeDeclaration(baseName: 'int', isNullable: true),
          name: 'field1',
        ),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[classDefinition],
      enums: <Enum>[],
    );
    final StringBuffer sink = StringBuffer();
    const InternalDotnetOptions options = InternalDotnetOptions(
      className: 'Messages',
      dotnetOut: '',
    );
    const DotnetGenerator generator = DotnetGenerator();
    generator.generate(
      options,
      root,
      sink,
      dartPackageName: defaultPackageName,
    );
    final String code = sink.toString();
    expect(code, contains('public static partial class Messages'));
    expect(code, contains('public sealed class Foobar : IEquatable<Foobar>'));
    expect(code, contains('public long? field1 { get; set; }'));
    expect(code, contains('public static Foobar FromList(IList<object?> list)'));
    expect(code, contains('public List<object?> ToList()'));
  });

  test('gen one enum', () {
    final Enum anEnum = Enum(
      name: 'Foobar',
      members: <EnumMember>[
        EnumMember(name: 'one'),
        EnumMember(name: 'twoThreeFour'),
      ],
    );
    final Root root = Root(
      apis: <Api>[],
      classes: <Class>[],
      enums: <Enum>[anEnum],
    );
    final StringBuffer sink = StringBuffer();
    const InternalDotnetOptions options = InternalDotnetOptions(
      className: 'Messages',
      dotnetOut: '',
    );
    const DotnetGenerator generator = DotnetGenerator();
    generator.generate(
      options,
      root,
      sink,
      dartPackageName: defaultPackageName,
    );
    final String code = sink.toString();
    expect(code, contains('public enum Foobar'));
    expect(code, contains('one = 0'));
    expect(code, contains('twoThreeFour = 1'));
    expect(code, contains('private static Foobar? FoobarOfRaw(int raw)'));
  });

  test('namespace', () {
    final Root root = Root(apis: <Api>[], classes: <Class>[], enums: <Enum>[]);
    final StringBuffer sink = StringBuffer();
    const InternalDotnetOptions options = InternalDotnetOptions(
      className: 'Messages',
      namespace: 'Example.Namespace',
      dotnetOut: '',
    );
    const DotnetGenerator generator = DotnetGenerator();
    generator.generate(
      options,
      root,
      sink,
      dartPackageName: defaultPackageName,
    );
    expect(sink.toString(), contains('namespace Example.Namespace'));
  });

  test('gen one host api', () {
    final Root root = Root(
      apis: <Api>[
        AstHostApi(
          name: 'Api',
          methods: <Method>[
            Method(
              name: 'doSomething',
              location: ApiLocation.host,
              parameters: <Parameter>[
                Parameter(
                  type: TypeDeclaration(
                    baseName: 'Input',
                    associatedClass: emptyClass,
                    isNullable: false,
                  ),
                  name: 'input',
                ),
              ],
              returnType: TypeDeclaration(
                baseName: 'Output',
                associatedClass: emptyClass,
                isNullable: false,
              ),
            ),
          ],
        ),
      ],
      classes: <Class>[
        Class(
          name: 'Input',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'input',
            ),
          ],
        ),
        Class(
          name: 'Output',
          fields: <NamedType>[
            NamedType(
              type: const TypeDeclaration(baseName: 'String', isNullable: true),
              name: 'output',
            ),
          ],
        ),
      ],
      enums: <Enum>[],
      containsHostApi: true,
    );
    final StringBuffer sink = StringBuffer();
    const InternalDotnetOptions options = InternalDotnetOptions(
      className: 'Messages',
      dotnetOut: '',
    );
    const DotnetGenerator generator = DotnetGenerator();
    generator.generate(
      options,
      root,
      sink,
      dartPackageName: defaultPackageName,
    );
    final String code = sink.toString();
    expect(code, contains('public interface Api'));
    expect(code, contains('public static class ApiSetup'));
    expect(code, contains('channel.SetMessageHandler(null);'));
    expect(code, contains('public static MessageCodec<object?> GetCodec()'));
  });
}
