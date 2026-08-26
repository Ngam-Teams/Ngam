import re

path = r'C:\Project\Ngam\lib\screens\explore\explore_view.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'import \'package:flutter_tts/flutter_tts.dart\';\n', '', content)
content = re.sub(r'import \'package:speech_to_text/speech_to_text.dart\' as stt;\n', '', content)
content = re.sub(r'import \'package:http/http.dart\' as http;\n', '', content)
content = re.sub(r'import \'dart:convert\';\n', '', content)

content = re.sub(r'stt\.SpeechToText\? _speechToText;\n', '', content)
content = re.sub(r'FlutterTts\? _flutterTts;\n', '', content)
content = re.sub(r'bool _speechEnabled = false;\n', '', content)

content = re.sub(r'\s*_initSpeech\(\);\n', '', content)
content = re.sub(r'\s*_initTts\(\);\n', '', content)
content = re.sub(r'\s*_aiInputController\.dispose\(\);\n', '', content)
content = re.sub(r'\s*_aiScrollController\.dispose\(\);\n', '', content)

content = re.sub(r'// State untuk AI panel.*?String _aiInlineRecognizedWords = "";\n', '', content, flags=re.DOTALL)

content = re.sub(r'setState\(\(\) \{\n\s*_isAIPanelOpen = !_isAIPanelOpen;\n\s*\}\);', 'showGlassToast(context, \'Lagi (Akan Datang)\');', content)
content = re.sub(r'HugeIcons\.strokeRoundedSparkles', 'HugeIcons.strokeRoundedMoreHorizontal', content)
content = re.sub(r'color: Colors\.blue,\n\s*size: 22', 'color: isDark ? Colors.white70 : Colors.black87,\n                          size: 22', content)

content = re.sub(r'\s*_buildAIChatPanel\(isDark\),\n', '\n', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done basic regex removals')
