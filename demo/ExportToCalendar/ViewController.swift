import UIKit
import EventKit


class ViewController: UIViewController {

    @IBOutlet weak var calendarName: UIButton!
    @IBOutlet weak var eventsTable: UITableView!
    
    let CalendarTitle = "CalendarTest"
    
    var calendarManager: CalendarManager!
    var createdEvents = [EKEvent]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        calendarManager = CalendarManager(calendarName: CalendarTitle)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.refreshEvents()
    }
    
    @IBAction func calendarNameHandler(sender: AnyObject){
        if let calendar = calendarManager.calendar {
            let alert = UIAlertController(title: "Do you want to delete the calendar?", message: "", preferredStyle: .Alert)
            let OKAction = UIAlertAction(title: "Yes", style: .Destructive, handler: { _ in
                self.removeCalendar()
                self.refreshEvents()
            })
            alert.addAction(OKAction)

            let CancelAction = UIAlertAction(title: "No", style: .Cancel, handler: nil)
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
        createEvent()
    }
}

extension ViewController: UITableViewDataSource {
 
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return createdEvents.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let event = createdEvents[indexPath.row]
        
        let cell = tableView.dequeueReusableCellWithIdentifier("eventCell") as! UITableViewCell
        cell.textLabel?.text = event.title
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = "dd-MMMM-yyyy hh:mm"
        
        cell.detailTextLabel?.text = event.allDay ? "All day" : formatter.stringFromDate(event.startDate) + " -> " + formatter.stringFromDate(event.endDate)
        
        return cell
    }
    
}

extension ViewController: UITableViewDelegate {
    
}

extension ViewController {
    
    private func refreshEvents() {
        self.calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                return
            }
            
            self.createdEvents = self.calendarManager.getEvents()
            self.eventsTable.reloadData()
        })
    }
    
    private func removeCalendar(){
        self.calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                return
            }
            
            self.calendarManager.removeCalendar(completion: {(wasRemoved: Bool, error: NSError?) in
                if wasRemoved {
                    println("Sucess Removing calendar!")
                    self.eventsTable.reloadData()
                } else {
                    println("Error deleting calendar because")
                }
            })
        })
    }
    
    private func createCalendar(){
        calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                return
            }
            
            self.calendarManager.addCalendar(completion: {(wasSaved: Bool, error: NSError?) in
                if wasSaved {
                    println("Success creating calendar")
                    self.calendarName.setTitle(self.CalendarTitle, forState: UIControlState.Normal)
                    self.calendarName.enabled = false
                }else {
                    if let theError = error {
                        println("Wasn't able to create calendar because: \(theError.localizedDescription)")
                    }
                }
            })
        })
    }
    
    private func createEvent() {
        calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                return
            }
            
            let event = self.calendarManager.createEvent()
            event.title = "Meeting with Mr.\(Int(arc4random_uniform(2000)))"
            event.startDate = NSDate()
            event.endDate = event.startDate.dateByAddingTimeInterval(Double(arc4random_uniform(24)) * 60 * 60)
            
            //other options
            event.notes = "Don't forget to bring his money"
            event.location = "Room \(Int(arc4random_uniform(100)))"
            //event.addAlarm()
            //event.allDay = true
            event.availability = EKEventAvailabilityFree
            
            
            //From docs: If the calendar of an event changes, its identifier most likely changes as well.
            let id = event.eventIdentifier
            
            self.calendarManager.insertEvent(event, completion: {(wasSaved: Bool, error: NSError?) in
                if wasSaved {
                    self.createdEvents.append(event)
                    self.eventsTable.reloadData()
                    println("Success adding event")
                }else {
                    if let theError = error {
                        println("Wasn't able to add event because: \(theError.localizedDescription)")
                    }
                }
            })
        })
    }
    
    private func clearCalendarEvents(){
        calendarManager.requestAuthorization({(error: NSError?) in
            if let theError = error {
                println("Authorization denied due to: \(theError.localizedDescription)")
                return
            }
            
            self.calendarManager.removeEvents({(error: NSError?) in
                if let theError = error {
                    println("Error deleting all events because \(theError.localizedDescription)")
                }else {
                    self.eventsTable.reloadData()
                }
            })
        })
    }
}