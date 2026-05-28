// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:path/path.dart' as path;

import '../ast.dart';
import '../functional.dart';
import '../generator.dart';
import '../generator_tools.dart';

/// Documentation open symbol.
const String _docCommentPrefix = '/**';

/// Documentation continuation symbol.
const String _docCommentContinuation = ' *';

/// Documentation close symbol.
const String _docCommentSuffix = ' */';

/// Documentation comment spec.
const DocumentCommentSpecification _docCommentSpec =
    DocumentCommentSpecification(
      _docCommentPrefix,
      closeCommentToken: _docCommentSuffix,
      blockContinuationToken: _docCommentContinuation,
    );

const String _codecName = 'PigeonCodec';

/// Options that control how C# code will be generated.
class DotnetOptions {
  /// Creates a [DotnetOptions] object.
  const DotnetOptions({
    this.className,
    this.namespace,
    this.copyrightHeader,
  });

  /// The name of the class that will house all generated classes.
  final String? className;

  /// The namespace where the generated class will live.
  final String? namespace;

  /// A copyright header that will get prepended to generated code.
  final Iterable<String>? copyrightHeader;

  /// Creates a [DotnetOptions] from a Map representation where:
  /// `x = DotnetOptions.fromMap(x.toMap())`.
  static DotnetOptions fromMap(Map<String, Object> map) {
    final Iterable<dynamic>? copyrightHeader =
        map['copyrightHeader'] as Iterable<dynamic>?;
    return DotnetOptions(
      className: map['className'] as String?,
      namespace: map['namespace'] as String?,
      copyrightHeader: copyrightHeader?.cast<String>(),
    );
  }

  /// Converts a [DotnetOptions] to a Map representation where:
  /// `x = DotnetOptions.fromMap(x.toMap())`.
  Map<String, Object> toMap() {
    return <String, Object>{
      if (className != null) 'className': className!,
      if (namespace != null) 'namespace': namespace!,
      if (copyrightHeader != null) 'copyrightHeader': copyrightHeader!,
    };
  }

  /// Overrides any non-null parameters from [options] into this to make a new
  /// [DotnetOptions].
  DotnetOptions merge(DotnetOptions options) {
    return DotnetOptions.fromMap(mergeMaps(toMap(), options.toMap()));
  }
}

/// Options that control how C# code will be generated internally.
class InternalDotnetOptions extends InternalOptions {
  /// Creates an [InternalDotnetOptions] object.
  const InternalDotnetOptions({
    required this.dotnetOut,
    this.className,
    this.namespace,
    this.copyrightHeader,
  });

  /// Creates [InternalDotnetOptions] from [DotnetOptions].
  InternalDotnetOptions.fromDotnetOptions(
    DotnetOptions options, {
    required this.dotnetOut,
    Iterable<String>? copyrightHeader,
  }) : className = options.className ?? _defaultClassName(dotnetOut),
       namespace = options.namespace,
       copyrightHeader = options.copyrightHeader ?? copyrightHeader;

  /// Path to the generated C# file.
  final String dotnetOut;

  /// The name of the class that will house all generated classes.
  final String? className;

  /// The namespace where the generated class will live.
  final String? namespace;

  /// A copyright header that will get prepended to generated code.
  final Iterable<String>? copyrightHeader;
}

String _defaultClassName(String outputPath) {
  final List<String> parts = path.basename(outputPath).split('.');
  return parts.length > 1 ? parts.first : path.basenameWithoutExtension(outputPath);
}

/// Class that manages all C# code generation.
class DotnetGenerator extends StructuredGenerator<InternalDotnetOptions> {
  /// Instantiates a C# generator.
  const DotnetGenerator();

  @override
  void writeFilePrologue(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent, {
    required String dartPackageName,
  }) {
    if (generatorOptions.copyrightHeader != null) {
      addLines(indent, generatorOptions.copyrightHeader!, linePrefix: '// ');
    }
    indent.writeln('// ${getGeneratedCodeWarning()}');
    indent.writeln('// $seeAlsoWarning');
    indent.writeln('#nullable enable');
    indent.newln();
  }

  @override
  void writeFileImports(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent, {
    required String dartPackageName,
  }) {
    indent.writeln('using System;');
    indent.writeln('using System.Collections;');
    indent.writeln('using System.Collections.Generic;');
    indent.writeln('using System.Linq;');
    indent.writeln('using Android.Util;');
    indent.writeln('using IO.Flutter.Plugin.Common;');
    indent.newln();
  }

  @override
  void writeOpenNamespace(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent, {
    required String dartPackageName,
  }) {
    if (generatorOptions.namespace != null) {
      indent.writeln('namespace ${generatorOptions.namespace}');
      indent.writeln('{');
      indent.inc();
    }
    indent.writeln(
      'public static partial class ${generatorOptions.className!}',
    );
    indent.writeln('{');
    indent.inc();
  }

  @override
  void writeCloseNamespace(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent, {
    required String dartPackageName,
  }) {
    indent.dec();
    indent.writeln('}');
    if (generatorOptions.namespace != null) {
      indent.dec();
      indent.writeln('}');
    }
  }

  @override
  void writeEnum(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent,
    Enum anEnum, {
    required String dartPackageName,
  }) {
    indent.newln();
    addDocumentationComments(
      indent,
      anEnum.documentationComments,
      _docCommentSpec,
    );
    indent.writeScoped('public enum ${anEnum.name} {', '}', () {
      for (int index = 0; index < anEnum.members.length; index++) {
        final EnumMember member = anEnum.members[index];
        addDocumentationComments(
          indent,
          member.documentationComments,
          _docCommentSpec,
        );
        final String suffix = index == anEnum.members.length - 1 ? '' : ',';
        indent.writeln('${member.name} = $index$suffix');
      }
    });
    indent.newln();
    indent.writeScoped(
      'private static ${anEnum.name}? ${anEnum.name}OfRaw(int raw) {',
      '}',
      () {
        indent.writeScoped('return raw switch {', '};', () {
          for (int index = 0; index < anEnum.members.length; index++) {
            indent.writeln('$index => ${anEnum.name}.${anEnum.members[index].name},');
          }
          indent.writeln('_ => null,');
        });
      },
    );
  }

  @override
  void writeDataClass(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent,
    Class classDefinition, {
    required String dartPackageName,
  }) {
    indent.newln();
    addDocumentationComments(
      indent,
      classDefinition.documentationComments,
      _docCommentSpec,
      generatorComments: const <String>[
        ' Generated class from Pigeon that represents data sent in messages.',
      ],
    );
    indent.writeScoped(
      'public sealed class ${classDefinition.name} : IEquatable<${classDefinition.name}> {',
      '}',
      () {
        for (final NamedType field in getFieldsInSerializationOrder(classDefinition)) {
          final String typeName = _dotnetTypeForDartType(field.type);
          final String initializer =
              !field.type.isNullable && _isReferenceType(field.type)
              ? ' = default!;'
              : '';
          addDocumentationComments(
            indent,
            field.documentationComments,
            _docCommentSpec,
          );
          indent.writeln(
            'public $typeName ${field.name} { get; set; }$initializer',
          );
        }
        indent.newln();
        indent.writeScoped(
          'public static ${classDefinition.name} FromList(IList<object?> list) {',
          '}',
          () {
            indent.writeln('return new ${classDefinition.name}');
            indent.writeScoped('{', '};', () {
              enumerate(
                getFieldsInSerializationOrder(classDefinition),
                (int index, NamedType field) {
                  indent.writeln(
                    '${field.name} = ${_decodeExpression(field.type, 'list[$index]')},',
                  );
                },
              );
            });
          },
        );
        indent.newln();
        indent.writeScoped('public List<object?> ToList() {', '}', () {
          indent.writeln('return new List<object?>');
          indent.writeScoped('{', '};', () {
            for (final NamedType field in getFieldsInSerializationOrder(classDefinition)) {
              indent.writeln('${_encodeExpression(field.type, field.name)},');
            }
          });
        });
        indent.newln();
        indent.writeln(
          'public bool Equals(${classDefinition.name}? other) => other is not null && ${_equalityExpression(classDefinition)};',
        );
        indent.writeln(
          'public override bool Equals(object? obj) => Equals(obj as ${classDefinition.name});',
        );
        indent.writeln(
          'public override int GetHashCode() => PigeonCombineHash(new object?[] { ${getFieldsInSerializationOrder(classDefinition).map((NamedType field) => field.name).join(', ')} });',
        );
      },
    );
  }

  @override
  void writeGeneralCodec(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent, {
    required String dartPackageName,
  }) {
    final List<EnumeratedType> enumeratedTypes = getEnumeratedTypes(root).toList();

    indent.newln();
    indent.writeScoped(
      'private sealed class $_codecName : StandardMessageCodec {',
      '}',
      () {
        indent.writeln(
          'public static readonly $_codecName Instance = new $_codecName();',
        );
        indent.newln();
        indent.writeln('private $_codecName() {}');
        indent.newln();
        indent.writeScoped(
          'protected override object? ReadValueOfType(byte type, Java.Nio.ByteBuffer buffer) {',
          '}',
          () {
            if (enumeratedTypes.isEmpty) {
              indent.writeln('return base.ReadValueOfType(type, buffer);');
              return;
            }
            indent.writeScoped('switch (type) {', '}', () {
              for (final EnumeratedType customType in enumeratedTypes) {
                indent.writeln('case ${customType.enumeration}:');
                indent.nest(1, () {
                  if (customType.type == CustomTypes.customClass) {
                    indent.writeln(
                      'return ${customType.name}.FromList((IList<object?>)ReadValue(buffer)!);',
                    );
                  } else {
                    indent.writeln(
                      'return ${customType.name}OfRaw(Convert.ToInt32(ReadValue(buffer)!));',
                    );
                  }
                });
              }
              indent.writeln('default:');
              indent.nest(1, () {
                indent.writeln('return base.ReadValueOfType(type, buffer);');
              });
            });
          },
        );
        indent.newln();
        indent.writeScoped(
          'protected override void WriteValue(Java.IO.ByteArrayOutputStream stream, object? value) {',
          '}',
          () {
            for (final EnumeratedType customType in enumeratedTypes) {
              indent.writeScoped(
                'if (value is ${customType.name} typedValue) {',
                '}',
                () {
                  indent.writeln('stream.Write(${customType.enumeration});');
                  if (customType.type == CustomTypes.customClass) {
                    indent.writeln('WriteValue(stream, typedValue.ToList());');
                  } else {
                    indent.writeln('WriteValue(stream, (int)typedValue);');
                  }
                  indent.writeln('return;');
                },
              );
            }
            indent.writeln('base.WriteValue(stream, value);');
          },
        );
      },
    );
  }

  @override
  void writeHostApi(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent,
    AstHostApi api, {
    required String dartPackageName,
  }) {
    indent.newln();
    addDocumentationComments(
      indent,
      api.documentationComments,
      _docCommentSpec,
      generatorComments: const <String>[
        ' Generated interface from Pigeon that represents a handler of messages from Flutter.',
      ],
    );
    indent.writeScoped('public interface ${api.name} {', '}', () {
      for (final Method method in api.methods) {
        addDocumentationComments(
          indent,
          method.documentationComments,
          _docCommentSpec,
        );
        indent.writeln('${_hostMethodSignature(method)};');
      }
    });
    indent.newln();
    indent.writeScoped('public static class ${api.name}Setup {', '}', () {
      indent.writeln('/** The codec used by ${api.name}. */');
      indent.writeln(
        'public static MessageCodec<object?> GetCodec() => $_codecName.Instance;',
      );
      indent.newln();
      indent.writeln(
        '/** Sets up an instance of `${api.name}` to handle messages through the `binaryMessenger`. */',
      );
      indent.writeScoped(
        'public static void SetUp(BinaryMessenger binaryMessenger, ${api.name}? api, string messageChannelSuffix = "") {',
        '}',
        () {
          indent.writeln(
            'var suffix = string.IsNullOrEmpty(messageChannelSuffix) ? "" : "." + messageChannelSuffix;',
          );
          for (final Method method in api.methods) {
            _writeHostMethodHandler(
              indent,
              api,
              method,
              dartPackageName: dartPackageName,
            );
          }
        },
      );
    });
  }

  @override
  void writeFlutterApi(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent,
    AstFlutterApi api, {
    required String dartPackageName,
  }) {
    indent.newln();
    addDocumentationComments(
      indent,
      api.documentationComments,
      _docCommentSpec,
      generatorComments: const <String>[
        ' Generated class from Pigeon that represents Flutter messages that can be called from C#.',
      ],
    );
    indent.writeScoped('public sealed class ${api.name} {', '}', () {
      indent.writeln('private readonly BinaryMessenger binaryMessenger;');
      indent.writeln('private readonly string messageChannelSuffix;');
      indent.newln();
      indent.writeScoped(
        'public ${api.name}(BinaryMessenger binaryMessenger, string messageChannelSuffix = "") {',
        '}',
        () {
          indent.writeln('this.binaryMessenger = binaryMessenger;');
          indent.writeln('this.messageChannelSuffix = messageChannelSuffix;');
        },
      );
      indent.newln();
      indent.writeln('/** The codec used by ${api.name}. */');
      indent.writeln(
        'public static MessageCodec<object?> GetCodec() => $_codecName.Instance;',
      );
      for (final Method method in api.methods) {
        indent.newln();
        addDocumentationComments(
          indent,
          method.documentationComments,
          _docCommentSpec,
        );
        indent.writeScoped(
          'public void ${method.name}(${_flutterMethodParameters(method)}) {',
          '}',
          () {
            final String sendArgument = method.parameters.isEmpty
                ? 'null'
                : 'new List<object?> { ${method.parameters.map((NamedType arg) => _encodeExpression(arg.type, arg.name)).join(', ')} }';
            indent.writeln(
              'var channelName = "${makeChannelName(api, method, dartPackageName)}" + (string.IsNullOrEmpty(messageChannelSuffix) ? "" : "." + messageChannelSuffix);',
            );
            indent.writeln(
              'var channel = new BasicMessageChannel<object?>(binaryMessenger, channelName, GetCodec());',
            );
            indent.writeln('channel.Send($sendArgument, channelReply =>');
            indent.writeScoped('{', '});', () {
              indent.writeScoped('if (channelReply is IList listReply) {', '}', () {
                indent.writeScoped('if (listReply.Count > 1) {', '}', () {
                  indent.writeln(
                    'error(new FlutterError((string)listReply[0]!, listReply[1] as string, listReply[2]));',
                  );
                });
                if (!method.returnType.isNullable && !method.returnType.isVoid) {
                  indent.writeScoped(
                    'else if (listReply[0] is null) {',
                    '}',
                    () {
                      indent.writeln(
                        'error(new FlutterError("null-error", "Flutter api returned null value for non-null return value.", ""));',
                      );
                    },
                  );
                }
                indent.writeScoped('else {', '}', () {
                  if (method.returnType.isVoid) {
                    indent.writeln('success();');
                  } else {
                    indent.writeln(
                      'success(${_decodeExpression(method.returnType, 'listReply[0]')});',
                    );
                  }
                });
              });
              indent.writeScoped('else {', '}', () {
                indent.writeln('error(CreateConnectionError(channelName));');
              });
            });
          },
        );
      }
    });
  }

  @override
  void writeGeneralUtilities(
    InternalDotnetOptions generatorOptions,
    Root root,
    Indent indent, {
    required String dartPackageName,
  }) {
    indent.newln();
    indent.writeScoped('public sealed class FlutterError : Exception {', '}', () {
      indent.writeln(
        'public FlutterError(string code, string? message, object? details) : base(message)',
      );
      indent.writeScoped('{', '}', () {
        indent.writeln('Code = code;');
        indent.writeln('Details = details;');
      });
      indent.newln();
      indent.writeln('public string Code { get; }');
      indent.writeln('public object? Details { get; }');
    });
    indent.newln();
    indent.writeScoped(
      'private static List<object?> WrapError(Exception exception) {',
      '}',
      () {
        indent.writeScoped('if (exception is FlutterError error) {', '}', () {
          indent.writeln(
            'return new List<object?> { error.Code, error.Message, error.Details };',
          );
        });
        indent.writeln(
          'return new List<object?> { exception.ToString(), exception.GetType().Name, "Cause: " + exception.InnerException + ", Stacktrace: " + Log.GetStackTraceString(exception) };',
        );
      },
    );
    if (root.containsFlutterApi) {
      indent.newln();
      indent.writeln(
        'private static FlutterError CreateConnectionError(string channelName) => new FlutterError("channel-error", "Unable to establish connection on channel: " + channelName + ".", "");',
      );
    }
    indent.newln();
    indent.writeScoped(
      'private static bool PigeonDeepEquals(object? a, object? b) {',
      '}',
      () {
        indent.writeln('if (ReferenceEquals(a, b)) { return true; }');
        indent.writeln('if (a is null || b is null) { return false; }');
        indent.writeln(
          'if (a is byte[] byteArrayA && b is byte[] byteArrayB) { return byteArrayA.SequenceEqual(byteArrayB); }',
        );
        indent.writeln(
          'if (a is int[] intArrayA && b is int[] intArrayB) { return intArrayA.SequenceEqual(intArrayB); }',
        );
        indent.writeln(
          'if (a is long[] longArrayA && b is long[] longArrayB) { return longArrayA.SequenceEqual(longArrayB); }',
        );
        indent.writeln(
          'if (a is double[] doubleArrayA && b is double[] doubleArrayB) { return doubleArrayA.SequenceEqual(doubleArrayB); }',
        );
        indent.writeScoped('if (a is IList listA && b is IList listB) {', '}', () {
          indent.writeln('if (listA.Count != listB.Count) { return false; }');
          indent.writeScoped(
            'for (var index = 0; index < listA.Count; index++) {',
            '}',
            () {
              indent.writeln(
                'if (!PigeonDeepEquals(listA[index], listB[index])) { return false; }',
              );
            },
          );
          indent.writeln('return true;');
        });
        indent.writeScoped(
          'if (a is IDictionary dictionaryA && b is IDictionary dictionaryB) {',
          '}',
          () {
            indent.writeln(
              'if (dictionaryA.Count != dictionaryB.Count) { return false; }',
            );
            indent.writeScoped(
              'foreach (DictionaryEntry entry in dictionaryA) {',
              '}',
              () {
                indent.writeln(
                  'if (!dictionaryB.Contains(entry.Key)) { return false; }',
                );
                indent.writeln(
                  'if (!PigeonDeepEquals(entry.Value, dictionaryB[entry.Key])) { return false; }',
                );
              },
            );
            indent.writeln('return true;');
          },
        );
        indent.writeln('return a.Equals(b);');
      },
    );
    indent.newln();
    indent.writeScoped(
      'private static int PigeonDeepHash(object? value) {',
      '}',
      () {
        indent.writeln('if (value is null) { return 0; }');
        indent.writeScoped('if (value is IList list) {', '}', () {
          indent.writeln('var hash = 17;');
          indent.writeScoped('foreach (var item in list) {', '}', () {
            indent.writeln('hash = hash * 31 + PigeonDeepHash(item);');
          });
          indent.writeln('return hash;');
        });
        indent.writeScoped('if (value is IDictionary dictionary) {', '}', () {
          indent.writeln('var hash = 17;');
          indent.writeScoped(
            'foreach (DictionaryEntry entry in dictionary) {',
            '}',
            () {
              indent.writeln('hash = hash * 31 + PigeonDeepHash(entry.Key);');
              indent.writeln('hash = hash * 31 + PigeonDeepHash(entry.Value);');
            },
          );
          indent.writeln('return hash;');
        });
        indent.writeln(
          'if (value is byte[] byteArray) { return byteArray.Aggregate(17, (current, item) => current * 31 + item); }',
        );
        indent.writeln(
          'if (value is int[] intArray) { return intArray.Aggregate(17, (current, item) => current * 31 + item); }',
        );
        indent.writeln(
          'if (value is long[] longArray) { return longArray.Aggregate(17, (current, item) => current * 31 + item.GetHashCode()); }',
        );
        indent.writeln(
          'if (value is double[] doubleArray) { return doubleArray.Aggregate(17, (current, item) => current * 31 + item.GetHashCode()); }',
        );
        indent.writeln('return value.GetHashCode();');
      },
    );
    indent.newln();
    indent.writeln(
      'private static int PigeonCombineHash(IEnumerable<object?> values) => values.Aggregate(17, (current, item) => current * 31 + PigeonDeepHash(item));',
    );
  }

  void _writeHostMethodHandler(
    Indent indent,
    Api api,
    Method method, {
    required String dartPackageName,
  }) {
    final String channelName = makeChannelName(api, method, dartPackageName);
    indent.writeln('{');
    indent.inc();
    indent.writeln(
      'var channel = new BasicMessageChannel<object?>(binaryMessenger, "$channelName" + suffix, GetCodec());',
    );
    indent.writeln('if (api != null)');
    indent.writeln('{');
    indent.inc();
    indent.writeln('channel.SetMessageHandler((message, reply) =>');
    indent.writeScoped('{', '});', () {
      if (method.parameters.isNotEmpty) {
        indent.writeln('var args = (IList<object?>)message!;');
        enumerate(method.parameters, (int index, NamedType parameter) {
          indent.writeln(
            '${_dotnetTypeForDartType(parameter.type)} ${_safeArgumentName(index, parameter)} = ${_decodeExpression(parameter.type, 'args[$index]')};',
          );
        });
      }
      if (method.isAsynchronous) {
        final String arguments = [
          ...indexMap(method.parameters, _safeArgumentName),
          if (method.returnType.isVoid) '() => reply(new List<object?> { null })',
          if (!method.returnType.isVoid)
            'result => reply(new List<object?> { ${_encodeExpression(method.returnType, 'result')} })',
          'error => reply(WrapError(error))',
        ].join(', ');
        indent.writeln('api.${method.name}($arguments);');
      } else {
        indent.writeScoped('try {', '} catch (Exception exception) {', () {
          if (method.returnType.isVoid) {
            indent.writeln(
              'api.${method.name}(${indexMap(method.parameters, _safeArgumentName).join(', ')});',
            );
            indent.writeln('reply(new List<object?> { null });');
          } else {
            indent.writeln(
              'var output = api.${method.name}(${indexMap(method.parameters, _safeArgumentName).join(', ')});',
            );
            indent.writeln(
              'reply(new List<object?> { ${_encodeExpression(method.returnType, 'output')} });',
            );
          }
        }, addTrailingNewline: false);
        indent.writeln('reply(WrapError(exception));');
        indent.writeln('}');
      }
    });
    indent.dec();
    indent.writeln('}');
    indent.writeln('else');
    indent.writeln('{');
    indent.inc();
    indent.writeln('channel.SetMessageHandler(null);');
    indent.dec();
    indent.writeln('}');
    indent.dec();
    indent.writeln('}');
  }
}

String _hostMethodSignature(Method method) {
  final List<String> arguments = method.parameters
      .map(
        (NamedType parameter) =>
            '${_dotnetTypeForDartType(parameter.type)} ${parameter.name}',
      )
      .toList();
  if (method.isAsynchronous) {
    if (method.returnType.isVoid) {
      arguments.add('Action success');
    } else {
      arguments.add('Action<${_dotnetTypeForDartType(method.returnType)}> success');
    }
    arguments.add('Action<Exception> error');
    return 'void ${method.name}(${arguments.join(', ')})';
  }
  return '${_dotnetTypeForDartType(method.returnType)} ${method.name}(${arguments.join(', ')})';
}

String _flutterMethodParameters(Method method) {
  final List<String> arguments = method.parameters
      .map(
        (NamedType parameter) =>
            '${_dotnetTypeForDartType(parameter.type)} ${parameter.name}',
      )
      .toList();
  if (method.returnType.isVoid) {
    arguments.add('Action success');
  } else {
    arguments.add('Action<${_dotnetTypeForDartType(method.returnType)}> success');
  }
  arguments.add('Action<Exception> error');
  return arguments.join(', ');
}

bool _isReferenceType(TypeDeclaration type) {
  if (type.associatedClass != null) {
    return true;
  }
  if (type.associatedEnum != null) {
    return false;
  }
  switch (type.baseName) {
    case 'bool':
    case 'int':
    case 'double':
      return false;
    default:
      return true;
  }
}

String _dotnetTypeForDartType(TypeDeclaration type) {
  final String baseType;
  if (type.associatedClass != null || type.associatedEnum != null) {
    baseType = type.baseName;
  } else {
    switch (type.baseName) {
      case 'bool':
        baseType = 'bool';
      case 'int':
        baseType = 'long';
      case 'String':
        baseType = 'string';
      case 'double':
        baseType = 'double';
      case 'Uint8List':
        baseType = 'byte[]';
      case 'Int32List':
        baseType = 'int[]';
      case 'Int64List':
        baseType = 'long[]';
      case 'Float64List':
        baseType = 'double[]';
      case 'List':
        final String innerType = type.typeArguments.isEmpty
            ? 'object?'
            : _dotnetTypeForDartType(type.typeArguments.single);
        baseType = 'List<$innerType>';
      case 'Map':
        final String keyType = type.typeArguments.isEmpty
            ? 'object?'
            : _dotnetTypeForDartType(type.typeArguments.first);
        final String valueType = type.typeArguments.length < 2
            ? 'object?'
            : _dotnetTypeForDartType(type.typeArguments[1]);
        baseType = 'Dictionary<$keyType, $valueType>';
      case 'Object':
        baseType = 'object';
      default:
        baseType = type.baseName;
    }
  }
  return type.isNullable ? '$baseType?' : baseType;
}

String _decodeExpression(TypeDeclaration type, String accessor) {
  if (type.associatedClass != null) {
    final String value =
        '${type.baseName}.FromList((IList<object?>)$accessor!)';
    return type.isNullable ? '$accessor is null ? null : $value' : value;
  }
  if (type.associatedEnum != null) {
    final String value =
        '${type.baseName}OfRaw(Convert.ToInt32($accessor!))';
    return type.isNullable
        ? '$accessor is null ? null : $value'
        : '$value ?? throw new InvalidOperationException("Unknown enum value for ${type.baseName}.")';
  }
  switch (type.baseName) {
    case 'bool':
      return type.isNullable
          ? '$accessor is null ? null : (bool)$accessor'
          : '(bool)$accessor!';
    case 'int':
      return type.isNullable
          ? '$accessor is null ? null : Convert.ToInt64($accessor)'
          : 'Convert.ToInt64($accessor!)';
    case 'String':
      return type.isNullable ? '$accessor as string' : '(string)$accessor!';
    case 'double':
      return type.isNullable
          ? '$accessor is null ? null : Convert.ToDouble($accessor)'
          : 'Convert.ToDouble($accessor!)';
    case 'Uint8List':
      return type.isNullable ? '$accessor as byte[]' : '(byte[])$accessor!';
    case 'Int32List':
      return type.isNullable ? '$accessor as int[]' : '(int[])$accessor!';
    case 'Int64List':
      return type.isNullable ? '$accessor as long[]' : '(long[])$accessor!';
    case 'Float64List':
      return type.isNullable ? '$accessor as double[]' : '(double[])$accessor!';
    case 'List':
    case 'Map':
      return type.isNullable
          ? '$accessor as ${_dotnetTypeForDartType(type)}'
          : '(${_dotnetTypeForDartType(type)})$accessor!';
    case 'Object':
      return type.isNullable ? accessor : '$accessor!';
    default:
      return type.isNullable
          ? '$accessor as ${_dotnetTypeForDartType(type)}'
          : '(${_dotnetTypeForDartType(type)})$accessor!';
  }
}

String _encodeExpression(TypeDeclaration type, String expression) {
  if (type.associatedClass != null) {
    return type.isNullable ? '$expression?.ToList()' : '$expression.ToList()';
  }
  if (type.associatedEnum != null) {
    return type.isNullable
        ? '$expression is null ? null : (int)$expression'
        : '(int)$expression';
  }
  return expression;
}

String _equalityExpression(Class classDefinition) {
  final Iterable<String> comparisons = getFieldsInSerializationOrder(
    classDefinition,
  ).map((NamedType field) => 'PigeonDeepEquals(${field.name}, other.${field.name})');
  return comparisons.isEmpty ? 'true' : comparisons.join(' && ');
}

String _argumentName(int count, NamedType argument) =>
    argument.name.isEmpty ? 'arg$count' : argument.name;

String _safeArgumentName(int count, NamedType argument) =>
    '${_argumentName(count, argument)}Arg';
