//
//  CalendarManager.swift
//  ExportToCalendar
//
//  Created by Bruno Henriques on 17/08/15.
//  Copyright (c) 2015 Bruno Henriques. All rights reserved.
//

import EventKit


protocol Calendarized {
    func toEKEvent(calendar: EKCalendar) -> EKEvent?
}


public class CalendarManager{
    public let eventStore = EKEventStore()
    public let calendarName: String
    
    private let sourceType: EKSourceType
    public var calendar: EKCalendar? {
        get {
        return eventStore.calendarsForEntityType(.Event).filter({$0.calendarIdentifier == calendarName}).first
        }
    }
    
    /**
        Init
    
        - parameter `String`::            name of the calendar
        - parameter `EKSourceType: opt`:  sourceType, by default is EKSourceTypeCalDav (iCloud)
    */
    public init(calendarName: String, sourceType: EKSourceType = .CalDAV){
        self.calendarName = calendarName
        self.sourceType = sourceType
    }
    
    /**
        Request access and execute block of code
        
        - parameter `completion:: (error: NSError?) -> ()` block of code
    */
    public func requestAuthorization(completion: () -> ()) throws{
        switch EKEventStore.authorizationStatusForEntityType(EKEntityType.Event) {
        case .Authorized:
            completion()
        case .Denied:
            throw getDeniedAccessToCalendarError()
        case .NotDetermined:
            var userAllowed = false
            eventStore.requestAccessToEntityType(.Event, completion: { (allowed, error) -> Void in
                userAllowed = !allowed
            })
            if(!userAllowed){
                throw self.getDeniedAccessToCalendarError()
            }
            
        default:
            throw getDeniedAccessToCalendarError()
        }
    }
    
    /**
        Add calendar
        
        - parameter `Bool: optional`: commit, default true
        - parameter `(wasSaved:: Bool, error: NSError?) -> () optional`: completion in main_queue, default nil
    */
    public func addCalendar(commit: Bool = true, completion: (() -> ())? = nil) throws {
        let newCalendar = EKCalendar(forEntityType: .Event, eventStore: eventStore)
        newCalendar.title = calendarName
        
        // defaultCalendarForNewEvents will always return a writtable source, even when there is no iCloud support.
        newCalendar.source = eventStore.defaultCalendarForNewEvents.source
        do {
            try eventStore.saveCalendar(newCalendar, commit: commit)
            completion?()
        } catch let error as NSError {
            throw EKErrorCode(rawValue: error.code) == .SourceDoesNotAllowCalendarAddDelete ? getDeniedAccessToCalendarError() : getGeneralError()
        }
    }
    
    /**
        Returns a new event attached to this calendar or nil if the calendar doesn't exist yet
        
        :return: `EKEvent?`
    */
    public func createEvent() -> EKEvent? {
        if let c = calendar {
            let event = EKEvent(eventStore: eventStore)
            event.calendar = c
            return event
        }
        
        return nil
    }
    
    /**
        Remove the event from the event store
        
        - parameter `String`:: eventId
        - parameter `Bool: optional`: commit, true
        - parameter `(wasRemoved:: Bool, error: NSError?)-> () optional`: completion block in main_queue, default nil
    */
    public func removeEvent(eventId: String, completion: (()-> ())? = nil) {
        if let e = getEvent(eventId){
            deleteEvent(e)
            completion?()
        }
    }
    
    /**
        Removes the calendar along with its events
        
        - parameter `Bool: optional`: commit, default true
        - parameter `(wasRemoved:: Bool, error: NSError?)-> () optional`: completion, default nil
    */
    public func removeCalendar(commit: Bool = true, completion: (()-> ())? = nil) throws {
        if let cal = calendar where EKEventStore.authorizationStatusForEntityType(EKEntityType.Event) == .Authorized {
            do {
                try eventStore.removeCalendar(cal, commit: true)
                completion?()
            } catch {
                throw getUnableToDeleteCalendarError()
            }
        }
    }
    
    /**
        Get events
        
        - parameter `NSDate`:: start date
        - parameter `NSDate`:: end date
        
        - returns: `(events: [EKEvent], error: NSError?)`
    */
    public func getEvents(startDate: NSDate, endDate: NSDate) throws -> [EKEvent]{
        if let c = calendar {
            let pred = eventStore.predicateForEventsWithStartDate(startDate, endDate: endDate, calendars: [c])
            
            return eventStore.eventsMatchingPredicate(pred)
        }
        
        throw getUnableToDeleteCalendarError()
    }
    
    /**
        Get event with id
        
        :return: `EKEvent?`: the event if exists
    */
    
    public func getEvent(eventId: String) -> EKEvent?{
        return eventStore.eventWithIdentifier(eventId)
    }
    
    
    /**
        Clear all events from the calendar. Commit is set to false
        
        - parameter `(error:: NSError?) -> () optional`: completion block in main_queue, default nil
    */
    public func clearEvents(completion: (() -> ())? = nil){
        if let c = calendar{
            let range = 63072000 as NSTimeInterval /* Two Years */
            let startDate = NSDate().dateByAddingTimeInterval(-range)
            let endDate = NSDate().dateByAddingTimeInterval(range)
            let predicate = eventStore.predicateForEventsWithStartDate(startDate, endDate: endDate, calendars: [c])
            
            eventStore.eventsMatchingPredicate(predicate).forEach(deleteEvent)
        }
        
        completion?()
    }
    
    private func deleteEvent(event: EKEvent) {
        do {
            try eventStore.removeEvent(event, span: .FutureEvents, commit: false)
        } catch _ {

        }
    }
    
    
    /**
        Insert new event in the calendar. Use createEvent method of don't forget to attach the intended calendar to the event
        
        - parameter `EKEvent`:: the event
        - parameter `Bool: optional`: commit, default true
        - parameter `(wasSaved:: Bool, error: NSError?)-> () optional`: completion block in main_queue, default nil
    */
    public func insertEvent(event: EKEvent, commit: Bool = true, completion: (() -> ())? = nil) throws {
        // Save Event in Calendar
        try eventStore.saveEvent(event, span: .ThisEvent, commit: commit)
    }
    
    /**
        Commit
        
        - returns: `NSError?`
    */
    public func commit() throws {
        try eventStore.commit()
    }
    
    /**
        Reset eventStore to latest saved state
    */
    public func reset(){
        eventStore.reset()
    }
}

extension CalendarManager {
    private func getErrorForDomain(domain: String, description: String, reason: String) -> NSError {
        let userInfo = [
            NSLocalizedDescriptionKey: description,
            NSLocalizedFailureReasonErrorKey: reason
        ]
        return NSError(domain: "CalendarNotFound", code: 999, userInfo: userInfo)
    }
    
    private func getGeneralError() -> NSError {
        return getErrorForDomain("CalendarError", description: "Unknown Error", reason: "An unknown error ocurred while trying to sync your calendar. Syncing will be turned off.")
    }
    
    private func getDeniedAccessToCalendarError() -> NSError {
        return getErrorForDomain("CalendarAuthorization", description: "Calendar access was denied", reason: "To continue syncing your calendars re-enable Calendar access for Técnico Lisboa in Settings->Privacy->Calendars.")
    }
    
    private func getRestrictedAccessToCalendarError() -> NSError {
        return getErrorForDomain("CalendarAuthorization", description: "Restricted access to calendar", reason: "Authorization was rejected. The app can't access the calendar service, possibily because of a parental control or enterprise setting being in place.")
    }
    
    private func getUnableToDeleteCalendarError() -> NSError {
        return getErrorForDomain("CalendarDeleteFailure", description: "Unable to delete the calendar.", reason: "Please remove it manually in the Calendar app.")
    }
    
    private func getDeniedAccessToCalendarAccountError(accountName: String) -> NSError {
        return getErrorForDomain("CalendarAuthorization", description: "Unable to create a new calendar.", reason: "Calendar access to your default account (\(accountName)) was rejected. Please use a different default account for Calendar events.")
    }
 }