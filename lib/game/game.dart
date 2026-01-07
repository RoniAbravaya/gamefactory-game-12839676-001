import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main game class for the mystical platformer adventure
class Batch20260107083440Platformer01Game extends FlameGame
    with HasTapDetectors, HasCollisionDetection, HasKeyboardHandlerComponents {
  
  /// Current game state
  GameState gameState = GameState.playing;
  
  /// Current level number (1-10)
  int currentLevel = 1;
  
  /// Player's current score
  int score = 0;
  
  /// Gems collected in current level
  int gemsCollected = 0;
  
  /// Total gems collected across all levels
  int totalGems = 0;
  
  /// Time remaining in current level (90 seconds)
  double timeRemaining = 90.0;
  
  /// Reference to the player character
  late PlayerComponent player;
  
  /// Camera component for following player
  late CameraComponent cameraComponent;
  
  /// Background parallax component
  late ParallaxComponent background;
  
  /// Level data and components
  final List<Component> levelComponents = [];
  
  /// Checkpoint positions for current level
  final List<Vector2> checkpoints = [];
  
  /// Current active checkpoint index
  int currentCheckpoint = 0;
  
  /// Analytics service integration hook
  Function(String event, Map<String, dynamic> parameters)? onAnalyticsEvent;
  
  /// Ad service integration hook
  Function(String adType, Function onComplete, Function onFailed)? onShowAd;
  
  /// Storage service integration hook
  Function(String key, dynamic value)? onSaveData;
  Function(String key, dynamic defaultValue)? onLoadData;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize camera
    cameraComponent = CameraComponent.withFixedResolution(
      width: 400,
      height: 800,
    );
    add(cameraComponent);
    
    // Load background
    await _loadBackground();
    
    // Initialize player
    player = PlayerComponent();
    add(player);
    
    // Load initial level
    await loadLevel(currentLevel);
    
    // Track game start
    _trackEvent('game_start', {
      'level': currentLevel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameState == GameState.playing) {
      // Update timer
      timeRemaining -= dt;
      
      // Check for time up
      if (timeRemaining <= 0) {
        _handleGameOver('time_up');
      }
      
      // Update camera to follow player
      cameraComponent.viewfinder.visibleGameSize = size;
      cameraComponent.viewfinder.position = Vector2(
        player.position.x,
        player.position.y - 200,
      );
    }
  }
  
  @override
  bool onTapDown(TapDownInfo info) {
    if (gameState == GameState.playing) {
      player.jump();
      return true;
    }
    return false;
  }
  
  /// Load a specific level
  Future<void> loadLevel(int levelNumber) async {
    try {
      // Clear existing level components
      for (final component in levelComponents) {
        component.removeFromParent();
      }
      levelComponents.clear();
      checkpoints.clear();
      
      // Reset level state
      currentLevel = levelNumber;
      gemsCollected = 0;
      timeRemaining = 90.0;
      currentCheckpoint = 0;
      gameState = GameState.playing;
      
      // Track level start
      _trackEvent('level_start', {
        'level': levelNumber,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Load level-specific components based on difficulty
      await _generateLevelComponents(levelNumber);
      
      // Position player at start
      player.position = Vector2(50, 600);
      player.resetState();
      
    } catch (e) {
      debugPrint('Error loading level $levelNumber: $e');
    }
  }
  
  /// Generate level components based on level number and difficulty
  Future<void> _generateLevelComponents(int levelNumber) async {
    // Calculate difficulty scaling
    final difficultyScale = (levelNumber - 1) / 9.0; // 0.0 to 1.0
    
    // Platform gap distance increases with level
    final baseGap = 80.0 + (difficultyScale * 40.0);
    
    // Number of platforms decreases with level (fewer checkpoints)
    final platformCount = 15 - (difficultyScale * 5).round();
    
    // Generate platforms
    for (int i = 0; i < platformCount; i++) {
      final x = 100.0 + (i * (baseGap + 50));
      final y = 400.0 + (i % 3) * 100.0; // Varying heights
      
      final platform = PlatformComponent(
        position: Vector2(x, y),
        isMoving: levelNumber > 2 && i % 4 == 0, // Moving platforms in later levels
        moveSpeed: 50.0 + (difficultyScale * 30.0),
      );
      
      add(platform);
      levelComponents.add(platform);
      
      // Add checkpoint every 3 platforms
      if (i % 3 == 0) {
        checkpoints.add(Vector2(x, y - 50));
      }
    }
    
    // Generate gems
    final gemCount = 8 + (difficultyScale * 4).round();
    for (int i = 0; i < gemCount; i++) {
      final x = 150.0 + (i * 120.0);
      final y = 300.0 + (i % 2) * 80.0;
      
      final gem = GemComponent(position: Vector2(x, y));
      add(gem);
      levelComponents.add(gem);
    }
    
    // Generate hazards (spikes) for higher levels
    if (levelNumber > 3) {
      final spikeCount = ((levelNumber - 3) * 2).clamp(0, 8);
      for (int i = 0; i < spikeCount; i++) {
        final x = 200.0 + (i * 150.0);
        final y = 500.0;
        
        final spike = SpikeComponent(position: Vector2(x, y));
        add(spike);
        levelComponents.add(spike);
      }
    }
    
    // Add exit portal at the end
    final exitPortal = ExitPortalComponent(
      position: Vector2(100.0 + (platformCount * (baseGap + 50)), 300.0),
    );
    add(exitPortal);
    levelComponents.add(exitPortal);
  }
  
  /// Load mystical fantasy background
  Future<void> _loadBackground() async {
    background = await loadParallaxComponent([
      ParallaxImageData('backgrounds/starry_sky.png'),
      ParallaxImageData('backgrounds/floating_islands.png'),
    ]);
    add(background);
  }
  
  /// Handle gem collection
  void collectGem(int value) {
    gemsCollected++;
    totalGems++;
    score += value;
    
    _trackEvent('gem_collected', {
      'level': currentLevel,
      'gems_in_level': gemsCollected,
      'total_gems': totalGems,
      'score': score,
    });
  }
  
  /// Handle reaching checkpoint
  void reachCheckpoint(int checkpointIndex) {
    if (checkpointIndex > currentCheckpoint) {
      currentCheckpoint = checkpointIndex;
      
      _trackEvent('checkpoint_reached', {
        'level': currentLevel,
        'checkpoint': checkpointIndex,
      });
    }
  }
  
  /// Handle level completion
  void completeLevel() {
    gameState = GameState.levelComplete;
    
    // Award completion bonus
    final completionBonus = 15 + (gemsCollected * 5);
    score += completionBonus;
    totalGems += 15; // Base gems per level
    
    _trackEvent('level_complete', {
      'level': currentLevel,
      'score': score,
      'gems_collected': gemsCollected,
      'time_remaining': timeRemaining,
      'completion_bonus': completionBonus,
    });
    
    // Save progress
    _saveGameData();
    
    // Show level complete overlay
    overlays.add('LevelCompleteOverlay');
  }
  
  /// Handle game over scenarios
  void _handleGameOver(String reason) {
    gameState = GameState.gameOver;
    
    _trackEvent('level_fail', {
      'level': currentLevel,
      'reason': reason,
      'score': score,
      'gems_collected': gemsCollected,
      'time_remaining': timeRemaining,
    });
    
    // Show game over overlay
    overlays.add('GameOverOverlay');
  }
  
  /// Restart from current checkpoint
  void restartFromCheckpoint() {
    if (currentCheckpoint < checkpoints.length) {
      player.position = checkpoints[currentCheckpoint].clone();
      player.resetState();
      gameState = GameState.playing;
      overlays.remove('GameOverOverlay');
    } else {
      restartLevel();
    }
  }
  
  /// Restart current level
  void restartLevel() {
    loadLevel(currentLevel);
    overlays.remove('GameOverOverlay');
  }
  
  /// Proceed to next level
  void nextLevel() {
    overlays.remove('LevelCompleteOverlay');
    
    if (currentLevel < 10) {
      // Check if next level is unlocked
      if (currentLevel >= 3 && !_isLevelUnlocked(currentLevel + 1)) {
        _showUnlockPrompt(currentLevel + 1);
      } else {
        loadLevel(currentLevel + 1);
      }
    } else {
      // Game completed
      _trackEvent('game_complete', {
        'final_score': score,
        'total_gems': totalGems,
      });
      overlays.add('GameCompleteOverlay');
    }
  }
  
  /// Check if a level is unlocked
  bool _isLevelUnlocked(int levelNumber) {
    if (levelNumber <= 3) return true;
    
    // Load from storage or return false
    final unlockedLevels = onLoadData?.call('unlocked_levels', <int>[1, 2, 3]) ?? [1, 2, 3];
    return unlockedLevels.contains(levelNumber);
  }
  
  /// Show unlock prompt for locked levels
  void _showUnlockPrompt(int levelNumber) {
    _trackEvent('unlock_prompt_shown', {
      'level': levelNumber,
    });
    
    overlays.add('UnlockPromptOverlay');
  }
  
  /// Unlock level via rewarded ad
  void unlockLevelWithAd(int levelNumber) {
    _trackEvent('rewarded_ad_started', {
      'level': levelNumber,
      'purpose': 'unlock_level',
    });
    
    onShowAd?.call('rewarded', () {
      // Ad completed successfully
      _trackEvent('rewarded_ad_completed', {
        'level': levelNumber,
        'purpose': 'unlock_level',
      });
      
      final unlockedLevels = onLoadData?.call('unlocked_levels', <int>[1, 2, 3]) ?? [1, 2, 3];
      if (!unlockedLevels.contains(levelNumber)) {
        unlockedLevels.add(levelNumber);
        onSaveData?.call('unlocked_levels', unlockedLevels);
      }
      
      _trackEvent('level_unlocked', {
        'level': levelNumber,
        'method': 'rewarded_ad',
      });
      
      overlays.remove('UnlockPromptOverlay');
      loadLevel(levelNumber);
    }, () {
      // Ad failed
      _trackEvent('rewarded_ad_failed', {
        'level': levelNumber,
        'purpose': 'unlock_level',
      });
    });
  }
  
  /// Save game data
  void _saveGameData() {
    onSaveData?.call('total_gems', totalGems);
    onSaveData?.call('highest_level', currentLevel);
    onSaveData?.call('total_score', score);
  }
  
  /// Track analytics event
  void _trackEvent(String event, Map<String, dynamic> parameters) {
    onAnalyticsEvent?.call(event, parameters);
  }
  
  /// Pause the game
  void pauseGame() {
    gameState = GameState.paused;
    overlays.add('PauseOverlay');
  }
  
  /// Resume the game
  void resumeGame() {
    gameState = GameState.playing;
    overlays.remove('PauseOverlay');
  }
}

/// Game state enumeration
enum GameState {
  playing,
  paused,
  gameOver,
  levelComplete,
}

/// Player character component
class PlayerComponent extends SpriteAnimationComponent with HasCollisionDetection {
  late Vector2 velocity;
  bool isOnGround = false;
  bool isJumping = false;
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Load player sprite animation
    animation = await game.loadSpriteAnimation(
      'characters/player.png',
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.2,
        textureSize: Vector2(32, 32),
      ),
    );
    
    size = Vector2(32, 32);
    velocity = Vector2.zero();
    
    // Add collision detection
    add(RectangleHitbox());
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Apply gravity
    if (!isOnGround) {
      velocity.y += 800 * dt; // Gravity
    }
    
    // Update position
    position += velocity * dt;
    
    // Check for falling off screen
    if (position.y > 1000) {
      (game as Batch20260107083440Platformer01Game)._handleGameOver('fell_off_screen');
    }
  }
  
  /// Make the player jump
  void jump() {
    if (isOnGround) {
      velocity.y = -400; // Jump velocity
      isOnGround = false;
      isJumping = true;
    }
  }
  
  /// Reset player state
  void resetState() {
    velocity = Vector2.zero();
    isOnGround = false;
    isJumping = false;
  }
}

/// Platform component
class PlatformComponent extends RectangleComponent with HasCollisionDetection {
  final bool isMoving;
  final double moveSpeed;
  late Vector2 moveDirection;
  late Vector2 startPosition;
  
  PlatformComponent({
    required Vector2 position,
    this.isMoving = false,
    this.moveSpeed = 50.0,
  }) : super(
    position: position,
    size: Vector2(100, 20),
    paint: Paint()..color = const Color(0xFF7B68EE),
  );
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    startPosition = position.clone();
    moveDirection = Vector2(1, 0);