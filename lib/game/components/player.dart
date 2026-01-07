import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/services.dart';

/// Player component for the mystical platformer game
/// Handles movement, jumping, animations, and collision detection
class Player extends SpriteAnimationComponent with HasKeyboardHandlerComponents, CollisionCallbacks, HasGameRef {
  /// Player movement speed in pixels per second
  static const double _moveSpeed = 150.0;
  
  /// Jump velocity in pixels per second
  static const double _jumpVelocity = -400.0;
  
  /// Gravity acceleration in pixels per second squared
  static const double _gravity = 980.0;
  
  /// Maximum fall speed
  static const double _maxFallSpeed = 500.0;

  /// Current velocity vector
  Vector2 velocity = Vector2.zero();
  
  /// Whether the player is currently on the ground
  bool isOnGround = false;
  
  /// Whether the player can jump (prevents double jumping)
  bool canJump = true;
  
  /// Current player health/lives
  int health = 3;
  
  /// Maximum health
  static const int maxHealth = 3;
  
  /// Whether the player is invulnerable (after taking damage)
  bool isInvulnerable = false;
  
  /// Invulnerability timer
  double invulnerabilityTimer = 0.0;
  
  /// Invulnerability duration in seconds
  static const double invulnerabilityDuration = 2.0;

  /// Animation states
  late SpriteAnimation idleAnimation;
  late SpriteAnimation runAnimation;
  late SpriteAnimation jumpAnimation;
  late SpriteAnimation fallAnimation;

  /// Current animation state
  PlayerState currentState = PlayerState.idle;

  @override
  Future<void> onLoad() async {
    try {
      // Load sprite animations
      await _loadAnimations();
      
      // Set initial size and animation
      size = Vector2(32, 48);
      animation = idleAnimation;
      
      // Add collision hitbox
      add(RectangleHitbox(
        size: Vector2(24, 44),
        position: Vector2(4, 2),
      ));
      
      // Set initial position
      position = Vector2(100, 300);
      
    } catch (e) {
      print('Error loading player: $e');
    }
  }

  /// Load all player animations
  Future<void> _loadAnimations() async {
    final spriteSheet = await gameRef.images.load('player_spritesheet.png');
    
    idleAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.2,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 0),
      ),
    );
    
    runAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.1,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 48),
      ),
    );
    
    jumpAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: 0.1,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 96),
        loop: false,
      ),
    );
    
    fallAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 2,
        stepTime: 0.15,
        textureSize: Vector2(32, 48),
        texturePosition: Vector2(0, 144),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update invulnerability timer
    if (isInvulnerable) {
      invulnerabilityTimer -= dt;
      if (invulnerabilityTimer <= 0) {
        isInvulnerable = false;
        opacity = 1.0;
      } else {
        // Flicker effect during invulnerability
        opacity = (invulnerabilityTimer * 10).floor() % 2 == 0 ? 0.5 : 1.0;
      }
    }
    
    // Apply gravity
    if (!isOnGround) {
      velocity.y += _gravity * dt;
      velocity.y = velocity.y.clamp(-_jumpVelocity, _maxFallSpeed);
    }
    
    // Update position based on velocity
    position += velocity * dt;
    
    // Update animation state
    _updateAnimationState();
    
    // Reset ground state (will be set by collision detection)
    isOnGround = false;
  }

  /// Handle tap input for jumping
  void handleTap() {
    jump();
  }

  /// Make the player jump
  void jump() {
    if (canJump && isOnGround) {
      velocity.y = _jumpVelocity;
      isOnGround = false;
      canJump = false;
      
      // Play jump sound effect
      _playJumpSound();
    }
  }

  /// Update animation based on current state
  void _updateAnimationState() {
    PlayerState newState;
    
    if (!isOnGround) {
      if (velocity.y < 0) {
        newState = PlayerState.jumping;
      } else {
        newState = PlayerState.falling;
      }
    } else if (velocity.x.abs() > 10) {
      newState = PlayerState.running;
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
      case PlayerState.running:
        animation = runAnimation;
        break;
      case PlayerState.jumping:
        animation = jumpAnimation;
        break;
      case PlayerState.falling:
        animation = fallAnimation;
        break;
    }
  }

  /// Handle collision with platforms
  void onPlatformCollision() {
    if (velocity.y >= 0) {
      isOnGround = true;
      canJump = true;
      velocity.y = 0;
    }
  }

  /// Handle collision with gems
  void onGemCollision() {
    // Increment score through game reference
    try {
      gameRef.add(ScoreUpdateEvent(points: 10));
    } catch (e) {
      print('Error updating score: $e');
    }
  }

  /// Handle collision with hazards
  void onHazardCollision() {
    if (!isInvulnerable) {
      takeDamage();
    }
  }

  /// Take damage and handle health reduction
  void takeDamage() {
    if (isInvulnerable) return;
    
    health--;
    isInvulnerable = true;
    invulnerabilityTimer = invulnerabilityDuration;
    
    // Play damage sound effect
    _playDamageSound();
    
    if (health <= 0) {
      _handleDeath();
    }
  }

  /// Handle player death
  void _handleDeath() {
    // Trigger game over event
    gameRef.add(GameOverEvent());
  }

  /// Heal the player
  void heal(int amount) {
    health = (health + amount).clamp(0, maxHealth);
  }

  /// Reset player to checkpoint or level start
  void resetToCheckpoint(Vector2 checkpointPosition) {
    position = checkpointPosition.clone();
    velocity = Vector2.zero();
    health = maxHealth;
    isInvulnerable = false;
    invulnerabilityTimer = 0.0;
    opacity = 1.0;
  }

  /// Play jump sound effect
  void _playJumpSound() {
    try {
      // Implementation depends on audio system
      // gameRef.audioManager.playSfx('jump.wav');
    } catch (e) {
      print('Error playing jump sound: $e');
    }
  }

  /// Play damage sound effect
  void _playDamageSound() {
    try {
      // Implementation depends on audio system
      // gameRef.audioManager.playSfx('damage.wav');
    } catch (e) {
      print('Error playing damage sound: $e');
    }
  }

  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    // Handle different collision types
    if (other is Platform) {
      onPlatformCollision();
    } else if (other is Gem) {
      onGemCollision();
      other.removeFromParent();
    } else if (other is Hazard) {
      onHazardCollision();
    }
    
    return true;
  }
}

/// Player animation states
enum PlayerState {
  idle,
  running,
  jumping,
  falling,
}

/// Score update event
class ScoreUpdateEvent extends Component {
  final int points;
  
  ScoreUpdateEvent({required this.points});
}

/// Game over event
class GameOverEvent extends Component {}

/// Placeholder components for collision detection
abstract class Platform extends PositionComponent {}
abstract class Gem extends PositionComponent {}
abstract class Hazard extends PositionComponent {}