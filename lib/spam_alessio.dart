import 'package:dio/dio.dart';
import 'dart:convert';

void spamAlessio(String message) async {
  final dio = Dio();
  await dio.post(
    "https://u423htfijhweiotfhgweoihtiowhei.orion.alessioc42.dev/logs",
    options: Options(
      headers: {
        "X-API-Key": "dfhieifhjiewhjfewjhfihwepfjhgpwehjgfrjewhtoijhrewf",
      }
    ),
    data: jsonEncode({"message": message})
  );
}