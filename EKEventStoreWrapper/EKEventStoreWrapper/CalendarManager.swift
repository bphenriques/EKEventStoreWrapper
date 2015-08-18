//
//  CalendarManager.swift
//  ExportToCalendar
//
//  Created by Bruno Henriques on 17/08/15.
//  Copyright (c) 2015 Bruno Henriques. All rights reserved.
//

import EventKit


public class CalendarManager{
    public let eventStore = EKEventStore()
    public let calendarName: String
    
    private let sourceType: EKSourceType
    public var calendar: EKCalendar? {
        get {
            return (eventStore.calendarsForEntityType(EKEntityTypeEvent) as! [EKCalendar]).filter({$0.title == self.calendarName}).first
        }
    }
    
    /**
        Init
    
        :param: `String`:            name of the calendar
        :param: `EKSourceType opt`:  sourceType, by default is EKSourceTypeCalDav (iCloud)
    */
    public init(calendarName: String, sourceType: EKSourceType = EKSourceTypeCalDAV){
        self.calendarName = calendarName
        self.sourceType = sourceType
    }
    
    /**
        Request access and execute block of code
    
        :param: `completion: (error: NSError?) -> ()` block of code
    */
    public func requestAuthorization(completion: (error: NSError?) -> ()){
        switch EKEventStore.authorizationStatusForEntityType(EKEntityTypeEvent) {
        case .Authorized:
            completion(error: nil)
        case .Denied:
            completion(error: generateDeniedAccessToCalendarError())
        case .NotDetermined:
            eventStore.requestAccessToEntityType(EKEntityTypeEvent, completion: {[weak self] (granted: Bool, error: NSError!) -> Void in
                completion(error: granted ? nil : error)
                })
        default:
            completion(error: generateDeniedAccessToCalendarError())
        }
    }
    
    /**
        Add calendar
        
        :param: `Bool optional`: commit, default true
        :param: `(wasSaved: Bool, error: NSError?) -> () optional`: completion in main_queue, default nil
    */
    public func addCalendar(commit: Bool = true, completion: ((wasSaved: Bool, error: NSError?) -> ())? = nil) {
        let newCalendar = EKCalendar(forEntityType: EKEntityTypeEvent, eventStore: eventStore)
        newCalendar.title = calendarName
        
        // Filter the available sources and select the ones pretended. The instance MUST com from eventStore
        let sourcesInEventStore = eventStore.sources() as! [EKSource]
        newCalendar.source = sourcesInEventStore.filter { $0.sourceType.value == self.sourceType.value }.first
        
        var error: NSError? = nil
        let calendarWasSaved = eventStore.saveCalendar(newCalendar, commit: commit, error: &error)
        
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(wasSaved: calendarWasSaved, error: error)
        })
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
        
        :param: `String`: eventId
        :param: `Bool optional`: commit, true
        :param: `(wasRemoved: Bool, error: NSError?)-> () optional`: completion block in main_queue, default nil
    */
    public func removeEvent(eventId: String, commit: Bool = true, completion: ((wasRemoved: Bool, error: NSError?)-> ())? = nil){
        // Remove event from Calendar
        var error: NSError?
        let eventWasRemoved = eventStore.removeEvent(getEvent(eventId), span: EKSpanThisEvent, commit: commit, error: &error)
        
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(wasRemoved: eventWasRemoved, error: error)
        })
    }
    
    /**
        Removes the calendar along with its events
        
        :param: `Bool optional`: commit, default true
        :param: `(wasRemoved: Bool, error: NSError?)-> () optional`: completion block in main_queue, default nil
    */
    public func removeCalendar(commit: Bool = true, completion: ((wasRemoved: Bool, error: NSError?)-> ())? = nil){
        var error: NSError?
        let wasRemoved = eventStore.removeCalendar(calendar, commit: commit, error: &error)
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(wasRemoved: wasRemoved, error: error)
        })
    }
    
    /**
        Get events
        
        :param: `NSDate`: start date
        :param: `NSDate`: end date
        
        :returns: `(events: [EKEvent], error: NSError?)`
    */
    public func getEvents(startDate: NSDate, endDate: NSDate) -> (events: [EKEvent], error: NSError?){
        if let c = calendar {
            let pred = eventStore.predicateForEventsWithStartDate(startDate, endDate: endDate, calendars: [c])
            
            if let result = eventStore.eventsMatchingPredicate(pred) as? [EKEvent]{
                return (result, nil)
            }else {
                return ([], generateInvalidRangeError())
            }
        }
        
        return ([], generateErrorCalendarNotFoundError())
    }
    
    /**
        Get event with id
        
        :return: `EKEvent?`: the event if exists
    */
    
    public func getEvent(eventId: String) -> EKEvent?{
        return eventStore.eventWithIdentifier(eventId)
    }
    
    
    /**
        Clear all events from the calendar. Removes and then creates the calendar
        
        :param: `(error: NSError?) -> () optional`: completion block in main_queue, default nil
    */
    public func clearEvents(completion: ((error: NSError?) -> ())? = nil){
        removeCalendar(commit: true, completion: {(wasRemoved: Bool, error: NSError?) in
            if wasRemoved {
                self.addCalendar(completion: {(wasSaved: Bool, error: NSError?) in
                    dispatch_async(dispatch_get_main_queue(), { _ in
                        completion?(error: wasSaved ? nil : error)
                    })
                })
            }else {
                dispatch_async(dispatch_get_main_queue(), { _ in
                    completion?(error: wasRemoved ? nil : error)
                })
            }
        })
    }
    
    /**
        Insert new event in the calendar. Use createEvent method of don't forget to attach the intended calendar to the event
        
        :param: `EKEvent`: the event
        :param: `Bool optional`: commit, default true
        :param: `(wasSaved: Bool, error: NSError?)-> () optional`: completion block in main_queue, default nil
    */
    public func insertEvent(event: EKEvent, commit: Bool = true, completion: ((wasSaved: Bool, error: NSError?)-> ())? = nil) {
        // Save Event in Calendar
        var error: NSError?
        let eventWasSaved = eventStore.saveEvent(event, span: EKSpanThisEvent, commit: commit, error: &error)
        
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(wasSaved: eventWasSaved, error: error)
        })
    }
    
    /**
        Commit
    
        :returns: `NSError?`
    */
    public func commit() -> NSError?{
        var error: NSError?
        eventStore.commit(&error)
        
        return error
    }
    
    /**
        Reset eventStore to latest saved state
    */
    public func reset(){
        eventStore.reset()
    }
}

extension CalendarManager {
    private func generateErrorCalendarNotFoundError() -> NSError{
        let userInfo = [
            NSLocalizedDescriptionKey: "Calendar not found",
            NSLocalizedFailureReasonErrorKey: "Calendar not found",
            NSLocalizedRecoverySuggestionErrorKey: "Add calendar before adding events"
        ]
        
        return NSError(domain: "CalendarNotFound", code: 667, userInfo: userInfo)
    }
    
    private func generateDeniedAccessToCalendarError() -> NSError{
        let userInfo = [
            NSLocalizedDescriptionKey: "Denied access to calendar",
            NSLocalizedFailureReasonErrorKey: "Authorization was rejected",
            NSLocalizedRecoverySuggestionErrorKey: "Try accepting authorization"
        ]
        return NSError(domain: "CalendarAuthorization", code: 666, userInfo: userInfo)
    }
    
    private func generateInvalidRangeError() -> NSError{
        let userInfo = [
            NSLocalizedDescriptionKey: "Invalid range",
            NSLocalizedFailureReasonErrorKey: "Error generating predicate",
            NSLocalizedRecoverySuggestionErrorKey: "Use a shorter range (e.g. 4 years)"
        ]
        return NSError(domain: "CalendarFetchError", code: 668, userInfo: userInfo)
    }
}