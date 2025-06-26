import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/domain/entities/habit_color.dart';

void main() {
  group('HabitColor', () {
    group('constructor', () {
      test('should create HabitColor with valid parameters', () {
        const color = HabitColor(
          value: 0xFF2196F3,
          hex: '#2196F3',
          name: 'Blue',
        );

        expect(color.value, 0xFF2196F3);
        expect(color.hex, '#2196F3');
        expect(color.name, 'Blue');
      });

      test('should have correct color property', () {
        const habitColor = HabitColor.blue;
        expect(habitColor.color, const Color(0xFF2196F3));
      });
    });

    group('predefined colors', () {
      test('should have blue color correctly defined', () {
        expect(HabitColor.blue.value, 0xFF2196F3);
        expect(HabitColor.blue.hex, '#2196F3');
        expect(HabitColor.blue.name, 'Blue');
      });

      test('should have green color correctly defined', () {
        expect(HabitColor.green.value, 0xFF4CAF50);
        expect(HabitColor.green.hex, '#4CAF50');
        expect(HabitColor.green.name, 'Green');
      });

      test('should have 8 predefined colors', () {
        expect(HabitColor.predefinedColors.length, 8);
      });

      test('predefined colors should be unique', () {
        final values = HabitColor.predefinedColors.map((c) => c.value).toSet();
        expect(values.length, HabitColor.predefinedColors.length);
      });
    });

    group('fromColor factory', () {
      test('should create HabitColor from Flutter Color', () {
        const flutterColor = Color(0xFF2196F3);
        final habitColor = HabitColor.fromColor(flutterColor);

        expect(habitColor.value, 0xFF2196F3);
        expect(habitColor.hex, '#2196F3');
        expect(habitColor.name, 'Blue'); // Should match predefined
      });

      test('should create custom color for unknown values', () {
        const customColor = Color(0xFF123456);
        final habitColor = HabitColor.fromColor(customColor);

        expect(habitColor.value, 0xFF123456);
        expect(habitColor.hex, '#123456');
        expect(habitColor.name, 'Custom');
      });
    });

    group('fromHex factory', () {
      test('should create HabitColor from hex string with #', () {
        final habitColor = HabitColor.fromHex('#2196F3');

        expect(habitColor.value, 0xFF2196F3);
        expect(habitColor.hex, '#2196F3');
        expect(habitColor.name, 'Blue');
      });

      test('should create HabitColor from hex string without #', () {
        final habitColor = HabitColor.fromHex('2196F3');

        expect(habitColor.value, 0xFF2196F3);
        expect(habitColor.hex, '2196F3');
        expect(habitColor.name, 'Blue');
      });

      test('should handle 6-digit hex by adding alpha channel', () {
        final habitColor = HabitColor.fromHex('FF5722');

        expect(habitColor.value, 0xFFFF5722);
        expect(habitColor.hex, 'FF5722');
      });

      test('should handle 8-digit hex with alpha channel', () {
        final habitColor = HabitColor.fromHex('80FF5722');

        expect(habitColor.value, 0x80FF5722);
        expect(habitColor.hex, '80FF5722');
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON correctly', () {
        const habitColor = HabitColor.blue;
        final json = habitColor.toJson();

        expect(json, {
          'value': 0xFF2196F3,
          'hex': '#2196F3',
          'name': 'Blue',
        });
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'value': 0xFF4CAF50,
          'hex': '#4CAF50',
          'name': 'Green',
        };

        final habitColor = HabitColor.fromJson(json);

        expect(habitColor.value, 0xFF4CAF50);
        expect(habitColor.hex, '#4CAF50');
        expect(habitColor.name, 'Green');
      });

      test('should maintain equality after JSON round-trip', () {
        const original = HabitColor.purple;
        final json = original.toJson();
        final deserialized = HabitColor.fromJson(json);

        expect(deserialized, original);
      });
    });

    group('equality', () {
      test('should be equal when all properties match', () {
        const color1 = HabitColor(
          value: 0xFF2196F3,
          hex: '#2196F3',
          name: 'Blue',
        );
        const color2 = HabitColor(
          value: 0xFF2196F3,
          hex: '#2196F3',
          name: 'Blue',
        );

        expect(color1, color2);
        expect(color1.hashCode, color2.hashCode);
      });

      test('should not be equal when properties differ', () {
        const color1 = HabitColor.blue;
        const color2 = HabitColor.green;

        expect(color1, isNot(color2));
      });

      test('predefined colors should be equal to themselves', () {
        expect(HabitColor.blue, HabitColor.blue);
        expect(HabitColor.green, HabitColor.green);
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        const habitColor = HabitColor.blue;
        expect(habitColor.toString(), 'HabitColor(name: Blue, hex: #2196F3)');
      });
    });

    group('edge cases', () {
      test('should handle empty hex string gracefully', () {
        expect(() => HabitColor.fromHex(''), throwsA(isA<FormatException>()));
      });

      test('should handle invalid hex characters', () {
        expect(() => HabitColor.fromHex('GGGGGG'), throwsA(isA<FormatException>()));
      });

      test('should handle null values in JSON', () {
        expect(() => HabitColor.fromJson({}), throwsA(isA<TypeError>()));
      });
    });
  });
}