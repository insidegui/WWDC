# The unofficial WWDC app for macOS

Enjoy WWDC from the comfort of your Mac with the unofficial WWDC app for macOS. Whether you're (virtually) attending or not, you can access livestreams, videos and sessions during the conference and as a year-round resource.

In partnership with CocoaHub, you can also use the app's Community tab to browse through Apple announcements, updates to the Swift language, new episodes from your favorite podcasts, community blog posts, and more.

⬇️ If you just want to download the latest release, go to [the website](https://wwdc.io).

## Schedule

The schedule tab shows the schedule for the current edition of WWDC, and allows you to watch live streams for the Keynote and other sessions throughout the week.

## Videos

Watch this year's videos as they're released and access videos from previous years. You can also read transcripts of sessions and easily jump to a specific point in the relevant video. Transcripts are also searchable and available in

![videos](./screenshots/v7/Transcript.png)

### Video features

- Watch videos in 0.5x, 1x, 1.25x, 1.5x, 1.75x or 2x speeds
- Fullscreen and native picture-in-picture support
- Navigate video contents easily with the help of transcripts

### Clip Sharing

Clip Sharing allows you to share a short segment (up to 5 minutes) from a session's video. This is a great feature for quickly sharing snippets of content from the conference.

![clipsharing](./screenshots/v7/ClipSharing.png)

## Chromecast

You can watch WWDC videos (both live and on-demand) on your Chromecast. Just click the Chromecast button while playing a video, choose your device from the list and control playback using the Google Home app on your phone.

![chromecast](./screenshots/v7/ChromeCast.png)

## Bookmarks

Have you ever found yourself watching a WWDC session and wishing you could take notes at a specific point in the video to refer back to later on? This is now possible with bookmarks.

With bookmarks, you can create a reference point within a video and add an annotation to it. Your bookmark annotations can also be considered while using the search, so it's easier than ever to find the content you've bookmarked before.

![bookmarks](./screenshots/v7/Video-Bookmark.png)

## Community

Browse content curated by the [CocoaHub](http://cocoahub.app) team in the Community tab.

![community](./screenshots/v7/Community.png)

## iCloud Sync

Enable the iCloud sync in preferences and your favorites, bookmarks and progress in sessions will be synced accross your Macs.

## Sharing

You can easily share links to sessions or videos by using the share button. The links shared are universal links that redirect to Apple's developer website, so if they're opened on a Mac which has the app installed, they will open in the app. The links are also compatible with iOS devices using the Apple Developer app.

## Nerdy bits 🤓

### Code of Conduct
We expect all of our contributors to help uphold the values set out in our [code of conduct](./CODE_OF_CONDUCT.md). We fundamentally believe this will help us build a better community, and with it a better app.

### Contributing

Please read the [contribution guidelines](CONTRIBUTING.md) before opening an issue or pull request.

### External libraries

A number of third-party libraries are used by the app:

- [Realm](https://realm.io): data storage and caching
- [Sparkle](https://sparkle-project.org/): automatic updates
- [CloudKitCodable](https://github.com/insidegui/CloudKitCodable): sync support
- [Siesta](http://bustoutsolutions.github.io/siesta/): networking
- [RxSwift](https://github.com/ReactiveX/RxSwift): reactive extensions
- [RxRealm](https://github.com/RxSwiftCommunity/RxRealm): reactive extensions for Realm

### Internal libraries

- **ConfCore** is the core of the app that deals with Apple's WWDC API, data storage, caching, syncing and transcripts (everything that has to do with data, basically)
- **ConfUIFoundation** contains shared color, font definitions and other useful extensions used by the main app target and `PlayerUI`
- **PlayerUI** contains the UI components for the video player and some general-purpose UI components used throughout the app
- **ThrowBack** provides support for migration of user data and preferences from old versions of the app

## Building the app

**Building requires Xcode 11.5 or later.**

Building the app requires [Carthage](https://github.com/Carthage/Carthage) to be installed.

**Clone this branch and before opening the project, run `./bootstrap.sh`** to fetch the dependencies (this script can take a while to run, that's normal).

Since the app uses CloudKit, when you build it yourself, all of the CloudKit-dependant functionality will not be available. CloudKit requires a provisioning profile and a paid developer account.

To build the app yourself without the need for a developer account and a CloudKit container, **always use the `WWDC` target when building**. The `WWDC with iCloud` target requires a paid developer account and a CloudKit container, which you won't be able to create because of the app's bundle identifier.

![schedule](./screenshots/v7/BuildTarget.png)

### Clearing app data during development

If you need to clear the app's preferences and stored data during development, you can run `./cleardata.sh` in the project folder. **This will delete all of your preferences and data like favorites, bookmarks and progress in videos, so be careful**.
