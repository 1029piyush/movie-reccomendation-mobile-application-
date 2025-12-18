import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MovieListScreen(),
    );
  }
}

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  List movies = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }

  Future<void> fetchMovies() async {
    final url = Uri.parse("http://10.162.94.9:8000/movies");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        movies = json.decode(response.body);
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Movies")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final posterPath = movies[index]["poster_path"];

return Card(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: ListTile(
    leading: posterPath != null && posterPath.isNotEmpty
        ? Image.network(
            "https://image.tmdb.org/t/p/w500$posterPath",
            width: 50,
            fit: BoxFit.cover,
          )
        : const Icon(Icons.movie, size: 40),
    title: Text(
                 movies[index]["title"],
                 style: const TextStyle(fontWeight: FontWeight.bold),
                ),
    subtitle: Text(movies[index]["genres"] ?? ""),
       ),
    );

              },
            ),
    );
  }
}
