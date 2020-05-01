//
//  ClearCache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

@objc
class ClearCache: NSObject {
    
    @objc
    class func clearAllCache() {
        
//        let tagsProvider : TagsProvider = TagsProvider(completionClosure: {})
        let tagsProvider : TagsProvider = TagsProvider()
        tagsProvider.clearTags()

//        let locationsProvider : TagsProvider = TagsProvider(completionClosure: {})
        let locationsProvider : LocationsProvider = LocationsProvider()
        locationsProvider.clearLocations()

        // Data
        TagsData.sharedInstance().clearCache()
        CategoriesData.sharedInstance().clearCache()

        // URL requests
        URLCache.shared.removeAllCachedResponses()
    }
}
