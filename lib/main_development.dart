import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:strop_app/app/app.dart';
import 'package:strop_app/bootstrap.dart';

Future<void> main() async {
  await dotenv.load();
  await bootstrap(() => const App());
}
