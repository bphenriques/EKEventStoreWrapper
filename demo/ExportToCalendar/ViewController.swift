import UIKit
import EventKit

public class CalendarManager{
    let eventStore = EKEventStore()
    let calendarName: String
    let sourceType: EKSourceType
    
    
    /**
        Init
        
        :param: `String`:            name of the calendar
        :param: `EKSourceType opt`:  sourceType, by default is EKSourceTypeCalDav (iCloud)
    */
    public init(calendarName: String, sourceType: EKSourceType = EKSourceTypeCalDAV){
        self.calendarName = calendarName
        self.sourceType = sourceType
    }
    
    public func requestAuthorization(completion: (error: NSError?) -> ()){
        switch EKEventStore.authorizationStatusForEntityType(EKEntityTypeEvent) {
        case .Authorized:
            println("Authorized access to calendar")
            completion(error: nil)
        case .Denied:
            println("Denied access to calendar")
            let userInfo = [
                NSLocalizedDescriptionKey: "Denied access to calendar",
                NSLocalizedFailureReasonErrorKey: "Authorization was rejected",
                NSLocalizedRecoverySuggestionErrorKey: "Try accepting authorization"
            ]
            completion(error: NSError(domain: "CalendarAuthorization", code: 666, userInfo: userInfo))
        case .NotDetermined:
            println("Requesting permission")
            eventStore.requestAccessToEntityType(EKEntityTypeEvent, completion: {[weak self] (granted: Bool, error: NSError!) -> Void in
                completion(error: granted ? nil : error)
            })
        default:
            println("default")
            let userInfo = [
                NSLocalizedDescriptionKey: "Default behaviour in authorization",
                NSLocalizedFailureReasonErrorKey: "We don't know",
                NSLocalizedRecoverySuggestionErrorKey: "Call 911"
            ]
            completion(error: NSError(domain: "CalendarAuthorization", code: 69, userInfo: userInfo))
        }
    }
    
    public func addCalendar(completion: ((wasSaved: Bool, error: NSError?) -> ())? = nil) {
        //create calendar
        let newCalendar = EKCalendar(forEntityType: EKEntityTypeEvent, eventStore: eventStore)
        newCalendar.title = calendarName
        
        // Access list of available sources from the Event Store
        let sourcesInEventStore = eventStore.sources() as! [EKSource]
        
        // Filter the available sources and select the ones pretended. The instance MUST com from eventStore
        newCalendar.source = sourcesInEventStore.filter { $0.sourceType.value == self.sourceType.value }.first
        
        // Save the calendar using the Event Store instance
        var error: NSError? = nil
        let calendarWasSaved = eventStore.saveCalendar(newCalendar, commit: true, error: &error)
        
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(wasSaved: calendarWasSaved, error: error)
        })
    }
    
    public func createEvent() -> EKEvent{
        return EKEvent(eventStore: eventStore)
    }
    
    public func removeEvent(eventId: String, completion: ((wasRemoved: Bool, error: NSError?)-> ())? = nil){
        let calendars = eventStore.calendarsForEntityType(EKEntityTypeEvent) as! [EKCalendar]
        
        // Remove event from Calendar
        let event = eventStore.eventWithIdentifier(eventId)
        var error: NSError?
        let eventWasRemoved = eventStore.removeEvent(event, span: EKSpanThisEvent, commit: true, error: &error)
        
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(wasRemoved: eventWasRemoved, error: error)
        })
    }
    
    public func removeCalendar(commit: Bool = true, completion: ((wasRemoved: Bool, error: NSError?)-> ())? = nil){
        let calendars = eventStore.calendarsForEntityType(EKEntityTypeEvent) as! [EKCalendar]
        let calendar = calendars.filter({ $0.title == self.calendarName }).first
        
        var error: NSError?
        let wasRemoved = eventStore.removeCalendar(calendar, commit: commit, error: &error)
    
        completion?(wasRemoved: wasRemoved, error: error)
    }
    
    public func insertEvent(event: EKEvent, completion: ((wasSaved: Bool, error: NSError?)-> ())? = nil) {
        let calendars = eventStore.calendarsForEntityType(EKEntityTypeEvent) as! [EKCalendar]
        
        for calendar in calendars {
            if calendar.title == calendarName {
                event.calendar = calendar
                
                // Save Event in Calendar
                var error: NSError?
                let eventWasSaved = eventStore.saveEvent(event, span: EKSpanThisEvent, error: &error)
                
                
                dispatch_async(dispatch_get_main_queue(), { _ in
                    completion?(wasSaved: eventWasSaved, error: error)
                })
                
                break
            }
        }
    }
}

// Handle situation if the calendar could not be saved
/*
if !calendarWasSaved {
    let alert = UIAlertController(title: "Calendar could not save", message: error?.localizedDescription, preferredStyle: .Alert)
    let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
    alert.addAction(OKAction)
    
    self.presentViewController(alert, animated: true, completion: nil)
} else {
    
    let alert = UIAlertController(title: "Calendar saved ", message: ":)", preferredStyle: .Alert)
    let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
    alert.addAction(OKAction)
    
    self.presentViewController(alert, animated: true, completion: nil)
    
    NSUserDefaults.standardUserDefaults().setObject(newCalendar.calendarIdentifier, forKey: "EventTrackerPrimaryCalendar")
}*/


class ViewController: UIViewController {

    let calendarManager = CalendarManager(calendarName: "CalendarTest")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
    }
    
    @IBAction func createRandomEvent(sender: AnyObject) {
        calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                return
            }
            let event = self.calendarManager.createEvent()
            event.title = "Reunião com o manel \(Int(arc4random_uniform(2000)))"
            event.startDate = NSDate()
            event.endDate = event.startDate.dateByAddingTimeInterval(Double(arc4random_uniform(24)) * 60 * 60)
            
            event.notes = "My cute note"
            event.location = "Paradise City"
            
            //event.addAlarm()
            //event.allDay = true
            event.availability = EKEventAvailabilityFree
            
            //If the calendar of an event changes, its identifier most likely changes as well.
            let id = event.eventIdentifier
            
            self.calendarManager.insertEvent(event, completion: {(wasSaved: Bool, error: NSError?) in
                if wasSaved {
                    println("Success adding event")
                }else {
                    if let theError = error {
                        println("Wasn't able to add event because: \(theError.localizedDescription)")
                    }
                }
            })
        })
    }
}

