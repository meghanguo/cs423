# painting_application

## Overview

This application is a painting application developed for a class. This gesture-based application lets you draw, save, edit, and favorite your drawings. It also recognizes shapes and perfects them when the user wants.

## Environment

Flutter was used to develop this app. It allows us to test it on iOS and Android without changing the language or how the code is structured.

## Getting started

Steps to run the app using Mac on a physical iOS device:

### Setting up Andriod Studio

1. Download Xcode on Mac if you don't have it already.

2. Have all the command line tools downloaded for Xcode using

    ```shell
    xcode-select --install
    ```

3. If Homebrew is not installed, use the following command to install it.

    ```shell
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

4. The next step is downloading Flutter to ensure the app runs properly. Use the following command in the terminal to do so.

    ```shell
    brew install --cask flutter
    ```

5. Go to [Android Studio website](https://developer.android.com/studio?gad_source=1&gclid=CjwKCAiAxqC6BhBcEiwAlXp457BcNK1DZWL75Ff40SK4VZEdezqvT_j7XEn9hDvUkzsTNOdh64_rfhoCv7MQAvD_BwE&gclsrc=aw.ds) and download Android Studio for Mac. Open the downloaded version and drag it to the applications folder.

6. Next go to configure in Android Studio and click on **SDK Manager** and select *Android 14.0 ("UpsideDownCake")* API level 34 under SDK Platforms and hit "OK".

7. Then click on the SDK Tools tab on the top next to SDK Platforms and select *Android SDK Command-line Tools*, *Android SDK Platform-Tools*, *NDK (Side by side)* and *Android SDK Build-Tools 36-rc1*.

8. Copy the Android SDK Location and open the terminal to change the directory to the Home directory.

    ```shell
    cd $HOME
    ```

9. Then in terminal type the following commands.

    ```shell
    nano .zshrc
    ```
   path = Android SDK Location

    ```shell
    export ANDROID_HOME=path
    ```

   Type ^X for Exit.

10. Restart the terminal and double check if everything is executed correctly by typing the following command.

    ```shell
    echo $ANDROID_HOME
    ```

    If the location doesn't appear then something is wrong. Double check the previous steps.

11. Next step is to accept Flutter licenses.

    ```shell
    flutter doctor --android-licenses
    ```

    Keep clicking **y** until all licenses are accepted.

12. Check what else is left to download by using

    ```shell
    flutter doctor
    ```

    There should be only Xcode that should be in yellow or red. Disregard connected devices error for now.

13. The next step is to install CocoaPods.

    ```shell
    brew install cocoapods
    ```

    After installing run

    ```shell
    flutter doctor
    ```

    and now everything should be ready in terms of Flutter.

14. Now got to Android Studio and got to Plugins and install **Flutter** plugin.

15. Just to make sure everything is fine. Make a new Flutter project and when asked for SDK path, got to your terminal type

    ```shell
    flutter doctor -v
    ```

    and this will give you the path. Copy that and paste it in Android Studio Flutter SDK path.

16. After creating a new a flutter project. If you see on top right a menu to select devices then the setup is done.

A guided [video](https://www.youtube.com/watch?v=fzAg7lOWqVE) of the mentioned steps above is avaliable as well.

### Clone git repo

The next step is to clone our repo. In terminal go the desired location to clone the project. Then type

```shell
git clone git@github.com:meghanguo/cs423.git
```

### Run the app on an iOS device

First open the project in Android Studio and make sure the device list is visible if not. It might ask you to enable Dart first.

Just in case in the terminal of Android Studio, type

```shell
flutter clean
flutter pub get
```

In your Mac terminal go to the project directory and go to ios folder instead the directory. You should see **Runner.xcworkspace** file.

Type

```shell
open Runner.xcworkspace
```

This should open Xcode window. Before running the project connect your iOS device to your Mac and make sure developer mode is on.

To finally run the app, click on **Run** button on the top left. This should download our app in your phone. Give it few minutes to complete the download and then you are ready to use our app.
