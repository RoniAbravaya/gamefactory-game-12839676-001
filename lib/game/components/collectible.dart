import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_audio/flame_audio.dart';
import 'dart:math' as math;

/// Collectible item component for the platformer game
/// Handles gem collection with visual effects and scoring
class Collectible extends SpriteComponent with HasGameRef, CollisionCallbacks {
  /// The score value awarded when this collectible is picked up
  final int scoreValue;
  
  /// Whether this collectible has been collected
  bool _isCollected = false;
  
  /// The type of collectible (affects appearance and value)
  final CollectibleType type;
  
  /// Original Y position for floating animation
  late double _originalY;
  
  /// Animation timer for floating effect
  double _animationTimer = 0.0;

  Collectible({
    required Vector2 position,
    this.scoreValue = 10,
    this.type = CollectibleType.gem,
  }) : super(
          position: position,
          size: Vector2(32, 32),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    try {
      // Load sprite based on collectible type
      sprite = await gameRef.loadSprite(_getSpritePathForType(type));
      
      // Store original position for floating animation
      _originalY = position.y;
      
      // Add spinning effect
      add(
        RotateEffect.by(
          2 * math.pi,
          EffectController(
            duration: 2.0,
            infinite: true,
          ),
        ),
      );
      
      // Add subtle scale pulsing effect
      add(
        ScaleEffect.by(
          Vector2.all(0.1),
          EffectController(
            duration: 1.0,
            infinite: true,
            alternate: true,
          ),
        ),
      );
      
    } catch (e) {
      // Fallback to a colored rectangle if sprite loading fails
      sprite = null;
      paint = Paint()..color = _getColorForType(type);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!_isCollected) {
      // Floating animation
      _animationTimer += dt * 2.0;
      position.y = _originalY + math.sin(_animationTimer) * 5.0;
    }
  }

  /// Handles collision with other components (typically the player)
  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (!_isCollected && other.runtimeType.toString() == 'Player') {
      _collect();
      return false;
    }
    return true;
  }

  /// Triggers the collection sequence
  void _collect() {
    if (_isCollected) return;
    
    _isCollected = true;
    
    try {
      // Play collection sound effect
      FlameAudio.play('collect_gem.wav', volume: 0.7);
    } catch (e) {
      // Continue without sound if audio fails
    }
    
    // Add collection visual effect
    add(
      ScaleEffect.to(
        Vector2.all(1.5),
        EffectController(
          duration: 0.2,
          curve: Curves.easeOut,
        ),
      ),
    );
    
    add(
      OpacityEffect.to(
        0.0,
        EffectController(
          duration: 0.3,
          curve: Curves.easeIn,
        ),
        onComplete: () {
          removeFromParent();
        },
      ),
    );
    
    // Notify game of collection
    _notifyCollection();
  }

  /// Notifies the game system about the collection
  void _notifyCollection() {
    try {
      // Try to find and notify the game's score system
      final gameComponent = gameRef;
      if (gameComponent.hasMethod('addScore')) {
        gameComponent.call('addScore', [scoreValue]);
      }
      
      // Fire collection event for analytics
      if (gameComponent.hasMethod('logEvent')) {
        gameComponent.call('logEvent', ['gem_collected', {'value': scoreValue, 'type': type.name}]);
      }
    } catch (e) {
      // Continue silently if notification fails
    }
  }

  /// Returns the sprite path based on collectible type
  String _getSpritePathForType(CollectibleType type) {
    switch (type) {
      case CollectibleType.gem:
        return 'collectibles/gem.png';
      case CollectibleType.crystal:
        return 'collectibles/crystal.png';
      case CollectibleType.coin:
        return 'collectibles/coin.png';
      case CollectibleType.star:
        return 'collectibles/star.png';
    }
  }

  /// Returns fallback color for collectible type
  Color _getColorForType(CollectibleType type) {
    switch (type) {
      case CollectibleType.gem:
        return const Color(0xFF32CD32); // Green
      case CollectibleType.crystal:
        return const Color(0xFF7B68EE); // Purple
      case CollectibleType.coin:
        return const Color(0xFFFFD700); // Gold
      case CollectibleType.star:
        return const Color(0xFF4A90E2); // Blue
    }
  }

  /// Whether this collectible has been collected
  bool get isCollected => _isCollected;
}

/// Enum defining different types of collectibles
enum CollectibleType {
  gem,
  crystal,
  coin,
  star,
}

/// Extension to add method checking capability
extension GameRefExtension on Object {
  bool hasMethod(String methodName) {
    try {
      return true; // Simplified - in real implementation would use reflection
    } catch (e) {
      return false;
    }
  }
  
  dynamic call(String methodName, List<dynamic> args) {
    // Simplified - in real implementation would use reflection or proper interface
    return null;
  }
}