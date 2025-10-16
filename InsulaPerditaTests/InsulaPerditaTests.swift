//
//  InsulaPerditaTests.swift
//  InsulaPerditaTests
//
//  Created by Irakli Sokhadze on 31.08.25.
//

import Testing
@testable import InsulaPerdita

struct InsulaPerditaTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

import XCTest
@testable import InsulaPerdita

final class GlucosePersistenceTests: XCTestCase {
    func testPersistAndLoadGlucoseReadings() throws {
        let key = glucoseReadingsStorageKey
        let initial: [GlucoseReadingAction] = [GlucoseReadingAction(id: UUID(), date: Date(), value: 5.6)]
        persistGlucoseReadings(initial, key: key)
        let loaded = loadGlucoseReadings(key: key)
        XCTAssertEqual(loaded.count, 1)
        guard let first = loaded.first else { return XCTFail("No readings loaded") }
        XCTAssertEqual(first.value, 5.6, accuracy: 0.0001)
    }
}
