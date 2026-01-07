import 'dart:async';
import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/player.dart';
import '../components/platform.dart';
import '../components/gem.dart';
import '../components/checkpoint.dart';
import '../components/spike.dart';
import '../components/moving_platform.dart';
import '../components/exit_portal.dart';
import '../components/background.dart';
import '../components/particle_system.dart';
import '../controllers/game_controller.dart';
import '../services/analytics_service.dart';
import '../models/level_config.dart';
import '../utils/constants.dart';

/// Game states for the platformer
enum GameState {
  playing,
  paused,
  gameOver,
  levelComplete,
  loading
}

/// Main FlameGame class for the mystical platformer game
class Batch20260107083440Platformer01Game extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection, HasTappables {
  
  /// Current game state
  GameState _gameState = GameState.loading;
  GameState get gameState => _gameState;

  /// Game controller reference
  late GameController gameController;

  /// Analytics service reference
  late AnalyticsService analyticsService;

  /// Current level configuration
  LevelConfig? _currentLevel;

  /// Player component
  late Player player;

  /// Game world components
  final List<Platform> platforms = [];
  final List<Gem> gems = [];
  final List<Checkpoint> checkpoints = [];
  final List<Spike> spikes = [];
  final List<MovingPlatform> movingPlatforms = [];
  ExitPortal? exitPortal;
  Background? background;
  ParticleSystem? particleSystem;

  /// Game metrics
  int _score = 0;
  int _lives = 3;
  int _gemsCollected = 0;
  int _totalGems = 0;
  double _levelTime = 0.0;
  double _maxLevelTime = 90.0;
  Vector2? _lastCheckpoint;

  /// Camera and world setup
  late CameraComponent cameraComponent;
  late World gameWorld;

  /// Getters for game state
  int get score => _score;
  int get lives => _lives;
  int get gemsCollected => _gemsCollected;
  int get totalGems => _totalGems;
  double get levelTime => _levelTime;
  double get maxLevelTime => _maxLevelTime;
  Vector2? get lastCheckpoint => _lastCheckpoint;

  @override
  Future<void> onLoad() async {
    try {
      // Initialize world and camera
      gameWorld = World();
      cameraComponent = CameraComponent(world: gameWorld);
      
      addAll([cameraComponent, gameWorld]);

      // Set up camera viewport
      cameraComponent.viewfinder.visibleGameSize = size;
      cameraComponent.viewfinder.anchor = Anchor.topLeft;

      // Initialize collision detection
      add(HasCollisionDetection.initializeCollisionDetection());

      // Load initial assets
      await _loadAssets();

      // Set initial state
      _gameState = GameState.playing;

      debugPrint('Batch-20260107-083440-platformer-01 Game initialized');
    } catch (e) {
      debugPrint('Error initializing game: $e');
      _gameState = GameState.gameOver;
    }
  }

  /// Load game assets
  Future<void> _loadAssets() async {
    // Preload sprite images
    await images.loadAll([
      'player_idle.png',
      'player_jump.png',
      'player_fall.png',
      'platform.png',
      'gem.png',
      'checkpoint.png',
      'spike.png',
      'moving_platform.png',
      'exit_portal.png',
      'background.png',
    ]);
  }

  /// Load a specific level
  Future<void> loadLevel(LevelConfig levelConfig) async {
    try {
      _gameState = GameState.loading;
      _currentLevel = levelConfig;

      // Clear existing level components
      await _clearLevel();

      // Reset game metrics
      _resetLevelMetrics();

      // Create background
      background = Background(levelConfig.backgroundStyle);
      gameWorld.add(background!);

      // Create particle system
      particleSystem = ParticleSystem();
      gameWorld.add(particleSystem!);

      // Create player
      player = Player(
        position: Vector2(levelConfig.playerStartX, levelConfig.playerStartY),
        game: this,
      );
      gameWorld.add(player);

      // Create platforms
      for (final platformData in levelConfig.platforms) {
        final platform = Platform(
          position: Vector2(platformData.x, platformData.y),
          size: Vector2(platformData.width, platformData.height),
        );
        platforms.add(platform);
        gameWorld.add(platform);
      }

      // Create moving platforms
      for (final movingPlatformData in levelConfig.movingPlatforms) {
        final movingPlatform = MovingPlatform(
          startPosition: Vector2(movingPlatformData.startX, movingPlatformData.startY),
          endPosition: Vector2(movingPlatformData.endX, movingPlatformData.endY),
          size: Vector2(movingPlatformData.width, movingPlatformData.height),
          speed: movingPlatformData.speed,
        );
        movingPlatforms.add(movingPlatform);
        gameWorld.add(movingPlatform);
      }

      // Create gems
      for (final gemData in levelConfig.gems) {
        final gem = Gem(
          position: Vector2(gemData.x, gemData.y),
          value: gemData.value,
        );
        gems.add(gem);
        gameWorld.add(gem);
      }
      _totalGems = gems.length;

      // Create checkpoints
      for (final checkpointData in levelConfig.checkpoints) {
        final checkpoint = Checkpoint(
          position: Vector2(checkpointData.x, checkpointData.y),
        );
        checkpoints.add(checkpoint);
        gameWorld.add(checkpoint);
      }

      // Create spikes
      for (final spikeData in levelConfig.spikes) {
        final spike = Spike(
          position: Vector2(spikeData.x, spikeData.y),
          size: Vector2(spikeData.width, spikeData.height),
        );
        spikes.add(spike);
        gameWorld.add(spike);
      }

      // Create exit portal
      exitPortal = ExitPortal(
        position: Vector2(levelConfig.exitX, levelConfig.exitY),
      );
      gameWorld.add(exitPortal!);

      // Set level time limit
      _maxLevelTime = levelConfig.timeLimit;

      // Set up camera to follow player
      cameraComponent.follow(player);

      _gameState = GameState.playing;

      // Log level start
      analyticsService.logEvent('level_start', {
        'level_number': levelConfig.levelNumber,
        'level_name': levelConfig.name,
      });

    } catch (e) {
      debugPrint('Error loading level: $e');
      _gameState = GameState.gameOver;
    }
  }

  /// Clear current level components
  Future<void> _clearLevel() async {
    // Remove all level components
    for (final platform in platforms) {
      platform.removeFromParent();
    }
    platforms.clear();

    for (final gem in gems) {
      gem.removeFromParent();
    }
    gems.clear();

    for (final checkpoint in checkpoints) {
      checkpoint.removeFromParent();
    }
    checkpoints.clear();

    for (final spike in spikes) {
      spike.removeFromParent();
    }
    spikes.clear();

    for (final movingPlatform in movingPlatforms) {
      movingPlatform.removeFromParent();
    }
    movingPlatforms.clear();

    exitPortal?.removeFromParent();
    exitPortal = null;

    background?.removeFromParent();
    background = null;

    particleSystem?.removeFromParent();
    particleSystem = null;

    if (gameWorld.children.contains(player)) {
      player.removeFromParent();
    }
  }

  /// Reset level metrics
  void _resetLevelMetrics() {
    _score = 0;
    _gemsCollected = 0;
    _totalGems = 0;
    _levelTime = 0.0;
    _lastCheckpoint = null;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_gameState == GameState.playing) {
      // Update level time
      _levelTime += dt;

      // Check time limit
      if (_levelTime >= _maxLevelTime) {
        _handleTimeUp();
      }

      // Update camera bounds
      _updateCamera();

      // Check win condition
      if (_gemsCollected >= _totalGems && exitPortal != null) {
        exitPortal!.activate();
      }
    }
  }

  /// Update camera to follow player with bounds
  void _updateCamera() {
    if (_currentLevel != null) {
      final viewport = cameraComponent.viewfinder;
      final playerPos = player.position;

      // Calculate camera bounds
      final leftBound = viewport.visibleGameSize.x / 2;
      final rightBound = _currentLevel!.width - viewport.visibleGameSize.x / 2;
      final topBound = viewport.visibleGameSize.y / 2;
      final bottomBound = _currentLevel!.height - viewport.visibleGameSize.y / 2;

      // Clamp camera position
      final targetX = playerPos.x.clamp(leftBound, rightBound);
      final targetY = playerPos.y.clamp(topBound, bottomBound);

      viewport.position = Vector2(targetX, targetY);
    }
  }

  /// Handle tap input for jumping
  @override
  bool onTapDown(TapDownInfo info) {
    if (_gameState == GameState.playing) {
      player.jump();
      return true;
    }
    return false;
  }

  /// Collect a gem
  void collectGem(Gem gem) {
    if (gems.contains(gem)) {
      _gemsCollected++;
      _score += gem.value;
      gems.remove(gem);
      gem.removeFromParent();

      // Add particle effect
      particleSystem?.addGemCollectionEffect(gem.position);

      // Play sound effect
      // AudioManager.instance.playSfx('gem_collect');

      // Update UI
      gameController.updateScore(_score);
      gameController.updateGemsCollected(_gemsCollected, _totalGems);

      // Log gem collection
      analyticsService.logEvent('gem_collected', {
        'gem_value': gem.value,
        'total_gems_collected': _gemsCollected,
        'level_number': _currentLevel?.levelNumber ?? 0,
      });
    }
  }

  /// Activate a checkpoint
  void activateCheckpoint(Checkpoint checkpoint) {
    _lastCheckpoint = checkpoint.position.clone();
    checkpoint.activate();

    // Add particle effect
    particleSystem?.addCheckpointEffect(checkpoint.position);

    // Log checkpoint activation
    analyticsService.logEvent('checkpoint_activated', {
      'checkpoint_x': checkpoint.position.x,
      'checkpoint_y': checkpoint.position.y,
      'level_number': _currentLevel?.levelNumber ?? 0,
    });
  }

  /// Handle player death
  void handlePlayerDeath() {
    if (_gameState != GameState.playing) return;

    _lives--;
    
    // Add death particle effect
    particleSystem?.addDeathEffect(player.position);

    if (_lives <= 0) {
      _handleGameOver();
    } else {
      _respawnPlayer();
    }

    // Log player death
    analyticsService.logEvent('player_death', {
      'lives_remaining': _lives,
      'death_position_x': player.position.x,
      'death_position_y': player.position.y,
      'level_number': _currentLevel?.levelNumber ?? 0,
    });
  }

  /// Respawn player at last checkpoint or start
  void _respawnPlayer() {
    final respawnPosition = _lastCheckpoint ?? 
        Vector2(_currentLevel?.playerStartX ?? 100, _currentLevel?.playerStartY ?? 100);
    
    player.respawn(respawnPosition);
    gameController.updateLives(_lives);
  }

  /// Handle level completion
  void handleLevelComplete() {
    if (_gameState != GameState.playing) return;

    _gameState = GameState.levelComplete;

    // Calculate final score with time bonus
    final timeBonus = max(0, (_maxLevelTime - _levelTime) * 10).round();
    _score += timeBonus;

    // Add completion particle effect
    particleSystem?.addLevelCompleteEffect(exitPortal!.position);

    // Update UI
    gameController.updateScore(_score);
    overlays.add('LevelCompleteOverlay');

    // Log level completion
    analyticsService.logEvent('level_complete', {
      'level_number': _currentLevel?.levelNumber ?? 0,
      'completion_time': _levelTime,
      'final_score': _score,
      'gems_collected': _gemsCollected,
      'time_bonus': timeBonus,
    });
  }

  /// Handle game over
  void _handleGameOver() {
    _gameState = GameState.gameOver;
    overlays.add('GameOverOverlay');

    // Log game over
    analyticsService.logEvent('level_fail', {
      'level_number': _currentLevel?.levelNumber ?? 0,
      'survival_time': _levelTime,
      'final_score': _score,
      'gems_collected': _gemsCollected,
      'death_cause': 'no_lives_remaining',
    });
  }

  /// Handle time up
  void _handleTimeUp() {
    _gameState = GameState.gameOver;
    overlays.add('GameOverOverlay');

    // Log time up
    analyticsService.logEvent('level_fail', {
      'level_number': _currentLevel?.levelNumber ?? 0,
      'final_score': _score,
      'gems_collected': _gemsCollected,
      'death_cause': 'time_up',
    });
  }

  /// Pause the game
  void pauseGame() {
    if (_gameState == GameState.playing) {
      _gameState = GameState.paused;
      overlays.add('PauseOverlay');
    }
  }

  /// Resume the game
  void resumeGame() {
    if (_gameState == GameState.paused) {
      _gameState = GameState.playing;
      overlays.remove('PauseOverlay');
    }
  }

  /// Restart current level
  void restartLevel() {
    if (_currentLevel != null) {
      overlays.remove('GameOverOverlay');
      overlays.remove('PauseOverlay');
      _lives = 3;
      loadLevel(_currentLevel!);
    }
  }

  /// Go to next level
  void nextLevel() {
    overlays.remove('LevelCompleteOverlay');
    gameController.loadNextLevel();
  }

  /// Return to main menu
  void returnToMenu() {
    overlays.remove('GameOverOverlay');
    overlays.remove('PauseOverlay');
    overlays.remove('LevelCompleteOverlay');
    gameController.returnToMenu();
  }

  @override
  void onRemove() {
    // Clean