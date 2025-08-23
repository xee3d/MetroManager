# MetroManager

A native macOS app for managing React Native/Expo Metro servers.

## 🚀 Key Features

### 📱 **Metro Server Management**
- **Expo** and **React Native CLI** project auto-detection (significantly improved accuracy)
- Automatic port conflict resolution (8081 → 8082, 8083...)
- Metro server start/stop/restart
- Real-time log monitoring
- **Stop All Servers** - One-click termination of all Metro servers

### 🎯 **Metro Shortcut System**
- **Basic Shortcuts** (all projects):
  - `r` - Reload app
  - `i` - Run app on iOS simulator
  - `a` - Run app on Android emulator
  - `d` - Open developer menu
  - `j` - Toggle debug mode
  - `m` - Open menu

- **Expo-Only Shortcuts** (displayed only for Expo projects):
  - `w` - Run app in web browser
  - `c` - Clear cache and logs
  - `s` - Send app to Expo Go
  - `t` - Connect via tunnel mode
  - `l` - Connect via LAN mode
  - `o` - Connect via localhost mode
  - `u` - Display URL information
  - `h` - Show help
  - `v` - Show version information
  - `q` - Quit Expo server

### 🔍 **External Process Detection**
- Auto-detect Metro servers running in other terminals
- Active server discovery through port scanning
- Automatic project name and path extraction
- "Zombie" process auto-cleanup

### 🎨 **User Experience**
- Intuitive SwiftUI interface
- Project-specific detailed information display
- Terminal integration (opens in new tab of existing terminal)
- Console text size adjustment
- Performance optimization (30-second interval background monitoring)
- Conditional UI display based on Expo project type
- **User-defined project type persistence** - manually set and save project types

## 📦 Installation & Execution

### 🎯 **Deploy App Execution**
```bash
# Download and run the app
open MetroManager-Release.app
```

### 🔧 **Development Build**
```bash
# Clone the project
git clone <repository-url>
cd MetroManager

# Build with Xcode
xcodebuild -project MetroManager.xcodeproj -scheme MetroManager -configuration Debug build

# Run the app
open /Users/ethanchoi/Library/Developer/Xcode/DerivedData/MetroManager-*/Build/Products/Debug/MetroManager.app
```

## 🛠️ System Requirements

- **macOS**: 13.0 or higher
- **Architecture**: Apple Silicon (ARM64) / Intel (x86_64)
- **Dependencies**: Node.js, npm/yarn/pnpm (for Metro execution)

## 📋 Usage

### 1. **Add Project**
- Click "Add Project" button
- Select project path
- Expo or React Native CLI auto-detection (improved accuracy)

### 2. **Start Metro Server**
- Select project and click "Start" button
- Automatically uses different port if conflict occurs
- Real-time log monitoring available

### 3. **Use Shortcuts**
- Shortcut buttons displayed when project is running
- Additional shortcut buttons for Expo projects
- Click desired function button to execute

### 4. **External Process Detection**
- Magnifying glass button to detect running Metro servers
- Trash button to clean up dead processes

### 5. **Terminal Integration**
- Terminal button to open project directory
- Opens in new tab of existing terminal window

### 6. **Project Type Management**
- Click on project type label to toggle between Expo/React Native CLI
- User-defined project types are persisted and won't be overridden by auto-detection
- External Metro detection preserves user settings

### 7. **Stop All Servers**
- Red stop button in toolbar to terminate all Metro servers at once
- Handles both internal and external processes
- Port scanning to find and terminate remaining Metro processes

## 🔧 Technical Stack

- **Language**: Swift 5
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (ObservableObject)
- **Build Tool**: Xcode 16
- **Target**: macOS 13.0+

## 📊 Performance Optimization

- **Background Monitoring**: 30-second intervals (minimal system load)
- **External Process Scanning**: Only when needed
- **Memory Usage**: < 1MB
- **App Size**: ~988KB

## 🎨 App Icon

Uses Claude code style dot text format icon

## 📝 License

Available for personal and commercial use

## 🤝 Contributing

Bug reports and feature suggestions welcome!

---

**MetroManager v0.7** - Making React Native development more convenient! 🚀

*Enhanced Expo project detection accuracy, expanded shortcut functionality, user-defined project type persistence, and stop all servers feature have been added.*
