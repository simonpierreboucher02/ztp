import Testing
import Foundation
@testable import ZTPExcel

@Suite("CellAddress Tests")
struct CellAddressTests {

    @Test("Parse simple addresses")
    func parseSimple() {
        let a1 = CellAddress(string: "A1")
        #expect(a1?.column == 1)
        #expect(a1?.row == 1)

        let b7 = CellAddress(string: "B7")
        #expect(b7?.column == 2)
        #expect(b7?.row == 7)
    }

    @Test("Parse multi-letter columns")
    func parseMultiLetter() {
        let aa1 = CellAddress(string: "AA1")
        #expect(aa1?.column == 27)

        let xfd = CellAddress(string: "XFD1")
        #expect(xfd?.column == 16384)
    }

    @Test("Reference round-trip")
    func referenceRoundTrip() {
        let addr = CellAddress(column: 27, row: 100)
        #expect(addr.reference == "AA100")

        let parsed = CellAddress(string: addr.reference)
        #expect(parsed == addr)
    }

    @Test("Column letter conversion")
    func columnLetters() {
        #expect(CellAddress.columnLetters(from: 1) == "A")
        #expect(CellAddress.columnLetters(from: 26) == "Z")
        #expect(CellAddress.columnLetters(from: 27) == "AA")
        #expect(CellAddress.columnLetters(from: 16384) == "XFD")
    }

    @Test("Invalid addresses return nil")
    func invalidAddresses() {
        #expect(CellAddress(string: "") == nil)
        #expect(CellAddress(string: "1A") == nil)
        #expect(CellAddress(string: "A0") == nil)
        #expect(CellAddress(string: "A1048577") == nil)
        #expect(CellAddress(string: "XFE1") == nil)
    }

    @Test("Max Excel limits")
    func maxLimits() {
        let max = CellAddress(string: "XFD1048576")
        #expect(max != nil)
        #expect(max?.column == 16384)
        #expect(max?.row == 1048576)
    }
}
