library swiper;

import 'dart:html';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dnd/dnd.dart';

final _log = new Logger('swiper');

/**
 * A touch and mouse slider for swiping through images and html.
 */
class Swiper {

  // -------------------
  // Events
  // -------------------
  StreamController<int> _onPageChange;
  StreamController<int> _onPageTransitionEnd;

  /**
   * Fired when the current page changed.
   *
   * The data is the page index. To get the page, use [currentPage].
   */
  Stream<int> get onPageChange {
    if (_onPageChange == null) {
      _onPageChange = new StreamController<int>.broadcast(
          onCancel: () => _onPageChange = null);
    }
    return _onPageChange.stream;
  }

  /**
   * Fired when the transition ends after a page change. If the user swipes
   * again before the previous transition ended, this event is only fired once,
   * at the end of all page transitions.
   *
   * The data is the page index. To get the page, use [currentPage].
   */
  Stream<int> get onPageTransitionEnd {
    if (_onPageTransitionEnd == null) {
      _onPageTransitionEnd = new StreamController<int>.broadcast(
          onCancel: () => _onPageTransitionEnd = null);
    }
    return _onPageTransitionEnd.stream;
  }

  /**
   * Fired when the user starts dragging.
   *
   * Note: The [onDragStart] is fired not on touchStart or mouseDown but as
   * soon as there is a drag movement. When a drag is started an [onDrag] event
   * will also be fired.
   */
  Stream<DraggableEvent> get onDragStart => _draggable.onDragStart;

  /**
   * Fired periodically throughout the drag operation.
   */
  Stream<DraggableEvent> get onDrag => _draggable.onDrag;

  /**
   * Fired when the user ends the dragging.
   *
   * Is also fired when the user clicks the 'esc'-key or the window loses focus.
   */
  Stream<DraggableEvent> get onDragEnd => _draggable.onDragEnd;


  // -------------------
  // Private Properties
  // -------------------
  /// The main swiper element.
  final Element _swiperElement;

  /// The container for all swipe pages (child of [_swiperElement]).
  Element _containerElement;

  /// Speed of prev and next transitions in milliseconds.
  final int _speed;

  /// If true the
  final bool _autoWidth;

  /// The aspect ratio of the Swiper if it should be automatically applied.
  final double _autoHeightRatio;

  /// If swipe distance is more than [_distanceThreshold] (in px), a swipe is
  /// detected (regardless of swipe duration).
  int _distanceThreshold;

  /// If swipe duration is less than [_durationThreshold] (in ms), a swipe is
  /// detected (regardless of swipe distance).
  int _durationThreshold;

  /// The [Draggable] used to track drags on the [_containerElement].
  Draggable _draggable;

  /// Stops the time between a drag start and a drag end to determine if the
  /// duration was below the [_durationThreshold].
  Stopwatch _dragStopwatch;

  /// Width of one slide.
  int _pageWidth;

  /// The current page index.
  int _currentIndex;

  /// If true, the next transitionEnd event will be fired, if false, the
  /// transitionEnd events will be ignored. Without this flag the transitionEnd
  /// would also fire when there was an animation with no index change.
  bool _fireNextPageTransitionEnd = false;

  /// Tracks listener subscriptions.
  List<StreamSubscription> _subs = [];

  /**
   * Creates a new [Swiper].
   *
   * The [swiperElement] must contain a child element that is the **container**
   * of all swipe pages.
   *
   * ## Options
   *
   * [startIndex] is the index position the Swiper should start at.
   *
   * [speed] is the speed of prev and next transitions in milliseconds.
   *
   * [autoWidth] defines if the Swiper should automatically adjust the width
   * when the browser is resized. You might want to disable this if you want
   * to manually do some width and height calculations. If disabled make sure
   * you call [resize] after the size of the Swiper changed.
   *
   * [autoHeightRatio] defines if and how the Swiper should calculate the
   * height. If defined, the height is calculated from the Swiper's width with
   * [autoHeightRatio] and automatically applied when the browser is resized.
   * This is useful, e.g. for responsive images.
   *
   * If a [handle] query String is specified, it restricts the dragging from
   * starting unless it occurs on the specified element(s). Only elements that
   * descend from [swiperElement] are permitted.
   *
   * If [cancel] query String is specified, drag starting is prevented on
   * specified elements.
   *
   * If swipe distance is more than [distanceThreshold] (in px), a swipe is
   * detected (regardless of swipe duration).
   *
   * If swipe duration is less than [durationThreshold] (in ms), a swipe is
   * detected (regardless of swipe distance).
   *
   * The [draggingClass] is the css class set to the [swiperElement]
   * while a user is dragging. If set to null, no such css class is added.
   *
   * The [draggingClassBody] is the css class set to the html body tag
   * while a user is dragging. If set to null, no such css class is added.
   */
  Swiper(Element swiperElement,
      { int startIndex: 0,
        int speed: 300,
        bool autoWidth: true,
        double autoHeightRatio: null,
        int distanceThreshold: 20,
        int durationThreshold: 250,
        String handle: null,
        String cancel: 'input, textarea, button, select, option',
        String draggingClass: 'swiper-dragging',
        String draggingClassBody: 'swiper-drag-occurring'})

      : this._swiperElement = swiperElement,
        this._speed = speed,
        this._autoWidth = autoWidth,
        this._autoHeightRatio = autoHeightRatio,
        this._distanceThreshold = distanceThreshold,
        this._durationThreshold = durationThreshold {

    _log.fine('Initializing Swiper');

    // Get the page-container.
    _containerElement = _swiperElement.children[0];

    // Validate and set the start index.
    _currentIndex = _getNextValidIndex(startIndex);

    // Horizontally stack pages inside the container.
    _initPages(_currentIndex);

    // Resize for the first time.
    resize();

    // We're ready, set to visible.
    _swiperElement.style.visibility = 'visible';

    // Set up the Draggable on the swiper.
    _draggable = new Draggable(_swiperElement,
        handle: handle,
        cancel: cancel,
        draggingClass: draggingClass,
        draggingClassBody: draggingClassBody,
        horizontalOnly: true); // Swiping is only done horizontally.

    // Listen for drag events.
    _subs.add(_draggable.onDragStart.listen(_handleDragStart));
    _subs.add(_draggable.onDrag.listen(_handleDrag));
    _subs.add(_draggable.onDragEnd.listen(_handleDragEnd));

    // Install transitionEnd listener.
    _subs.add(_containerElement.onTransitionEnd.listen((_) {
      // Remove css animation transition style.
      _removeCssTransition();

      if (_fireNextPageTransitionEnd) {
        _firePageTransitionEndEvent();
      }
    }));

    if (_autoWidth) {
      // Install browser resize listener. This is done asynchronously after the
      // visibility has been applied, because setting visibility would somethimes
      // trigger a resize event.
      new Future(() {
        _subs.add(window.onResize.listen((_) => resize()));
      });
    }
  }

  /**
   * Initializes the pages and shows the page at [startIndex].
   */
  void _initPages(int startIndex) {
    // Stack the pages horizontally with the `left` css attribute of 100%, 200%,
    // 300%, etc.
    for (int i = 0; i < _containerElement.children.length; i++) {
      _containerElement.children[i].style.left = '${i}00%';
    }

    // Move to the start index.
    _translatePercentX(-startIndex * 100);
  }

  /**
   * Fires an [onPageTransitionEnd] event.
   */
  void _firePageTransitionEndEvent() {
    // Fire the page transition end event.
    _log.fine('Transition end event: index=$_currentIndex');
    if (_onPageTransitionEnd != null) {
      _onPageTransitionEnd.add(_currentIndex);
    }
    _fireNextPageTransitionEnd = false;
  }

  /**
   * The current page index.
   */
  int get currentIndex => _currentIndex;

  /**
   * The current page.
   */
  Element get currentPage => _containerElement.children[currentIndex];

  /**
   * The main swiper element.
   */
  Element get swiperElement => _swiperElement;

  /**
   * The container for all swipe pages (child of [swiperElement]).
   */
  Element get containerElement => _containerElement;

  /**
   * Moves to the page at [index].
   *
   * The [speed] is the duration of the transition in milliseconds.
   * If no [speed] is provided, the speed attribute of this [Swiper] is used.
   *
   * If [noEvents] is set to true, no [onPageChange] and [onPageTransitionEnd]
   * events are fired.
   */
  void moveToIndex(int index, {int speed, bool noEvents: false}) {
    // Validate index.
    index = _getNextValidIndex(index);

    // Use default speed if none was provided.
    if (speed == null) {
      speed = _speed;
    }

    _log.fine('Moving to index: index=$index, speed=$speed');

    // Do the move with or without animation.
    if (speed > 0) {
      _moveToIndexAnim(index, speed);
    } else {
      _moveToIndexNoAnim(index);
    }

    // Fire events if there was a move to a new index.
    if (index != _currentIndex && !noEvents) {
      // Fire page change event.
      _log.fine('Page change event: index=$index');
      if (_onPageChange != null) {
        _onPageChange.add(index);
      }

      // Ensure that the page transition end event is fired.
      if (speed > 0) {
        // At the end of the animation there will be a transitionEnd event.
        // Set the flag that the next transitionEnd event triggers a new
        // pageTransitionEnd event.
        _fireNextPageTransitionEnd = true;

      } else {
        // As there was no animation, no transitionEndEvent will be fired by the
        // browser. So we need to manually call the fire method here.
        _firePageTransitionEndEvent();
      }
    }

    // Set the new current index.
    _currentIndex = index;
  }

  /**
   * Moves to [index] with an animation.
   *
   * [speed] defines the duration of the animation. [speed] must be > 0.
   */
  void _moveToIndexAnim(int index, int speed) {
    _addCssTransition(speed);
    _translatePercentX(index * -100);
  }

  /**
   * Moves to [index] with no animation.
   */
  void _moveToIndexNoAnim(int index) {
    _translatePercentX(index * -100);
  }

  /**
   * Moves the current page to the specified [offset].
   */
  void _moveToOffset(int offset) {
    _translatePixelX(_currentIndex * -_pageWidth + offset);
  }

  /**
   * Moves to the next page.
   */
  void next({int speed}) {
    if (hasNext()) {
      moveToIndex(currentIndex + 1, speed: speed);
    }
  }

  /**
   * Moves to the previous page.
   */
  void prev({int speed}) {
    if (hasPrev()) {
      moveToIndex(currentIndex - 1, speed: speed);
    }
  }

  /**
   * Returns true if there is a next page.
   */
  bool hasNext() {
    return currentIndex < _containerElement.children.length - 1;
  }

  /**
   * Returns true if there is a previous page.
   */
  bool hasPrev() {
    return currentIndex > 0;
  }

  /**
   * Updates the cached page width and the container sizes.
   *
   * The [resize] method is automatically called when the browser is resized.
   * But if the [Swiper] is resized other than trough browser resizing, [resize]
   * must be called manually.
   */
  void resize() {
    // Get the swiper's contentWidth. The contentWidth is a ROUNDEN pixel value.
    _pageWidth = _swiperElement.contentEdge.width.round();

    // We set the ROUNDED width to the container element. This is important,
    // otherwise a floating point value might get passed down to the
    // pages because they are 100%-width. A floating point width of the pages
    // would cause rounding errors.
    _containerElement.style.width = '${_pageWidth}px';

    if (_autoHeightRatio != null) {
      // Calculate the height with the provided aspect ratio.
      _containerElement.style.height = '${(_pageWidth * _autoHeightRatio).floor()}px';
    }
  }

  /**
   * Unistalls all listeners. This will return the swiper element back to its
   * pre-init state.
   */
  void destroy() {
    _subs.forEach((sub) => sub.cancel());
    _subs.clear();
    _draggable.destroy();
    _draggable = null;
  }

  /**
   * Handles drag start.
   */
  void _handleDragStart(DraggableEvent dragEvent) {
    // Start the stopwatch.
    _dragStopwatch = new Stopwatch()..start();

    // Ensure there is no transition animation style during the drag operation.
    _removeCssTransition();
  }

  /**
   * Handles drag.
   */
  void _handleDrag(DraggableEvent dragEvent) {
    int deltaX = _calcDragDelta(dragEvent.startPosition.x, dragEvent.position.x);

    _log.finest('Drag: deltaX=$deltaX');

    // Increases resistance if necessary.
    deltaX = _addResistance(deltaX);

    // Translate to new x-position.
    _moveToOffset(deltaX);
  }

  /**
   * Handles drag end.
   */
  void _handleDragEnd(DraggableEvent dragEvent) {
    // Stop the stopwatch.
    _dragStopwatch.stop();

    int index = _currentIndex;
    int dragDelta = _calcDragDelta(dragEvent.startPosition.x, dragEvent.position.x);

    // Determine if the drag leads to a new index. If the event was cancelled
    // we go back to last index. Otherwise, we check if thresholds for new
    // index were met.
    if (!dragEvent.cancelled) {
      _log.finest('DragEnd: dragDelta=$dragDelta');

      // Determine if we are past the thresholds.
      if (dragDelta.abs() > _distanceThreshold ||
          _dragStopwatch.elapsedMilliseconds < _durationThreshold) {

        // Direction of swipe. Dragging left means revealing page on the right!
        bool dragLeft = dragDelta < 0;

        if (dragLeft && hasNext()) {
          index++;
        } else if (!dragLeft && hasPrev()){
          index--;
        }
      }
    }

    // Adjust the speed to the distance left for the move animation.
    int animDistance;
    if (index !=  _currentIndex) {
      // New index: Calc distance left.
      animDistance = (_pageWidth - dragDelta.abs()).abs();
    } else {
      // Back to old index: Just reverse drag distance.
      animDistance = dragDelta.abs();
    }
    int adjustedSpeed = _adjustSpeed(_speed, animDistance);

    // Move to index (might be the same as the current index).
    moveToIndex(index, speed: adjustedSpeed);
  }

  /**
   * If [index] is out of bounds, the nearest valid index is returned.
   * If [index] is already valid, it is just returned again.
   */
  int _getNextValidIndex(int index) {
    // Ensure left bound.
    if (index < 0) {
      return 0;
    }

    // Ensure is in right bound.
    if (index > _containerElement.children.length - 1) {
      return _containerElement.children.length - 1;
    }

    // Was already valid, just return index.
    return index;
  }

  /**
   * Calculates the delta movement between [startX] and [endX] coordinates.
   *
   * * Result > 0 means dragging right, possible revealing a slide on the left.
   * * Result < 0 means dragging left, possible revealing a slide on the right.
   */
  int _calcDragDelta(int startX, int endX) {
    return endX - startX;
  }

  /**
   * Adds move resistance if first page and sliding left or last page and
   * sliding right.
   */
  int _addResistance(int offset) {
    bool firstPage = !hasPrev();
    bool lastPage = !hasNext();

    if ( (firstPage && offset > 0) || (lastPage && offset < 0) ) {
      // Add resistance.
      return offset ~/ (offset.abs() / _pageWidth + 1);
    } else {
      // No resistance.
      return offset;
    }
  }

  /**
   * Helper method to adjusts the [speed] proportionally to the [distance].
   * The [speed] corresponds to the distance of one page ([_swiperWidth]).
   */
  int _adjustSpeed(int speed, num distance) {
    if (distance > _pageWidth) {
      return speed;
    }

    return (speed / _pageWidth * distance).round();
  }

  /**
   * Sets the transform translate property to the [xPercent] value.
   */
  void _translatePercentX(int xPercent) {
    _containerElement.style.transform = 'translate3d(${xPercent}%, 0, 0)';
  }

  /**
   * Sets the transform translate property to the [xPixel] value.
   */
  void _translatePixelX(int xPixel) {
    // Unsing `translate3d` to activate GPU hardware-acceleration (a bit of a hack).
    _containerElement.style.transform = 'translate3d(${xPixel}px, 0, 0)';
  }

  /**
   * Adds the css transition style for the [_containerElement]. The transition is
   * for an ease-out animation with duration of [speed].
   */
  void _addCssTransition(int speed) {
    _containerElement.style
        ..transitionProperty = 'transform'
        ..transitionDuration = '${speed}ms'
        ..transitionTimingFunction = 'ease-out';
  }

  /**
   * Removes the css transition style from [_containerElement].
   */
  void _removeCssTransition() {
    _containerElement.style.transition = null;
  }
}




