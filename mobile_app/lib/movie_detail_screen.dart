import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MovieDetailScreen extends StatefulWidget {
  final int? movieId;
  final int? tmdbId;

  const MovieDetailScreen({super.key, this.movieId, this.tmdbId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool loading = true;
  Map? movie;
  String? error;

  List<String> genres = [];
  List<String> cast = [];

  // 🔁 FEED
  List feedMovies = [];
  int offset = 0;
  bool loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchMovie();
    loadFeed();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        loadFeed();
      }
    });
  }

  Future<void> fetchMovie() async {
    try {
      final int id = widget.movieId ?? widget.tmdbId!;

      final url = widget.movieId != null
          ? Uri.parse("http://10.235.29.8:8000/movies/$id")
          : Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["error"] != null) {
          error = data["error"];
        } else {
          movie = data;
          await fetchGenresAndCast(id);
        }
      } else {
        error = "Failed to load movie";
      }
    } catch (e) {
      error = e.toString();
    }

    setState(() => loading = false);
  }

  // 🎭 GENRES + CAST
  Future<void> fetchGenresAndCast(int id) async {
    try {
      final genreRes = await http.get(
        Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id/genres"),
      );
      final castRes = await http.get(
        Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id/cast"),
      );

      if (genreRes.statusCode == 200) {
        genres = List<String>.from(jsonDecode(genreRes.body));
      }

      if (castRes.statusCode == 200) {
        cast = List<String>.from(jsonDecode(castRes.body));
      }
    } catch (_) {}
  }

  // 🔁 LOAD MORE MOVIES (DB LOOP)
  Future<void> loadFeed() async {
    if (loadingMore) return;
    loadingMore = true;

    final res = await http.get(
      Uri.parse(
        "http://10.235.29.8:8000/movies/feed?offset=$offset",
      ),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      feedMovies.addAll(data);
     offset += data.length as int;

      setState(() {});
    }

    loadingMore = false;
  }

  // 🎬 TRAILER
  Future<void> playTrailer() async {
    final int? id = widget.movieId ?? widget.tmdbId;
    if (id == null) return;

    final res = await http.get(
      Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id/trailer"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data["youtube_key"] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black),
              body: YoutubePlayer(
                controller: YoutubePlayerController(
                  initialVideoId: data["youtube_key"],
                  flags: const YoutubePlayerFlags(autoPlay: true),
                ),
                showVideoProgressIndicator: true,
              ),
            ),
          ),
        );
      }
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
                  child: Text(error!,
                      style: const TextStyle(color: Colors.white)),
                )
              : ListView(
                  controller: _scrollController,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        movie!["overview"] ?? "",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    // 🎭 GENRES
                    if (genres.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: genres
                              .map(
                                (g) => Chip(
                                  label: Text(g),
                                  backgroundColor: Colors.grey.shade800,
                                  labelStyle: const TextStyle(
                                      color: Colors.white),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                    // 👥 CAST
                    if (cast.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Cast",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 40,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: cast.length,
                                itemBuilder: (_, i) => Padding(
                                  padding:
                                      const EdgeInsets.only(right: 12),
                                  child: Text(
                                    cast[i],
                                    style: const TextStyle(
                                        color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: playTrailer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Play Trailer"),
                      ),
                    ),

                    // 🔁 INFINITE FEED
                    ...feedMovies.map(
                      (m) => GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MovieDetailScreen(movieId: m["id"]),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Image.network(
                                m["poster_url"],
                                width: 90,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  m["title"],
                                  style: const TextStyle(
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
    );
  }
}
