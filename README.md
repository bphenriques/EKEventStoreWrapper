#### Warning: Use tag 0.9.12. As of last tag, the code is being re-done from scratch for the best of mankind! Sorry for the inconvinience. In retrospective, I could have done better :)

___

# EKEventStoreWrapper
EKEventStoreWrapper

The goal is to simplify EKEventStore usage:
```swift

let calendarManager = CalendarManager(calendarName: "CalendarTest")

calendarManager.requestAuthorization({(error: NSError?) in
    if let theError = error {
        println("Authorization denied due to: \(theError.localizedDescription)")
        return
    }
            
    self.calendarManager.addCalendar(completion: {(wasSaved: Bool, error: NSError?) in
        if wasSaved {
            println("Success creating calendar")
        }else {
            if let theError = error {
                println("Wasn't able to create calendar because: \(theError.localizedDescription)")
            }
        }
    })
})

calendarManager.requestAuthorization() {(error: NSError?) in
    if let theError = error {
        println("Authorization denied due to: \(theError.localizedDescription)")
        self.openSettings()
    }else {
        if let event = self.calendarManager.createEvent() {
            event.title = "Meeting with Mr.\(Int(arc4random_uniform(2000)))"
            event.startDate = NSDate()
            event.endDate = event.startDate.dateByAddingTimeInterval(Double(arc4random_uniform(24)) * 60 * 60)
            
            //other options
            event.notes = "Don't forget to bring the meeting memos"
            event.location = "Room \(Int(arc4random_uniform(100)))"
            event.availability = EKEventAvailabilityFree
            
            self.calendarManager.insertEvent(event) {(wasSaved: Bool, error: NSError?) in
                if wasSaved {
                    self.refreshEvents()
                    println("Success adding event")
                }else {
                    if let theError = error {
                        println("Wasn't able to add event because: \(theError.localizedDescription)")
                    }
                }
            }
        }
    }
}

```

# Demo
A demo is included in the demo folder showing the developed features.

# Install
1 - In the Podfile:
```
pod 'EKEventStoreWrapper', :git => 'https://github.com/bphenriques/EKEventStoreWrapper.git', :tag => '0.9.8'
```
2 - Run
```
pod install
```

