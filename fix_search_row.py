import re

def main():
    try:
        with open('C:\\Project\\Ngam\\lib\\screens\\rezrv\\explore_view.dart', 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print("Error:", e)
        return

    # First, let's capture the exact text field and QR blocks we want to replace.
    # Because regex across many lines can be flaky, we'll replace the whole _buildSearchRow method up to the return.
    
    pattern = r'Widget _buildSearchRow\(bool isDark\) =>.*?Padding\(.*?const SizedBox\(width: 12\),.*?_AnimatedPressable.*?child: Center\(.*?HugeIcon\(icon: HugeIcons.strokeRoundedQrCode01.*?\).*?\),\s*\),\s*\),\s*\)\s*\]\),\s*\);'

    new_row = """Widget _buildSearchRow(bool isDark) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          Expanded(
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: _getGlassSettings(isDark),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: _isSearching
                            ? CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? Colors.white : _lightModeGray))
                            : HugeIcon(icon: HugeIcons.strokeRoundedSearch01,
                            color: isDark ? Colors.white70 : _lightModeGray
                                .withValues(alpha: 0.6),
                            size: 20,
                            strokeWidth: 2.0)
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: Colors.blue,
                          ),
                          primaryColor: Colors.blue,
                        ),
                        child: TextField(
                          controller: _searchController, focusNode: _searchFocus, onChanged: _handleSearch, onSubmitted: _executeSearch,
                          style: TextStyle(color: isDark ? Colors.white : _lightModeGray, fontWeight: FontWeight.w600, fontSize: 15),
                          cursorColor: Colors.blue, 
                          textAlignVertical: TextAlignVertical.center, 
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.searchHint, 
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : _lightModeGray.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w400), 
                            border: InputBorder.none, 
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),

                    if (_searchController.text.isNotEmpty)
                      GestureDetector(onTap: _clearSearch,
                          child: Icon(Icons.close, size: 18,
                              color: isDark ? Colors.white70 : _lightModeGray
                                  .withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _AnimatedPressable(
            onTap: () {
              setState(() {
                _isAIPanelOpen = !_isAIPanelOpen;
              });
            },
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 100.0),
              settings: _getGlassSettings(isDark),
              child: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                    child: HugeIcon(icon: HugeIcons.strokeRoundedSparkles,
                        color: Colors.blue,
                        size: 22,
                        strokeWidth: 2.0)
                ),
              ),
            ),
          )
        ]),
      );"""

    # We use DOTALL so .*? matches newlines
    new_content, count = re.subn(pattern, new_row, content, flags=re.DOTALL)
    
    if count == 0:
        print("Regex didn't match. Something is wrong.")
    else:
        with open('C:\\Project\\Ngam\\lib\\screens\\rezrv\\explore_view.dart', 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Patched!")

if __name__ == '__main__':
    main()
