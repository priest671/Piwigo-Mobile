//
//  PiwigoAlbumData.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "Model.h"
#import "CategoriesData.h"

@interface PiwigoAlbumData()

@property (nonatomic, strong) NSArray *imageList;
@property (nonatomic, strong) NSMutableDictionary *imageIds;

@property (nonatomic, assign) BOOL isLoadingMoreImages;
@property (nonatomic, assign) NSInteger lastImageBulkCount;
@property (nonatomic, assign) NSInteger onPage;

@end

@implementation PiwigoAlbumData

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.imageIds = [NSMutableDictionary new];
		
		self.isLoadingMoreImages = NO;
		self.lastImageBulkCount = [Model sharedInstance].imagesPerPage;
		self.onPage = 0;
	}
	return self;
}

-(void)loadAllCategoryImageDataForProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							  OnCompletion:(void (^)(BOOL completed))completion
{
	[self loopLoadImagesForProgress:progress
					   onCompletion:^(BOOL completed) {
		if(completion)
		{
			completion(YES);
		}
	}];
}

-(void)loopLoadImagesForProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
					onCompletion:(void (^)(BOOL completed))completion
{
	[self loadCategoryImageDataChunkForProgress:progress
								   OnCompletion:^(BOOL completed) {
		if(completed && self.imageList.count != self.numberOfImages)
		{
			[self loopLoadImagesForProgress:progress
							   onCompletion:completion];
		}
		else
		{
			if(completion)
			{
				completion(YES);
			}
		}
	}];
}

-(void)loadCategoryImageDataChunkForProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
								OnCompletion:(void (^)(BOOL completed))completion
{
	if(self.isLoadingMoreImages) return;
	
	self.isLoadingMoreImages = YES;
	
	[ImageService loadImageChunkForLastChunkCount:self.lastImageBulkCount
									  forCategory:self.albumId
										   onPage:self.onPage
								 ListOnCompletion:^(AFHTTPRequestOperation *operation, NSInteger count) {
									 
									 if(progress)
									 {
										 PiwigoAlbumData *downloadingCategory = [[CategoriesData sharedInstance] getCategoryById:self.albumId];
										 NSInteger numOfImgs = downloadingCategory.numberOfImages;
										 progress(self.onPage, numOfImgs);
									 }
									 
									 self.lastImageBulkCount = count;
									 self.onPage++;
									 self.isLoadingMoreImages = NO;
									 
									 if(completion)
									 {
										 completion(YES);
									 }
								 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
									 
									 self.isLoadingMoreImages = NO;
									 if(completion)
									 {
										 completion(NO);
									 }
								 }];
}

-(void)addImages:(NSArray*)images
{
	NSMutableArray *newImages = [NSMutableArray new];
	NSMutableArray *updateImages = [[NSMutableArray alloc] initWithArray:images];
	[images enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		PiwigoImageData *image = (PiwigoImageData*)obj;
		if(![self.imageIds objectForKey:image.imageId]) {
			[newImages addObject:image];
			[updateImages removeObject:image];
		}
	}];
	
	if(updateImages.count > 0)
	{
		NSMutableArray *newImageUpdateList = [[NSMutableArray alloc] initWithArray:self.imageList];
		for(PiwigoImageData *updateImage in updateImages)
		{
			for(PiwigoImageData *existingImage in self.imageList)
			{
				if([existingImage.imageId integerValue] == [updateImage.imageId integerValue])
				{
					[newImageUpdateList removeObject:existingImage];
					break;
				}
			}
		}
		
		// this image has already been added, so update it
		for(PiwigoImageData *updateImage in updateImages)
		{
			for(PiwigoImageData *existingImage in self.imageList)
			{
				if([existingImage.imageId integerValue]  == [updateImage.imageId integerValue])
				{
					[newImageUpdateList addObject:updateImage];
					break;
				}
			}
		}
		
		self.imageList = newImageUpdateList;
	}
	
	NSMutableArray *newImageList = [[NSMutableArray alloc] initWithArray:self.imageList];
	for(PiwigoImageData *imageData in newImages)
	{
		[newImageList addObject:imageData];
		[self.imageIds setValue:@(0) forKey:imageData.imageId];
	}
	self.imageList = newImageList;
}

-(void)sortImageList:(ImageListOrder)order
{
	// @TODO: change sort based on enum
	self.imageList = [self.imageList sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		PiwigoImageData *imgData1 = (PiwigoImageData*)obj1;
		PiwigoImageData *imgData2 = (PiwigoImageData*)obj2;
		
		return [imgData1.imageId integerValue] < [imgData2.imageId integerValue];
	}];
}

-(void)removeImage:(PiwigoImageData*)image
{
	NSMutableArray *newImageArray = [[NSMutableArray alloc] initWithArray:self.imageList];
	[newImageArray removeObject:image];
	self.imageList = newImageArray;
	
	[self.imageIds removeObjectForKey:image.imageId];
}

@end
