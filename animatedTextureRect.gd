@tool
@icon("icon.png")
class_name AnimatedTextureRect;
extends TextureRect;
## A [TextureRect] with animation support via [SpriteFrames].

## Triggered as soon as the animation ends, when loop mode is "None".
signal animation_ended;
## Triggered as soon as the animation restarts and the first frame is redrawn.
signal animation_looped;

## The [SpriteFrames] containing the information for all animations.
@export var animations: SpriteFrames;
## The initial animation to be used when the scene starts and/or in the editor preview.[br][br]
## This value must be a [code]string[/code] containing the exact name of the animation within the [SpriteFrames].
@export var startAnimation: String = "default":
	set(value):
		startAnimation = value;
		_setup();
## The loop mode to be used for the initial animation.[br][br]
@export var startLoopMode: LOOP_MODE = LOOP_MODE.KEEP:
	set(value):
		startLoopMode = value;
		_setup();
## Determines whether the initial animation should play automatically as soon as the scene starts.
@export var playOnStart: bool = true;
## Determines whether the initial animation should play in editor mode.
@export var playOnEditor: bool = false:
	set(value):
		playOnEditor = value;
		_setup();

# Prevents the TextureRect's standard "texture" property from appearing in the editor panel, since this property is intended to be modified internally by this script.
func _validate_property(property: Dictionary) -> void:
	if (property.name == "texture"):
		property.usage = PROPERTY_USAGE_INTERNAL;

func _ready():
	_setup();

func _setup():
	stop();
	_animationName = startAnimation;
	if animations:
		if animations.has_animation(startAnimation): set_to_frame(0); # If the initial animation is valid, make the first frame visible.
	if (playOnStart && !Engine.is_editor_hint()) || (Engine.is_editor_hint() && playOnEditor):
		play(startAnimation, startLoopMode); # Plays the animation as soon as the scene starts, if the corresponding variable is enabled. It also plays the animation in the editor if the other corresponding variable is enabled.

@onready var _playingAnim: bool = false;
@onready var _animationName: String;
@onready var _loop: SpriteFrames.LoopMode;
var _animFps: float;
var _frameCount: int;
var _currentFrame: int;
var _currentFrameDuration: float;
var _lastUpdate: float;
var _pong: bool = false;
func _process(delta: float) -> void:
	if !_playingAnim: return; # It prevents the rest of the code from being read if the conditions for playing the animation are not met.
	if !playOnEditor && Engine.is_editor_hint(): return;
	
	_lastUpdate += delta;
	if _lastUpdate >= 1.0 / _animFps * _currentFrameDuration: # When this condition is met, the next frame of the animation must be rendered.
		_lastUpdate = 0;
		if _loop == SpriteFrames.LoopMode.LOOP_LINEAR && _currentFrame+1 > _frameCount-1: # Loop back to the first frame in linear mode
			_currentFrame = 0;
			animation_looped.emit()
		elif _loop == SpriteFrames.LoopMode.LOOP_PINGPONG: # Reverses the animation when the last frame plays in pingpong mode.
			if !_pong && _currentFrame >= _frameCount-1: _pong = true;
			elif _pong && _currentFrame <= 0:
				_pong = false;
				animation_looped.emit();
			
			if !_pong: _currentFrame += 1;
			else: _currentFrame -= 1;
		else: # Proceeds to the next frame normally for the other cases.
			_currentFrame += 1;
		_currentFrameDuration = animations.get_frame_duration(_animationName, _currentFrame); # This defines how much additional time the frame should last when changed in the SpriteFrames.
		_updateFrame();
		if _loop == SpriteFrames.LoopMode.LOOP_NONE && _currentFrame >= _frameCount-1: # When the last frame plays with looping disabled.
			_playingAnim = false;
			animation_ended.emit();

# Sets the "texture" property of the TextureRect to the current animation frame.
func _updateFrame():
	texture = animations.get_frame_texture(_animationName, _currentFrame);
	pass;

## Defines how the animation should loop.
enum LOOP_MODE {
	LOOP_NONE, ## It doesn't loop.
	LOOP_LINEAR, ## Plays all frames, and upon reaching the last one, restarts from the first. Emits: [signal animation_ended] signal.
	LOOP_PINGPONG, ## Plays all frames, and upon reaching the last one, plays the animation in reverse until it returns to the first frame, then restarts. Emits: [signal animation_ended] signal.
	KEEP ## Keeps the loop mode set in the [SpriteFrames] animation.
};

## Plays an animation.[br][br]
## [param animation]: A [code]string[/code] containing the exact name of the animation within the [SpriteFrames].[br]
## [param loop]: [color=darkgray](Optional)[/color]. Sets the loop mode. See [enum LOOP_MODE].[br]
## [param startFrame]: [color=darkgray](Optional)[/color]. Defines the frame index at which the animation should start. Defaults to [code]0[/code].[br]
## [param fps]: [color=darkgray](Optional)[/color]. Sets the animation's FPS. If set to [code]0.0[/code], it will use the value defined in the [SpriteFrames] animation.
func play(animation: String, loop: LOOP_MODE = LOOP_MODE.KEEP, startFrame: int = 0, fps: float = 0.0):
	_animationName = animation;
	if (!animations.has_animation(animation)): # Prevents the code from executing and reports an error if the animation name is not valid.
		stop();
		push_error("\"%s\" is not a valid animation." % animation);
		return Error.ERR_INVALID_PARAMETER;
	_loop = animations.get_animation_loop_mode(animation) if loop == LOOP_MODE.KEEP else loop; # Sets the properties for the animation to be played now. If modifications are provided as arguments, it uses them, otherwise it uses the ones specified in the SpriteFrames.
	_animFps = animations.get_animation_speed(animation) if fps == 0 else fps;
	_frameCount = animations.get_frame_count(animation);
	_currentFrame = startFrame;
	_lastUpdate = 0; # Resets the variables to the default for the new animation.
	_pong = false;
	_playingAnim = true;
	_updateFrame(); # Renders the initial frame, since the animation function in "_process" only starts from the next frame.

## Sets the animation to the chosen frame index and pauses it.
func set_to_frame(frame: int):
	if frame > animations.get_frame_count(_animationName)-1 || frame < 0: # If the specified frame is invalid, it prevents code execution and reports an error.
		push_error("The \"%s\" animation does not have a frame %s." % [_animationName, frame]);
		return;
	pause()
	_currentFrame = frame
	_updateFrame();

var _pauseState: bool = false;
## Pauses the animation at the current frame.
func pause():
	if (_playingAnim):
		_playingAnim = false;
		_pauseState = true;

## Resumes the animation from the current frame, if the animation had previously been paused.
func resume():
	if (_pauseState):
		_playingAnim = true;

## It stops the animation completely and displays nothing else, becoming completely empty. [method play] can be used to play other animations after this.
func stop():
	_playingAnim = false;
	_pauseState = false;
	var _lastUpdate = 0;
	var _currentFrame = 0
	texture = null;
