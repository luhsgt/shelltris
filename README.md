# Shelltris
A Tetris Electronika 60 inspired game written in shell script.

## Features
- 7 bag tetromino randomizer
- Holding pieces
- 3 different styles to play the game in
- Ghost piece for easier gameplay
- Pausing

## Installation

### Requirements
- **Bash 4.0 or higher**  
  (macOS ships with Bash 3.2, so you’ll likely need to upgrade.)

---

### macOS

1. Make the script executable:
   ```bash
   chmod +x tetris.sh
   ```
2. Install the latest version of Bash (if not already installed). One option is via [Homebrew](https://brew.sh/):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   brew install bash
   ```
3. Run the game using your newly installed Bash:
   ```bash
   /opt/homebrew/bin/bash ./tetris.sh
   ```

---

### Windows & Linux

1. Make the script executable:
   ```bash
   chmod +x tetris.sh
   ```
2. Run it (most Linux distros already have Bash 4+):
   ```bash
   bash ./tetris.sh
   ```

---

## Notes
- macOS users **must** upgrade Bash before running the game, as the built-in version is too old for certain features (like associative arrays).
- Linux and Windows users with modern Bash can run the game directly after making it executable.
- There is a known issue with playing the game at high speeds where the pipe can be overrun with commands causing input delay and making it nearly unplayable but I find it unlikely anyone will ever face this issue. 
