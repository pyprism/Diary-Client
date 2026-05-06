import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppAdaptiveScaffold extends StatelessWidget {
  final Widget child;
  final String location;

  const AppAdaptiveScaffold({
    super.key,
    required this.location,
    required this.child,
  });

  static const _navItems = [
    _NavItem(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        path: '/home'),
    _NavItem(
        label: 'Diary',
        icon: Icons.book_outlined,
        activeIcon: Icons.book,
        path: '/diary'),
    _NavItem(
        label: 'Tags',
        icon: Icons.label_outline,
        activeIcon: Icons.label,
        path: '/tags'),
    _NavItem(
        label: 'Shares',
        icon: Icons.ios_share_outlined,
        activeIcon: Icons.ios_share,
        path: '/shares'),
  ];

  int _selectedIndex() {
    if (location.startsWith('/diary')) return 1;
    if (location.startsWith('/tags')) return 2;
    if (location.startsWith('/shares')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    if (index == _selectedIndex()) return;
    context.go(_navItems[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= 1024) {
          return _WideLayout(
            navItems: _navItems,
            selectedIndex: _selectedIndex(),
            onTap: (i) => _onTap(context, i),
            child: child,
          );
        } else if (width >= 600) {
          return _MediumLayout(
            navItems: _navItems,
            selectedIndex: _selectedIndex(),
            onTap: (i) => _onTap(context, i),
            child: child,
          );
        } else {
          return _NarrowLayout(
            navItems: _navItems,
            selectedIndex: _selectedIndex(),
            onTap: (i) => _onTap(context, i),
            child: child,
          );
        }
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}

// Mobile: bottom navigation bar
class _NarrowLayout extends StatelessWidget {
  final Widget child;
  final List<_NavItem> navItems;
  final int selectedIndex;
  final void Function(int) onTap;

  const _NarrowLayout({
    required this.child,
    required this.navItems,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        destinations: navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

// Tablet: navigation rail
class _MediumLayout extends StatelessWidget {
  final Widget child;
  final List<_NavItem> navItems;
  final int selectedIndex;
  final void Function(int) onTap;

  const _MediumLayout({
    required this.child,
    required this.navItems,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onTap,
            labelType: NavigationRailLabelType.all,
            destinations: navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// Desktop: permanent navigation drawer
class _WideLayout extends StatelessWidget {
  final Widget child;
  final List<_NavItem> navItems;
  final int selectedIndex;
  final void Function(int) onTap;

  const _WideLayout({
    required this.child,
    required this.navItems,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: NavigationDrawer(
              selectedIndex: selectedIndex,
              onDestinationSelected: onTap,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 16, 16),
                  child: Text(
                    'Diary',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                ),
                ...navItems.map((item) => NavigationDrawerDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    )),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
