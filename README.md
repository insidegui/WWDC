# WWDC app for OS X

*Warning: Some features described on the readme may not be available on the latest release, download the source and build if you want the latest features.*

Don't like WWDC's website? Use this app to watch WWDC sessions on your Mac.

To download the latest release, [click here](https://github.com/insidegui/WWDC/blob/master/Releases/WWDC_latest.zip?raw=true).

You can also install using [Homebrew Cask](http://caskroom.io):

	$ brew cask install wwdc

![screenshot](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/screenshot.png)

## Download the entire session videos

To download every available session video of 2015, go to settings and klick the "Download All Videos" button.

## El Capitan support

Almost everything works fine on El Capitan, but live ~~sessions currently only play the audio, this seems to be a bug in AVFoundation and I'm currently trying to fix it~~. I've managed to get live streamed sessions working on El Capitan by using a custom player view, but I've not had the time to implement complete controls (volume, scrubbing, etc). 

## Searching

You can perform an advanced search using the qualifiers "year", "focus", "track", "downloaded" and "description".

Example searches:

	year:2013 focus:ios scroll

	year:2014 track:frameworks cocoa

	track:frameworks core
	
	year:2014 downloaded:yes
	
	description:iwork
	
## Sharing

You can share direct links to specific session videos. Just select the session on the list and ⌘C to copy It's URL, or use the right-click menu. For instance, [this link](wwdc://2014/101) opens up the 2014 keynote.

![rightmenushare](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/rightmenushare.png)

## Reading

WWDC for OS X is integrated with [ASCIIWWDC](http://asciiwwdc.com), so you can see and search through transcripts of the sessions while watching the videos.

![screenshot2](https://raw.githubusercontent.com/insidegui/WWDC/master/screenshots/screenshot2.png)

## Build Instructions

The only steps required before you build is to pull down the code and submodules:

	$ git clone --recursive https://github.com/insidegui/WWDC.git
