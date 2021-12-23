import 'package:logging/logging.dart';

class FastLogger {
  FastLogger(String name) : logger = Logger(name);

  Logger logger;

  void info(String Function() message) {
    if (logger.level >= Level.INFO) {
      logger.info(message());
    }
  }

  void warning(String Function() message) {
    if (logger.level >= Level.WARNING) {
      logger.warning(message());
    }
  }

  void fine(String Function() message) {
    if (logger.level >= Level.FINE) {
      logger.fine(message());
    }
  }

  void finest(String Function() message) {
    if (logger.level >= Level.FINEST) {
      logger.finest(message());
    }
  }

  void severe(String Function() message) {
    if (logger.level >= Level.SEVERE) {
      logger.severe(message());
    }
  }

  void shout(String Function() message) {
    if (logger.level >= Level.SEVERE) {
      logger.shout(message());
    }
  }

  void finer(String Function() message) {
    if (logger.level >= Level.FINER) {
      logger.finer(message());
    }
  }
}
