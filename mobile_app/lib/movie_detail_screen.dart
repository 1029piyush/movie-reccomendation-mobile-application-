import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'search_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final int? movieId;
  final int? tmdbId;

  const MovieDetailScreen({super.key, this.movieId, this.tmdbId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  Map? movie;
  String? error;

  List<String> genres = [];
  List<String> cast = [];
  List randomMovies = [];

  YoutubePlayerController? _ytController;
  bool showTrailer = false;
  bool isMuted = true;
  String? youtubeKey;

  bool showMenu = false;
  late AnimationController _menuController;

  @override
  void initState() {
    super.initState();
    fetchMovie();
    fetchRandomMovies();

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _menuController.dispose();
    super.dispose();
  }

  // ================= MOVIE =================
  Future<void> fetchMovie() async {
    try {
      final int id = widget.movieId ?? widget.tmdbId!;
      final url = widget.movieId != null
          ? Uri.parse("http://10.235.29.8:8000/movies/$id")
          : Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id");

      final res = await http.get(url);

      if (res.statusCode == 200) {
        movie = jsonDecode(res.body);
        fetchGenresAndCast(id);
        fetchTrailerKey(id);
        Future.delayed(const Duration(seconds: 2), startTrailer);
      } else {
        error = "Failed to load movie";
      }
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> fetchGenresAndCast(int id) async {
    try {
      final g = await http.get(
          Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id/genres"));
      final c = await http.get(
          Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id/cast"));

      if (g.statusCode == 200) {
        genres = List<String>.from(jsonDecode(g.body));
      }
      if (c.statusCode == 200) {
        cast = List<String>.from(jsonDecode(c.body)).take(5).toList();
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> fetchTrailerKey(int id) async {
    final res = await http.get(
        Uri.parse("http://10.235.29.8:8000/tmdb/movie/$id/trailer"));
    if (res.statusCode == 200) {
      youtubeKey = jsonDecode(res.body)["youtube_key"];
    }
  }

  void startTrailer() {
    if (youtubeKey == null || !mounted) return;
    _ytController = YoutubePlayerController(
      initialVideoId: youtubeKey!,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: isMuted,
        loop: true,
        hideControls: true,
        disableDragSeek: true,
      ),
    );
    setState(() => showTrailer = true);
  }

  // ================= RANDOM =================
  Future<void> fetchRandomMovies() async {
    try {
      final res =
          await http.get(Uri.parse("http://10.235.29.8:8000/movies"));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        data.shuffle();
        randomMovies = data.take(3).toList();
        setState(() {});
      }
    } catch (_) {}
  }

  // ================= LOADING =================
  Widget googleLoading() {
    return Column(
      children: [
        Container(height: 240, color: Colors.grey.shade900),
        const SizedBox(height: 20),
        Container(
          height: 24,
          width: 220,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.grey.shade800,
        ),
        const SizedBox(height: 12),
        ...List.generate(
          4,
          (_) => Container(
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  void toggleMenu() {
    setState(() {
      showMenu = !showMenu;
      showMenu ? _menuController.forward() : _menuController.reverse();
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: loading
                ? googleLoading()
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: showTrailer && _ytController != null
                                  ? Stack(
                                      children: [
                                        YoutubePlayer(
                                          controller: _ytController!,
                                          showVideoProgressIndicator: true,
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          right: 10,
                                          child: IconButton(
                                            icon: Icon(
                                              isMuted
                                                  ? Icons.volume_off
                                                  : Icons.volume_up,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
                                              isMuted = !isMuted;
                                              isMuted
                                                  ? _ytController!.mute()
                                                  : _ytController!.unMute();
                                              setState(() {});
                                            },
                                          ),
                                        )
                                      ],
                                    )
                                  : youtubeKey != null
                                      ? Image.network(
                                          "https://img.youtube.com/vi/$youtubeKey/hqdefault.jpg",
                                          fit: BoxFit.cover,
                                        )
                                      : const SizedBox(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  movie!["title"] ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(Icons.favorite_border,
                                  color: Colors.white),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            movie!["overview"] ?? "",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),

                        if (genres.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              children: genres
                                  .map((g) => Chip(
                                        label: Text(g),
                                        backgroundColor:
                                            Colors.grey.shade800,
                                        labelStyle: const TextStyle(
                                            color: Colors.white),
                                      ))
                                  .toList(),
                            ),
                          ),

                        if (cast.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 12,
                              children: cast
                                  .map((c) => Text(c,
                                      style: const TextStyle(
                                          color: Colors.white70)))
                                  .toList(),
                            ),
                          ),

                        if (randomMovies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: randomMovies.map<Widget>((m) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MovieDetailScreen(
                                            movieId: m["id"]),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width /
                                        3.4,
                                    child: Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            m["poster_url"],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          m["title"],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // 🔲 MENU SLIDER (IDENTICAL TO HOME)
          Positioned(
            bottom: 82,
            right: 8,
            child: SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: _menuController,
                curve: Curves.easeOut,
              ),
              axisAlignment: -1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.person, color: Colors.white70),
                        SizedBox(height: 16),
                        Icon(Icons.favorite, color: Colors.white70),
                        SizedBox(height: 16),
                        Icon(Icons.info_outline, color: Colors.white70),
                        SizedBox(height: 16),
                        Icon(Icons.settings, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🔽 BOTTOM BAR
          Positioned(
            bottom: 18,
            right: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(38),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SearchScreen()),
                          );
                        },
                        child:
                            const Icon(Icons.search, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: toggleMenu,
                        child: const Icon(Icons.menu, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
