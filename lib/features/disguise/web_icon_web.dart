import 'package:web/web.dart' as web;

const _titles = {
  'weather': 'Weather',
  'notes': 'Notes',
  'calendar': 'Calendar',
  'calculator': 'Calculator',
};

void setWebIcon(String name) {
  web.document.title = _titles[name] ?? 'Content';
  web.document
      .querySelector('link[rel="icon"]')
      ?.setAttribute(
        'href',
        _titles.containsKey(name) ? 'icons/disguise-$name.png' : 'favicon.png',
      );
}
