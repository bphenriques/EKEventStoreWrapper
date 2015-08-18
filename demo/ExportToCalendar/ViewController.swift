import UIKit
import EventKit
import EKEventStoreWrapper

class ViewController: UIViewController {

    @IBOutlet weak var calendarName: UIButton!
    @IBOutlet weak var createEvent: UIButton!
    @IBOutlet weak var clearEvents: UIButton!
    @IBOutlet weak var eventsTable: UITableView!
    
    let CalendarTitle = "CalendarTest"
    
    var calendarManager: CalendarManager!
    var events = [EKEvent]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        calendarManager = CalendarManager(calendarName: CalendarTitle)
        
    }
    
    private func refreshButtons() {
        if let c = calendarManager.calendar{
            calendarName.setTitle(CalendarTitle, forState: .Normal)
            createEvent.hidden = false
            clearEvents.hidden = false
        }else {
            calendarName.setTitle("Create \(CalendarTitle)", forState: .Normal)
            createEvent.hidden = true
            clearEvents.hidden = true
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refreshButtons()
        refreshEvents()
    }
    
    @IBAction func calendarNameHandler(sender: AnyObject){
        if let calendar = calendarManager.calendar {
            let alert = UIAlertController(title: DeleteCalendarAlertText.title, message: DeleteCalendarAlertText.message, preferredStyle: .Alert)
            let OKAction = UIAlertAction(title: AlertActions.yes, style: .Destructive, handler: { _ in
                self.removeCalendar()
                self.refreshEvents()
            })
            alert.addAction(OKAction)

            let CancelAction = UIAlertAction(title: AlertActions.no, style: .Cancel, handler: nil)
            alert.addAction(CancelAction)

            self.presentViewController(alert, animated: true, completion: nil)
        }else {
            createCalendar()
        }
    }
    
    @IBAction func deleteAllEvents(sender: AnyObject) {
        clearCalendarEvents()
    }
    
    @IBAction func createRandomEvent(sender: AnyObject) {
        insertEvent()
    }
}

extension ViewController: UITableViewDataSource {
 
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let event = events[indexPath.row]
        
        let cell = tableView.dequeueReusableCellWithIdentifier("eventCell") as! UITableViewCell
        cell.textLabel?.text = event.title
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = "dd-MMMM-yyyy hh:mm"
        
        cell.detailTextLabel?.text = event.allDay ? "All day" : formatter.stringFromDate(event.startDate) + " -> " + formatter.stringFromDate(event.endDate)
        
        return cell
    }
    
}

extension ViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            self.calendarManager.requestAuthorization() {(error: NSError?) in
                if let theError = error {
                    println("Authorization denied due to: \(theError.localizedDescription)")
                    UIApplication.sharedApplication().openURL(NSURL(string:UIApplicationOpenSettingsURLString)!)
                }else {
                    let event = self.events[indexPath.row]
                    self.calendarManager.removeEvent(event.eventIdentifier) {(wasRemoved: Bool, error: NSError?) in
                        if wasRemoved {
                            self.refreshEvents()
                        }else {
                            println("Coudn't remove event because \(error?.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

extension ViewController {
    
    private func refreshEvents() {
        self.calendarManager.requestAuthorization() {(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                self.openSettings()
            }else {
                let today = NSDate()
                let twoYears = Double(2 * 366 * 24 * 60 * 60)
                let start = today.dateByAddingTimeInterval(-twoYears)
                let end = today.dateByAddingTimeInterval(twoYears)
                
                let result = self.calendarManager.getEvents(start, endDate: end)
                
                self.events = result.events
                self.eventsTable.reloadData()
                
                if let error = result.error {
                    println(error.localizedDescription)
                }
            }
        }
    }
    
    private func removeCalendar(){
        self.calendarManager.requestAuthorization() {(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                self.openSettings()
            }else {
                self.calendarManager.removeCalendar() {(wasRemoved: Bool, error: NSError?) in
                    if wasRemoved {
                        println("Sucess Removing calendar!")
                        self.refreshEvents()
                        self.refreshButtons()
                    } else {
                        println("Error deleting calendar because \(error?.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func createCalendar(){
        calendarManager.requestAuthorization() {(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                self.openSettings()
            }else {
                self.calendarManager.addCalendar() {(wasSaved: Bool, error: NSError?) in
                    if wasSaved {
                        println("Success creating calendar")
                        self.refreshButtons()
                    }else {
                        if let theError = error {
                            println("Wasn't able to create calendar because: \(theError.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func insertEvent() {
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
    }
    
    private func clearCalendarEvents(){
        calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                self.openSettings()
            } else {
                self.calendarManager.clearEvents() {(error: NSError?) in
                    if let theError = error {
                        println("Error deleting all events because \(theError.localizedDescription)")
                    }else {
                        self.refreshEvents()
                    }
                }
            }
        })
    }
}

extension ViewController {
    private func openSettings() {
        let alert = UIAlertController(title: NoAccessAlertText.title, message: NoAccessAlertText.message, preferredStyle: .Alert)
        let yes = UIAlertAction(title: AlertActions.yes, style: .Default, handler: { _ in
            UIApplication.sharedApplication().openURL(NSURL(string:UIApplicationOpenSettingsURLString)!)
        })
        alert.addAction(yes)
        
        let no = UIAlertAction(title: AlertActions.no, style: .Cancel, handler: nil)
        alert.addAction(no)
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

extension ViewController{
    typealias AlertText = (title: String, message: String)
    
    private var NoAccessAlertText: AlertText {get {
        return ("The app doesn't have access to calendar", "Do you want to open the settings?")
    }}
    
    private var DeleteCalendarAlertText: AlertText {get {
        return ("Do you want to delete the calendar?", "")
    }}
    
    private var AlertActions: (yes: String, no: String){get {
        return ("Yes", "No")
    }}

}