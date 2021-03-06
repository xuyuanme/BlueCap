//
//  BeaconRegionsViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 9/16/14.
//  Copyright (c) 2014 gnos.us. All rights reserved.
//

import UIKit
import BlueCapKit

class BeaconRegionsViewController: UITableViewController {

    var stopScanBarButtonItem   : UIBarButtonItem!
    var startScanBarButtonItem  : UIBarButtonItem!
    var beaconRegions           = [String:BeaconRegion]()

    var isRanging               = [String:Bool]()
    var isInRegion              = [String:Bool]()
    
    struct MainStoryBoard {
        static let beaconRegionCell         = "BeaconRegionCell"
        static let beaconsSegue             = "Beacons"
        static let beaconRegionAddSegue     = "BeaconRegionAdd"
        static let beaconRegionEditSegue    = "BeaconRegionEdit"
    }
    
    required init(coder aDecoder:NSCoder) {
        super.init(coder:aDecoder)
        self.stopScanBarButtonItem = UIBarButtonItem(barButtonSystemItem:.Stop, target:self, action:"toggleMonitoring:")
        self.startScanBarButtonItem = UIBarButtonItem(barButtonSystemItem:.Refresh, target:self, action:"toggleMonitoring:")
        self.stopScanBarButtonItem.tintColor = UIColor.blackColor()
        self.startScanBarButtonItem.tintColor = UIColor.blackColor()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.navigationItem.title = "Beacon Regions"
        self.setScanButton()
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"didBecomeActive", name:BlueCapNotification.didBecomeActive, object:nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"didResignActive", name:BlueCapNotification.didResignActive, object:nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.navigationItem.title = ""
    }
    
    
    override func prepareForSegue(segue:UIStoryboardSegue, sender:AnyObject!) {
        if segue.identifier == MainStoryBoard.beaconsSegue {
            let selectedIndexPath = sender as NSIndexPath
            let beaconsViewController = segue.destinationViewController as BeaconsViewController
            let beaconName = BeaconStore.getBeaconNames()[selectedIndexPath.row]
            if let beaconRegion = self.beaconRegions[beaconName] {
                beaconsViewController.beaconRegion = beaconRegion
            }
        } else if segue.identifier == MainStoryBoard.beaconRegionAddSegue {
        } else if segue.identifier == MainStoryBoard.beaconRegionEditSegue {
            let selectedIndexPath = sender as NSIndexPath
            let viewController = segue.destinationViewController as BeaconRegionViewController
            viewController.regionName = BeaconStore.getBeaconNames()[selectedIndexPath.row]
        }
    }
    
    func toggleMonitoring(sender:AnyObject) {
        if CentralManager.sharedInstance().isScanning == false {
            if BeaconManager.sharedInstance().isRanging() {
                BeaconManager.sharedInstance().stopRangingAllBeacons()
                BeaconManager.sharedInstance().stopMonitoringAllRegions()
                self.beaconRegions.removeAll(keepCapacity:false)
                self.setScanButton()
            } else {
                self.startMonitoring()
            }
            self.tableView.reloadData()
        } else {
            self.presentViewController(UIAlertController.alertWithMessage("Central scan is active. Cannot scan and monitor simutaneously. Stop scan to start monitoring"), animated:true, completion:nil)
        }
    }
    
    func setScanButton() {
        if BeaconManager.sharedInstance().isRanging() {
            self.navigationItem.setLeftBarButtonItem(self.stopScanBarButtonItem, animated:false)
        } else {
            self.navigationItem.setLeftBarButtonItem(self.startScanBarButtonItem, animated:false)
        }
    }
    
    func startMonitoring() {
        for (name, uuid) in BeaconStore.getBeacons() {
            let beacon = BeaconRegion(proximityUUID:uuid, identifier:name) {(beaconRegion) in
                beaconRegion.startMonitoringRegion = {
                    BeaconManager.sharedInstance().startRangingBeaconsInRegion(beaconRegion)
                    self.setScanButton()
                    self.isRanging[name] = false
                    self.isInRegion[name] = false
                    Logger.debug("BeaconRegionsViewController#startMonitoring: started monitoring region \(name)")
                }
                beaconRegion.enterRegion = {
                    let beaconManager = BeaconManager.sharedInstance()
                    if !beaconManager.isRangingRegion(beaconRegion.identifier) {
                        beaconManager.startRangingBeaconsInRegion(beaconRegion)
                        self.updateDisplay()
                    }
                    self.isInRegion[name] = true
                    Notify.withMessage("Entering region '\(name)'. Started ranging beacons.")
                }
                beaconRegion.exitRegion = {
                    BeaconManager.sharedInstance().stopRangingBeaconsInRegion(beaconRegion)
                    self.isInRegion[name] = false
                    self.updateWhenActive()
                    Notify.withMessage("Exited region '\(name)'. Stoped ranging beacons.")
                }
                beaconRegion.errorMonitoringRegion = {(error) in
                    BeaconManager.sharedInstance().stopRangingBeaconsInRegion(beaconRegion)
                    self.updateWhenActive()
                    self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
                }
                beaconRegion.rangedBeacons = {(beacons) in
                    for beacon in beacons {
                        Logger.debug("major:\(beacon.major), minor: \(beacon.minor), rssi: \(beacon.rssi)")
                    }
                    if let isRanging = self.isRanging[name] {
                        if !isRanging && beacons.count > 0 {
                            self.isRanging[name] = true
                            self.updateWhenActive()
                        }
                    }
                    if UIApplication.sharedApplication().applicationState == .Active && beacons.count > 0 {
                        NSNotificationCenter.defaultCenter().postNotificationName(BlueCapNotification.didUpdateBeacon, object:beaconRegion)
                    }
                }
            }
            BeaconManager.sharedInstance().startMonitoringForRegion(beacon)
            self.beaconRegions[name] = beacon
        }
    }
    
    func updateDisplay() {
        if UIApplication.sharedApplication().applicationState == .Active {
            self.tableView.reloadData()
        }
    }

    func didResignActive() {
        Logger.debug("BeaconRegionsViewController#didResignActive")
    }
    
    func didBecomeActive() {
        Logger.debug("BeaconRegionsViewController#didBecomeActive")
        self.tableView.reloadData()
    }

    // UITableViewDataSource
    override func numberOfSectionsInTableView(tableView:UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BeaconStore.getBeacons().count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(MainStoryBoard.beaconRegionCell, forIndexPath: indexPath) as BeaconRegionCell
        let name = BeaconStore.getBeaconNames()[indexPath.row]
        let beaconRegions = BeaconStore.getBeacons()
        cell.rangingActivityIndicator.stopAnimating()
        if let beaconRegionUUID = beaconRegions[name] {
            cell.nameLabel.text = name
            cell.uuidLabel.text = beaconRegionUUID.UUIDString
        }
        var isBeaconInRegion = false
        if let isInRegion = self.isInRegion[name] {
            isBeaconInRegion = isInRegion
        }
        if BeaconManager.sharedInstance().isRangingRegion(name) {
            if let region = BeaconManager.sharedInstance().beaconRegion(name) {
                if region.beacons.count == 0 {
                    cell.accessoryType = .None
                    cell.rangingActivityIndicator.startAnimating()
                } else {
                    cell.accessoryType = .DetailButton
                }
            } else {
                cell.accessoryType = .DisclosureIndicator
            }
        } else  if isBeaconInRegion {
            cell.accessoryType = .None
            cell.rangingActivityIndicator.startAnimating()
        } else {
            cell.accessoryType = .DisclosureIndicator
        }
        return cell
    }
    
    override func tableView(tableView:UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let name = BeaconStore.getBeaconNames()[indexPath.row]
        return !BeaconManager.sharedInstance().isRangingRegion(name)
    }
    
    override func tableView(tableView:UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath:NSIndexPath) {
        if editingStyle == .Delete {
            let name = BeaconStore.getBeaconNames()[indexPath.row]
            BeaconStore.removeBeacon(name)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation:.Fade)
        }
    }
    
    // UITableViewDelegate
    override func tableView(tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath) {
        let name = BeaconStore.getBeaconNames()[indexPath.row]
        if BeaconManager.sharedInstance().isRangingRegion(name) {
            self.performSegueWithIdentifier(MainStoryBoard.beaconsSegue, sender:indexPath)
        } else {
            self.performSegueWithIdentifier(MainStoryBoard.beaconRegionEditSegue, sender:indexPath)
        }
    }
    
}
