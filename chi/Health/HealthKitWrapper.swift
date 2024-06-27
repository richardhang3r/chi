//
//  HealthKitWrapper.swift
//  track
//
//  Created by Richard Hanger on 5/24/24.
//

//
//  HealthData.swift
//  strive
//
//  Created by Richard Hanger on 12/14/23.
//
import Foundation
import HealthKit
import os.log
import CloudKit
import SwiftData

struct HealthDateData : Identifiable, Sendable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    var value: Double
    var type: String
}

class HealthData {
    
    static let healthStore: HKHealthStore = HKHealthStore()
    static var backgroundQueries: [HKObserverQuery] = []
    
    // MARK: - Data Types
    static var readDataTypes: [HKSampleType] {
        return allHealthDataTypes
    }
    
    static var shareDataTypes: [HKSampleType] {
        return allHealthDataTypes
    }
    
    static private func health_enable_background_delivery(sample_type: HKSampleType) {
        HealthData.healthStore.enableBackgroundDelivery(for: sample_type, frequency: HKUpdateFrequency.immediate) {
            success, error in
            
            if error != nil {
                // Perform Proper Error Handling Here...
                print("*** An error occured while setting up the stepCount observer. \(error.debugDescription) ***")
            }
            
            print("succ: \(success.description)")
        }
    }
    
    static func healthUpdateAsync(dataType: String) async throws -> [HealthDateData] {
        return try await withCheckedThrowingContinuation { continuation in
            self.calculate_values(type_id: dataType) { success, error, data in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "HealthDataErrorDomain", code: -1, userInfo: nil))
                }
            }
        }
    }
    
    static func health_data_update(dataType: String, completion: ( (_ success: Bool, _ error: Error?,_ data: [HealthDateData]) -> Void)?=nil) {
        self.calculate_values(type_id: dataType) {success,error,data in
            DispatchQueue.main.async {
                let userInfo = [UserInfoKey.healthKitChanges: data]
                NotificationCenter.default.post(name: .healthKitDataUpdate, object: nil, userInfo: userInfo)
            }
            completion?(success, error, data)
        }
    }

    static func healthConfigureBackgroundQuery(for dataType: String) {
        guard let sample_type : HKSampleType = getSampleType(for: dataType) else {
            Logger.healthKit.error("No HKSample type for \(dataType) ")
            return
        }
        if self.backgroundQueries.firstIndex(where: {$0.objectType!.identifier == dataType}) != nil {
            Logger.healthKit.info("\(dataType) query already here")
            return
        }
        self.health_enable_background_delivery(sample_type: sample_type)
        let observerQuery = self.health_start_background_query(type_id: dataType)
        self.backgroundQueries.append(observerQuery)
        Logger.healthKit.info("Added observer Query for \(dataType) Total Queries \(self.backgroundQueries.count)")

    }
    
    static func health_configure_background_query(dataType: String) {
        guard let sample_type : HKSampleType = getSampleType(for: dataType) else {
            Logger.healthKit.error("No HKSample type for \(dataType) ")
            return
        }
        
        // update this data with latest!!
        health_data_update(dataType: dataType)
        
        if self.backgroundQueries.firstIndex(where: {$0.objectType!.identifier == dataType}) != nil {
            Logger.healthKit.info("\(dataType) query already here")
            return
        }
        self.health_enable_background_delivery(sample_type: sample_type)
        let observerQuery = self.health_start_background_query(type_id: dataType)
        self.backgroundQueries.append(observerQuery)
        Logger.healthKit.info("Added observer Query for \(dataType) Total Queries \(self.backgroundQueries.count)")
    }
    
    static func health_remove_background_query(dataType: String) {
        if let index = self.backgroundQueries.firstIndex(where: {$0.objectType!.identifier == dataType}){
            Logger.healthKit.info("Removing \(dataType) background Query")
            let query : HKObserverQuery = self.backgroundQueries.remove(at: index)
            HealthData.healthStore.stop(query)
            return
        }
    }
        
    private static var allHealthDataTypes: [HKSampleType] {
        let typeIdentifiers: [String] = [
            HKQuantityTypeIdentifier.stepCount.rawValue,
            HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
            HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue
        ]
        
        return typeIdentifiers.compactMap { getSampleType(for: $0) }
    }
    
    // MARK: - Authorization
    
    /// Request health data from HealthKit if needed, using the data types within `HealthData.allHealthDataTypes`
    class func requestHealthDataAccessIfNeeded(dataTypes: [String]? = nil, completion: @escaping (_ success: Bool) -> Void) {
        var readDataTypes = Set(allHealthDataTypes)
        //var shareDataTypes = Set(allHealthDataTypes)
        
        if let dataTypeIdentifiers = dataTypes {
            readDataTypes = Set(dataTypeIdentifiers.compactMap { getSampleType(for: $0) })
            //shareDataTypes = readDataTypes
        }
        
        requestHealthDataAccessIfNeeded(toShare: nil, read: readDataTypes, completion: completion)
    }
    
    /// Request health data from HealthKit if needed.
    class func requestHealthDataAccessIfNeeded(toShare shareTypes: Set<HKSampleType>?,
                                               read readTypes: Set<HKObjectType>?,
                                               completion: @escaping (_ success: Bool) -> Void) {
        if !HKHealthStore.isHealthDataAvailable() {
            fatalError("Health data is not available!")
        }
        
        print("Requesting HealthKit authorization...")
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { (success, error) in
            if let error = error {
                print("requestAuthorization error:", error.localizedDescription)
            }
            
            if success {
                print("HealthKit authorization request was successful!")
            } else {
                print("HealthKit authorization was not successful.")
            }
            
            completion(success)
        }
    }
    
    // MARK: - HKHealthStore
    
    class func saveHealthData(_ data: [HKObject], completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        healthStore.save(data, withCompletion: completion)
    }
    
    // MARK: - HKStatisticsCollectionQuery
    class func fetchStatistics(with identifier: HKQuantityTypeIdentifier,
                               predicate: NSPredicate? = nil,
                               options: HKStatisticsOptions,
                               startDate: Date,
                               endDate: Date = Date(),
                               interval: DateComponents,
                               completion: @escaping (HKStatisticsCollection) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            fatalError("*** Unable to create a step count type ***")
        }
        
        let anchorDate = createAnchorDate()
        
        // Create the query
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: options,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        
        // Set the results handler
        query.initialResultsHandler = { query, results, error in
            if let statsCollection = results {
                completion(statsCollection)
            }
        }
         
        healthStore.execute(query)
    }
    
    // MARK: - Helper Functions
    
    class func clearHealthAnchor(from sample: HKSampleType?) {
        if let samp = sample {
            print("clearing health anchor for \(samp)")
            setAnchor(nil, for: samp)
        }
    }
    
    class func updateAnchor(_ newAnchor: Date?, from sample: HKSampleType) {
        setAnchor(newAnchor, for: sample)
    }
    
    private static let userDefaults = UserDefaults.standard
    
    private static let anchorKeyPrefix = "Anchor_"
    
    private class func anchorKey(for type: HKSampleType) -> String {
        return anchorKeyPrefix + type.identifier
    }
    
    /// Returns the saved anchor used in a long-running anchored object query for a particular sample type.
    /// Returns nil if a query has never been run.
    class func getAnchor(for type: HKSampleType) -> Date? {
        let time : Double = UserDefaults.standard.double(forKey: anchorKey(for: type))
        return Date(timeIntervalSinceReferenceDate: time)
    }
    
    /// Update the saved anchor used in a long-running anchored object query for a particular sample type.
    private class func setAnchor(_ anchor_date: Date?, for type: HKSampleType) {
        let time = anchor_date?.timeIntervalSinceReferenceDate ?? getLastWeekStartDate().timeIntervalSinceReferenceDate
        UserDefaults.standard.setValue(time, forKey: anchorKey(for: type))
    }
    
    static func processHealthData(complete_cb: @escaping @Sendable () -> Void) {
        // Simulate data processing
        DispatchQueue.global().async {
            // Process the data here
            // ...

            // Call the completion callback after processing
            complete_cb()
        }
    }

    static private func health_start_background_query(type_id: String) -> HKObserverQuery {
        let sample_type = getSampleType(for: type_id)!
        let observerQuery = HKObserverQuery(sampleType: sample_type, predicate: nil, updateHandler: { [self] (query: HKObserverQuery, completionHandler: @escaping HKObserverQueryCompletionHandler, error: Error?) in
            
            if error != nil {
                // Handle the error here
                NotificationManager.notifyDeveloper(subtitle: "obsrv hk err", message: error!.localizedDescription)
                completionHandler()
                return
            }
                       
            self.calculate_values(type_id: type_id) {success,error,data in
                Task {
                    await MainActor.run {
                        print("obsrv!!")
                        let ckManager = CloudKitManager()
                        var recordsToSave : [CKRecord] = []
                        let modelContext = MainModelContainer().makeContainer().mainContext
                        var justCompleted : Bool = false
                        let _goals = try? modelContext.fetch(FetchDescriptor<Goal>())
                        if let goals = _goals {
                            for goal in goals {
                                goal.updateCount += 1
                                if goal.type.healthIdentifier.rawValue == type_id {
                                    for datum in data {
                                        justCompleted = goal.updateData(val: datum.value, date: datum.startDate)
                                        if justCompleted {
                                            NotificationManager.notifyFromActivityMonitor(message: "complete! \(goal.type.title) \(Int(goal.getLocalUserValue()))/\(Int(goal.target))")
                                        }
                                    }
                                    Task {
                                        if let me = goal.getLocalUser() {
                                            do {
                                                let record = goal.lastKnownRecord!
                                                print("got goal record obsrv \(record.debugDescription)")
                                                try await CloudManager.updateUser(me: me, recordId: goal.lastKnownRecord!.recordID)
                                                NotificationManager.notifyDeveloper(subtitle: "obsrv cloudkit success", message: "\(goal.type.title): \(Int(goal.getLocalUserValue()))")
                                            } catch {
                                                print("observ cloud \(error)")
                                                NotificationManager.notifyDeveloper(subtitle: "obsrv cloudkit err", message: CloudManager.mapCloudKitError(error))
                                            }
                                        }
                                    }
                                    goal.updateCount += 1
                                }
                            }
                            do {
                                try modelContext.save()
                            } catch {
                                print("save err \(error)")
                            }
                        } else {
                            print("failed to fetch goals")
                        }
                    }
                }
                completionHandler()
            }
        })
        
        HealthData.healthStore.execute(observerQuery)
        return observerQuery
    }
        
    static private func calculate_values(type_id: String, completion: ( (_ success: Bool, _ error: Error?,_ data: [HealthDateData]) -> Void)?=nil) {
        let identifier = HKQuantityTypeIdentifier(rawValue: type_id)
        guard let _ = getSampleType(for: type_id),
              let quantityType = HKObjectType.quantityType(forIdentifier: identifier)
        else {
            fatalError("*** Unable to create a step count type ***")
        }
        //let anchor_date : Date = HealthData.getAnchor(for: sample_type) ?? Calendar.current.startOfDay(for: Date.now)
        let anchor_date : Date = Calendar.current.startOfDay(for: Date.now)
        //HealthData.updateAnchor(Date.now, from: sample_type)
        //let anchor_date = Calendar.current.date(byAdding: .day, value: -1, to: date)
        //let startOfDay = Calendar.current.startOfDay(for: Date.now)

        let predicate = HKQuery.predicateForSamples(withStart: anchor_date, end: Date.now, options: .strictStartDate)

        
        print("calculating values from \(anchor_date.debugDescription) to \(Date().description)")
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: getStatisticsOptions(for: type_id),
                                                anchorDate: anchor_date,
                                                intervalComponents: DateComponents(day: 1))
        
        query.initialResultsHandler = { (query, results, error) -> Void in
            if let statsCollection = results {
                var all_data: [HealthDateData] = []
                let sources = statsCollection.sources()
                statsCollection.enumerateStatistics(from: anchor_date, to: Date()) { (statistics, stop) in
                    let val : Double
                    if let quantity = getStatisticsQuantity(for: statistics, with: getStatisticsOptions(for: type_id)),
                       let unit = preferredUnit(for: type_id) {
                        val = quantity.doubleValue(for: unit)
                    } else {
                        val = 0.0
                    }
                    let t2 = HealthDateData(startDate: statistics.startDate, endDate: statistics.endDate, value: val, type: type_id)
                    all_data.append(t2)
                    /*
                    DispatchQueue.main.async {
                        let userInfo = [UserInfoKey.healthKitChanges: t2]
                        NotificationCenter.default.post(name: .healthKitDataUpdate, object: nil, userInfo: userInfo)
                    }
                     */
                }
                
                let health_data = all_data.sorted(by: {$0.endDate > $1.endDate})
                if let latest_data = health_data.first {
                    print("latest date \(latest_data.endDate.debugDescription)")
                }
                completion?(true,nil, all_data)
            } else {
                completion?(false, NSError(domain: "HealthDataErrorDomain", code: -1, userInfo: nil), [])
            }
        }
        HealthData.healthStore.execute(query)
    }
}

// MARK: Sample Type Identifier Support
/// Return an HKSampleType based on the input identifier that corresponds to an HKQuantityTypeIdentifier, HKCategoryTypeIdentifier
/// or other valid HealthKit identifier. Returns nil otherwise.
func getSampleType(for identifier: String) -> HKSampleType? {
    if let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier)) {
        return quantityType
    }
    
    if let categoryType = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier)) {
        return categoryType
    }
    
    return nil
}

// MARK: - Unit Support
/// Return the appropriate unit to use with an HKSample based on the identifier. Asserts for compatible units.
func preferredUnit(for sample: HKSample) -> HKUnit? {
    let unit = preferredUnit(for: sample.sampleType.identifier, sampleType: sample.sampleType)
    
    if let quantitySample = sample as? HKQuantitySample, let unit = unit {
        assert(quantitySample.quantity.is(compatibleWith: unit),
               "The preferred unit is not compatiable with this sample.")
    }
    
    return unit
}

/// Returns the appropriate unit to use with an identifier corresponding to a HealthKit data type.
func preferredUnit(for sampleIdentifier: String) -> HKUnit? {
    return preferredUnit(for: sampleIdentifier, sampleType: nil)
}

func preferredUnit(for quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKUnit? {
    var unit: HKUnit?
    switch quantityTypeIdentifier {
    case .heartRate:
        unit = HKUnit(from:"count/min")
    case .stepCount:
        unit = .count()
    case .distanceWalkingRunning, .sixMinuteWalkTestDistance:
        unit = .meter()
    case .bodyMass:
        unit = .pound()
    case .timeInDaylight:
        unit = .minute()
    default:
        break
    }
    return unit
}

private func preferredUnit(for identifier: String, sampleType: HKSampleType? = nil) -> HKUnit? {
    var unit: HKUnit?
    let sampleType = sampleType ?? getSampleType(for: identifier)
    
    if sampleType is HKQuantityType {
        let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: identifier)
        
        switch quantityTypeIdentifier {
        case .heartRate:
            unit = HKUnit(from:"count/min")
        case .stepCount:
            unit = .count()
        case .distanceWalkingRunning, .sixMinuteWalkTestDistance:
            unit = .meter()
        case .bodyMass:
            unit = .pound()
        case .timeInDaylight:
            unit = .minute()
        default:
            break
        }
    }
    
    return unit
}
/// Return an anchor date for a statistics collection query.
func createAnchorDate() -> Date {
    // Set the arbitrary anchor date to Monday at 3:00 a.m.
    let calendar: Calendar = .current
    var anchorComponents = calendar.dateComponents([.day, .month, .year, .weekday], from: Date())
    let offset = (7 + (anchorComponents.weekday ?? 0) - 2) % 7
    
    anchorComponents.day! -= offset
    anchorComponents.hour = 3
    
    let anchorDate = calendar.date(from: anchorComponents)!
    
    return anchorDate
}

/// This is commonly used for date intervals so that we get the last seven days worth of data,
/// because we assume today (`Date()`) is providing data as well.
func getLastWeekStartDate(from date: Date = Date()) -> Date {
    return Calendar.current.date(byAdding: .day, value: -6, to: date)!
}

func createLastWeekPredicate(from endDate: Date = Date()) -> NSPredicate {
    let startDate = getLastWeekStartDate(from: endDate)
    return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
}

/// Return the most preferred `HKStatisticsOptions` for a data type identifier. Defaults to `.discreteAverage`.
func getStatisticsOptions(for dataTypeIdentifier: String) -> HKStatisticsOptions {
    var options: HKStatisticsOptions = .discreteAverage
    let sampleType = getSampleType(for: dataTypeIdentifier)
    
    if sampleType is HKQuantityType {
        let quantityTypeIdentifier = HKQuantityTypeIdentifier(rawValue: dataTypeIdentifier)
        
        options =  getStatisticsOptions(for: quantityTypeIdentifier)
    }
    
    return options
}

func getStatisticsOptions(for quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKStatisticsOptions {
    var options: HKStatisticsOptions = .discreteAverage
    switch quantityTypeIdentifier {
    case .heartRate:
        options = .discreteMax
    case .stepCount, .distanceWalkingRunning, .timeInDaylight:
        options = .cumulativeSum
    case .sixMinuteWalkTestDistance, .bodyMass, .appleMoveTime, .appleExerciseTime:
        options = .discreteAverage
    default:
        break
    }
    return options
}

/// Return the statistics value in `statistics` based on the desired `statisticsOption`.
func getStatisticsQuantity(for statistics: HKStatistics, with statisticsOptions: HKStatisticsOptions) -> HKQuantity? {
    var statisticsQuantity: HKQuantity?
    
    switch statisticsOptions {
    case .discreteMax:
        statisticsQuantity = statistics.maximumQuantity()
    case .cumulativeSum:
        statisticsQuantity = statistics.sumQuantity()
    case .discreteAverage:
        statisticsQuantity = statistics.averageQuantity()
    default:
        break
    }
    
    return statisticsQuantity
}
