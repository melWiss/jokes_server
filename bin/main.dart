import 'dart:math';

import 'package:jokes_server/jokes_server.dart' as jokes_server;
import 'dart:io';
import 'dart:convert';

File jokesFile;
List jokesJson;
void main(List<String> arguments) async {
  jokesFile = File(Directory.current.path + '/jokes.json');
  if (!(await jokesFile.exists())) {
    jokesFile = await jokesFile.create(recursive: true);
    await jokesFile.writeAsString(jsonEncode([]));
  }

  jokesJson = jsonDecode(await jokesFile.readAsString());
  var addr = arguments.length != 0 ? arguments[0] : "0.0.0.0";
  int port = arguments.length == 2 ? int.parse(arguments[1]) : 8080;
  var server = await HttpServer.bind(addr, port);
  print('Serving at ${server.address}:${server.port}');

  await for (var request in server) {
    if (request.method == 'GET') {
      switch (request.requestedUri.path) {
        case '/':
          returnToClient(request, {'server': 'morning sir'});
          break;
        case '/getRandomJoke':
          getRandomJoke(request, jokesJson);
          break;
        case '/getJokeById':
          getJokeById(request, jokesJson);
          break;
        default:
          {
            returnToClient(
                request, {'error': "there's nothing to get from here"});
          }
          ;
          break;
      }
    } else if (request.method == 'POST') {
      switch (request.requestedUri.path) {
        case '/':
          returnToClient(request, {'error': 'you cant post anything here'});
          break;
        case '/postJoke':
          postJoke(request);
          break;
        case '/upvoteJoke':
          voteJoke(request, true);
          break;
        case '/downvoteJoke':
          voteJoke(request, false);
          break;
        default:
          {
            returnToClient(request, {'error': "there's nothing to post here"});
          }
          ;
          break;
      }
    }
  }
}

void getJokeById(HttpRequest request, List listData) {
  int id = int.parse(request.uri.queryParameters['id']);
  List<Map> jokes = [];
  for (var k in listData) {
    if (k['id'] == id) {
      jokes.add(k);
    }
  }
  if (jokes.length == 0)
    returnToClient(request, {'error': 'joke not found'});
  else
    returnToClient(request, {'jokes': jokes});
}

void voteJoke(HttpRequest request, bool vote) async {
  String postedData = await utf8.decoder.bind(request).join();
  Map data;
  try {
    data = jsonDecode(postedData);
    Map b;
    for (var k in jokesJson) {
      if (k['id'] == data['id']) {
        b = k;
        break;
      }
    }
    if (b != null) {
      if (vote) {
        b['upvotes'] += 1;
        data = b;
      } else {
        b['downvotes'] += 1;
        data = b;
        int allVotes = b['downvotes'] + b['upvotes'];
        if (allVotes > 99) {
          if (((b['downvotes'] / allVotes) * 100) >= 75) {
            jokesJson.remove(b);
            print("joke deleted:\n" + jsonEncode(b));
          }
        }
      }
      await jokesFile.writeAsString(jsonEncode(jokesJson));
    } else {
      data = {'error': 'joke not found'};
    }
  } catch (e) {
    data = {'errorType': 'not Valid', 'error': e.toString()};
  }
  returnToClient(request, data);
}

void postJoke(HttpRequest request) async {
  String postedData = await utf8.decoder.bind(request).join();
  Map data;
  try {
    data = jsonDecode(postedData);
    data = {
      'id': jokesJson.length + 1,
      'joke': data['joke'],
      'upvotes': 0,
      'downvotes': 0
    };
    jokesJson.add(data);
    await jokesFile.writeAsString(jsonEncode(jokesJson));
    print("joke added:\n" + jsonEncode(data));
  } catch (e) {
    data = {'errorType': 'not Valid', 'error': e.toString()};
  }
  returnToClient(request, data);
}

void getRandomJoke(HttpRequest request, List data) {
  try {
    int index = Random.secure().nextInt(data.length);
    returnToClient(request, data[index]);
  } catch (e) {
    returnToClient(
      request,
      {
        'error': "there's no joke in database",
        'data': e.toString(),
      },
    );
  }
}

void returnToClient(HttpRequest req, Map data) {
  req.response
    ..headers.contentType = ContentType('application', 'json', charset: 'utf-8')
    ..write(jsonEncode(data))
    ..close();
}
