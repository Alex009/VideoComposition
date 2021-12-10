//
//  VideoCompositionTests.swift
//  VideoCompositionTests
//
//  Created by Aleksey Mikhailov on 10.12.2021.
//
//

import XCTest
import AVFoundation
@testable import VideoComposition

class VideoCompositionTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() async throws {
        let bundle: Bundle = Bundle(for: type(of: self))
        let fileManager: FileManager = FileManager.default

        let imageUrl: URL = bundle.url(forResource: "IMG_8731", withExtension: "jpeg")!
        let videoUrl: URL = bundle.url(forResource: "IMG_8730", withExtension: "MOV")!

        let outputFile: URL = getDocumentsDirectory().appendingPathComponent("output.mov")

        let input: InputAsset = .merge(assets: [.imageFile(url: imageUrl), .videoFile(url: videoUrl)])
        let compositor = VideoCompositor()

        try? fileManager.removeItem(at: outputFile)

        do {
            try await compositor.compose(input: input, exportUrl: outputFile)
        } catch {
            print(error)
            print("hi")
        }

        print(outputFile)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
