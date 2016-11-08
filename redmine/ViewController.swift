//
//  ViewController.swift
//  Redmine
//
//  Created by Geiser on 25/04/16.
//  Copyright © 2016 Geiser. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    let API_KEY = "8bdcbfea88969d9fe715a77dc177137b55f335cd"
    let USER_ID = "60"
    let LIMIT = 100
    let HOURS_PER_DAY = 5
    
    var processing = false

    @IBOutlet weak var startDate: NSDatePicker!
    @IBOutlet weak var endDate: NSDatePicker!
    @IBOutlet weak var goButton: NSButton!
    @IBOutlet weak var totalProgress: NSProgressIndicator!
    @IBOutlet weak var hoursProgress: NSProgressIndicator!
    @IBOutlet weak var total1Label: NSTextField!
    @IBOutlet weak var total2Label: NSTextField!
    @IBOutlet weak var hoursLabel: NSTextField!
    @IBOutlet weak var usdLabel: NSTextField!
    @IBOutlet weak var brlLabel: NSTextField!
    @IBOutlet weak var usdPerHourField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var start = Date()
        var end = Date()
        
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.day , .month , .year], from: Date())
        
        if(components.day! <= 15) {
            start = firstDayOfMonth()
            end = addDays(start, days: 14)
        }
        else {
            start = addDays(firstDayOfMonth(), days: 15);
            end = lastDayOfMonth()
        }
        
        startDate.dateValue = start
        endDate.dateValue = end
        usdPerHourField.intValue = 19
        total1Label.stringValue = "0h"
        total2Label.stringValue = "0h"
        hoursLabel.stringValue = "0h"
        usdLabel.stringValue = "0 USD";
        brlLabel.stringValue = "0 BRL";
    }

    @IBAction func stepProgress(_ sender: AnyObject) {
        
        self.processing = true
        
        let button = sender as! NSButton
        let oldTitle = button.title
        
        button.title = "Processing..."
        button.isEnabled = false
        
        let url : String = createRedmineURL(startDate.dateValue, end: endDate.dateValue, offset: 0)!
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            
            var totalHours : Double = 0;
            
            do {
                let json = self.convertStringToDictionary(data!)
                for entry in json!["time_entries"] as! [Dictionary<String, AnyObject>] {
                    totalHours += entry["hours"] as! Double
                }
            }
            
            let totalWorkdays = self.calculateWorkdays(self.startDate.dateValue, to: self.endDate.dateValue)
            
            var today = Date()
            if(today.compare(self.endDate.dateValue).rawValue > 0) {
                today = self.endDate.dateValue
            }
            
            let currentWorkdays = self.calculateWorkdays(self.startDate.dateValue, to: today)
            
            self.hoursLabel.stringValue = String(totalHours) + "h"
            self.hoursProgress.doubleValue = (totalHours / Double.init(totalWorkdays * self.HOURS_PER_DAY)) * 100
            self.total1Label.stringValue = String(currentWorkdays * self.HOURS_PER_DAY) + "h"
            self.total2Label.stringValue = String(totalWorkdays * self.HOURS_PER_DAY) + "h"
            self.totalProgress.doubleValue = (Double.init(currentWorkdays) / Double.init(totalWorkdays)) * 100
            
            self.calcXoom(totalHours * self.usdPerHourField.doubleValue, button: button, oldTitle: oldTitle )
            
            CATransaction.commit()
            
        }) .resume()

    }
    
    func addDays(_ date: Date, days: Double) -> Date {
        return date.addingTimeInterval(days * 24 * 60 * 60)
    }
    
    func firstDayOfMonth() -> Date {
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components([.year, .month], from: Date())
        return calendar.date(from: components)!
    }
    
    func lastDayOfMonth() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.month = 1
        components.day = -1
        return (calendar as NSCalendar).date(byAdding: components, to: firstDayOfMonth(), options: [])!
    }
    
    func createRedmineURL(_ start: Date, end: Date, offset: Int) -> String? {
        
        // create "http://onerhino-apps.sourcerepo.com/redmine/onerhino/time_entries.json?key=$key&f[]=spent_on&op[spent_on]=><&v[spent_on][]=$from_date&v[spent_on][]=$to_date&f[]=user_id&op[user_id]==&v[user_id][]=$user_id&limit=$max&offset=$offset" URL using NSURLComponents
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https";
        urlComponents.host = "onerhino-apps.sourcerepo.com";
        urlComponents.path = "/redmine/onerhino/time_entries.json";
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // add params
        let keyQuery = URLQueryItem(name: "key", value: API_KEY)
        let fSpentOnQuery = URLQueryItem(name: "f[]", value: "spent_on")
        let opSpentOnQuery = URLQueryItem(name: "op[spent_on]", value: "><")
        let vSpentOn1Query = URLQueryItem(name: "v[spent_on][]", value: formatter.string(from: start))
        let vSpentOn2Query = URLQueryItem(name: "v[spent_on][]", value: formatter.string(from: end))
        let fUserIdQuery = URLQueryItem(name: "f[]", value: "user_id")
        let opUserIdQuery = URLQueryItem(name: "op[user_id]", value: "=")
        let vUserIdQuery = URLQueryItem(name: "v[user_id][]", value: USER_ID)
        let limitQuery = URLQueryItem(name: "limit", value: String(LIMIT))
        let offsetQuery = URLQueryItem(name: "offset", value: String(offset))
        urlComponents.queryItems = [keyQuery, fSpentOnQuery,opSpentOnQuery,vSpentOn1Query,vSpentOn2Query,fUserIdQuery,opUserIdQuery,vUserIdQuery,limitQuery,offsetQuery]
        
        return urlComponents.url?.absoluteString
    }
    
    func convertStringToDictionary(_ data: Data) -> [String:AnyObject]? {
        let text = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        if let data = text!.data(using: String.Encoding.utf8.rawValue) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }
    
    func calculateWorkdays(_ from: Date, to: Date ) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.startOfDay(for: to)
        var dates = [start]
        var currentDate = start
        repeat {
            currentDate = (cal as NSCalendar).date(byAdding: NSCalendar.Unit.day, value: 1, to: currentDate, options: .matchNextTime)!
            dates.append(currentDate)
        } while !cal.isDate(currentDate, inSameDayAs: end)
        
        let weekdays = dates.filter { !cal.isDateInWeekend($0) }
        return weekdays.count
    }
    
    func calcXoom(_ amount: Double, button: NSButton, oldTitle: String) {
     
        var urlComponents = URLComponents()
        urlComponents.scheme = "https";
        urlComponents.host = "www.xoom.com";
        urlComponents.path = "/ajax/options-xfer-amount-ajax";
        
        // add params
        let receiveCountryCodeQuery = URLQueryItem(name: "receiveCountryCode", value: "BR")
        let sendAmountQuery = URLQueryItem(name: "sendAmount", value: String.init(amount))
        
        urlComponents.queryItems = [receiveCountryCodeQuery, sendAmountQuery]
        
        let request : NSMutableURLRequest = NSMutableURLRequest()
        
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.86 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        request.url = urlComponents.url
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            
            var brlValue : Double = 0;
            
            do {
                let json = self.convertStringToDictionary(data!)
                let elements = json!["result"]
                let val = elements!["receiveAmountLocal"]
                
                brlValue = Double.init(String.init(val! as! String))!
                
            }
            
            self.usdLabel.stringValue = String.init(amount) + " USD"
            self.brlLabel.stringValue = String.init(brlValue) + " BRL"
            
            
            button.title = oldTitle
            button.isEnabled = true
            
            self.processing = false
            
            CATransaction.commit()
            
            
        }) .resume()
        
    }

}

