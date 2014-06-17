//
//  CentralManager.swift
//  BlueCap
//
//  Created by Troy Stribling on 6/4/14.
//  Copyright (c) 2014 gnos.us. All rights reserved.
//

import Foundation
import CoreBluetooth

class CentralManager : NSObject, CBCentralManagerDelegate {
    
    var afterPowerOn                : (()->())?
    var afterPowerOff               : (()->())?
    var afterPeripheralDiscovered   : ((Peripheral!, Int)->())?
    
    var discoveredPeripherals : Dictionary<CBPeripheral, Peripheral> = [:]
    let cbCentralManager : CBCentralManager!
    
    var isScanning  = false
    var connecting  = false
    
    var peripherals : Peripheral[] {
        return Array(self.discoveredPeripherals.values)
    }
    
    // APPLICATION INTERFACE
    class func sharedinstance() -> CentralManager {
        if !thisCentralManager {
            thisCentralManager = CentralManager()
        }
        return thisCentralManager!;
    }
    
    // scanning
    func startScanning(afterPeripheralDiscovered:((peripheral:Peripheral!, rssi:Int)->())?) {
        startScanningForServiceUUIDds(nil, afterPeripheralDiscovered)
    }
    
    func startScanningForServiceUUIDds(uuids:CBUUID[]!, afterPeripheralDiscovered:((peripheral:Peripheral!, rssi:Int)->())?) {
        if !self.isScanning {
            Logger.debug("CentralManager#startScanningForServiceUUIDds")
            self.isScanning = true
            self.afterPeripheralDiscovered = afterPeripheralDiscovered
            self.cbCentralManager.scanForPeripheralsWithServices(uuids,options: nil)
        }
    }
    
    func stopScanning() {
        if (self.isScanning) {
            Logger.debug("CentralManager#stopScanning")
            self.isScanning = false
            self.cbCentralManager.stopScan()
        }
    }
    
    // connection
    func disconnectAllPeripherals() {
        Logger.debug("CentralManager#disconnectAllPeripherals")
        for peripheral in self.peripherals {
            peripheral.disconnect()
        }
    }
    
    func connectPeripheral(peripheral:Peripheral) {
        Logger.debug("CentralManager#connectPeripheral")
        self.cbCentralManager.connectPeripheral(peripheral.cbPeripheral, options:nil)
    }
    
    func cancelPeripheralConnection(peripheral:Peripheral) {
        Logger.debug("CentralManager#cancelPeripheralConnection")
        self.cbCentralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
    }
    
    // power up
    func powerOn(afterPowerOnCallback:(()->())?) {
        self.powerOn(afterPowerOnCallback, nil)
    }

    func powerOn(afterPowerOn:(()->())?, afterPowerOff:(()->())?) {
        Logger.debug("powerOn")
        self.afterPowerOn = afterPowerOn
        self.afterPowerOff = afterPowerOff
        if self.poweredOn() && self.afterPowerOn {
            self.afterPowerOn!()
        }
    }

    func poweredOn() -> Bool {
        return self.cbCentralManager.state == CBCentralManagerState.PoweredOn
    }
    
    // CBCentralManagerDelegate
    // peripheral
    func centralManager(central:CBCentralManager!, didConnectPeripheral peripheral:CBPeripheral!) {
        Logger.debug("CentralManager#didConnectPeripheral")
        if let bcPeripheral = self.discoveredPeripherals[peripheral] {
            bcPeripheral.didConnectPeripheral()
        }
    }
    
    func centralManager(central:CBCentralManager!, didDisconnectPeripheral peripheral:CBPeripheral!, error:NSError!) {
        Logger.debug("CentralManager#didDisconnectPeripheral")
        if let bcPeripheral = self.discoveredPeripherals[peripheral] {
            bcPeripheral.didDisconnectPeripheral()
        }
//        self.discoveredPeripherals.removeAll(keepCapacity:false)
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral:CBPeripheral!, advertisementData:NSDictionary!, RSSI:NSNumber!) {
        if !self.discoveredPeripherals[peripheral] {
            let bcPeripheral = Peripheral(cbPeripheral:peripheral, advertisement:advertisementData)
            Logger.debug("CentralManager#didDiscoverPeripheral: \(bcPeripheral.name)")
            self.discoveredPeripherals[peripheral] = bcPeripheral
            if let afterPeripheralDiscovered = self.afterPeripheralDiscovered {
                afterPeripheralDiscovered(bcPeripheral, RSSI.integerValue)
            }
        }
    }
    
    func centralManager(central:CBCentralManager!, didFailToConnectPeripheral peripheral:CBPeripheral!, error:NSError!) {
        Logger.debug("CentralManager#didFailToConnectPeripheral")
        if let bcPeripheral = self.discoveredPeripherals[peripheral] {
            bcPeripheral.didFailToConnectPeripheral(error)
        }
    }
    
    func centralManager(central:CBCentralManager!, didRetrieveConnectedPeripherals peripherals:AnyObject[]!) {
        Logger.debug("CentralManager#didRetrieveConnectedPeripherals")
    }
    
    func centralManager(central:CBCentralManager!, didRetrievePeripherals peripherals:AnyObject[]!) {
        Logger.debug("CentralManager#didRetrievePeripherals")
    }
    
    // centrail manager state
    func centralManager(central: CBCentralManager!, willRestoreState dict:NSDictionary!) {
        Logger.debug("CentralManager#willRestoreState")
    }
    
    func centralManagerDidUpdateState(central:CBCentralManager!) {
        switch(self.cbCentralManager.state) {
        case .Unauthorized:
            Logger.debug("CentralManager#centralManagerDidUpdateState: Unauthorized")
            break
        case .Unknown:
            Logger.debug("CentralManager#centralManagerDidUpdateState: Unknown")
            break
        case .Unsupported:
            Logger.debug("CentralManager#centralManagerDidUpdateState: Unsupported")
            break
        case .Resetting:
            Logger.debug("CentralManager#centralManagerDidUpdateState: Resetting")
            break
        case .PoweredOff:
            Logger.debug("CentralManager#centralManagerDidUpdateState: PoweredOff")
            if (self.afterPowerOff) {
                asyncCallback(self.afterPowerOff!)
            }
            break
        case .PoweredOn:
            Logger.debug("CentralManager#centralManagerDidUpdateState: PoweredOn")
            if (self.afterPowerOn) {
                asyncCallback(self.afterPowerOn!)
            }
            break
        }
    }
    
    // INTERNAL INTERFACE
    class func syncCallback(request:()->()) {
        CentralManager.sharedinstance().syncCallback(request)
    }
    
    class func asyncCallback(request:()->()) {
        CentralManager.sharedinstance().asyncCallback(request)
    }
    
    class func delayCallback(delay:Float, request:()->()) {
        CentralManager.sharedinstance().delayCallback(delay, request)
    }
    
    func syncCallback(request:()->()) {
        dispatch_sync(dispatch_get_main_queue(), request)
    }
    
    func asyncCallback(request:()->()) {
        dispatch_async(dispatch_get_main_queue(), request)
    }
    
    func delayCallback(delay:Float, request:()->()) {
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay*Float(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue(), request)
    }
    
    // PRIVATE INTERFACE
    init() {
        super.init()
        self.cbCentralManager = CBCentralManager(delegate:self, queue:nil)
    }
    
}

var thisCentralManager : CentralManager?