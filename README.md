Psst, want me to love you? Then [check this out](https://getbrowserhub.com) 😁

# WWDC app for OS X

Don't like the WWDC website? Prefer native apps?

Use this app to watch WWDC sessions on your Mac.

[Click here to download the latest release](https://raw.githubusercontent.com/insidegui/WWDC/master/Releases/WWDC_latest.zip).

![screenshot](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/screenshot.png)

Also, check this out: [WWDC app for the new Apple TV](https://github.com/insidegui/WWDC-tvOS) :)

## Searching

The app has a powerful search feature. When you first launch the app, It indexes the videos database and downloads transcripts from ASCIIWWDC, so when you search, not only will you get search results from session titles and descriptions, but also from what the presenter said in the sessions.

The app even shows a list of phrases matching your search so you can jump right to the point in the session where your searched word/phrase appears.

![Transcript Search](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/transcriptsearch.png)

With the handy filter bar you can filter sessions by year, track and focus, and also filter to show only favorited or downloaded sessions.

![Transcript Search](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/filterbar.png)
	
## Sharing

You can share direct links to specific session videos. Just select the session on the list and ⌘C to copy It's URL, or use the right-click menu.

![rightmenushare](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/rightmenushare.png)

## Reading

WWDC for OS X is integrated with [ASCIIWWDC](http://asciiwwdc.com), so you can see and search through transcripts of the sessions while watching the videos.

![screenshot2](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/screenshot2.png)

## Build Instructions

**Building requires Xcode 7.0 or later**

The only steps required before you build is to pull down the code and submodules:

	$ git clone --recursive https://github.com/insidegui/WWDC.git

### Cask

You can also install using [Homebrew Cask](http://caskroom.io):

	$ brew cask install wwdc
	
### PlayBack Tip: Speed Up / Slow Down

Speed up or slow down playback by ⌥ + clicking on the skip forward or backward arrows on the player window.
