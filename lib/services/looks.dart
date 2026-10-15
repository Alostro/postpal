import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A subtle, human-looking edit. Every value at its neutral setting
/// (exposure 0, contrast 1, saturation 1, warmth 0, fade 0) leaves the photo unchanged.
class Look {
  const Look(this.name, this.description,
      {this.exposure = 0,
      this.contrast = 1,
      this.saturation = 1,
      this.warmth = 0,
      this.fade = 0});

  final String name;
  final String description;
  final double exposure; // -1..1
  final double contrast; // ~0.8..1.3
  final double saturation; // ~0.6..1.4
  final double warmth; // -1..1
  final double fade; // 0..1, lifts the blacks for a soft film feel

  /// The 4x5 colour matrix (Flutter ColorFilter.matrix format, offsets in 0-255)
  /// at [strength] 0..1. The same matrix is used for preview and export.
  List<double> matrix(double strength) {
    double mix(double neutral, double v) => neutral + (v - neutral) * strength;
    final e = mix(0, exposure);
    final c = mix(1, contrast);
    final s = mix(1, saturation);
    final w = mix(0, warmth);
    final f = mix(0, fade);

    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sat = <double>[
      lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0,
      lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0,
      lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final con = <double>[
      c, 0, 0, 0, 128 * (1 - c),
      0, c, 0, 0, 128 * (1 - c),
      0, 0, c, 0, 128 * (1 - c),
      0, 0, 0, 1, 0,
    ];
    final bright = e * 45;
    final warm = <double>[
      1, 0, 0, 0, bright + w * 18,
      0, 1, 0, 0, bright + w * 5,
      0, 0, 1, 0, bright - w * 18,
      0, 0, 0, 1, 0,
    ];
    final k = f * 0.14;
    final fadeM = <double>[
      1 - k, 0, 0, 0, k * 255,
      0, 1 - k, 0, 0, k * 255,
      0, 0, 1 - k, 0, k * 255,
      0, 0, 0, 1, 0,
    ];
    return _mul(fadeM, _mul(warm, _mul(con, sat)));
  }

  /// a ∘ b : apply b first, then a.
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var col = 0; col < 5; col++) {
        var v = 0.0;
        for (var i = 0; i < 4; i++) {
          v += a[r * 5 + i] * b[i * 5 + col];
        }
        if (col == 4) v += a[r * 5 + 4];
        out[r * 5 + col] = v;
      }
    }
    return out;
  }
}

const looks = <Look>[
  Look('Natural', 'Just a little cleaner. Looks like a good phone photo.',
      exposure: 0.15, contrast: 1.05, saturation: 1.05, warmth: 0.15),
  Look('Warm', 'Cosy, golden tones. Great for restaurants at night.',
      exposure: 0.1, contrast: 1.04, saturation: 1.05, warmth: 0.7, fade: 0.2),
  Look('Food pop', 'Brighter colour so the food looks fresh, not fake.',
      exposure: 0.2, contrast: 1.1, saturation: 1.22, warmth: 0.25),
  Look('Clean', 'Bright and airy. Good for daytime, grad and outfit shots.',
      exposure: 0.35, contrast: 0.97, saturation: 0.95, warmth: -0.1),
  Look('Film', 'Soft and slightly faded, like a disposable camera.',
      contrast: 0.94, saturation: 0.88, warmth: 0.35, fade: 0.8),
  Look('Moody', 'Deeper shadows and calmer colour for evening vibes.',
      exposure: -0.15, contrast: 1.15, saturation: 0.85, warmth: 0.1),
];

Look lookByName(String name) =>
    looks.firstWhere((l) => l.name == name, orElse: () => looks.first);

/// Runs in a background isolate: loads [args]['in'], applies [args]['matrix'],
/// writes a JPEG to [args]['out'] and returns that path.
/// Throws if this library can't decode the file (e.g. HEIC); the caller then
/// decodes with the phone's own decoder and uses [processRgba].
Future<String> processPhoto(Map<String, Object> args) async {
  final decoded = img.decodeImage(await File(args['in'] as String).readAsBytes());
  if (decoded == null) throw const FormatException('unsupported format');
  return _finish(img.bakeOrientation(decoded), args);
}

/// Same as [processPhoto], but for pixels already decoded by Android
/// (RGBA bytes in args['rgba'], size in args['w'] / args['h']).
Future<String> processRgba(Map<String, Object> args) async {
  final rgba = args['rgba'] as Uint8List;
  final image = img.Image.fromBytes(
    width: args['w'] as int,
    height: args['h'] as int,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return _finish(image, args);
}

Future<String> _finish(img.Image source, Map<String, Object> args) async {
  final outPath = args['out'] as String;
  final m = (args['matrix'] as List).cast<double>();
  var image = source;

  // Instagram shows up to 1080px wide; keep extra room but stay fast.
  const maxSide = 2160;
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
  }

  // Normalise to plain 8-bit RGB so every photo type edits the same way.
  if (image.format != img.Format.uint8 || image.hasPalette || image.numChannels != 3) {
    image = image.convert(format: img.Format.uint8, numChannels: 3);
  }

  num clamp(num v) => v < 0 ? 0 : (v > 255 ? 255 : v);
  for (final p in image) {
    final r = p.r, g = p.g, b = p.b;
    p.r = clamp(m[0] * r + m[1] * g + m[2] * b + m[4]);
    p.g = clamp(m[5] * r + m[6] * g + m[7] * b + m[9]);
    p.b = clamp(m[10] * r + m[11] * g + m[12] * b + m[14]);
  }

  await File(outPath).writeAsBytes(img.encodeJpg(image, quality: 92));
  return outPath;
}
