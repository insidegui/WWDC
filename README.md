# The unofficial WWDC app for macOS

WWDC for macOS allows both attendees and non-attendees to access WWDC livestreams, videos and sessions during the conference and as a year-round resource.

⬇️ If you just want to download the latest release, go to [the website][1].

## Schedule

The schedule tab shows the schedule for the most recent WWDC, and allows you to watch live streams for the Keynote and other sessions throughout the week.

![schedule][image-1]

## Videos

Watch this year's videos as they're released and access videos from previous years. With [ASCIIWWDC][2] integration, you can also read transcripts of sessions and easily jump to a specific point in the relevant video.

![videos][image-2]

### Video features

- Watch videos in 0.5x, 1x, 1.5x or 2x speeds
- Fullscreen and native picture-in-picture support
- Navigate video contents easily with the help of transcripts

## Chromecast

You can watch WWDC videos (both live and on-demand) on your Chromecast. Just click the Chromecast button while playing a video, choose your device from the list and control playback using the Google Home app on your phone.

![chromecast][image-3]

## Bookmarks

Have you ever found yourself watching a WWDC session and wishing you could take notes at a specific point in the video to refer back to later on? This is now possible with bookmarks.

With bookmarks, you can create a reference point within a video and add an annotation to it. Your bookmark annotations can also be considered while using the search, so it's easier than ever to find the content you've bookmarked before.

![bookmarks][image-4]

## iCloud Sync

With version 6.0, you can try out our new iCloud sync feature. Enable the feature in preferences and your favorites, bookmarks and progress in sessions will be synced accross all your Macs.

## Sharing

You can easily share links to sessions or videos by using the share button. The links shared are for Apple's developer website, but the app can open these links if you drag them into the icon (or if you use [BrowserFreedom][3]).

## Nerdy bits 🤓

### Code of Conduct
We expect all of our contributors to help uphold the values set out in our [code of conduct][4]. We fundamentally believe this will help us build a better community, and with it a better app.

### Contributing

Please read the [contribution guidelines][5] before opening an issue or pull request.

### External libraries

A number of third-party libraries are used by the app:

- [Realm][6]: data storage and caching
- [Sparkle][7]: automatic updates
- [CloudKitCodable][8]: sync support
- [Fabric][9]: crash reporting and error logging
- [Siesta][10]: networking
- [RxSwift][11]: reactive extensions
- [RxRealm][12]: reactive extensions for Realm

### Internal libraries

- **ConfCore** is the core of the app that deals with Apple's WWDC API, data storage, caching, syncing and transcripts (everything that has to do with data, basically)
- **PlayerUI** contains the UI components for the video player and some general-purpose UI components used throughout the app
- **ThrowBack** provides support for migration of user data and preferences from old versions of the app

## Building the app

**Building requires Xcode 10.2 or later.**

Building the app requires [Carthage][13] to be installed.

**Clone this branch and before opening the project, run `./bootstrap.sh`** to fetch the dependencies (this script can take a while to run, that's normal).

Since the app uses CloudKit, when you build it yourself, all of the CloudKit-dependant functionality will not be available. CloudKit requires a provisioning profile and a paid developer account.

To build the app yourself without the need for a developer account and a CloudKit container, **always use the `WWDC` target when building**. The `WWDC with iCloud` target requires a paid developer account and a CloudKit container, which you won't be able to create because of the app's bundle identifier.

![schedule][image-5]

### Clearing app data during development

If you need to clear the app's preferences and stored data during development, you can run `./cleardata.sh` in the project folder. **This will delete all of your preferences and data like favorites, bookmarks and progress in videos, so be careful**.

[1]:	https://wwdc.io
[2]:	http://asciiwwdc.com
[3]:	https://getbrowserfreedom.com
[4]:	./CODE_OF_CONDUCT.md
[5]:	CONTRIBUTING.md
[6]:	https://realm.io
[7]:	https://sparkle-project.org/
[8]:	https://github.com/insidegui/CloudKitCodable
[9]:	https://fabric.io
[10]:	http://bustoutsolutions.github.io/siesta/
[11]:	https://github.com/ReactiveX/RxSwift
[12]:	https://github.com/RxSwiftCommunity/RxRealm
[13]:	https://github.com/Carthage/Carthage

[image-1]:	./screenshots/v5/Schedule.png
[image-2]:	./screenshots/v5/Transcript.png
[image-3]:	./screenshots/v5/ChromeCast.png
[image-4]:	./screenshots/v5/Video-Bookmark.png
[image-5]:	./screenshots/v5/BuildTarget.png