//
//  UploadViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PHAssetCollection;

@interface UploadViewController : UIViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId andGroupAsset:(PHAssetCollection*)groupAsset;

@end
