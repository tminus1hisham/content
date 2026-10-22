import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/prefs.dart';
import 'pin_pad.dart';

const decoyWeatherKey = 'decoy.weather';
const _forecastUrl =
    'https://api.open-meteo.com/v1/forecast?latitude=-1.2864&longitude=36.8172'
    '&current=temperature_2m,weather_code'
    '&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto';

/// WMO weather interpretation codes (as used by Open-Meteo).
(String, IconData) describeWeather(int code) => switch (code) {
  0 => ('Clear', Icons.wb_sunny_outlined),
  1 || 2 => ('Partly cloudy', Icons.wb_cloudy_outlined),
  3 => ('Overcast', Icons.cloud_outlined),
  45 || 48 => ('Fog', Icons.foggy),
  51 || 53 || 55 => ('Drizzle', Icons.grain),
  56 || 57 || 66 || 67 => ('Freezing rain', Icons.ac_unit),
  61 || 63 || 65 => ('Rain', Icons.water_drop_outlined),
  71 || 73 || 75 || 77 || 85 || 86 => ('Snow', Icons.ac_unit),
  80 || 81 || 82 => ('Showers', Icons.umbrella_outlined),
  95 || 96 || 99 => ('Thunderstorm', Icons.thunderstorm_outlined),
  _ => ('Cloudy', Icons.cloud_outlined),
};

class _Day {
  const _Day(this.date, this.max, this.min, this.code);
  final DateTime date;
  final num max, min;
  final int code;
}

class _Forecast {
  const _Forecast(this.temp, this.code, this.days);
  final num temp;
  final int code;
  final List<_Day> days;

  static _Forecast? parse(String? raw) {
    if (raw == null) return null;
    try {
      if (jsonDecode(raw) case {
        'current': {'temperature_2m': num temp, 'weather_code': int code},
        'daily': {
          'time': List time,
          'temperature_2m_max': List max,
          'temperature_2m_min': List min,
          'weather_code': List codes,
        },
      }) {
        final days = <_Day>[];
        for (var i = 0; i < time.length; i++) {
          if (i < max.length && i < min.length && i < codes.length) {
            if ((time[i], max[i], min[i], codes[i]) case (
              String t,
              num hi,
              num lo,
              int c,
            )) {
              final date = DateTime.tryParse(t);
              if (date != null) days.add(_Day(date, hi, lo, c));
            }
          }
        }
        return _Forecast(temp, code, days);
      }
    } on FormatException {
      // Fall through: treat as no data.
    }
    return null;
  }
}

/// Working weather app for Nairobi via Open-Meteo (no key). Shows the last
/// cached forecast when offline.
class DecoyWeather extends ConsumerStatefulWidget {
  const DecoyWeather({super.key});

  @override
  ConsumerState<DecoyWeather> createState() => _DecoyWeatherState();
}

class _DecoyWeatherState extends ConsumerState<DecoyWeather> {
  late _Forecast? _forecast = _Forecast.parse(switch (ref
      .read(sharedPreferencesProvider)
      .get(decoyWeatherKey)) {
    final String s => s,
    _ => null,
  });
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _Forecast? fresh;
    String? body;
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
        ),
      ).get<String>(_forecastUrl);
      body = response.data;
      fresh = _Forecast.parse(body);
    } on DioException {
      fresh = null;
    }
    if (fresh != null) {
      await ref
          .read(sharedPreferencesProvider)
          .setString(decoyWeatherKey, body!);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = fresh == null;
      _forecast = fresh ?? _forecast;
    });
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const DecoyTitle('Weather')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (forecast == null && _loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (forecast == null)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text('No connection', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else ...[
              if (_offline)
                const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Offline. Showing the last forecast.'),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('Nairobi', style: textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Icon(describeWeather(forecast.code).$2, size: 64),
                      Text(
                        '${forecast.temp.round()}°',
                        style: textTheme.displayMedium,
                      ),
                      Text(describeWeather(forecast.code).$1),
                    ],
                  ),
                ),
              ),
              for (final day in forecast.days)
                ListTile(
                  leading: Icon(describeWeather(day.code).$2),
                  title: Text(DateFormat.EEEE().format(day.date)),
                  subtitle: Text(describeWeather(day.code).$1),
                  trailing: Text(
                    '${day.max.round()}° / ${day.min.round()}°',
                    style: textTheme.titleMedium,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
