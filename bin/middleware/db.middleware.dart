import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

class DBMiddleware {
  final Connection db;
  DBMiddleware(this.db);

  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        return innerHandler(request.change(
          context: {
            'db': db,
          }
        ));
      };
    };
  }
}