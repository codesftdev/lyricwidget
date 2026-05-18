<div align="center">

# LyricWidget

LyricWidget is a widget for KDE Plasma 6 that shows currently playing song information and provide playback controls, alongside live lyrics from LRCLIB.

LyricWidget is a fork of [PlasMusic Toolbar](https://github.com/ccatterina/plasmusic-toolbar), with this fork aiming to add more features.

<img width="363" height="105" alt="image" src="https://github.com/user-attachments/assets/a98c66ba-6c9e-45cd-aac4-87d8f6631aa3" />

</div>

## Compatibility

- Compatible with KDE Plasma 6.0.4 and newer.
- Plasma 5: a Plasma 5 version of the original PlasMusic Toolbar widget is available in the `plasma5` branch: https://github.com/ccatterina/plasmusic-toolbar/tree/plasma5
- Compatibility with vertical panels is limited and some features may not work well. Please use LyricWidget in a horizontal panel.

## Features

### 🎵 Now Playing Song
- Show the currently playing song's title and artist in the KDE panel

### ⏯️ Playback Controls
- Manage your music effortlessly with Play, Pause, Next, and Previous controls directly from the KDE panel.

### 📸 Full View
- Full View provides the album image, along with Play, Pause, Next, Previous, Shuffle, and Repeat controls. Adjust the volume and track position with ease.
<img width="187.5" height="297" alt="image" src="https://github.com/user-attachments/assets/ffa5bd30-d78b-476b-8646-29b0243f9911" />

### 🛠️ Configurations
- **Icon customization:** Change the widget's icon in the panel view to suit your preferences. You can also choose to display the album cover.
- **Font customization:** Change the widget's text font to suit your preferences.
- **Panel song/icon/controls visibility:** Choose whether to show icon, song text and playback controls in the panel view.
- **Preferred source**: Change the widget preferred source for music information (choose between active MPRIS2 sources).
- **Song text customization**: Customize the maximum (or fixed) text width and scrolling behavior with adjustable scroll speed.
- **Live Lyrics**: Display live lyrics in both the full view and panel view


## Installation

### Manual
1. Clone the repository:
    ```sh
    git clone https://github.com/codesftdev/lyricwidget
    ```

2. Install the widget:

    ```sh
    kpackagetool6 -i /path/to/lyricwidget --type Plasma/Applet
    ```

3. Upgrading the widget:

    ```sh
    kpackagetool6 -u /path/to/lyricwidget/src/ --type Plasma/Applet
    ```

4. Removing the widget:

    ```sh
    kpackagetool6 -r lyricwidget --type Plasma/Applet
    ```


## Translations

**Warning**: The translations are from the original PlasMusic toolbar, and this project's translations may be incomplete, missing, or using machine translation.

### Prerequisites

Make sure you have the package `gettext` installed on your system, as it is required for managing translations.

### I18n helper script

The widget comes with a helper script (`bin/i18n`) to manage translations:

1. **Extract translatable strings** from the source code:
   ```sh
   ./bin/i18n extract
   ```
   Creates/updates the translation template file (`src/translate/template.pot`) and updates existing `.po` files.

1. **Check translation status**:
   ```sh
   ./bin/i18n check
   ```
   Check if translations template is up to date and shows how many strings are untranslated in each language file.

1. **Initialize a new language**:
   ```sh
   ./bin/i18n init <lang_code>
   ```
   For example, `./bin/i18n init fr` creates a new French translation file.

1. **Compile translations**:
   ```sh
   ./bin/i18n compile
   ```
   This compiles all `.po` files into `.mo` files that the widget can use.

### Contributing Translations

1. Create or edit a `.po` file in the `src/translate/` directory.
2. Compile the translations to verify they work correctly.
3. Submit a pull request with your changes to the `src/translate/` directory, do not include the compiled `.mo` files, as they will be generated automatically during the build process.
