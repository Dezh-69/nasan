# Nasan

Nasan is a family alert application designed to let users send immediate notifications or "rings" to family members, ensuring they can get in touch quickly during critical situations.

## What the System Does
The system allows users to log in, connect with family members, and send direct alert notifications (rings) to their devices. It handles background messaging and can ring the target device even when the app is in the background, utilizing native channels (like `RingReceiver`) and Firebase Cloud Messaging (FCM). It also supports sending abort requests to stop the ringing remotely.

## Who Uses It
This app is designed for families and close groups who need a reliable way to get someone's attention urgently.

## My Role
**Developer**: Gervyn
* Responsible for building the Flutter frontend, integrating Firebase services, managing state with Riverpod, and implementing native background ringing channels for Android.*

## Tools and Languages Used
### Languages
- **Dart**: Core programming language for the Flutter app.
- **Kotlin**: Used for native Android background execution and ring handling.

### Frameworks & Libraries
- **Flutter**: Cross-platform UI framework.
- **Firebase**: 
  - **Firebase Auth**: User authentication.
  - **Cloud Firestore**: Database for storing user and group data.
  - **Firebase Cloud Messaging (FCM)**: For pushing real-time ring alerts and abort signals.
  - **Cloud Functions**: Backend logic.
- **Riverpod**: State management.
- **GoRouter**: Navigation and routing.

---
*Note: If any of the above details need adjustments or further expansion (e.g., specific target audience details or further role descriptions), feel free to let me know and we can refine this README further!*
