library swiper;

import 'dart:html';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:dnd/drag_detector.dart';

final _log = new Logger('swiper');

/**
 * A touch and mouse slider for swiping through images and html.
 */
class Swiper {
  /// How many pixels until a swipe is detected.
  static const int DISTANCE_THRESHOLD = 20;
  
  /// The container for all swipe pages. 
  Element container;
  
  // --------------
  // Options
  // --------------
  /// Speed of prev and next transitions in milliseconds. 
  int speed = 300;
  
  // -------------------
  // Events
  // -------------------
  StreamController<int> _onPageChange;
  StreamController<int> _onTransitionEnd;
  
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
   * Fired when the transition ends. When the user swipes again before the 
   * previous transition ended, this event is only fired once, at the end of all 
   * transitions.
   * 
   * The data is the page index. To get the page, use [currentPage].
   */
  Stream<int> get onTransitionEnd {
    if (_onTransitionEnd == null) {
      _onTransitionEnd = new StreamController<int>.broadcast(
          onCancel: () => _onTransitionEnd = null);
    }
    return _onTransitionEnd.stream;
  }
  
  
  // -------------------
  // Private Properties
  // -------------------
  /// The [DragDetector] used to track drags on the [container].
  DragDetector _dragDetector;
  
  /// Width of one slide.
  int _pageWidth;
  
  /// The current page index.
  int _currentIndex;
  
  /// The x-position of the current page.
  int _currentPageX;
  
  /// The current transform translate CSS property on [container].
  int _currentTranslateX;
  
  /// Tracks listener subscriptions.
  List<StreamSubscription> _subs = [];
  
  /**
   * Creates a new [Swiper]. 
   * 
   * The [swiperElement] must contain a child element that is the **container**
   * of all swipe pages.
   * 
   * You can provide an optional [startIndex] for the initial index that should
   * be displayed.
   * 
   * When [disableTouch] is set to true, swiping with touch will be ignored.
   * When [disableMouse] is set to true, swiping with mouse will be ignored.
   */
  Swiper(Element swiperElement, {startIndex: 0, disableTouch: false, 
                                 disableMouse: false}) {
    _log.finer('Initializing Swiper');
    
    // Get the pages container.
    container = swiperElement.children[0];
    
    // Set default transition style.
    container.style
        ..transitionProperty = 'transform'
        ..transitionTimingFunction = 'ease-out';
    
    // Horizontally stack pages.
    _stackPages();
    
    // Init size.
    _pageWidth = _calcPageWidth();
    
    // Go to initial page.
    moveToIndex(startIndex, speed: 0);
    
    // We're ready, set to visible.
    swiperElement.style.visibility = 'visible';

    // Set up the DragDetector on the [container].
    _dragDetector = new DragDetector.forElement(container, 
        disableTouch: disableTouch, disableMouse: disableMouse);
    
    // Swiping is only done horizontally.
    _dragDetector.horizontalOnly = true;
    
    // Listen for drag events.
    _subs.add(_dragDetector.onDrag.listen(_handleDrag));
    _subs.add(_dragDetector.onDragEnd.listen(_handleDragEnd));
    
    
    // Install transition end listener.
    container.onTransitionEnd.listen((_) {
      _log.finer('Transition ended (with animation): currentIndex=$currentIndex');
      if (_onTransitionEnd != null) {
        _onTransitionEnd.add(currentIndex);
      }
    });
    
    // Install window resize listener (but only after visibility has been set).
    new Future(() => 
        window.onResize.listen((e) {
          refreshSize();
        }
      )
    );
  }
  
  /**
   * Stacks the pages of [container] horizontally with the `left` css attribute.
   */
  void _stackPages() {
    // Position pages with left attribute of 100%, 200%, 300%, etc.
    for (int i = 0; i < container.children.length; i++) {
      container.children[i].style.left = '${i}00%';      
    }
  }

  /**
   * The current page index.
   */
  int get currentIndex => _currentIndex;
  
  /**
   * The current page.
   */
  Element get currentPage => container.children[currentIndex];
   
  /**
   * Moves to the page at [index]. 
   * 
   * The [speed] is the duration of the transition in milliseconds. 
   * If no [speed] is provided, the speed attribute of this [Swiper] is used.
   * 
   * If [noPageChangeEvent] is set to true, no page change event is fired.
   */
  void moveToIndex(int index, {int speed, bool noPageChangeEvent: false}) {
    _log.finer('Moving to index: index=$index, speed=$speed');
    
    int oldIndex = _currentIndex;
     
    if (index < 0) {
      _currentIndex = 0;
    } else if (index > container.children.length - 1) {
      _currentIndex = container.children.length - 1;
    } else {
      _currentIndex = index;
    }
    
    if (oldIndex != _currentIndex) {
      // Fire page change event.
      if (!noPageChangeEvent) {
        _log.finer('Page change event: currentIndex=$_currentIndex');
        if (_onPageChange != null) {
          _onPageChange.add(_currentIndex);
        }
      }
      
      // The index changed, update current page x. 
      _updateCurrentPageX();
     
      // Set new translate and make sure the transitionEnd event is fired.
      _setTranslateX(_currentPageX, speed: speed, forceTransitionEndEvent: true);
      
    } else {
      // No change in index. Move back to current page.
      _setTranslateX(_currentPageX, speed: speed);
    }
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
    return currentIndex < container.children.length - 1;
  }
   
  /**
   * Returns true if there is a previous page.
   */
  bool hasPrev() {
    return currentIndex > 0;
  }

  /**
   * Updates and refreshes the size.
   */
  void refreshSize() {
    _pageWidth = _calcPageWidth();
    _updateCurrentPageX();
    _setTranslateX(_currentPageX, speed: 0);
  }
  
  /**
   * Unistalls all listeners. This will return the [container] back to its 
   * pre-init state.
   */
  void destroy() {
    _subs.forEach((sub) => sub.cancel());
    _subs.clear();
    _dragDetector.destroy();
    _dragDetector = null;
  }
  
  /**
   * Handles drag.
   */
  void _handleDrag(DragEvent dragEvent) {
    int deltaX = _calcDelta(dragEvent.startCoords.x, dragEvent.coords.x);
    
    _log.finest('Drag: deltaX=$deltaX');

    // Increases resistance if necessary.
    deltaX = _addResistance(deltaX);
    
    // Translate to new x-position.
    _setTranslateX(_currentPageX - deltaX, speed: 0);
  }
  
  /**
   * Handles drag end.
   */
  void _handleDragEnd(DragEvent dragEvent) {
    int deltaX = _calcDelta(dragEvent.startCoords.x, dragEvent.coords.x);
    
    _log.finest('DragEnd: deltaX=$deltaX');
    
    int index = _currentIndex;
    
    // Determine if we are past the threshold.
    if (deltaX.abs() > DISTANCE_THRESHOLD) {
      // Determine direction of swipe.
      bool directionRight = deltaX > 0;
      
      if (directionRight && hasNext()) {
        index++;
      } else if (!directionRight && hasPrev()){
        index--;
      }
    }      
    
    // Move to index (might be the same as the current index).
    moveToIndex(index);
  }
  
  /**
   * Calculates the delta movement between [startX] and [endX] coordinates.
   * 
   * * Result > 0 means sliding to the RIGHT slide.
   * * Result < 0 means sliding to the LEFT slide.
   */
  int _calcDelta(int startX, int endX) {
    return startX - endX;
  }
  
  /**
   * Adds move resistance if first page and sliding left or last page and
   * sliding right.
   * 
   * * [deltaX] > 0 means user is sliding to the RIGHT slide.
   * * [deltaX] < 0 means user is sliding to the LEFT slide.
   */
  int _addResistance(int deltaX) {
    bool firstPage = !hasPrev();
    bool lastPage = !hasNext();
    
    if ( (firstPage && deltaX < 0) || (lastPage && deltaX > 0) ) {
      // Add resistance.
      return deltaX ~/ (deltaX.abs() / _pageWidth + 1);
    } else {
      // No resistance.
      return deltaX; 
    }
  }
  
  /**
   * Updates the page width.
   */
  int _calcPageWidth() {
    // Get the page width.
    // (Note: getBoundingClientRect() will only work in Safari from version 4).
    return container.getBoundingClientRect().width.round();
  }
  
  /**
   * Calculates the [_currentPageX] from [_currentIndex] and [_pageWidth].
   * This update must be called whenever [_currentIndex] or [_pageWidth] 
   * changes.
   */
  void _updateCurrentPageX() {
    _currentPageX = -(_currentIndex * _pageWidth);
  }
  
  /**
   * Sets the transform translate CSS property on the [container] to the 
   * specified [x] value.
   * 
   * * [x] > 0 moves the [container] to the RIGHT (shows slide on the LEFT).
   * * [x] < 0 moves the [container] to the LEFT (shows slide on the RIGHT).
   * 
   * Optionally the [speed] can be set as duration of the transition animation.
   * If no [speed] is specified, the default speed is used (proportionally 
   * adjusted to change in [x]).
   * 
   * A transitionEnd event is automatically fired except if the transition
   * duration is 0ms. If a transitionEnd event is required even in the case of 
   * 0ms duration, the [forceTransitionEndEvent] must be set to true.
   */
  void _setTranslateX(int x, {int speed, bool forceTransitionEndEvent: false}) {
    if (speed == null) {
      speed = _adjustSpeed(this.speed, _pageWidth, (x - _currentTranslateX).abs()); 
    }
    
    _log.finest('Setting translate: x=$x, speed=$speed');
    
    _currentTranslateX = x;
    
    container.style.transitionDuration = '${speed}ms';
    
    // Adding `translateZ(0)` to activate GPU hardware-acceleration in 
    // browsers that support this (a bit of a hack).
    container.style.transform = 'translate(${x}px, 0) translateZ(0)';
    
    
    // Manually fire transition event if speed is 0 as transitionEnd event won't fire.
    if (forceTransitionEndEvent && speed <= 0) {
      _log.finer('Transition ended (no animation): currentIndex=$currentIndex');
      if (_onTransitionEnd != null) {
        _onTransitionEnd.add(currentIndex);
      }
    }
  }
  
  /**
   * Helper method to adjusts the speed proportionally to the [actualDistance].
   */
  int _adjustSpeed(int speed, int pageDistance, int actualDistance) {
    if (actualDistance > pageDistance) {
      return speed;
    }
    
    return (speed / pageDistance * actualDistance).round();
  }
}




