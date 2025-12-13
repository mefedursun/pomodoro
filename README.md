# 🍅 Pomodoro Timer

A beautiful, dark-themed Pomodoro timer app built with Flutter. Features a circular progress indicator, task management, daily goals, and more!

## 🌐 Live Demo

**[Try it in your browser!](https://your-username.github.io/pomodoro/)** (Chrome recommended)

## ✨ Features

- **⏱️ Pomodoro Timer**
  - 25-minute work sessions (customizable)
  - 5-minute short breaks (customizable)
  - 15-minute long breaks (customizable)
  - Circular progress indicator with beautiful animations
  - Auto-transition between sessions

- **📋 Task Management**
  - Add, edit, and delete tasks
  - Task priorities (High, Medium, Low)
  - Mark tasks as complete
  - Search and filter tasks
  - Swipe to delete
  - Hide/show completed tasks

- **🎯 Daily Goals**
  - Set daily pomodoro goals
  - Track progress with visual progress bar
  - Reset daily goals
  - Automatic daily reset

- **🎨 Beautiful UI**
  - Dark theme with gradient backgrounds
  - Smooth animations and transitions
  - Shadow effects and visual depth
  - Responsive design (Portrait & Landscape)
  - Confetti celebration on work session completion

- **⚙️ Settings**
  - Customize timer durations
  - Sound effects toggle
  - All settings saved locally

- **💾 Local Storage**
  - All data saved locally using SharedPreferences
  - Tasks persist across app restarts
  - Settings persist across sessions

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/pomodoro.git
   cd pomodoro
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Web Build

To build for web:

```bash
flutter build web --release
```

The build output will be in `build/web/` directory.

### GitHub Pages Deployment

1. Build the web app:
   ```bash
   flutter build web --release --base-href "/pomodoro/"
   ```

2. Copy the `build/web` contents to the `docs` folder (or `gh-pages` branch)

3. Push to GitHub and enable GitHub Pages in repository settings

## 📱 Platforms

- ✅ Web (Chrome, Firefox, Safari, Edge)
- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🛠️ Technologies

- **Flutter** - UI Framework
- **Provider** - State Management
- **SharedPreferences** - Local Storage
- **Google Fonts** - Typography (Merriweather, Inter)
- **Percent Indicator** - Circular Progress
- **Confetti** - Celebration Animation

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.5.4
  percent_indicator: ^4.2.5
  google_fonts: ^6.3.3
  provider: ^6.1.5+1
  confetti: ^0.8.0
```

## 🎨 Design

- **Background**: Dark gradient (#1F1F1F → #1A1A1A)
- **Surface**: #2A2A2A
- **Text**: #EAEAEA (primary), #A0A0A0 (secondary)
- **Accent**: #D97757 (orange-red)
- **Success**: #66BB6A (green)

## 📄 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## ⭐ Show your support

Give a ⭐ if you like this project!

---

Made with ❤️ using Flutter
