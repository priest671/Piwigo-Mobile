//
//  piwigoWebAPI.swift
//  piwigoWebAPI
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://app.quicktype.io/?share=2O9jStiO6T444YFJc8F3
//     https://jsonlint.com/?code=

import Foundation
import XCTest

class piwigoWebAPI: XCTestCase {

    // MARK: - pwg.images…
    func testPwgImagesUploadDecoding() {
        
        // Case of a JPG file
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.upload", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesUploadJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.stat, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")
        
        XCTAssertEqual(result.imagesUpload.image_id, 6580)
        XCTAssertEqual(result.imagesUpload.name, "Delft - 06")
        XCTAssertEqual(result.imagesUpload.square_src, "https://.../20200628211106-5fc9fb08-sq.jpg")
        XCTAssertEqual(result.imagesUpload.src, "https://.../20200628211106-5fc9fb08-th.jpg")

        // Case of a PNG file
        guard let url2 = bundle.url(forResource: "pwg.images.upload2", withExtension: "json"),
            let data2 = try? Data(contentsOf: url2) else {
                return
        }
        
        guard let result2 = try? decoder.decode(ImagesUploadJSON.self, from: data2) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result2.stat, "ok")
        XCTAssertEqual(result2.errorCode, 0)
        XCTAssertEqual(result2.errorMessage, "")
        
        XCTAssertEqual(result2.imagesUpload.image_id, 6582)
        XCTAssertEqual(result2.imagesUpload.name, "Screenshot 2020-06-28 at 14.01.38")
        XCTAssertEqual(result2.imagesUpload.square_src, "https://.../20200628212043-0a9c6158-sq.png")
        XCTAssertEqual(result2.imagesUpload.src, "https://.../20200628212043-0a9c6158-th.png")
    }

    func testPwgImagesSetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.setInfo", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesSetInfoJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.stat, "ok")
        XCTAssertTrue(result.imageSetInfo)
    }

    
    // MARK: - pwg.tags…
    func testPwgTagsGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.getList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(TagJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.stat, "ok")
        XCTAssertEqual(result.tagPropertiesArray[1].id, 14)
        XCTAssertEqual(result.tagPropertiesArray[2].counter, 9)
    }

    func testPwgTagsGetAdminListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.getAdminList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(TagJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.stat, "ok")
        XCTAssertEqual(result.tagPropertiesArray[0].id, 1)
        XCTAssertEqual(result.tagPropertiesArray[2].name, "Piwigo")
    }

    func testPwgTagsAddDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.add", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(TagAddJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.stat, "ok")
        XCTAssertEqual(result.tagProperties.id, 26)
    }

    // MARK: - community
    func testCommunityImagesUploadCompletedDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "community.images.uploadCompleted", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CommunityImagesUploadCompletedJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.stat, "ok")
        XCTAssertTrue(result.isSubmittedToModerator)
    }
}
