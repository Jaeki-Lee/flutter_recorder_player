import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalAppDirectory {
  static String documentDirectory = "";
  static String temporaryDirectory = "";
  LocalAppDirectory() {
    init();
  }

  static void init() async {
    await getApplicationDocumentsDirectory().then((document) {
      documentDirectory = document.path;
      // print(documentDirectory);
    });

    await getTemporaryDirectory().then((tempDir) {
      temporaryDirectory = tempDir.path;
      // print(temporaryDirectory);
    });
  }
}
