import 'dart:io';
import 'dart:async';
import 'dart:convert' show JSON;
import 'package:http_server/http_server.dart';
import 'package:route/server.dart';

main() {

  String portEnv = Platform.environment['PORT'];
  int port = portEnv == null ? 9999 : int.parse(portEnv);

  runZoned(() {
    HttpServer.bind('0.0.0.0', port).then((HttpServer server) {
      print('Server started on port: ${port}');

      new Router(server)
        ..serve('/', method: 'GET').listen(sayHi);
    });
  },
  onError: (e, stackTrace) {
    print('Error: $e $stackTrace');
  });

}

void sayHi(HttpRequest request) {
  var powered_by = Platform.environment['POWERED_BY'];
  var message;
  if (powered_by == null) {
    message = "Powered by Deis";
  } else {
    message = "Powered by $powered_by"; 
  }
  request.response..headers.set(HttpHeaders.CONTENT_TYPE, 'application/json')
                  ..write(message)
                  ..close();
}