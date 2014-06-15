import 'dart:html';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:swiper/swiper.dart';

main() {
  initLogging();
  
  // Initialize the Swiper.
  Swiper swiper = new Swiper(querySelector('.swiper'), speed: 600);
  
  // Set up method calls for button clicks.
  ButtonElement prevButton = querySelector('.previous')
      ..onClick.listen((_) => swiper.prev());
  ButtonElement nextButton = querySelector('.next')
      ..onClick.listen((_) => swiper.next());
  
  InputElement moveInput = querySelector('.move-input');
  ButtonElement moveButton = querySelector('.move-button')..onClick.listen((_) {
    int index = int.parse(moveInput.value, onError: (txt) => 0);
    moveInput.value = index.toString();
    swiper.moveToIndex(index);
  });
  
  // Write events to TextArea.
  TextAreaElement events = querySelector('.events');
  swiper.onPageChange.listen((index) {
    events.appendText('PageChange Event: index=${index}\n');
  });
  swiper.onTransitionEnd.listen((index) {
    events.appendText('TransitionEnd Event: index=${index}\n');
    events.scrollTop = events.scrollHeight;
  });
  
}

initLogging() {
  DateFormat dateFormat = new DateFormat('yyyy.mm.dd HH:mm:ss.SSS');
  
  // Print output to console.
  Logger.root.onRecord.listen((LogRecord r) {
    print('${dateFormat.format(r.time)}\t${r.loggerName}\t[${r.level.name}]:\t${r.message}');
  });
  
  // Root logger level.
  Logger.root.level = Level.INFO;
  
  hierarchicalLoggingEnabled = true;
  new Logger('swiper')..level = Level.FINE;
}