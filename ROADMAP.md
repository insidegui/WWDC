# WWDC for macOS: roadmap

This document describes the current state of development and what has to be done for the next release.

## Next major update: WWDC 5.0

Main goals:

- Migrate to Swift 3
- Refactor
- Redesign
- New features
- Fix issues


### Migrate to Swift 3

With the introduction of macOS Sierra and Xcode 8, we now have Swift 3. Swift 3 changes a lot of stuff and our code should be migrated to it before macOS Sierra ships (october 2016, probably).

### Refactor

There are lots of issues with the way the app is structured right now and we should fix them:

##### Avoid using singletons

Singletons are usually bad, and this app has at least 3 of them.

##### Decouple UI from backend

Currently, the UI has to know about how the backend works. More specifically, it has to worry about Realm and it's threading and validation requirements, this has caused lots of bugs and crashes.

My intention is to completely abstract away the backend, it will download the information, store it locally and return the data in simple structs which can be used by the UI.

**Extra credit:** move all networking and parsing to a XPC process. This would improve stability and security, the XPC process can be sandboxed with permission to access the network and the database file. If there's something wrong with the data or the implementation, only the background process will crash and not the entire app.

##### Be more "swifty"

Adopt more modern ways of solving problems:

- Use `map`, `forEach` and others instead of for loops and enumeration
- Use value semantics whenever possible (structs and enums instead of classes)
- Use protocols instead of inheritance

##### Use RxSwift (or similar) to manage state

RxSwift is an awesome library and I've been using it on other projects, I think it really helps with state management, especially when binding model data to the UI.

### Redesign

Apple moved to a dark UI with the new version of their app, I think this app would also benefit from using a darker UI.

The schedule should be separated from the videos, this year I used the same list to present the schedule because I didn't have the time to design a better solution. I think we should use the same approach Apple uses on their app: separate it into different sections (schedule, news and videos).

The preferences window should also be redesigned to separate the preferences in different categories.

The downloads window should be moved into a popover since it doesn't make sense to keep it opened all the time.

### New features

**New features should only be implemented once we have completed all of the above.**

##### State restoration

Save state between launches, this will include the current search filters, current selected item, etc (as much as we can reasonably save and restore).

##### Implement `NSUserActivity` stuff

Use the `NSUserActivity` APIs to allow Siri integration on macOS and handoff between Macs (not as useful as iOS->Mac handoff but still useful).

##### Sync favorites and current progress between Macs

With the introduction of macOS Sierra, apps distributed outside the AppStore can now use iCloud and CloudKit, we should take advatage of that and sync user data, probably using iCloud Key Value Storage.

##### Bookmark specific points in sessions

Sometimes I'm watching a session and I know the current thing the presenter is saying will be useful to me in the future, so I'd like to be able to add a "bookmark" to the current point on the video so I can quickly get back to it later (maybe allow the user to add annotations, that would be cool).

## Fix issues

Close all open issues, many of them will be fixed by implementing the changes described above.