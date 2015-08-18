# EKEventStoreWrapper
EKEventStoreWrapper

The goal is to sugarcoat the code when handling calendar:
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
```
