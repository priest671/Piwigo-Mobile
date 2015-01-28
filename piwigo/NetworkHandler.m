//
//  NetworkHandler.m
//  WordSearch
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import "NetworkHandler.h"
#import "Model.h"

NSString * const kPiwigoSessionLogin = @"format=json&method=pwg.session.login";
NSString * const kPiwigoSessionGetStatus = @"format=json&method=pwg.session.getStatus";
NSString * const kPiwigoCategoriesGetList = @"format=json&method=pwg.categories.getList";
NSString * const kPiwigoCategoriesGetImages = @"format=json&method=pwg.categories.getImages&cat_id={albumId}&per_page={perPage}&page={page}&order={order}";
NSString * const kPiwigoImagesUpload = @"format=json&method=pwg.images.upload";

@interface NetworkHandler()

@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSDictionary *dictionary;
@property (nonatomic, assign) SEL action;
@property (nonatomic, copy) SuccessBlock block;

@end

@implementation NetworkHandler


// path: format={param1}
// URLParams: {@"param1" : @"hello" }
+(AFHTTPRequestOperation*)post:(NSString*)path
				 URLParameters:(NSDictionary*)urlParams
					parameters:(NSDictionary*)parameters
					   success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
					   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
		
	AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
	NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
	[jsonAcceptableContentTypes addObject:@"text/plain"];
	jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
	manager.responseSerializer = jsonResponseSerializer;
	
	AFHTTPRequestOperation *operation = [manager POST:[NetworkHandler getURLWithPath:path andURLParams:urlParams]
			  parameters:parameters
				 success:success
				 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
					 if(fail) {
						 fail(operation, error);
					 }
				 }];
	
//	[[Model sharedInstance].piwigoQueue addOperation:operation];

	return operation;
}

+(AFHTTPRequestOperation*)postMultiPart:(NSString*)path
							 parameters:(NSDictionary*)parameters
							   success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
							   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	
	AFHTTPRequestSerializer *request = [AFHTTPRequestSerializer serializer];
	[request setValue:@"multipart/form-data" forHTTPHeaderField:@"Content-Type"];
	manager.requestSerializer = request;
	
	AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
	NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
	[jsonAcceptableContentTypes addObject:@"text/plain"];
	jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
	manager.responseSerializer = jsonResponseSerializer;
	
	
	return [manager POST:[NetworkHandler getURLWithPath:path andURLParams:nil]
			  parameters:nil
constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
	
	NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
	[mutableHeaders setValue:[NSString stringWithFormat:@"multipart/form-data"] forKey:@"Content-Type"];
	
	[formData appendPartWithFileData:[parameters objectForKey:@"data"]
								name:@"file"
							fileName:@"blob"
							mimeType:@"image/jpeg"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:@"name"] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"name"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:@"chunk"] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"chunk"];
	[formData appendPartWithFormData:[[parameters objectForKey:@"chunks"] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"chunks"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:@"album"] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"category"];
//	[formData appendPartWithFormData:[@"0" dataUsingEncoding:NSUTF8StringEncoding]
//								name:@"level"];
	
	[formData appendPartWithFormData:[[Model sharedInstance].pwgToken dataUsingEncoding:NSUTF8StringEncoding]
								name:@"pwg_token"];
	}
				 success:success
				 failure:fail];
}



+(NSString*)getURLWithPath:(NSString*)path andURLParams:(NSDictionary*)params
{
	NSString *url = [NSString stringWithFormat:@"http://%@/ws.php?%@", [Model sharedInstance].serverName, path];

	for(NSString *parameter in params)
	{
		NSString *replaceMe = [NSString stringWithFormat:@"{%@}", parameter];
		NSString *toReplace = [NSString stringWithFormat:@"%@", [params objectForKey:parameter]];
		url = [url stringByReplacingOccurrencesOfString:replaceMe withString:toReplace];
	}
	
	return url;
}

+(void)showConnectionError:(NSError*)error
{
	UIAlertView *connectionError = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
															  message:[NSString stringWithFormat:@"%@", [error.userInfo objectForKey:@"NSLocalizedDescription"]]
															 delegate:nil
													cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Okay")
													otherButtonTitles:nil];
	[connectionError show];
}

@end
