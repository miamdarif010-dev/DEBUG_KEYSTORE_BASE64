import 'package:cloud_functions/cloud_functions.dart';

class GameService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  Future<Map<String, dynamic>> getGameStatus() async {
    final callable = _functions.httpsCallable('getGameStatus');
    final response = await callable.call();

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> startBikeGame() async {
    final callable = _functions.httpsCallable('startBikeGame');
    final response = await callable.call();

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> finishBikeGame(
    String sessionId,
    int score,
  ) async {
    final callable = _functions.httpsCallable('finishBikeGame');

    final response = await callable.call({
      'sessionId': sessionId,
      'score': score,
    });

    return Map<String, dynamic>.from(response.data as Map);
  }
}
