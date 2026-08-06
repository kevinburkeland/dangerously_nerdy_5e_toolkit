import 'package:flutter/material.dart';

enum ObjectSize { tiny, small, medium, large, huge }

extension ObjectSizeExtension on ObjectSize {
  String get displayName {
    switch (this) {
      case ObjectSize.tiny:
        return 'Tiny';
      case ObjectSize.small:
        return 'Small';
      case ObjectSize.medium:
        return 'Medium';
      case ObjectSize.large:
        return 'Large';
      case ObjectSize.huge:
        return 'Huge';
    }
  }

  int get pointCost {
    switch (this) {
      case ObjectSize.tiny:
      case ObjectSize.small:
        return 1;
      case ObjectSize.medium:
        return 2;
      case ObjectSize.large:
        return 4;
      case ObjectSize.huge:
        return 8;
    }
  }

  int get maxHp {
    switch (this) {
      case ObjectSize.tiny:
        return 20;
      case ObjectSize.small:
        return 10;
      case ObjectSize.medium:
        return 40;
      case ObjectSize.large:
        return 80;
      case ObjectSize.huge:
        return 100;
    }
  }

  int get armorClass => ac;

  int get ac {
    switch (this) {
      case ObjectSize.tiny:
        return 18;
      case ObjectSize.small:
        return 16;
      case ObjectSize.medium:
        return 13;
      case ObjectSize.large:
        return 10;
      case ObjectSize.huge:
        return 10;
    }
  }

  int get attackBonus {
    switch (this) {
      case ObjectSize.tiny:
        return 8;
      case ObjectSize.small:
        return 6;
      case ObjectSize.medium:
        return 5;
      case ObjectSize.large:
        return 6;
      case ObjectSize.huge:
        return 8;
    }
  }

  int get damageDiceCount {
    switch (this) {
      case ObjectSize.tiny:
      case ObjectSize.small:
      case ObjectSize.medium:
        return 1;
      case ObjectSize.large:
      case ObjectSize.huge:
        return 2;
    }
  }

  int get damageDiceSides {
    switch (this) {
      case ObjectSize.tiny:
        return 4;
      case ObjectSize.small:
        return 8;
      case ObjectSize.medium:
        return 10;
      case ObjectSize.large:
        return 10;
      case ObjectSize.huge:
        return 12;
    }
  }

  int get damageBonus {
    switch (this) {
      case ObjectSize.tiny:
        return 4;
      case ObjectSize.small:
        return 2;
      case ObjectSize.medium:
        return 1;
      case ObjectSize.large:
        return 2;
      case ObjectSize.huge:
        return 4;
    }
  }

  int get strScore {
    switch (this) {
      case ObjectSize.tiny:
        return 4;
      case ObjectSize.small:
        return 6;
      case ObjectSize.medium:
        return 10;
      case ObjectSize.large:
        return 14;
      case ObjectSize.huge:
        return 18;
    }
  }

  int get dexScore {
    switch (this) {
      case ObjectSize.tiny:
        return 18;
      case ObjectSize.small:
        return 14;
      case ObjectSize.medium:
        return 12;
      case ObjectSize.large:
        return 10;
      case ObjectSize.huge:
        return 6;
    }
  }

  String get damageFormula => '${damageDiceCount}d$damageDiceSides+$damageBonus';

  Color get accentColor {
    switch (this) {
      case ObjectSize.tiny:
        return const Color(0xFF4CAF50); // Green
      case ObjectSize.small:
        return const Color(0xFF03A9F4); // Light Blue
      case ObjectSize.medium:
        return const Color(0xFFFF9800); // Amber
      case ObjectSize.large:
        return const Color(0xFFE91E63); // Pink/Red
      case ObjectSize.huge:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  String get defaultExample {
    switch (this) {
      case ObjectSize.tiny:
        return 'Silver Coin / Needle';
      case ObjectSize.small:
        return 'Dagger / Chair';
      case ObjectSize.medium:
        return 'Sword / Table';
      case ObjectSize.large:
        return 'Cart / Statue';
      case ObjectSize.huge:
        return 'Bouldering Pillar / Wagon';
    }
  }
}

class AnimatedObjectInstance {
  final String id;
  String name;
  final ObjectSize size;
  int currentHp;
  final int maxHp;
  String damageType; // Bludgeoning, Piercing, Slashing
  bool isSilvered;

  AnimatedObjectInstance({
    required this.id,
    required this.name,
    required this.size,
    required this.currentHp,
    required this.maxHp,
    this.damageType = 'Bludgeoning',
    this.isSilvered = false,
  });

  bool get isDead => currentHp <= 0;

  double get hpPercent => (currentHp / maxHp).clamp(0.0, 1.0);

  void takeDamage(int amount) {
    currentHp = (currentHp - amount).clamp(0, maxHp);
  }

  void heal(int amount) {
    currentHp = (currentHp + amount).clamp(0, maxHp);
  }

  AnimatedObjectInstance copyWith({
    String? id,
    String? name,
    ObjectSize? size,
    int? currentHp,
    int? maxHp,
    String? damageType,
    bool? isSilvered,
  }) {
    return AnimatedObjectInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      damageType: damageType ?? this.damageType,
      isSilvered: isSilvered ?? this.isSilvered,
    );
  }
}
