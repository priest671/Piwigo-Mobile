//
//  UploadImage.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos

class UploadImage {

    // MARK: - Shared instances
    /// The UploadsProvider that collects upload data, saves it to Core Data, and serves it to the uploader.
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()
    /// The UploadManager that prepares and transfers images
    var uploadManager: UploadManager?


    // MARK: - Image preparation
    func prepare(_ upload: UploadProperties, from imageAsset: PHAsset) -> Void {
        
        // Retrieve UIImage
        let (fixedImageObject, imageError) = retrieveUIImage(from: imageAsset)
        if let _ = imageError {
            updateUploadRequestWith(upload, error: imageError)
        }
        guard let imageObject = fixedImageObject else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            updateUploadRequestWith(upload, error: error)
            return
        }

        // Retrieve image data
        let (fullSizeData, dataError) = retrieveFullSizeImageData(from: imageAsset)
        if let _ = dataError {
            updateUploadRequestWith(upload, error: dataError)
        }
        guard let imageData = fullSizeData else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            updateUploadRequestWith(upload, error: error)
            return
        }
        
        // Modify image
        modifyImage(for: upload, with: imageData, andObject: imageObject) { [unowned self] (newUpload, error) in
            // Update upload request
            self.updateUploadRequestWith(newUpload, error: error)
        }
    }
    
    private func updateUploadRequestWith(_ upload: UploadProperties, error: Error?) {

        // Error?
        if let error = error {
            // Could not prepare image
            let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier, category: upload.category,
                requestDate: upload.requestDate, requestState: .preparingError,
                requestDelete: upload.requestDelete, requestError: error.localizedDescription,
                creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
                isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacyLevel,
                imageTitle: upload.imageTitle, comment: upload.comment, tags: upload.tags, imageId: upload.imageId)
            
            // Update request with error description
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Consider next image
                self.uploadManager?.setIsPreparing(status: false)
            })
            return
        }

        // Update state of upload
        let uploadProperties = UploadProperties.init(localIdentifier: upload.localIdentifier, category: upload.category,
            requestDate: upload.requestDate, requestState: .prepared,
            requestDelete: upload.requestDelete, requestError: "",
            creationDate: upload.creationDate, fileName: upload.fileName, mimeType: upload.mimeType,
            isVideo: upload.isVideo, author: upload.author, privacyLevel: upload.privacyLevel,
            imageTitle: upload.imageTitle, comment: upload.comment, tags: upload.tags, imageId: upload.imageId)

        // Update request ready for transfer
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            // Upload ready for transfer
            self.uploadManager?.setIsPreparing(status: false)
        })
    }

    // MARK: - Retrieve UIImage and Image Data
    
    private func retrieveUIImage(from imageAsset: PHAsset) -> (UIImage?, Error?) {
        print("   > retrieveUIImageFrom...")

        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = true
        // Requests the most recent version of the image asset
        options.version = .current
        // Requests the highest-quality image available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested video
        options.isNetworkAccessAllowed = true
        // Requests Photos to resize the image according to user settings
        var size = PHImageManagerMaximumSize
        options.resizeMode = .exact
        if Model.sharedInstance().resizeImageOnUpload && Float(Model.sharedInstance().photoResize) < 100.0 {
            let scale = CGFloat(Model.sharedInstance().photoResize) / 100.0
            size = CGSize(width: CGFloat(imageAsset.pixelWidth) * scale, height: CGFloat(imageAsset.pixelHeight) * scale)
            options.resizeMode = .exact
        }

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
            print(String(format: "   > retrieveUIImageFrom... progress %lf", progress))
        }

        // Requests image…
        var error: Error?
        var fixedImageObject: UIImage?
        PHImageManager.default().requestImage(for: imageAsset, targetSize: size, contentMode: .default,
                                              options: options, resultHandler: { imageObject, info in
            // Any error?
            if info?[PHImageErrorKey] != nil || (imageObject?.size.width == 0) || (imageObject?.size.height == 0) {
//                print("     returned info(\(String(describing: info)))")
                error = info?[PHImageErrorKey] as? Error
                return
            }

            // Retrieved UIImage representation for the specified asset
            if let imageObject = imageObject {
                // Fix orientation if needed
                fixedImageObject = self.fixOrientationOf(imageObject)
                return
            }
            else {
                error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                return
            }
        })
        return (fixedImageObject, error)
    }

    private func retrieveFullSizeImageData(from imageAsset: PHAsset) -> (Data?, Error?) {
        print("   > retrieveFullSizeAssetDataFromImage...")

        // Case of an image…
        let options = PHImageRequestOptions()
        // Does not block the calling thread until image data is ready or an error occurs
        options.isSynchronous = true
        // Requests the most recent version of the image asset
        options.version = .current
        // Requests a fast-loading image, possibly sacrificing image quality.
        options.deliveryMode = .fastFormat
        // Photos can download the requested video from iCloud
        options.isNetworkAccessAllowed = true

        // The block Photos calls periodically while downloading the photo
        options.progressHandler = { progress, error, stop, info in
            print(String(format: "   > retrieveFullSizeAssetDataFromImage... progress %lf", progress))
        }

        var error: Error?
        var data: Data?
        autoreleasepool {
            if #available(iOS 13.0, *) {
                PHImageManager.default().requestImageDataAndOrientation(for: imageAsset, options: options,
                                                                        resultHandler: { imageData, dataUTI, orientation, info in
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        error = info?[PHImageErrorKey] as? Error
                    } else {
                        data = imageData
                    }
                })
            } else {
                PHImageManager.default().requestImageData(for: imageAsset, options: options,
                                                          resultHandler: { imageData, dataUTI, orientation, info in
                    if info?[PHImageErrorKey] != nil || ((imageData?.count ?? 0) == 0) {
                        error = info?[PHImageErrorKey] as? Error
                    } else {
                        data = imageData
                    }
                })
            }
        }
        return (data, error)
    }

    
    // MARK: - Modify Metadata
    
    private func modifyImage(for upload: UploadProperties,
                             with originalData: Data, andObject originalObject: UIImage,
                             completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        print("   > modifyImage...")

        // Create CGI reference from image data (to retrieve complete metadata)
        guard let source: CGImageSource = CGImageSourceCreateWithData((originalData as CFData), nil) else {
            // Could not prepare image source
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Get metadata from image data
        guard var imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as Dictionary? else {
            // Could not retrieve metadata
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            completionHandler(upload, error)
            return
        }

        // Strip GPS metadata if user requested it in Settings
        if Model.sharedInstance().stripGPSdataOnUpload {
            imageMetadata = ImageService.stripGPSdata(fromImageMetadata: imageMetadata)! as Dictionary<NSObject, AnyObject>
        }

        // Fix image metadata (size, type, etc.)
        imageMetadata = ImageService.fixMetadata(imageMetadata, of: originalObject)! as Dictionary<NSObject, AnyObject>

        // Apply compression if user requested it in Settings, or convert to JPEG if necessary
        var imageCompressed: Data? = nil
        var newUpload = upload
        let fileExt = (URL(fileURLWithPath: upload.fileName!).pathExtension).lowercased()
        if Model.sharedInstance().compressImageOnUpload && (CGFloat(Model.sharedInstance().photoQuality) < 100.0) {
            // Compress image (only possible in JPEG)
            let compressionQuality: CGFloat = CGFloat(Model.sharedInstance().photoQuality) / 100.0
            imageCompressed = originalObject.jpegData(compressionQuality: compressionQuality)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName!).deletingPathExtension().appendingPathExtension("JPG").lastPathComponent
        }
        else if !(Model.sharedInstance().uploadFileTypes.contains(fileExt)) {
            // Image in unaccepted file format for Piwigo server => convert to JPEG format
            imageCompressed = originalObject.jpegData(compressionQuality: 1.0)

            // Final image file will be in JPEG format
            newUpload.fileName = URL(fileURLWithPath: upload.fileName!).deletingPathExtension().appendingPathExtension("JPG").lastPathComponent
        }

        // If compression failed or imageCompressed is nil, try to use original image
        if imageCompressed == nil {
            let UTI: CFString? = CGImageSourceGetType(source)
            let imageDataRef = CFDataCreateMutable(nil, CFIndex(0))
            var destination: CGImageDestination? = nil
            if let imageDataRef = imageDataRef, let UTI = UTI {
                destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil)
            }
            if let destination = destination, let CGImage = originalObject.cgImage {
                CGImageDestinationAddImage(destination, CGImage, nil)
            }
            if let destination = destination {
                if !CGImageDestinationFinalize(destination) {
                    let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    completionHandler(upload, error)
                    return
                }
            }
            imageCompressed = imageDataRef as Data?
        }

        // Add metadata to final image
        let imageData = ImageService.writeMetadata(imageMetadata, intoImageData: imageCompressed)

        // Try to determine MIME type from image data
        newUpload.mimeType = "image/jpeg"
        if let type = contentType(forImageData: imageData) {
            if type.count > 0  {
                // Adopt determined Mime type
                newUpload.mimeType = type
                // Re-check filename extension if MIME type known
                let fileExt = (URL(fileURLWithPath: newUpload.fileName ?? "").pathExtension).lowercased()
                let expectedFileExtension = fileExtension(forImageData: imageData)
                if !(fileExt == expectedFileExtension) {
                    newUpload.fileName = URL(fileURLWithPath: upload.fileName ?? "file").deletingPathExtension().appendingPathExtension(expectedFileExtension ?? "").lastPathComponent
                }
            }
        }

        // File name of final image data to be stored into Piwigo/Uploads directory
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + newUpload.fileName!
        guard let fileURL = uploadManager?.applicationUploadsDirectory.appendingPathComponent(fileName) else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.updateUploadRequestWith(upload, error: error)
            return
        }
        
        // Deletes temporary image file if exists (incomplete previous attempt?)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
        }

        // Store final image data into Piwigo/Uploads directory
        do {
            try imageData?.write(to: fileURL)
        } catch let error as NSError {
            completionHandler(newUpload, error)
            return
        }
        completionHandler(newUpload, nil)
    }


    // MARK: - Fix Image Orientation
    
    private func fixOrientationOf(_ image: UIImage) -> UIImage {

        // No-op if the orientation is already correct
        if image.imageOrientation == .up {
            return image
        }

        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform: CGAffineTransform = .identity

        switch image.imageOrientation {
            case .down, .downMirrored:
                transform = transform.translatedBy(x: image.size.width, y: image.size.height)
                transform = transform.rotated(by: .pi)
            case .left, .leftMirrored:
                transform = transform.translatedBy(x: image.size.width, y: 0)
                transform = transform.rotated(by: .pi / 2)
            case .right, .rightMirrored:
                transform = transform.translatedBy(x: 0, y: image.size.height)
                transform = transform.rotated(by: -.pi / 2)
            case .up, .upMirrored:
                break
            @unknown default:
                break
        }

        switch image.imageOrientation {
            case .upMirrored, .downMirrored:
                transform = transform.translatedBy(x: image.size.width, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .leftMirrored, .rightMirrored:
                transform = transform.translatedBy(x: image.size.height, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            case .up, .down, .left, .right:
                break
            @unknown default:
                break
        }

        // Now we draw the underlying CGImage into a new context,
        // applying the transform calculated above.
        let ctx = CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height),
                            bitsPerComponent: image.cgImage!.bitsPerComponent, bytesPerRow: 0,
                            space: image.cgImage!.colorSpace!, bitmapInfo: image.cgImage!.bitmapInfo.rawValue)
        ctx?.concatenate(transform)
        switch image.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                // Grr...
                ctx?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.height , height: image.size.width ))
            default:
                ctx?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width , height: image.size.height ))
        }

        // And now we just create a new UIImage from the drawing context
        let cgimg = ctx?.makeImage()
        var img: UIImage? = nil
        if let cgimg = cgimg {
            img = UIImage(cgImage: cgimg)
        }
        return img!
    }


    // MARK: - MIME type and file extension sniffing

    private func contentType(forImageData data: Data?) -> String? {
        var bytes: [UInt8] = []
        (data! as NSData).getBytes(&bytes, length: 12)

        if memcmp(bytes, &jpg, jpg.count) == 0 {
            return "image/jpeg"
        } else if memcmp(bytes, &heic, heic.count) == 0 {
            return "image/heic"
        } else if memcmp(bytes, &png, png.count) == 0 {
            return "image/png"
        } else if memcmp(bytes, &gif87a, gif87a.count) == 0 || memcmp(bytes, &gif89a, gif89a.count) == 0 {
            return "image/gif"
        } else if memcmp(bytes, &bmp, bmp.count) == 0 {
            return "image/x-ms-bmp"
        } else if memcmp(bytes, &psd, psd.count) == 0 {
            return "image/vnd.adobe.photoshop"
        } else if memcmp(bytes, &iff, iff.count) == 0 {
            return "image/iff"
        } else if memcmp(bytes, &webp, webp.count) == 0 {
            return "image/webp"
        } else if memcmp(bytes, &win_ico, win_ico.count) == 0 || memcmp(bytes, &win_cur, win_cur.count) == 0 {
            return "image/x-icon"
        } else if memcmp(bytes, &tif_ii, tif_ii.count) == 0 || memcmp(bytes, &tif_mm, tif_mm.count) == 0 {
            return "image/tiff"
        } else if memcmp(bytes, &jp2, jp2.count) == 0 {
            return "image/jp2"
        }
        return nil
    }

    private func fileExtension(forImageData data: Data?) -> String? {
        var bytes: [UInt8] = []
        (data! as NSData).getBytes(&bytes, length: 12)

        if memcmp(bytes, &jpg, jpg.count) == 0 {
            return "jpg"
        } else if memcmp(bytes, &heic, heic.count) == 0 {
            return "heic"
        } else if memcmp(bytes, &png, png.count) == 0 {
            return "png"
        } else if memcmp(bytes, &gif87a, gif87a.count) == 0 || memcmp(bytes, &gif89a, gif89a.count) == 0 {
            return "gif"
        } else if memcmp(bytes, &bmp, bmp.count) == 0 {
            return "bmp"
        } else if memcmp(bytes, &psd, psd.count) == 0 {
            return "psd"
        } else if memcmp(bytes, &iff, iff.count) == 0 {
            return "iff"
        } else if memcmp(bytes, &webp, webp.count) == 0 {
            return "webp"
        } else if memcmp(bytes, &win_ico, win_ico.count) == 0 {
            return "ico"
        } else if memcmp(bytes, &win_cur, win_cur.count) == 0 {
            return "cur"
        } else if memcmp(bytes, &tif_ii, tif_ii.count) == 0 || memcmp(bytes, &tif_mm, tif_mm.count) == 0 {
            return "tif"
        } else if memcmp(bytes, &jp2, jp2.count) == 0 {
            return "jp2"
        }
        return nil
    }

    // See https://en.wikipedia.org/wiki/List_of_file_signatures
    // https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

    // https://en.wikipedia.org/wiki/BMP_file_format
    var bmp: [UInt8] = "BM".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/GIF
    var gif87a: [UInt8] = "GIF87a".map { $0.asciiValue! }
    var gif89a: [UInt8] = "GIF89a".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    var heic: [UInt8] = [0x00, 0x00, 0x00, 0x18] + "ftypheic".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/ILBM
    var iff: [UInt8] = "FORM".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/JPEG
    var jpg: [UInt8] = [0xff, 0xd8, 0xff]
    
    // https://en.wikipedia.org/wiki/JPEG_2000
    var jp2: [UInt8] = [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    var png: [UInt8] = [0x89] + "PNG".map { $0.asciiValue! } + [0x0d, 0x0a, 0x1a, 0x0a]
    
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    var psd: [UInt8] = "8BPS".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/TIFF
    var tif_ii: [UInt8] = "II".map { $0.asciiValue! } + [0x2a, 0x00]
    var tif_mm: [UInt8] = "MM".map { $0.asciiValue! } + [0x00, 0x2a]
    
    // https://en.wikipedia.org/wiki/WebP
    var webp: [UInt8] = "RIFF".map { $0.asciiValue! }
    
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    var win_ico: [UInt8] = [0x00, 0x00, 0x01, 0x00]
    var win_cur: [UInt8] = [0x00, 0x00, 0x02, 0x00]
}
