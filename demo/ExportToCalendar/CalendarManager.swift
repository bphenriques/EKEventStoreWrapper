//
//  CalendarManager.swift
//  ExportToCalendar
//
//  Created by Bruno Henriques on 17/08/15.
//  Copyright (c) 2015 Bruno Henriques. All rights reserved.
//

import Foundation
import UIKit
import EventKit


public class CalendarManager{
    public let eventStore = EKEventStore()
    public let calendarName: String
    
    public var calendar: EKCalendar? {
        get {
            let calendars = eventStore.calendarsForEntityType(EKEntityTypeEvent) as! [EKCalendar]
            for c in calendars {
                if c.title == calendarName {
                    return c
                }
            }
            
            println("Calendar not found, did you created?")
            return nil
        }
    }
    private let sourceType: EKSourceType
    
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
        ---
    */
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
    
    /**
        ---
    */
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
    
    /**
    ---
    */
    public func createEvent() -> EKEvent{
        return EKEvent(eventStore: eventStore)
    }
    
    /**
    ---
    */
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
    
    /**
    ---
    */
    public func removeCalendar(commit: Bool = true, completion: ((wasRemoved: Bool, error: NSError?)-> ())? = nil){
        var error: NSError?
        let wasRemoved = eventStore.removeCalendar(calendar, commit: commit, error: &error)
        completion?(wasRemoved: wasRemoved, error: error)
    }
    
    public func getEvents(predicate: NSPredicate? = nil) -> [EKEvent]{
        if let c = calendar {
            
            if let pred = predicate{
                return eventStore.eventsMatchingPredicate(predicate) as! [EKEvent]
            }
            
            //predicate is nil if using -infinity and +infinity
            let twoYears = Double(2 * 366 * 24 * 60 * 60)
            let startDate = NSDate().dateByAddingTimeInterval(-twoYears)
            let endDate = NSDate().dateByAddingTimeInterval(twoYears)
            let pred = eventStore.predicateForEventsWithStartDate(startDate, endDate: endDate, calendars: [c])
            
            return eventStore.eventsMatchingPredicate(pred) as? [EKEvent] ?? []
        }
        
        println("Calendar wasn't added yet")
        
        return []
    }
    
    public func removeEvents(completion: ((error: NSError?) -> ())?){
        for event in getEvents() {
            var error: NSError?
            eventStore.removeEvent(event, span: EKSpanThisEvent, error: &error)
        
            if error != nil {
                dispatch_async(dispatch_get_main_queue(), { _ in
                    completion?(error: error)
                })
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), { _ in
            completion?(error: nil)
        })
    }

    /**
    ---
    */
    public func insertEvent(event: EKEvent, completion: ((wasSaved: Bool, error: NSError?)-> ())? = nil) {
        if let c = calendar{
            event.calendar = calendar
            
            // Save Event in Calendar
            var error: NSError?
            let eventWasSaved = eventStore.saveEvent(event, span: EKSpanThisEvent, error: &error)
            
            
            dispatch_async(dispatch_get_main_queue(), { _ in
                completion?(wasSaved: eventWasSaved, error: error)
            })
        }else {
            println("Calendar not found")
        }
    }
}