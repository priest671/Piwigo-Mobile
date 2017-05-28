//
//  TagsService.h
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

@interface TagsService : NetworkHandler

+(NSURLSessionTask*)getTagsOnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

@end
