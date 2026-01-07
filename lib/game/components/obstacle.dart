import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Obstacle component that can damage the player on collision
/// Supports different obstacle types like spikes, moving hazards, and static obstacles
class Obstacle extends PositionComponent with HasGameRef, CollisionCallbacks {
  /// Type of obstacle determining behavior and appearance
  final ObstacleType obstacleType;
  
  /// Movement pattern for moving obstacles
  final MovementPattern? movementPattern;
  
  /// Damage dealt to player on collision
  final int damage;
  
  /// Visual sprite for the obstacle
  late SpriteComponent _sprite;
  
  /// Collision hitbox
  late RectangleHitbox _hitbox;
  
  /// Movement parameters
  Vector2? _startPosition;
  Vector2? _endPosition;
  double _movementSpeed = 50.0;
  bool _movingToEnd = true;
  
  /// Animation parameters for animated obstacles
  late SpriteAnimationComponent? _animationComponent;
  
  /// Particle effect for magical obstacles
  ParticleSystemComponent? _particleEffect;

  Obstacle({
    required this.obstacleType,
    this.movementPattern,
    this.damage = 1,
    Vector2? position,
    Vector2? size,
  }) : super(position: position, size: size ?? _getDefaultSize(obstacleType));

  /// Get default size based on obstacle type
  static Vector2 _getDefaultSize(ObstacleType type) {
    switch (type) {
      case ObstacleType.spikes:
        return Vector2(32, 32);
      case ObstacleType.movingSpike:
        return Vector2(24, 24);
      case ObstacleType.crystalHazard:
        return Vector2(40, 40);
      case ObstacleType.magicalOrb:
        return Vector2(28, 28);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _startPosition = position.clone();
    
    // Setup collision hitbox
    _hitbox = RectangleHitbox(
      size: size * 0.8, // Slightly smaller than visual for better gameplay
      position: size * 0.1, // Center the smaller hitbox
    );
    add(_hitbox);
    
    // Load appropriate visual based on obstacle type
    await _loadVisual();
    
    // Setup movement pattern if specified
    _setupMovement();
    
    // Add particle effects for magical obstacles
    _addParticleEffects();
  }

  /// Load the visual representation of the obstacle
  Future<void> _loadVisual() async {
    try {
      switch (obstacleType) {
        case ObstacleType.spikes:
          _sprite = SpriteComponent(
            sprite: await gameRef.loadSprite('obstacles/spikes.png'),
            size: size,
          );
          add(_sprite);
          break;
          
        case ObstacleType.movingSpike:
          _sprite = SpriteComponent(
            sprite: await gameRef.loadSprite('obstacles/moving_spike.png'),
            size: size,
          );
          add(_sprite);
          break;
          
        case ObstacleType.crystalHazard:
          final spriteAnimation = await gameRef.loadSpriteAnimation(
            'obstacles/crystal_hazard.png',
            SpriteAnimationData.sequenced(
              amount: 4,
              stepTime: 0.3,
              textureSize: Vector2(40, 40),
            ),
          );
          _animationComponent = SpriteAnimationComponent(
            animation: spriteAnimation,
            size: size,
          );
          add(_animationComponent!);
          break;
          
        case ObstacleType.magicalOrb:
          _sprite = SpriteComponent(
            sprite: await gameRef.loadSprite('obstacles/magical_orb.png'),
            size: size,
          );
          add(_sprite);
          
          // Add pulsing effect
          _sprite.add(
            ScaleEffect.by(
              Vector2.all(1.2),
              EffectController(
                duration: 1.0,
                alternate: true,
                infinite: true,
              ),
            ),
          );
          break;
      }
    } catch (e) {
      // Fallback to colored rectangle if sprites fail to load
      _createFallbackVisual();
    }
  }

  /// Create a fallback visual using colored rectangles
  void _createFallbackVisual() {
    final color = _getObstacleColor();
    final rect = RectangleComponent(
      size: size,
      paint: Paint()..color = color,
    );
    add(rect);
  }

  /// Get color based on obstacle type for fallback visual
  Color _getObstacleColor() {
    switch (obstacleType) {
      case ObstacleType.spikes:
        return const Color(0xFFFF6B6B); // Red
      case ObstacleType.movingSpike:
        return const Color(0xFFFF4444); // Darker red
      case ObstacleType.crystalHazard:
        return const Color(0xFF7B68EE); // Purple
      case ObstacleType.magicalOrb:
        return const Color(0xFFFFD700); // Gold
    }
  }

  /// Setup movement pattern for moving obstacles
  void _setupMovement() {
    if (movementPattern == null) return;
    
    switch (movementPattern!) {
      case MovementPattern.horizontal:
        _endPosition = _startPosition! + Vector2(100, 0);
        break;
      case MovementPattern.vertical:
        _endPosition = _startPosition! + Vector2(0, 80);
        break;
      case MovementPattern.circular:
        // Circular movement will be handled in update
        break;
      case MovementPattern.pendulum:
        _endPosition = _startPosition! + Vector2(60, 60);
        break;
    }
  }

  /// Add particle effects for magical obstacles
  void _addParticleEffects() {
    if (obstacleType == ObstacleType.crystalHazard || 
        obstacleType == ObstacleType.magicalOrb) {
      
      _particleEffect = ParticleSystemComponent(
        particle: Particle.generate(
          count: 10,
          lifespan: 2.0,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, -20),
            speed: Vector2.random() * 30,
            position: size / 2,
            child: CircleParticle(
              radius: 2.0,
              paint: Paint()..color = const Color(0xFF7B68EE).withOpacity(0.7),
            ),
          ),
        ),
      );
      add(_particleEffect!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update movement based on pattern
    _updateMovement(dt);
  }

  /// Update obstacle movement
  void _updateMovement(double dt) {
    if (movementPattern == null) return;
    
    switch (movementPattern!) {
      case MovementPattern.horizontal:
      case MovementPattern.vertical:
      case MovementPattern.pendulum:
        _updateLinearMovement(dt);
        break;
      case MovementPattern.circular:
        _updateCircularMovement(dt);
        break;
    }
  }

  /// Update linear movement (horizontal, vertical, pendulum)
  void _updateLinearMovement(double dt) {
    if (_startPosition == null || _endPosition == null) return;
    
    final direction = _movingToEnd ? 1.0 : -1.0;
    final target = _movingToEnd ? _endPosition! : _startPosition!;
    final movement = (target - position).normalized() * _movementSpeed * dt * direction;
    
    position += movement;
    
    // Check if reached target
    final distanceToTarget = (target - position).length;
    if (distanceToTarget < 5.0) {
      _movingToEnd = !_movingToEnd;
    }
  }

  /// Update circular movement
  void _updateCircularMovement(double dt) {
    if (_startPosition == null) return;
    
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final radius = 40.0;
    final speed = 2.0;
    
    position = _startPosition! + Vector2(
      math.cos(time * speed) * radius,
      math.sin(time * speed) * radius,
    );
  }

  @override
  bool onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    // Handle collision with player
    if (other.runtimeType.toString().contains('Player')) {
      _onPlayerCollision(other);
      return true;
    }
    return false;
  }

  /// Handle collision with player
  void _onPlayerCollision(PositionComponent player) {
    // Deal damage to player
    if (player is HasGameRef) {
      // Trigger damage event
      gameRef.children.query<Component>().forEach((component) {
        if (component.runtimeType.toString().contains('GameManager')) {
          // Send damage event to game manager
        }
      });
    }
    
    // Add hit effect
    _addHitEffect();
  }

  /// Add visual effect when obstacle hits player
  void _addHitEffect() {
    final hitEffect = ScaleEffect.by(
      Vector2.all(1.3),
      EffectController(
        duration: 0.2,
        alternate: true,
      ),
    );
    add(hitEffect);
    
    // Add particle burst
    final burstParticle = ParticleSystemComponent(
      particle: Particle.generate(
        count: 15,
        lifespan: 0.5,
        generator: (i) => AcceleratedParticle(
          acceleration: Vector2(0, 100),
          speed: Vector2.random() * 100,
          position: size / 2,
          child: CircleParticle(
            radius: 3.0,
            paint: Paint()..color = const Color(0xFFFF6B6B),
          ),
        ),
      ),
    );
    add(burstParticle);
    
    // Remove burst effect after animation
    burstParticle.add(
      RemoveEffect(delay: 0.5),
    );
  }

  /// Spawn obstacle at specified position with given type
  static Obstacle spawn({
    required Vector2 position,
    required ObstacleType type,
    MovementPattern? movement,
    int damage = 1,
  }) {
    return Obstacle(
      obstacleType: type,
      movementPattern: movement,
      damage: damage,
      position: position,
    );
  }

  /// Remove obstacle from game
  void destroy() {
    removeFromParent();
  }
}

/// Types of obstacles available in the game
enum ObstacleType {
  spikes,
  movingSpike,
  crystalHazard,
  magicalOrb,
}

/// Movement patterns for obstacles
enum MovementPattern {
  horizontal,
  vertical,
  circular,
  pendulum,
}