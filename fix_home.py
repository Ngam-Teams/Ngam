import re

def main():
    try:
        with open('C:\\Project\\Ngam\\lib\\screens\\customer\\customer_home_screen.dart', 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print("Error:", e)
        return

    # Replace the body and bottomNavigationBar with Stack and lazy init
    
    new_state = """
class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  
  // Array untuk menyimpan status pemuatan setiap tab
  final List<bool> _initializedPages = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    // Buang splash screen lepas frame pertama di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _initializedPages[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _initializedPages[0] ? const ExploreView() : const SizedBox.shrink(),
      _initializedPages[1] ? const MyRezrvView() : const SizedBox.shrink(),
      _initializedPages[2] ? const ChatScreen() : const SizedBox.shrink(),
      _initializedPages[3] ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavCustomer(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}
"""

    pattern = r'class _CustomerHomeScreenState extends State<CustomerHomeScreen> \{.*?\}\n\}'
    
    content = re.sub(pattern, new_state.strip(), content, flags=re.DOTALL)
    
    with open('C:\\Project\\Ngam\\lib\\screens\\customer\\customer_home_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched customer_home_screen!")

if __name__ == '__main__':
    main()
