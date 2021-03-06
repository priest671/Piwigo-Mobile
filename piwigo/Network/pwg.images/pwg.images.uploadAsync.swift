//
//  pwg.images.uploadAsync.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - pwg.images.uploadAsync
let kPiwigoImagesUploadAsync = "format=json&method=pwg.images.uploadAsync"

struct ImagesUploadAsyncJSON: Decodable {

    var status: String?
    var chunks: ImagesUploadAsync!
    var data: ImagesGetInfo!
    var derivatives: Derivatives!
    var errorCode = 0
    var errorMessage = ""

    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case result = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case derivatives
    }

    private enum DerivativesCodingKeys: String, CodingKey {
        case squareImage = "square"
        case thumbImage = "thumb"
        case mediumImage = "medium"
        
        case smallImage = "small"
        case xSmallImage = "xsmall"
        case xxSmallImage = "2small"

        case largeImage = "large"
        case xLargeImage = "xlarge"
        case xxLargeImage = "xxlarge"
    }

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
//        dump(rootContainer)

        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Decodes response from the data and store them in the array
            data = try? rootContainer.decode(ImagesGetInfo.self, forKey: .result)
            
            // Did the server returned the image parameters?
            guard let _ = data, let _ = data.imageId else {
                // The server returned the list of uploaded chunks
                chunks = try rootContainer.decode(ImagesUploadAsync.self, forKey: .result)
//                print("    > \(chunks.message ?? "Done - No message!")")
                return
            }

            // The server returned pwg.images.getInfo data
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
//            dump(resultContainer)

            // Decodes derivatives
            do {
                try derivatives = resultContainer.decode(Derivatives.self, forKey: .derivatives)
            }
            catch {
                // Sometimes, width and height are provided as String instead of Int!
                derivatives = Derivatives()
                let derivativesContainer = try resultContainer.nestedContainer(keyedBy: DerivativesCodingKeys.self, forKey: .derivatives)
//                dump(derivativesContainer)
                
                // Square image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .squareImage)
                    derivatives?.squareImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .squareImage)
                    derivatives?.squareImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // Thumbnail image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .thumbImage)
                    derivatives?.thumbImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .thumbImage)
                    derivatives?.thumbImage = Derivative.init(url: square.url,
                                                              width: Int(square.width ?? "1"),
                                                              height: Int(square.height ?? "1"))
                }

                // Medium image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .mediumImage)
                    derivatives?.mediumImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .mediumImage)
                    derivatives?.mediumImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // Small image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .smallImage)
                    derivatives?.smallImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .smallImage)
                    derivatives?.smallImage = Derivative.init(url: square.url,
                                                              width: Int(square.width ?? "1"),
                                                              height: Int(square.height ?? "1"))
                }

                // XSmall image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xSmallImage)
                    derivatives?.xSmallImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xSmallImage)
                    derivatives?.xSmallImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // XXSmall image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xxSmallImage)
                    derivatives?.xxSmallImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xxSmallImage)
                    derivatives?.xxSmallImage = Derivative.init(url: square.url,
                                                                width: Int(square.width ?? "1"),
                                                                height: Int(square.height ?? "1"))
                }

                // Large image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .largeImage)
                    derivatives?.largeImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .largeImage)
                    derivatives?.largeImage = Derivative.init(url: square.url,
                                                              width: Int(square.width ?? "1"),
                                                              height: Int(square.height ?? "1"))
                }

                // XLarge image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xLargeImage)
                    derivatives?.xLargeImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xLargeImage)
                    derivatives?.xLargeImage = Derivative.init(url: square.url,
                                                               width: Int(square.width ?? "1"),
                                                               height: Int(square.height ?? "1"))
                }

                // XXLarge image
                do {
                    let square = try derivativesContainer.decode(Derivative.self, forKey: .xxLargeImage)
                    derivatives?.xxLargeImage = square
                }
                catch {
                    let square = try derivativesContainer.decode(DerivativeStr.self, forKey: .xxLargeImage)
                    derivatives?.xxLargeImage = Derivative.init(url: square.url,
                                                                width: Int(square.width ?? "1"),
                                                                height: Int(square.height ?? "1"))
                }
            }
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error
            errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
        }
        else {
            // Unexpected Piwigo server error
            errorCode = -1
            errorMessage = "Unexpected error encountered while calling server method with provided parameters."
        }
    }
}


// MARK: - Result contains a message until all chunks have been uploaded
struct ImagesUploadAsync: Decodable
{
    let message: String?         // "chunks uploaded = 2,5"
}
