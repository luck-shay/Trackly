# State Management Refactoring Implementation Guide

## ✅ COMPLETED: CalendarScreen

**Status:** Production Ready
**Branch:** Ready to merge
**Tests:** Compile without errors

### Summary of Changes:
- Converted `_CalendarViewState` (StatefulWidget) → `_CalendarView` (StatelessWidget)
- Extended `CalendarProvider` with scope management
- All 2 `setState()` calls replaced with provider-based state management
- Removed local `enum _CalendarScope`, now using `enum CalendarScope` from provider

---

## 📋 NEXT: DashboardScreen Refactoring

**Scope:** HIGH Priority
**Difficulty:** MEDIUM  
**Estimated Impact:** 6-7 `setState()` calls eliminated

### Current Issues (Lines to fix):
1. **Line 132** - `_selectedFilter` state
2. **Line 275** - `_completedHabitIdsForOrdering` state
3. **Line 299** - `_isLoadingSectionPrefs` state
4. **Line 307** - `_groupOrderIds`, `_personalOrderIds` states
5. **Line 368, 376** - Filter order updates
6. **Line 1399** - Filter state changes

### Implementation Steps:

#### Step 1: Wrap with Provider
```dart
// main.dart or before DashboardScreen push
ChangeNotifierProvider(
  create: (_) => DashboardFilterProvider(),
  child: DashboardScreen(),
)
```

#### Step 2: Replace setState calls
**Before:**
```dart
setState(() {
  _selectedFilter = filter;
});
```

**After:**
```dart
context.read<DashboardFilterProvider>().setSelectedFilter(filter);
```

#### Step 3: Use Consumer for reactive updates
**Before:**
```dart
if (_selectedFilter == DashboardFilter.all) {
  // show all
}
```

**After:**
```dart
Consumer<DashboardFilterProvider>(
  builder: (context, filterProvider, _) {
    if (filterProvider.selectedFilter == DashboardFilter.all) {
      // show all
    }
  }
)
```

#### Step 4: Replace direct field access
**Before:**
```dart
_groupOrderIds = ids;
_personalOrderIds = ids;
```

**After:**
```dart
filterProvider.setGroupOrderIds(ids);
filterProvider.setPersonalOrderIds(ids);
```

---

## 📋 OPTIONAL: Friend Profile Screen

**Scope:** LOW Priority
**Difficulty:** EASY
**Impact:** 1 `setState()` call

### Current Issue:
- Line 54/69: `_isRemovingFriend` state

### Reason It's Low Priority:
- Highly localized state
- Only affects button loading indicator
- Not impacting multiple widgets

### If Refactoring:
Use `AsyncActionProvider` with action ID: `'unfriend_${friend.uid}'`

---

## 📋 TODO: Group Detail Screen

**Scope:** MEDIUM Priority
**Difficulty:** MEDIUM
**Impact:** 10+ `setState()` calls

### Analysis Needed:
1. Review all 10 setState calls
2. Categorize as:
   - UI-only state (animation, UI flags) → Keep as StatefulWidget
   - Domain state → Move to provider
   - View state (filters, sorting) → Move to provider

### Estimated Breakdown:
- UI-only states: ~3 (keep as is)
- View states: ~7 (move to provider)

---

## Best Practices Going Forward

### ✅ DO Move to Provider:
1. **Data/Domain State**
   - User profiles, habits, groups
   - Loaded data from network

2. **Navigation/View State**
   - Filter selections
   - Sorting preferences
   - Tab selections
   - Modal/dialog open state
   - Expanded/collapsed state affecting multiple widgets

3. **Form State (Complex)**
   - Multi-step forms
   - Cross-field validation
   - Large form objects

4. **Loading/Error States**
   - Network request status
   - Form submission status
   - Anything affecting UI across components

### ✅ FINE to Keep as setState:
1. **Brief Animations**
   - Fade/scale that doesn't persist
   - Duration < 1 second

2. **Single-widget UI States**
   - Button hover state
   - Temporary focus state
   - Single input field state (unless part of form provider)

3. **Micro-interactions**
   - Expanding details within one widget
   - Toggling details in a ListTile

### ❌ NEVER setState:
- Network calls
- User data
- Anything involving Firestore/API
- State needed by sibling/parent widgets

---

## Provider Architecture Standards

### File Naming
```
lib/providers/
├── calendar_provider.dart          # Focused concern: calendar UI state
├── dashboard_filter_provider.dart  # Focused concern: dashboard filters
├── habits_provider.dart             # Domain: habit data
├── create_habit_provider.dart       # Form: creating new habit
└── async_action_provider.dart       # Generic: loading states
```

### Provider Naming Convention
- `XyzProvider` for main providers
- Extends `ChangeNotifier`
- No UI imports in providers

### Method Naming
```dart
// Getters for state
String get selectedFilter => _selectedFilter;
List<String> get groupOrderIds => _groupOrderIds;

// Setters for state changes
void setSelectedFilter(DashboardFilter filter) {
  if (_selectedFilter != filter) {
    _selectedFilter = filter;
    notifyListeners();  // Always after changes
  }
}

// Avoid direct field mutation
// Bad:  provider._selectedFilter = value;
// Good: provider.setSelectedFilter(value);
```

---

## Testing Checklist

Before considering a refactoring "done":

- [ ] Compiles without errors/warnings
- [ ] No unused imports/variables
- [ ] Proper null safety
- [ ] Provider properly initialized/disposed
- [ ] setState completely removed from affected screen
- [ ] All state changes go through provider methods
- [ ] No direct field mutations from outside provider
- [ ] Consumer rebuilds only when necessary
- [ ] Performance acceptable
- [ ] Hot reload works properly

---

## Compilation Verification

Run this before committing:
```bash
flutter analyze
flutter build apk --analyze-size  # or flutter build web
```

All providers should have:
```
✓ No errors
✓ No warnings (except expected Flutter warnings)
✓ No unused code
```

---

## Rollout Plan

### Phase 1 (Done ✅):
- [x] CalendarProvider extended
- [x] CalendarScreen refactored
- [x] DashboardFilterProvider created
- [x] AsyncActionProvider created

### Phase 2 (Ready):
- [ ] Refactor DashboardScreen
- [ ] Verify compilation
- [ ] Test filter switching
- [ ] Test habit ordering

### Phase 3 (Optional):
- [ ] Refactor GroupDetailScreen
- [ ] Refactor CreateScreens (if not already using providers)
- [ ] Refactor FriendProfileScreen

### Phase 4 (Maintenance):
- [ ] Code review
- [ ] Performance testing
- [ ] Documentation update
