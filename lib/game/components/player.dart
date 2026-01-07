import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';

/// Player component for the mystical platformer game
/// Handles jumping, animations, collision detection, and health system
class Player extends SpriteAnimationComponent
    with HasKeyboardHandlerComponents, HasCollisionDetection, CollisionCallbacks {
  
  /// Player movement speed
  static const double moveSpeed = 200.0;
  
  /// Jump force applied to player
  static const double jumpForce = -400.0;
  
  /// Gravity acceleration
  static const double gravity = 980.0;
  
  /// Maximum fall speed
  static const double maxFallSpeed = 500.0;
  
  /// Player health points
  static const int maxHealth = 3;
  
  /// Invulnerability duration after taking damage
  static const double invulnerabilityDuration = 2.0;
  
  /// Current velocity
  Vector2 velocity = Vector2.zero();
  
  /// Whether player is on ground
  bool isOnGround = false;
  
  /// Current health
  int health = maxHealth;
  
  /// Whether player is invulnerable
  bool isInvulnerable = false;
  
  /// Timer for invulnerability frames
  Timer? invulnerabilityTimer;
  
  /// Animation states
  late SpriteAnimation idleAnimation;
  late SpriteAnimation jumpAnimation;
  late SpriteAnimation fallAnimation;
  late SpriteAnimation hurtAnimation;
  
  /// Current animation state
  PlayerState currentState = PlayerState.idle;
  
  /// Callback when player collects a gem
  Function(int points)? onGemCollected;
  
  /// Callback when player takes damage
  Function(int newHealth)? onHealthChanged;
  
  /// Callback when player dies
  Function()? onPlayerDeath;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set player size
    size = Vector2(32, 48);
    
    // Add collision detection
    add(RectangleHitbox());
    
    // Load animations
    await _loadAnimations();
    
    // Set initial animation
    animation = idleAnimation;
    
    // Initialize invulnerability timer
    invulnerabilityTimer = Timer(
      invulnerabilityDuration,
      onTick: () {
        isInvulnerable = false;
        opacity = 1.0;
      },
      repeat: false,
    );
  }
  
  /// Load all player animations
  Future<void> _loadAnimations() async {
    final spriteSheet = await game.images.load('player_spritesheet.png');
    
    idleAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.2,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 0),
      ),
    );
    
    jumpAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.1,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 48),
      ),
    );
    
    fallAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.15,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 96),
      ),
    );
    
    hurtAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: 0.1,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 144),
      ),
    );
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Update invulnerability timer
    invulnerabilityTimer?.update(dt);
    
    // Apply gravity
    if (!isOnGround) {
      velocity.y += gravity * dt;
      velocity.y = velocity.y.clamp(-jumpForce, maxFallSpeed);
    }
    
    // Update position
    position += velocity * dt;
    
    // Update animation state
    _updateAnimationState();
    
    // Handle invulnerability visual effect
    if (isInvulnerable) {
      opacity = (opacity == 1.0) ? 0.5 : 1.0;
    }
    
    // Reset ground state (will be set by collision detection)
    isOnGround = false;
  }
  
  /// Handle tap input for jumping
  void jump() {
    if (isOnGround && health > 0) {
      velocity.y = jumpForce;
      isOnGround = false;
      _playJumpSound();
    }
  }
  
  /// Update animation based on current state
  void _updateAnimationState() {
    PlayerState newState;
    
    if (health <= 0) {
      newState = PlayerState.hurt;
    } else if (velocity.y < 0) {
      newState = PlayerState.jumping;
    } else if (velocity.y > 0 && !isOnGround) {
      newState = PlayerState.falling;
    } else {
      newState = PlayerState.idle;
    }
    
    if (newState != currentState) {
      currentState = newState;
      _setAnimation(newState);
    }
  }
  
  /// Set animation based on state
  void _setAnimation(PlayerState state) {
    switch (state) {
      case PlayerState.idle:
        animation = idleAnimation;
        break;
      case PlayerState.jumping:
        animation = jumpAnimation;
        break;
      case PlayerState.falling:
        animation = fallAnimation;
        break;
      case PlayerState.hurt:
        animation = hurtAnimation;
        break;
    }
  }
  
  @override
  bool onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    // Handle platform collisions
    if (other is Platform) {
      _handlePlatformCollision(other, intersectionPoints);
      return true;
    }
    
    // Handle gem collection
    if (other is Gem && !other.isCollected) {
      _collectGem(other);
      return false;
    }
    
    // Handle hazard collisions
    if (other is Hazard) {
      _takeDamage();
      return true;
    }
    
    return true;
  }
  
  /// Handle collision with platforms
  void _handlePlatformCollision(Platform platform, Set<Vector2> intersectionPoints) {
    // Check if player is falling onto platform from above
    if (velocity.y > 0 && position.y < platform.position.y) {
      velocity.y = 0;
      position.y = platform.position.y - size.y;
      isOnGround = true;
    }
  }
  
  /// Collect a gem and award points
  void _collectGem(Gem gem) {
    gem.collect();
    onGemCollected?.call(gem.points);
    _playGemSound();
  }
  
  /// Take damage and handle invulnerability
  void _takeDamage() {
    if (isInvulnerable || health <= 0) return;
    
    health--;
    isInvulnerable = true;
    invulnerabilityTimer?.start();
    
    // Knockback effect
    velocity.y = jumpForce * 0.5;
    
    onHealthChanged?.call(health);
    _playHurtSound();
    
    if (health <= 0) {
      _die();
    }
  }
  
  /// Handle player death
  void _die() {
    velocity = Vector2.zero();
    currentState = PlayerState.hurt;
    _setAnimation(PlayerState.hurt);
    onPlayerDeath?.call();
  }
  
  /// Reset player to full health and clear invulnerability
  void resetHealth() {
    health = maxHealth;
    isInvulnerable = false;
    opacity = 1.0;
    invulnerabilityTimer?.stop();
    onHealthChanged?.call(health);
  }
  
  /// Check if player has fallen off the screen
  bool hasFallenOffScreen() {
    return position.y > game.size.y + 100;
  }
  
  /// Play jump sound effect
  void _playJumpSound() {
    // TODO: Implement sound effect
    // game.audioManager.playSfx('jump.wav');
  }
  
  /// Play gem collection sound effect
  void _playGemSound() {
    // TODO: Implement sound effect
    // game.audioManager.playSfx('gem_collect.wav');
  }
  
  /// Play hurt sound effect
  void _playHurtSound() {
    // TODO: Implement sound effect
    // game.audioManager.playSfx('hurt.wav');
  }
}

/// Player animation states
enum PlayerState {
  idle,
  jumping,
  falling,
  hurt,
}

/// Platform component for collision detection
class Platform extends RectangleComponent with HasCollisionDetection {
  Platform({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }
}

/// Gem collectible component
class Gem extends SpriteComponent with HasCollisionDetection {
  final int points;
  bool isCollected = false;
  
  Gem({required Vector2 position, this.points = 10})
      : super(position: position, size: Vector2(24, 24));
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
    sprite = await Sprite.load('gem.png');
  }
  
  /// Collect this gem
  void collect() {
    if (isCollected) return;
    isCollected = true;
    removeFromParent();
  }
}

/// Hazard component that damages the player
class Hazard extends SpriteComponent with HasCollisionDetection {
  Hazard({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
    sprite = await Sprite.load('spike.png');
  }
}