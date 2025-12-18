import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MovieDetailScreen extends StatefulWidget {
  final int movieId;

  const MovieDetailScreen({super.key, required this.movieId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool loading = true;
  Map? movie;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchMovie();
  }

  Future<void> fetchMovie() async {
    try {
      final url = Uri.parse(
          "http://10.235.29.8:8000/movies/${widget.movieId}");
      final response = await http.get(url);

      print("DETAIL STATUS: ${response.statusCode}");
      print("DETAIL BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["error"] != null) {
          setState(() {
            error = data["error"];
            loading = false;
          });
        } else {
          setState(() {
            movie = data;
            loading = false;
          });
        }
      } else {
        setState(() {
          error = "Failed to load movie";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (movie!["poster_url"] != null)
                        Image.network(movie!["poster_url"]),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          movie!["title"] ?? "",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          movie!["overview"] ?? "",
                          style:
                              const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
