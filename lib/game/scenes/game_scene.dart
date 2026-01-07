import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

/// Main game scene component that manages the platformer gameplay
/// Handles level loading, player spawning, game state, and UI integration
class GameScene extends Component with HasKeyboardHandlerComponents, HasTapHandlers {
  late Player player;
  late CameraComponent camera;
  late World world;
  late TextComponent scoreDisplay;
  late TextComponent levelDisplay;
  late TextComponent timeDisplay;
  
  int currentLevel = 1;
  int score = 0;
  int gemsCollected = 0;
  double levelTime = 90.0;
  double currentTime = 90.0;
  bool isGameActive = false;
  bool isPaused = false;
  bool levelCompleted = false;
  
  List<Platform> platforms = [];
  List<Gem> gems = [];
  List<Hazard> hazards = [];
  List<Checkpoint> checkpoints = [];
  Vector2? lastCheckpointPosition;
  
  late Timer gameTimer;
  Random random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize world and camera
    world = World();
    camera = CameraComponent.withFixedResolution(
      world: world,
      width: 400,
      height: 800,
    );
    
    addAll([world, camera]);
    
    // Initialize UI components
    await _initializeUI();
    
    // Load the first level
    await loadLevel(currentLevel);
    
    // Start game timer
    _startGameTimer();
  }

  /// Initialize UI components for score, level, and time display
  Future<void> _initializeUI() async {
    scoreDisplay = TextComponent(
      text: 'Gems: 0',
      position: Vector2(20, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    
    levelDisplay = TextComponent(
      text: 'Level: 1',
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF7B68EE),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    
    timeDisplay = TextComponent(
      text: 'Time: 90',
      position: Vector2(280, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF6B6B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    
    camera.viewport.addAll([scoreDisplay, levelDisplay, timeDisplay]);
  }

  /// Load and setup a specific level with platforms, gems, and hazards
  Future<void> loadLevel(int level) async {
    try {
      // Clear existing level components
      _clearLevel();
      
      // Reset level state
      currentLevel = level;
      currentTime = levelTime;
      levelCompleted = false;
      isGameActive = true;
      
      // Generate level layout based on difficulty
      await _generateLevelLayout(level);
      
      // Spawn player at starting position
      await _spawnPlayer();
      
      // Update UI
      _updateUI();
      
      // Analytics: level start
      _trackEvent('level_start', {'level': level});
      
    } catch (e) {
      print('Error loading level $level: $e');
      // Fallback to basic level
      await _generateBasicLevel();
    }
  }

  /// Generate level layout based on difficulty progression
  Future<void> _generateLevelLayout(int level) async {
    final difficulty = _calculateDifficulty(level);
    final platformCount = 8 + (level * 2);
    final gemCount = 5 + level;
    final hazardCount = max(0, level - 2);
    
    // Generate platforms
    await _generatePlatforms(platformCount, difficulty);
    
    // Generate gems
    await _generateGems(gemCount);
    
    // Generate hazards
    if (hazardCount > 0) {
      await _generateHazards(hazardCount, difficulty);
    }
    
    // Generate checkpoints
    await _generateCheckpoints(level);
    
    // Add exit portal at the end
    await _addExitPortal();
  }

  /// Generate platforms with increasing difficulty
  Future<void> _generatePlatforms(int count, double difficulty) async {
    platforms.clear();
    
    // Starting platform
    final startPlatform = Platform(
      position: Vector2(200, 700),
      size: Vector2(120, 20),
      isMoving: false,
    );
    platforms.add(startPlatform);
    world.add(startPlatform);
    
    double currentY = 650;
    double currentX = 200;
    
    for (int i = 1; i < count; i++) {
      // Calculate next platform position with difficulty scaling
      final jumpDistance = 80 + (difficulty * 40);
      final verticalGap = 60 + (difficulty * 20);
      
      currentY -= verticalGap + random.nextDouble() * 40;
      currentX += (random.nextDouble() - 0.5) * jumpDistance;
      
      // Keep platforms within screen bounds
      currentX = currentX.clamp(60, 340);
      
      final isMoving = difficulty > 0.3 && random.nextDouble() < difficulty;
      final platform = Platform(
        position: Vector2(currentX, currentY),
        size: Vector2(100 - (difficulty * 20), 20),
        isMoving: isMoving,
        moveSpeed: isMoving ? 50 + (difficulty * 30) : 0,
        moveRange: isMoving ? 80 + (difficulty * 40) : 0,
      );
      
      platforms.add(platform);
      world.add(platform);
    }
  }

  /// Generate collectible gems throughout the level
  Future<void> _generateGems(int count) async {
    gems.clear();
    
    for (int i = 0; i < count; i++) {
      final platformIndex = random.nextInt(platforms.length);
      final platform = platforms[platformIndex];
      
      final gem = Gem(
        position: Vector2(
          platform.position.x + random.nextDouble() * platform.size.x,
          platform.position.y - 40,
        ),
        value: 10 + random.nextInt(15),
      );
      
      gems.add(gem);
      world.add(gem);
    }
  }

  /// Generate hazards like spikes based on difficulty
  Future<void> _generateHazards(int count, double difficulty) async {
    hazards.clear();
    
    for (int i = 0; i < count; i++) {
      final platformIndex = 1 + random.nextInt(platforms.length - 2);
      final platform = platforms[platformIndex];
      
      final hazard = Hazard(
        position: Vector2(
          platform.position.x + platform.size.x + 20,
          platform.position.y - 30,
        ),
        type: HazardType.spikes,
      );
      
      hazards.add(hazard);
      world.add(hazard);
    }
  }

  /// Generate checkpoints for player respawn
  Future<void> _generateCheckpoints(int level) async {
    checkpoints.clear();
    
    final checkpointCount = max(1, 4 - (level ~/ 3));
    final platformStep = platforms.length ~/ (checkpointCount + 1);
    
    for (int i = 1; i <= checkpointCount; i++) {
      final platformIndex = i * platformStep;
      if (platformIndex < platforms.length) {
        final platform = platforms[platformIndex];
        final checkpoint = Checkpoint(
          position: Vector2(platform.position.x, platform.position.y - 50),
        );
        
        checkpoints.add(checkpoint);
        world.add(checkpoint);
      }
    }
  }

  /// Add exit portal at the end of the level
  Future<void> _addExitPortal() async {
    if (platforms.isNotEmpty) {
      final lastPlatform = platforms.last;
      final exitPortal = ExitPortal(
        position: Vector2(lastPlatform.position.x, lastPlatform.position.y - 60),
      );
      world.add(exitPortal);
    }
  }

  /// Spawn player at the starting position
  Future<void> _spawnPlayer() async {
    final startPosition = lastCheckpointPosition ?? Vector2(200, 650);
    
    player = Player(position: startPosition);
    world.add(player);
    
    // Setup camera to follow player
    camera.follow(player);
  }

  /// Calculate difficulty factor based on level progression
  double _calculateDifficulty(int level) {
    return (level - 1) / 9.0; // 0.0 to 1.0 scale for levels 1-10
  }

  /// Start the game timer countdown
  void _startGameTimer() {
    gameTimer = Timer(
      1.0,
      repeat: true,
      onTick: () {
        if (isGameActive && !isPaused) {
          currentTime -= 1.0;
          _updateTimeDisplay();
          
          if (currentTime <= 0) {
            _handleTimeUp();
          }
        }
      },
    );
    add(gameTimer);
  }

  /// Handle time running out
  void _handleTimeUp() {
    isGameActive = false;
    _trackEvent('level_fail', {
      'level': currentLevel,
      'reason': 'time_up',
      'gems_collected': gemsCollected,
    });
    
    // Trigger game over UI
    _showGameOverScreen();
  }

  /// Handle player collecting a gem
  void onGemCollected(Gem gem) {
    if (!isGameActive) return;
    
    score += gem.value;
    gemsCollected++;
    gems.remove(gem);
    gem.removeFromParent();
    
    _updateScoreDisplay();
    
    // Check if all gems collected
    if (gems.isEmpty) {
      _addBonusPoints(100);
    }
  }

  /// Handle player reaching a checkpoint
  void onCheckpointReached(Checkpoint checkpoint) {
    lastCheckpointPosition = checkpoint.position.clone();
    checkpoint.activate();
  }

  /// Handle player reaching the exit portal
  void onExitPortalReached() {
    if (!isGameActive) return;
    
    levelCompleted = true;
    isGameActive = false;
    
    // Calculate completion bonus
    final timeBonus = (currentTime * 5).round();
    _addBonusPoints(timeBonus);
    
    _trackEvent('level_complete', {
      'level': currentLevel,
      'time_remaining': currentTime,
      'gems_collected': gemsCollected,
      'final_score': score,
    });
    
    _showLevelCompleteScreen();
  }

  /// Handle player falling or hitting hazards
  void onPlayerDeath(String reason) {
    if (!isGameActive) return;
    
    _trackEvent('level_fail', {
      'level': currentLevel,
      'reason': reason,
      'gems_collected': gemsCollected,
    });
    
    // Respawn at last checkpoint or restart level
    _respawnPlayer();
  }

  /// Respawn player at last checkpoint
  void _respawnPlayer() {
    player.removeFromParent();
    
    final respawnPosition = lastCheckpointPosition ?? Vector2(200, 650);
    player = Player(position: respawnPosition);
    world.add(player);
  }

  /// Add bonus points to score
  void _addBonusPoints(int points) {
    score += points;
    _updateScoreDisplay();
  }

  /// Update all UI displays
  void _updateUI() {
    levelDisplay.text = 'Level: $currentLevel';
    _updateScoreDisplay();
    _updateTimeDisplay();
  }

  /// Update score display
  void _updateScoreDisplay() {
    scoreDisplay.text = 'Gems: $gemsCollected';
  }

  /// Update time display
  void _updateTimeDisplay() {
    timeDisplay.text = 'Time: ${currentTime.round()}';
  }

  /// Clear all level components
  void _clearLevel() {
    for (final platform in platforms) {
      platform.removeFromParent();
    }
    for (final gem in gems) {
      gem.removeFromParent();
    }
    for (final hazard in hazards) {
      hazard.removeFromParent();
    }
    for (final checkpoint in checkpoints) {
      checkpoint.removeFromParent();
    }
    
    platforms.clear();
    gems.clear();
    hazards.clear();
    checkpoints.clear();
    
    if (player.isMounted) {
      player.removeFromParent();
    }
  }

  /// Generate a basic fallback level
  Future<void> _generateBasicLevel() async {
    // Simple 3-platform level as fallback
    final basicPlatforms = [
      Platform(position: Vector2(200, 700), size: Vector2(120, 20), isMoving: false),
      Platform(position: Vector2(200, 600), size: Vector2(100, 20), isMoving: false),
      Platform(position: Vector2(200, 500), size: Vector2(100, 20), isMoving: false),
    ];
    
    for (final platform in basicPlatforms) {
      platforms.add(platform);
      world.add(platform);
    }
    
    // Add one gem
    final gem = Gem(position: Vector2(200, 460), value: 10);
    gems.add(gem);
    world.add(gem);
    
    // Add exit portal
    final exitPortal = ExitPortal(position: Vector2(200, 440));
    world.add(exitPortal);
  }

  /// Show level complete screen
  void _showLevelCompleteScreen() {
    // This would trigger UI overlay showing completion
    print('Level $currentLevel completed! Score: $score');
  }

  /// Show game over screen
  void _showGameOverScreen() {
    // This would trigger UI overlay showing game over
    print('Game Over! Time ran out. Score: $score');
  }

  /// Pause the game
  void pauseGame() {
    isPaused = true;
  }

  /// Resume the game
  void resumeGame() {
    isPaused = false;
  }

  /// Restart current level
  Future<void> restartLevel() async {
    lastCheckpointPosition = null;
    gemsCollected = 0;
    score = 0;
    await loadLevel(currentLevel);
  }

  /// Advance to next level
  Future<void> nextLevel() async {
    if (currentLevel < 10) {
      lastCheckpointPosition = null;
      await loadLevel(currentLevel + 1);
    }
  }

  /// Track analytics events
  void _trackEvent(String eventName, Map<String, dynamic> parameters) {
    // Analytics implementation would go here
    print('Analytics: $eventName - $parameters');
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (isGameActive && !isPaused) {
      player.jump();
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!isGameActive || isPaused) return;
    
    // Update game logic
    _checkCollisions();
    _updateMovingPlatforms(dt);