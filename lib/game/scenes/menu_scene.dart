import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Main menu scene for the platformer game featuring mystical floating islands
class MenuScene extends Component with HasGameRef, TapCallbacks {
  late SpriteComponent background;
  late TextComponent titleText;
  late RectangleComponent playButton;
  late TextComponent playButtonText;
  late RectangleComponent levelSelectButton;
  late TextComponent levelSelectButtonText;
  late RectangleComponent settingsButton;
  late TextComponent settingsButtonText;
  late List<SpriteComponent> floatingParticles;
  
  double animationTime = 0.0;
  final int particleCount = 15;

  @override
  Future<void> onLoad() async {
    await _setupBackground();
    await _setupTitle();
    await _setupButtons();
    await _setupFloatingParticles();
  }

  /// Sets up the mystical background with starry night sky
  Future<void> _setupBackground() async {
    background = SpriteComponent()
      ..sprite = await Sprite.load('menu_background.png')
      ..size = gameRef.size
      ..position = Vector2.zero();
    add(background);
  }

  /// Creates the game title with mystical styling
  Future<void> _setupTitle() async {
    titleText = TextComponent(
      text: 'Mystical Islands',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFD700),
          shadows: [
            Shadow(
              offset: Offset(2, 2),
              blurRadius: 8,
              color: Color(0xFF7B68EE),
            ),
          ],
        ),
      ),
    );
    titleText.position = Vector2(
      gameRef.size.x / 2 - titleText.size.x / 2,
      gameRef.size.y * 0.2,
    );
    add(titleText);
  }

  /// Creates menu buttons with mystical crystal theme
  Future<void> _setupButtons() async {
    final buttonWidth = gameRef.size.x * 0.7;
    final buttonHeight = 60.0;
    final centerX = gameRef.size.x / 2;
    
    // Play Button
    playButton = RectangleComponent(
      size: Vector2(buttonWidth, buttonHeight),
      paint: Paint()
        ..color = const Color(0xFF4A90E2)
        ..style = PaintingStyle.fill,
    );
    playButton.position = Vector2(
      centerX - buttonWidth / 2,
      gameRef.size.y * 0.45,
    );
    playButton.decorator.addLast(PaintDecorator.blur(2.0));
    add(playButton);

    playButtonText = TextComponent(
      text: 'PLAY',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
    playButtonText.position = Vector2(
      centerX - playButtonText.size.x / 2,
      gameRef.size.y * 0.45 + buttonHeight / 2 - playButtonText.size.y / 2,
    );
    add(playButtonText);

    // Level Select Button
    levelSelectButton = RectangleComponent(
      size: Vector2(buttonWidth, buttonHeight),
      paint: Paint()
        ..color = const Color(0xFF7B68EE)
        ..style = PaintingStyle.fill,
    );
    levelSelectButton.position = Vector2(
      centerX - buttonWidth / 2,
      gameRef.size.y * 0.55,
    );
    levelSelectButton.decorator.addLast(PaintDecorator.blur(2.0));
    add(levelSelectButton);

    levelSelectButtonText = TextComponent(
      text: 'LEVEL SELECT',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
    levelSelectButtonText.position = Vector2(
      centerX - levelSelectButtonText.size.x / 2,
      gameRef.size.y * 0.55 + buttonHeight / 2 - levelSelectButtonText.size.y / 2,
    );
    add(levelSelectButtonText);

    // Settings Button
    settingsButton = RectangleComponent(
      size: Vector2(buttonWidth, buttonHeight),
      paint: Paint()
        ..color = const Color(0xFF32CD32)
        ..style = PaintingStyle.fill,
    );
    settingsButton.position = Vector2(
      centerX - buttonWidth / 2,
      gameRef.size.y * 0.65,
    );
    settingsButton.decorator.addLast(PaintDecorator.blur(2.0));
    add(settingsButton);

    settingsButtonText = TextComponent(
      text: 'SETTINGS',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
    settingsButtonText.position = Vector2(
      centerX - settingsButtonText.size.x / 2,
      gameRef.size.y * 0.65 + buttonHeight / 2 - settingsButtonText.size.y / 2,
    );
    add(settingsButtonText);
  }

  /// Creates floating magical particles for background animation
  Future<void> _setupFloatingParticles() async {
    floatingParticles = [];
    
    for (int i = 0; i < particleCount; i++) {
      final particle = SpriteComponent()
        ..sprite = await Sprite.load('magic_particle.png')
        ..size = Vector2(8, 8)
        ..position = Vector2(
          gameRef.random.nextDouble() * gameRef.size.x,
          gameRef.random.nextDouble() * gameRef.size.y,
        );
      
      floatingParticles.add(particle);
      add(particle);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    animationTime += dt;
    
    _animateTitle(dt);
    _animateParticles(dt);
    _animateButtons(dt);
  }

  /// Animates the title with a gentle glow effect
  void _animateTitle(double dt) {
    final glowIntensity = 0.5 + 0.3 * (1 + math.sin(animationTime * 2)) / 2;
    titleText.textRenderer = TextPaint(
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFD700),
        shadows: [
          Shadow(
            offset: const Offset(2, 2),
            blurRadius: 8 * glowIntensity,
            color: const Color(0xFF7B68EE),
          ),
        ],
      ),
    );
  }

  /// Animates floating particles with gentle movement
  void _animateParticles(double dt) {
    for (int i = 0; i < floatingParticles.length; i++) {
      final particle = floatingParticles[i];
      
      // Gentle floating motion
      particle.position.y += math.sin(animationTime + i) * 20 * dt;
      particle.position.x += math.cos(animationTime * 0.5 + i) * 10 * dt;
      
      // Wrap around screen edges
      if (particle.position.y > gameRef.size.y + 10) {
        particle.position.y = -10;
      }
      if (particle.position.x > gameRef.size.x + 10) {
        particle.position.x = -10;
      } else if (particle.position.x < -10) {
        particle.position.x = gameRef.size.x + 10;
      }
      
      // Gentle opacity animation
      particle.opacity = 0.6 + 0.4 * (1 + math.sin(animationTime * 3 + i)) / 2;
    }
  }

  /// Animates buttons with subtle hover effects
  void _animateButtons(double dt) {
    final hoverScale = 1.0 + 0.05 * math.sin(animationTime * 4);
    
    playButton.scale = Vector2.all(hoverScale);
    levelSelectButton.scale = Vector2.all(1.0 + 0.03 * math.sin(animationTime * 3));
    settingsButton.scale = Vector2.all(1.0 + 0.04 * math.sin(animationTime * 2.5));
  }

  @override
  bool onTapDown(TapDownEvent event) {
    final tapPosition = event.localPosition;
    
    if (_isPointInButton(tapPosition, playButton)) {
      _onPlayButtonPressed();
      return true;
    } else if (_isPointInButton(tapPosition, levelSelectButton)) {
      _onLevelSelectButtonPressed();
      return true;
    } else if (_isPointInButton(tapPosition, settingsButton)) {
      _onSettingsButtonPressed();
      return true;
    }
    
    return false;
  }

  /// Checks if a point is within a button's bounds
  bool _isPointInButton(Vector2 point, RectangleComponent button) {
    return point.x >= button.position.x &&
           point.x <= button.position.x + button.size.x &&
           point.y >= button.position.y &&
           point.y <= button.position.y + button.size.y;
  }

  /// Handles play button press
  void _onPlayButtonPressed() {
    // Add button press animation
    playButton.scale = Vector2.all(0.95);
    
    // Navigate to game scene
    // This would typically trigger a scene change in the game
    print('Play button pressed - Starting game');
  }

  /// Handles level select button press
  void _onLevelSelectButtonPressed() {
    levelSelectButton.scale = Vector2.all(0.95);
    print('Level select button pressed - Opening level selection');
  }

  /// Handles settings button press
  void _onSettingsButtonPressed() {
    settingsButton.scale = Vector2.all(0.95);
    print('Settings button pressed - Opening settings menu');
  }
}

import 'dart:math' as math;