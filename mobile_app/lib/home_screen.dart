import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'movie_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  List sections = [];

  bool showMenu = false;
  late AnimationController _menuController;

  @override
  void initState() {
    super.initState();
    fetchHome();

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Future<void> fetchHome() async {
    final url = Uri.parse("http://10.235.29.8:8000/home");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        sections = data["sections"];
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  void toggleMenu() {
    setState(() {
      showMenu = !showMenu;
      showMenu ? _menuController.forward() : _menuController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 110,
                    ),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      return buildSection(sections[index]);
                    },
                  ),
          ),

          // 🔝 TOP GLASS BAR (STATUS READABLE)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: MediaQuery.of(context).padding.top + 10,
                  color: Colors.black.withOpacity(0.35),
                ),
              ),
            ),
          ),

          // 🔲 BOTTOM RIGHT GLASS BAR
          Positioned(
            bottom: 18,
            right: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12, // 🔼 taller
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(38),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconBtn(Icons.search, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      }),
                      const SizedBox(width: 14), // 🟢 separation
                      iconBtn(Icons.menu, toggleMenu),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 📂 MENU SLIDER (RIGHT EDGE)
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
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.person,
                            color: Colors.white70, size: 22),
                        SizedBox(height: 16),
                        Icon(Icons.favorite,
                            color: Colors.white70, size: 22),
                        SizedBox(height: 16),
                        Icon(Icons.info_outline,
                            color: Colors.white70, size: 22),
                        SizedBox(height: 16),
                        Icon(Icons.settings,
                            color: Colors.white70, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎬 SECTION — TIGHT SPACING
  Widget buildSection(dynamic section) {
    final List movies = section["movies"];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4), // 🔽 reduced
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              section["title"],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 255,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                return buildPoster(movies[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🎞 POSTER
  Widget buildPoster(dynamic movie) {
    final posterUrl = movie["poster_url"];
    final title = movie["title"] ?? "";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(movieId: movie["id"]),
          ),
        );
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
