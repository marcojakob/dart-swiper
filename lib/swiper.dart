library swiper;

import 'dart:html';
import 'dart:async';
import 'package:logging/logging.dart';

final _log = new Logger('swiper');

/**
 * A touch (and mouse) slider for swiping through images and html.
 */
class Swiper {
  /// How many pixels until a swipe is detected.
  static const int DISTANCE_THRESHOLD = 20;
  
  /// The container for all swipe pages. 
  Element container;
  
  // --------------
  // Options
  // --------------
  
  /// Speed of prev and next transitions in milliseconds. Default is 300.
  int speed;
  
  /// Stop any touches on the container from scrolling the page. Default is false.
  bool disableScroll;
  
  /// Disable swiping with touch events.
  bool disableTouch;  

  /// Disable swiping with mouse events.
  bool disableMouse;
  
  
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
  
  /// Width of one slide.
  int _pageWidth;
  
  /// The current page index.
  int _currentIndex = 0;
  
  /// The x-position of the current page.
  int _currentPageX = 0;
  
  /// Coordinates where the mousedown or touchstart events occured.
  Point _startCoords;
  
  /// Delta movement of touchmove or mousemove. Positive x-value means right,
  /// positive y-value means down.
  Point _moveDelta = const Point(0, 0);
  
  /// Used for testing first move event.
  bool _isScrolling;
  
  // Track the listener subscriptions to later be able to unsubscribe.
  List<StreamSubscription> _pointerDownSubs = [];
  List<StreamSubscription> _pointerMoveAndUpSubs = [];
  
  /**
   * Creates a new [Swiper]. 
   * 
   * The [swiperElement] must contain a child element that is the **container**
   * of all swipe pages.
   */
  Swiper(Element swiperElement, {this.speed: 300, this.disableScroll: false,
        this.disableMouse: false, this.disableTouch: false, startIndex: 0}) {
    _log.finest('Initializing Swiper');
    
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

    // Install pointer down event listeners.
    _pointerDownSubs.add(container.onTouchStart.listen((e) => 
        _handlePointerDown(touchEvent: e)));
    _pointerDownSubs.add(container.onMouseDown.listen((e) => 
        _handlePointerDown(mouseEvent: e)));
    
    // Install transition end listener.
    container.onTransitionEnd.listen((_) {
      _log.finest('Transition end event: currentIndex=$currentIndex');
      if (_onTransitionEnd != null) {
        _onTransitionEnd.add(currentIndex);
      }
    });
    
    // Install window resize listener (but only after visibility has been set).
    new Future(() => 
        window.onResize.listen((e) {
          _pageWidth = _calcPageWidth();
          _setTranslateWithIndex(speed: 0);
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
   */
  void moveToIndex(int index, {int speed}) {
    if (speed == null) {
      speed = this.speed;
    }
     
    _log.finest('Moving to index: index=$index, speed=$speed');
    
    int oldIndex = currentIndex;
     
    if (index < 0) {
      _currentIndex = 0;
    } else if (index > container.children.length - 1) {
      _currentIndex = container.children.length - 1;
    } else {
      _currentIndex = index;
    }
    
    _setTranslateWithIndex(speed: speed);
     
    if (oldIndex != currentIndex) {
      _log.finest('Page change event: currentIndex=$currentIndex');
      // Fire page change event.
      if (_onPageChange != null) {
        _onPageChange.add(currentIndex);
      }
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
   * Unistalls all listeners.
   */
  void destroy() {
    _pointerDownSubs.forEach((sub) => sub.cancel());
    _pointerDownSubs.clear();
  }
  
  /**
   * Handle event when pointer is activated.
   * 
   * Provide a [touchEvent] when **touchstart** event are fired.
   * Provide a [mouseEvent] when a **mousedown** event is fired.
   */
  void _handlePointerDown({TouchEvent touchEvent, MouseEvent mouseEvent}) {
    
    if (touchEvent != null) {
      // Stop here if touch is disabled.
      if (disableTouch) return;
      
      _startCoords = touchEvent.touches[0].page;
      
      // Attach pointer-move and pointer-up listeners.
      _pointerMoveAndUpSubs.add(container.onTouchMove.listen((e) => 
          _handlePointerMove(touchEvent: e)));
      _pointerMoveAndUpSubs.add(document.onTouchEnd.listen((e) => 
          _handlePointerUp(touchEvent: e)));
      
    } else {
      // Stop here if touch is disabled.
      if (disableMouse) return;
      
      _startCoords = mouseEvent.page;
      
      // Attach move and end listeners.
      _pointerMoveAndUpSubs.add(container.onMouseMove.listen((e) => 
          _handlePointerMove(mouseEvent: e)));
      _pointerMoveAndUpSubs.add(document.onMouseUp.listen((e) => 
          _handlePointerUp(mouseEvent: e)));
      
      // Prevent default on everything except for the following html elements.
      Element target = mouseEvent.target;
      if (!(target is SelectElement || target is InputElement ||
            target is TextAreaElement || target is ButtonElement)) {
        mouseEvent.preventDefault();
      }
    }
    
    _log.finest('Pointer down: startCoords=$_startCoords');
    
    // Reset.
    _moveDelta = const Point(0, 0);
    _isScrolling = null;
  }
  
  /**
   * Handle pointer move event.
   * 
   * Provide a [touchEvent] when **touchmove** event are fired.
   * Provide a [mouseEvent] when a **mousemove** event is fired.
   */
  void _handlePointerMove({TouchEvent touchEvent, MouseEvent mouseEvent}) {
    
    if (touchEvent != null) {
      // Exit when double touch gesture is detected (pinching).
      if (touchEvent.touches.length > 1) {
        _isScrolling = true;        
        return;
      }
      
      // Measure change in x and y.
      _moveDelta = _startCoords - touchEvent.touches[0].page;
      
      // Determine if scrolling test has already run during this move operation.
      if (_isScrolling == null) {
        // Test for vertical scrolling.
        _isScrolling = _moveDelta.y.abs() > _moveDelta.x.abs();
        _log.finest('Is scrolling: $_isScrolling');
      }

      // Prevent native scrolling.
      if (disableScroll || // Prevent all scrolling.
          !_isScrolling) { // Prevent only when swiping.
        touchEvent.preventDefault();
      }
      
    } else { // MouseEvent.
      
      // Measure change in x and y.
      _moveDelta = _startCoords - mouseEvent.page;
      
      // Mouse is never scrolling.
      _isScrolling = false;
    }
    
    _log.finest('Pointer move: moveDelta=$_moveDelta');
    
    if (!_isScrolling) {
      // Increases resistance if necessary 
      _moveDelta = new Point(_addResistance(_moveDelta.x), _moveDelta.y);
      
      // Translate to new x-position.
      _setTranslateWithX(_currentPageX - _moveDelta.x, speed: 0);
    }
  }
  
  /**
   * Handle pointer up event.
   * 
   * Provide a [touchEvent] when **touchend** event are fired.
   * Provide a [mouseEvent] when a **mouseup** event is fired.
   */
  void _handlePointerUp({TouchEvent touchEvent, MouseEvent mouseEvent}) {
    _log.finest('Pointer up');
    
    // Cancel the all subscriptions that were set up in pointer down.
    _pointerMoveAndUpSubs.forEach((sub) => sub.cancel());
    _pointerMoveAndUpSubs.clear();

    // Stop if user is scrolling.
    if (_isScrolling == null || _isScrolling) return;
    
    int newIndex = _currentIndex;
    
    // Determine if we are past the threshold.
    if (_moveDelta.x.abs() > DISTANCE_THRESHOLD) {
      // Determine direction of swipe.
      bool directionRight = _moveDelta.x > 0;
      
      if (directionRight && hasNext()) {
        newIndex++;
      } else if (!directionRight && hasPrev()){
        newIndex--;
      }
    }      
    
    if (newIndex != _currentIndex) {
      int adjustedSpeed = _adjustSpeed(this.speed, _pageWidth, _pageWidth - _moveDelta.x.abs());
      
      // Move to new index.
      moveToIndex(newIndex, speed: adjustedSpeed);
      
      // Ensure that no click event is fired.
      _suppressClickEvent();
      
    } else {
      int adjustedSpeed = _adjustSpeed(this.speed, _pageWidth, _moveDelta.x.abs());
      
      // Move back to old index.
      moveToIndex(newIndex, speed: adjustedSpeed);
    }
    
  }
  
  /**
   * Makes sure that the next click event is ignored.
   */
  void _suppressClickEvent() {
    StreamSubscription clickSub = container.onClick.listen((event) {
      _log.finest('Suppressing a click event');
      event.stopPropagation();
      event.preventDefault();
    });
    
    // Wait until the end of event loop to see if a click event is fired.
    // Then cancel the listener.
    new Future(() {
      _log.finest('Cancel suppressing click events');  
      clickSub.cancel();
      clickSub = null;
    });
  }
  
  /**
   * Helper method to adjusts the speed proportionally to the [actualDistance].
   */
  int _adjustSpeed(int fullSpeed, int fullDistance, int actualDistance) {
    return (fullSpeed / fullDistance * actualDistance).round();
  }
  
  /**
   * Adds move resistance if first page and sliding left or last page and
   * sliding right.
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
   * Sets the transform translate CSS property on the [container] to the 
   * x value calculated with [currentIndex] and [_pageWidth].
   * 
   * Also sets [speed] as the duration of the transition animation.
   */
  void _setTranslateWithIndex({int speed: 0}) {
    _currentPageX = -(currentIndex * _pageWidth);
    _setTranslateWithX(_currentPageX, speed: speed);
  }
  
  /**
   * Sets the transform translate CSS property on the [container] to the 
   * specified [x] value.
   * 
   * Also sets [speed] as the duration of the transition animation.
   */
  void _setTranslateWithX(int x, {int speed: 0}) {
    _log.finest('Setting translate: x=$x, speed=$speed');
    
    container.style.transitionDuration = '${speed}ms';
    
    // Adding `translateZ(0)` to activate GPU hardware-acceleration in 
    // browsers that support this.
    container.style.transform = 'translate(${x}px, 0) translateZ(0)';
  }
}




