## WWDC for macOS - Version 5 overhaul

This branch contains the development of the new major version of WWDC for macOS.

This new version is pretty much a rewrite from the ground up, using what we have learned from creating the original app to make a better architected, more stable and more usable app :)

The development of this version is being coordinated in a Slack team, if you'd like to join, let me know and I'll send you an invitation.

### The Goal

The goal is to have this new version released before next WWDC (june 2017).

Steps:

- Redesign by [Vicente](https://github.com/vicenteborrell)
- Implement new backend and database layer
- Implement the new UI
- Fix initial bugs
- RELEASE =D


### Main features

#### Schedule
- List the schedule for the current/last event
- Let the user create reminders for the sessions/labs
- Stream live videos of the sessions when available

#### Videos
- List videos from all available WWDC editions
- Stream videos
- Download HD versions of the videos for offline watching (bonus: allow the user to choose to download SD versions of the videos)
- Show resources associated with sessions/videos (slides, links, etc)
- Show and search transcripts from ASCIIWWDC

#### News

Nothing special about this, just the news from the "news" tab on the iOS app :)

#### Bookmarks
This is a new feature, the user will be able to create bookmarks at specific points in videos and add notes associated with these bookmarks so they can search later, find their notes and quickly jump to the point in the video where the original note was created.

BONUS: make the bookmarks collaborative using CloudKit's sharing features or allow the user to mark bookmarks as public so other users of the app can see their bookmarks.

### Architecture

I want to use an architecture similar to what I used on my [Astronomer demo app](http://github.com/insidegui/Astronomer). I think this is the way to go to have a stable and performant app.

### Dependencies

Currently, these are the dependencies the app uses:

- Realm: data storage
- RxSwift: reactive extensions
- RxRealm: reactive extensions for Realm
- SwiftyJSON: for JSON parsing