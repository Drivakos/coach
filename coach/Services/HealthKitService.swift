import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read permission for step count. Returns true if authorization was granted.
    func requestPermission() async -> Bool {
        guard isAvailable else { return false }
        let stepType = HKQuantityType(.stepCount)
        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            return true
        } catch {
            return false
        }
    }

    /// Fetches the cumulative step count from midnight today until now.
    func fetchTodaySteps() async -> Int? {
        guard isAvailable else { return nil }
        let stepType = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map { Int($0) })
            }
            store.execute(query)
        }
    }
}
