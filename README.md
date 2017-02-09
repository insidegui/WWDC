If you want to support my open source projects financially, you can do so by purchasing a copy of [BrowserFreedom](https://getbrowserfreedom.com), [Mediunic](https://itunes.apple.com/app/mediunic-medium-client/id1088945121?mt=12) or sending Bitcoin to `3DH9B42m6k2A89hy1Diz3Vr3cpDNQTQCbJ` 😁

**IMPORTANT: [Development of the next version is happening in the Version 5 branch, I will not accept pull requests to master until version5 is merged](https://github.com/insidegui/WWDC/tree/version5)**

# The unofficial WWDC app for macOS

This is the unofficial WWDC app for macOS.

Use this app to watch WWDC sessions on your Mac and do much more. Keep reading...

**⬇️ [Click here to download the latest release](https://raw.githubusercontent.com/insidegui/WWDC/master/Releases/WWDC_latest.zip) ⬇️**

**Requires macOS 10.11 or later**

## Schedule, Live Streaming and Videos

The app shows the schedule for the current WWDC and videos for the past events.

Please note that since this app is focused on videos, the schedule only shows sessions which will be live streamed, not labs and other events.

When sessions are live, a "live" indicator appears on the list and a "Watch Live" button becomes available:

![Schedule Screenshot](screenshots/screenshot-schedule.png)

## Controlling playback speed

You can cycle through playback speeds by pressing `⌘⇧R` or by option-clicking on the skip forward arrows when the video is playing.

## Searching

The app has a powerful search feature. When you first launch the app, it indexes the videos database and downloads transcripts from ASCIIWWDC, so when you search, not only will you get search results from session titles and descriptions, but also from what the presenter said in the sessions.

The app even shows a list of phrases matching your search so you can jump right to the point in the session where your searched word/phrase appears.

![Transcript Search](screenshots/transcriptsearch.png)

With the handy filter bar you can filter sessions by year, track and focus, and also filter to show only favorited or downloaded sessions.

![Transcript Search](screenshots/filterbar.png)
	
## Sharing

You can share direct links to specific session videos. Just select the session on the list and ⌘C to copy it's URL, or use the right-click menu.

![rightmenushare](screenshots/rightmenushare.png)

## Reading

WWDC for macOS is integrated with [ASCIIWWDC](http://asciiwwdc.com), so you can see and search through transcripts of the sessions while watching the videos.

![screenshot2](screenshots/screenshot2.png)

## Contributing

Please check out the [contribution guidelines](CONTRIBUTING.md) and [roadmap](ROADMAP.md) before contributing.

The app is currently implemented in Swift 3 (conversion done on December 2016). The architecture is not very nice, since I started working on this when I had just started to use Swift, it could be a lot more "swifty".

## Build Instructions

**Pre-requisites:**

- macOS 10.12
- Xcode 8.1
- [CocoaPods](https://cocoapods.org)

Clone the repository:

	$ git clone --recursive https://github.com/insidegui/WWDC.git

Install dependencies:

	$ pod install

### Cask

You can also install using [Homebrew Cask](http://caskroom.io):

	$ brew cask install wwdc

