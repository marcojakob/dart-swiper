import 'dart:html';
import 'package:swiper/swiper.dart';

main() {
  // Initialize the Swiper.
  Swiper swiper = new Swiper(querySelector('.swiper'), speed: 600);
  
  // Set up method calls for button clicks.
  ButtonElement prevButton = querySelector('#previous-button')
      ..onClick.listen((_) => swiper.prev());
  ButtonElement nextButton = querySelector('#next-button')
      ..onClick.listen((_) => swiper.next());
  
  InputElement moveInput = querySelector('#move-input');
  ButtonElement moveButton = querySelector('#move-button')..onClick.listen((_) {
    int index = int.parse(moveInput.value, onError: (txt) => 0);
    moveInput.value = index.toString();
    swiper.moveToIndex(index);
  });
  
  // Write events to TextArea.
  TextAreaElement events = querySelector('#events');
  swiper.onPageChange.listen((index) {
    append(events, 'PageChange Event: index=${index}\n');
  });
  swiper.onPageTransitionEnd.listen((index) {
    append(events, 'TransitionEnd Event: index=${index}\n');
  });
}

void append(TextAreaElement textArea, String text) {
  textArea.appendText(text);
  textArea.scrollTop = textArea.scrollHeight;
}