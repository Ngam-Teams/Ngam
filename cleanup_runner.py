import os
import re

# 1. login_screen.dart
login_path = r'C:\Project\Ngam\lib\screens\auth\login_screen.dart'
with open(login_path, 'r', encoding='utf-8') as f:
    login_text = f.read()

# Replace:
# final role = authProvider.userRole;
# if (role == 'runner') {
#   Navigator.pushReplacementNamed(context, '/runner-home');
# } else {
#   Navigator.pushReplacementNamed(context, '/customer-home');
# }
# With:
# Navigator.pushReplacementNamed(context, '/customer-home');

login_text = re.sub(r'final role = authProvider\.userRole;\s*if \(role == \'runner\'\) \{\s*Navigator\.pushReplacementNamed\(context, \'/runner-home\'\);\s*\} else \{\s*Navigator\.pushReplacementNamed\(context, \'/customer-home\'\);\s*\}', r"Navigator.pushReplacementNamed(context, '/customer-home');", login_text)

with open(login_path, 'w', encoding='utf-8') as f:
    f.write(login_text)

# 2. main.dart
main_path = r'C:\Project\Ngam\lib\main.dart'
with open(main_path, 'r', encoding='utf-8') as f:
    main_text = f.read()

# Remove imports
main_text = re.sub(r'import \'screens/runner/.*?\';\n', '', main_text)
# Remove route
main_text = re.sub(r'\'/runner-home\': \(context\) => const RunnerHomeScreen\(\),', '', main_text)
# Remove home logic
main_text = re.sub(r'if \(auth\.isRunner\) \{\s*return const RunnerHomeScreen\(\);\s*\} else \{\s*return const CustomerHomeScreen\(\);\s*\}', 'return const CustomerHomeScreen();', main_text)

with open(main_path, 'w', encoding='utf-8') as f:
    f.write(main_text)
print("Cleaned login_screen and main_dart")
