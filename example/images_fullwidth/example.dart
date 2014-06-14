library swiper_example;

import 'dart:html';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:swiper/swiper.dart';

final _log = new Logger('swiper_example');

main() {
  initLogging();
  
  Swiper swiper = new Swiper(querySelector('.swiper'));
}

initLogging() {
  DateFormat dateFormat = new DateFormat('yyyy.mm.dd HH:mm:ss.SSS');
  
  // Print output to console.
  Logger.root.onRecord.listen((LogRecord r) {
    print('${dateFormat.format(r.time)}\t${r.loggerName}\t[${r.level.name}]:\t${r.message}');
  });
  
  // Root logger level.
  Logger.root.level = Level.FINEST;
}