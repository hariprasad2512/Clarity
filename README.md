# Clarity 

Clarity is a custom, native macOS to-do application designed to help organize a chaotic life. 

Built completely based on the minimalistic philosophy, this app avoids the feature bloat and rigid workflows of standard productivity tools. It offers a minimal, fast, and highly personalized experience.

## ✨ Features

* **Native macOS Experience:** Built entirely with SwiftUI for a seamless and responsive desktop interface.
* **Bold Visual Identity:** Features a massive input box and a clean, unapologetically green aesthetic.
* **Smart Scheduling:** Integrates Apple's `NSDataDetector` to automatically extract natural language dates (e.g., "Buy groceries tomorrow at 5 PM") directly from your typed tasks.
* **Manual Overrides:** Includes a native date picker for explicitly setting specific deadlines when needed.
* **Local Privacy-First Storage:** Powered by SwiftData to act as the brain that remembers your tasks locally on your Mac, with zero cloud reliance.
* **Smart Alerts:** Utilizes the UserNotifications framework to give you a tap on the shoulder precisely when a task is due, complete with a bug-free cancellation system for completed tasks.

## 🚀 Installation (v1.0 Release)

You can download the compiled app directly from the Releases page and run it immediately on your Mac.

1. Navigate to the **Releases** section on the right side of this GitHub repository.
2. Download the latest `Clarity.app` (or the `.zip` containing it).
3. Drag and drop the `Clarity.app` file directly into your Mac's **Applications** folder.
4. Drag the app into your Mac Dock to easily access it and see the custom "Focus Lens" logo.

## 🛠️ Built With

* **SwiftUI** - User Interface
* **SwiftData** - Local Database Modeling
* **UserNotifications** - macOS Alert System
* **NSDataDetector** - Natural Language Processing
