/*
 IQDatabaseManager

 The MIT License (MIT)
 
 Copyright (c) 2014 Mohd Iftekhar Qurashi
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "IQDatabaseManager.h"

/*************************************/

//Category Methods are used as private methods. Because these are used only inside the class. Not able to access from outside.
@interface IQDatabaseManager()

@property(nonatomic, strong, readonly) NSManagedObjectContext *mainContext;
@property(nonatomic, strong, readonly) NSManagedObjectContext *privateWriterContext;
@property(nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property(nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end


@implementation IQDatabaseManager
@synthesize mainContext = _mainContext, privateWriterContext = _privateWriterContext, persistentStoreCoordinator = _persistentStoreCoordinator, managedObjectModel = _managedObjectModel;

#pragma mark - Abstract method exceptions.
+(NSURL*)modelURL
{
    NSString *selector = NSStringFromSelector(_cmd);
    [NSException raise:NSInternalInconsistencyException format:@"%@ is abstract method You must override %@ method in %@ class and must not call [super %@].",selector,selector,NSStringFromClass([self class]),selector];
    return nil;
}

+(NSURL*)storeURL
{
    NSURL *applicationDocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [applicationDocumentsDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",NSStringFromClass([self class])]];
    
    return storeURL;
}

+(NSDictionary*)persistentStoreOptions
{
    // Set Core Data migration options
    // For automatic lightweight migration set NSMigratePersistentStoresAutomaticallyOption to YES
    // For automatic migration using a mapping model set NSInferMappingModelAutomaticallyOption to YES
    
    return @{NSMigratePersistentStoresAutomaticallyOption:@(YES),
             NSInferMappingModelAutomaticallyOption:@(YES)};
}

-(void)willStartInitialization
{
    
}

#pragma mark - Computed Properties

-(NSManagedObjectContext *)privateWriterContext
{
    if (_privateWriterContext == nil) {
        _privateWriterContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _privateWriterContext.name = @"PrivateWriterContext";
        [_privateWriterContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _privateWriterContext;
}

- (NSManagedObjectContext *)mainContext {
    if (_mainContext == nil) {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _mainContext.name = @"MainContext";
        _mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        _mainContext.parentContext = self.privateWriterContext;
    }
    return _mainContext;
}

-(NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator == nil) {
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    }
    return _persistentStoreCoordinator;
}

-(NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel == nil) {
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[self class] modelURL]];
    }
    return _managedObjectModel;
}

#pragma mark - Initialize and Save.
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self willStartInitialization];
        
        NSURL *storeURL = [[self class] storeURL];
        
        NSError *error = nil;
        NSPersistentStoreCoordinator *persistentStoreCoordinator = self.persistentStoreCoordinator;
        
        NSDictionary *optionsDictionary = [[self class] persistentStoreOptions];
        
        BOOL shouldAddPersistentStore = YES;
        for (NSPersistentStore * store in persistentStoreCoordinator.persistentStores)
        {
            if ([store.URL isEqual:storeURL])
            {
                shouldAddPersistentStore = NO;
            }
        }
        
        if (shouldAddPersistentStore)
        {
            if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:optionsDictionary error:&error])
            {
                NSLog(@"PersistentStore Error: %@, %@", error, [error userInfo]);
                
                //Removign file and now trying once again
                [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
                
                if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
                {
                    //If issue still not resolved then removing file and aborting.
                    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
                    abort();
                }
            }
        }
    }
    
    return self;
}

+(instancetype)sharedManager
{
    static NSMutableDictionary *sharedDictionary;
    
    if (sharedDictionary == nil)    sharedDictionary = [[NSMutableDictionary alloc] init];
    
    id sharedObject = [sharedDictionary objectForKey:NSStringFromClass([self class])];
    
    if (sharedObject == nil)
    {
        @synchronized(self) {
            
            //Again trying (May be set from another thread)
            sharedObject = [sharedDictionary objectForKey:NSStringFromClass([self class])];
            
            if (sharedObject)
            {
                return sharedObject;
            }
            else if (![NSStringFromClass(self) isEqualToString:NSStringFromClass([IQDatabaseManager class])])
            {
                sharedObject = [[self alloc] init];
                
                sharedDictionary[NSStringFromClass([self class])] = sharedObject;
            }
            else
            {
                [NSException raise:NSInternalInconsistencyException format:@"You must subclass %@",NSStringFromClass([IQDatabaseManager class])];
                return nil;
            }
        }
    }
    
    return sharedObject;
}

-(BOOL)saveMainContextSynchronously
{
    __weak typeof(self) weakSelf = self;
    __block BOOL isSaved = NO;
    
    [_mainContext performBlockAndWait:^{
        
        if ([weakSelf.mainContext hasChanges])
        {
            NSError *error = nil;
            
            isSaved = [weakSelf.mainContext save:&error];
            
            if (error)
            {
                NSLog(@"Error Saving main context: %@",error);
            }
        }
    }];
    
    return isSaved;
}

//Save main context
-(void)saveMainContext:(void(^)(BOOL success, NSError *error))completionHandler
{
    __weak typeof(self) weakSelf = self;
    
    [_mainContext performBlock:^{
        
        if ([weakSelf.mainContext hasChanges])
        {
            NSError *error = nil;
            BOOL isSaved = NO;
            
            isSaved = [weakSelf.mainContext save:&error];
            
            if (error)
            {
                NSLog(@"Error Saving main context: %@",error);
            }
            
            if (completionHandler)
            {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionHandler(isSaved,error);
                }];
            }
        }
        else
        {
            if (completionHandler)
            {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionHandler(NO,nil);
                }];
            }
        }
    }];
}

//Save writer context
-(void)saveWriterContext:(void(^)(BOOL success, NSError *error))completionHandler
{
    __weak typeof(self) weakSelf = self;
    
    [_privateWriterContext performBlock:^{
        
        if ([weakSelf.privateWriterContext hasChanges])
        {
            NSError *error = nil;
            BOOL isSaved = NO;
            
            [weakSelf.privateWriterContext save:&error];
            
            if (error)
            {
                NSLog(@"Error Saving private context: %@",error);
            }
            
            if (completionHandler)
            {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionHandler(isSaved,error);
                }];
            }
        }
        else
        {
            if (completionHandler)
            {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionHandler(NO,nil);
                }];
            }
        }
    }];
}

-(void)saveMainAndWriterContext
{
    [self saveMainContext:^(BOOL success, NSError *error) {
        [self saveWriterContext:nil];
    }];
}

-(NSArray*)tableNames
{
    NSDictionary *entities = [_managedObjectModel entitiesByName];
    return [entities allKeys];
}

-(NSDictionary*)attributesForTable:(NSString*)tableName
{
    NSEntityDescription *description = [[_managedObjectModel entitiesByName] objectForKey:tableName];

    NSDictionary *properties = [description propertiesByName];
    NSArray *allKeys = [properties allKeys];
    
    NSMutableDictionary *attributeDictionary = [[NSMutableDictionary alloc] init];
    for (NSString *key in allKeys)
    {
        if ([[properties objectForKey:key] attributeType] == NSTransformableAttributeType)
        {
            attributeDictionary[key] = @"id";
        }
        else
        {
            NSString *attributeClassName = [[properties objectForKey:key] attributeValueClassName];
            
            if (attributeClassName)
            {
                attributeDictionary[key] = attributeClassName;
            }
        }
    }
    
    return attributeDictionary;
}



#pragma mark - Fetch Records

- (NSArray *)allObjectsFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName
                      wherePredicate:predicate
                  includeSubentities:NO
                      sortDescriptor:descriptor
                           inContext:context];
}

- (NSArray *)allObjectsFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate includeSubentities:(BOOL)includeSubentities sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    context = context ?: _mainContext;
    
    //Creating fetch request object for fetching records.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:tableName];
    fetchRequest.includesSubentities = includeSubentities;
#if TARGET_IPHONE_SIMULATOR
    [fetchRequest setReturnsObjectsAsFaults:NO];
#endif
    
    if (predicate)  [fetchRequest setPredicate:predicate];
    if (descriptor) [fetchRequest setSortDescriptors:@[descriptor]];
    
    __block NSArray *objects = nil;
    objects = [context executeFetchRequest:fetchRequest error:nil];
    
    return objects;
}

- (NSArray *)allObjectsFromTable:(NSString*)tableName sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName wherePredicate:nil sortDescriptor:descriptor inContext:context];
}

- (NSArray *)allDictionariesFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    context = context ?: _mainContext;
    
    //Creating fetch request object for fetching records.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:tableName];
    fetchRequest.includesSubentities = NO;
    [fetchRequest setResultType:NSDictionaryResultType];
    
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:tableName inManagedObjectContext:context];
    NSArray *allRelationships = entityDescription.relationshipsByName.allKeys;
    allRelationships = [allRelationships arrayByAddingObjectsFromArray:entityDescription.attributesByName.allKeys];
    [fetchRequest setPropertiesToFetch:allRelationships];
    
#if TARGET_IPHONE_SIMULATOR
    [fetchRequest setReturnsObjectsAsFaults:NO];
#endif
    
    if (predicate)  [fetchRequest setPredicate:predicate];
    if (descriptor) [fetchRequest setSortDescriptors:@[descriptor]];
    
    __block NSArray *objects = nil;
    objects = [context executeFetchRequest:fetchRequest error:nil];
    
    return objects;
}

- (NSArray *)allDictionariesFromTable:(NSString*)tableName sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    return [self allDictionariesFromTable:tableName wherePredicate:nil sortDescriptor:descriptor inContext:context];
}

- (NSArray *)allObjectsFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName wherePredicate:predicate sortDescriptor:nil inContext:context];
}

- (NSArray *)allObjectsFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate includingSubentities:(BOOL)includeSubentities inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName wherePredicate:predicate includeSubentities:includeSubentities sortDescriptor:nil inContext:context];
}

-(NSArray*)allObjectsFromTable:(NSString*)tableName inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName wherePredicate:nil sortDescriptor:nil inContext:context];
}

- (NSArray *)distictObjectsForAttribute:(NSString*)attribute forTableName:(NSString*)tableName predicate:(NSPredicate*)predicate inContext:(NSManagedObjectContext*)context;
{
    return [self distictObjectsForAttribute:attribute
                               forTableName:tableName
                                  predicate:predicate
                         includeSubentities:NO
                                  inContext:context];
}

- (NSArray *)distictObjectsForAttribute:(NSString*)attribute forTableName:(NSString*)tableName predicate:(NSPredicate*)predicate includeSubentities:(BOOL)includeSubentities inContext:(NSManagedObjectContext*)context
{
    context = context ?: _mainContext;
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:tableName];
    fetchRequest.includesSubentities = includeSubentities;
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:tableName inManagedObjectContext:context];
    
    if (predicate)  [fetchRequest setPredicate:predicate];
    
    // Required! Unless you set the resultType to NSDictionaryResultType, distinct can't work.
    // All objects in the backing store are implicitly distinct, but two dictionaries can be duplicates.
    // Since you only want distinct names, only ask for the 'name' property.
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.propertiesToFetch = @[[[entity propertiesByName] objectForKey:attribute]];
    fetchRequest.returnsDistinctResults = YES;
    
    __block NSArray *objects = nil;
    objects = [context executeFetchRequest:fetchRequest error:nil];
    
    return objects;
}

/***Key Value predicate***/
- (NSArray *)allObjectsFromTable:(NSString*)tableName where:(NSString*)key equals:(id)value sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    if (key && value)
    {
        if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSDate class]])
        {
            NSPredicate *predicate;
            if (key && value)   predicate = [NSPredicate predicateWithFormat:@"self.%@ == %@",key,value];
            return [self allObjectsFromTable:tableName wherePredicate:predicate sortDescriptor:descriptor inContext:context];
        }
        else
        {
            NSArray *allObjects = [self allObjectsFromTable:tableName wherePredicate:nil sortDescriptor:descriptor inContext:context];
            
            NSMutableArray *filteredArray = [[NSMutableArray alloc] init];
            
            for (NSManagedObject *object in allObjects)
                if ([[object valueForKey:key] isEqual:value])
                    [filteredArray addObject:object];

            return filteredArray;
        }
    }
    else
    {
        return [self allObjectsFromTable:tableName wherePredicate:nil sortDescriptor:descriptor inContext:context];
    }
}

- (NSArray *)allObjectsFromTable:(NSString*)tableName where:(NSString*)key equals:(id)value inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName where:key equals:value sortDescriptor:nil inContext:context];
}


- (NSArray *)allObjectsFromTable:(NSString*)tableName where:(NSString*)key contains:(id)value sortDescriptor:(NSSortDescriptor*)descriptor inContext:(NSManagedObjectContext*)context
{
    NSPredicate *predicate;
    if (key && value)
    {
        NSString *predicateString = [NSString stringWithFormat:@"self.%@ contains[c] \"%@\"",key,value];
        predicate = [NSPredicate predicateWithFormat:predicateString];
    }
    
    return [self allObjectsFromTable:tableName wherePredicate:predicate sortDescriptor:descriptor inContext:context];
}

- (NSArray *)allObjectsFromTable:(NSString*)tableName where:(NSString*)key contains:(id)value inContext:(NSManagedObjectContext*)context
{
    return [self allObjectsFromTable:tableName where:key contains:value sortDescriptor:nil inContext:context];
}


/*First object*/
- (NSManagedObject *)firstObjectFromTable:(NSString*)tableName inContext:(NSManagedObjectContext*)context
{
    return [self firstObjectFromTable:tableName wherePredicate:nil inContext:context];
}

- (NSManagedObject *)firstObjectFromTable:(NSString*)tableName where:(NSString*)key equals:(id)value inContext:(NSManagedObjectContext*)context
{
    if (key && value && ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSDate class]]))
    {
        NSPredicate *predicate;
        if (key && value)   predicate = [NSPredicate predicateWithFormat:@"self.%@ == %@",key,value];
        
        return [self firstObjectFromTable:tableName wherePredicate:predicate inContext:context];
    }
    else
    {
        return [self firstObjectFromTable:tableName wherePredicate:nil inContext:context];
    }
}

- (NSManagedObject *)firstObjectFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate inContext:(NSManagedObjectContext*)context
{
    return [self firstObjectFromTable:tableName
                       wherePredicate:predicate
                   includeSubentities:NO
                            inContext:context];
}

- (NSManagedObject *)firstObjectFromTable:(NSString*)tableName wherePredicate:(NSPredicate*)predicate includeSubentities:(BOOL)includeSubentities inContext:(NSManagedObjectContext*)context
{
    context = context ?: _mainContext;
    
    //Creating fetch request object for fetching records.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:tableName];
    fetchRequest.includesSubentities = includeSubentities;
    
    if (predicate)  [fetchRequest setPredicate:predicate];
    
    fetchRequest.fetchLimit = 1;
    
    __block NSManagedObject* object;
    
    NSArray *objects = [context executeFetchRequest:fetchRequest error:nil];
    
    object = [objects firstObject];
    
    return object;
}

#pragma mark - Insert & Update Records

//Update object
- (NSManagedObject*)updateRecord:(NSManagedObject*)object withAttribute:(NSDictionary*)dictionary
{
    NSArray *allValidKeys = object.entity.attributesByName.allKeys;
    
    for (NSString *aKey in allValidKeys)
    {
        id value = [dictionary objectForKey:aKey];
        
        if (value && [value isKindOfClass:[NSNull class]] == NO)
        {
            [object setValue:value forKey:aKey];
        }
        else if ([value isKindOfClass:[NSNull class]])
        {
            [object setValue:nil forKey:aKey];
        }
    }
    
    return object;
}

//Insert object
- (NSManagedObject*)insertRecordInTable:(NSString*)tableName withAttribute:(NSDictionary*)dictionary inContext:(NSManagedObjectContext*)context
{
    context = context ?: _mainContext;
    
    NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:tableName inManagedObjectContext:context];
    
    return [self updateRecord:object withAttribute:dictionary];
}

- (NSManagedObject*)insertRecordWithoutContextInTable:(NSString*)tableName withAttribute:(NSDictionary*)dictionary
{
    NSEntityDescription *entity = [NSEntityDescription entityForName:tableName inManagedObjectContext:self.mainContext];
    NSManagedObject *unassociatedObject = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:nil];
    
    return [self updateRecord:unassociatedObject withAttribute:dictionary];
}

//(Insert || Update) object
- (NSManagedObject*)insertRecordInTable:(NSString*)tableName withAttribute:(NSDictionary*)dictionary updateOnExistKey:(NSString*)key equals:(id)value inContext:(NSManagedObjectContext*)context
{
    context = context ?: _mainContext;
    
    NSManagedObject *object = [self firstObjectFromTable:tableName where:key equals:value inContext:context];
    
    if (object)
    {
        return [self updateRecord:object withAttribute:dictionary];
    }
    else
    {
        return [self insertRecordInTable:tableName withAttribute:dictionary inContext:context];
    }
}

#pragma mark - Delete Records
//Delete all records in table.
-(void)flushTable:(NSString*)tableName inContext:(NSManagedObjectContext*)context
{
    NSArray *records = [self allObjectsFromTable:tableName inContext:context];
    
    for (NSManagedObject *object in records)
    {
        [object.managedObjectContext deleteObject:object];
    }
}

//Delete object
-(void)deleteRecord:(NSManagedObject*)object
{
    [object.managedObjectContext deleteObject:object];
}

-(void)performBlockAndSaveNewPrivateContext:(void(^)(NSManagedObjectContext* privateContext))newPrivateContextHandler saveCompletion:(void(^)(void))completionHandler
{
    NSManagedObjectContext *privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    privateContext.name = @"PrivateContext";
    privateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    [privateContext setParentContext:self.mainContext];
    
    [privateContext performBlock:^{
        
        if (newPrivateContextHandler)
        {
            newPrivateContextHandler(privateContext);
        }
        
        //Save
        if ([privateContext hasChanges])
        {
            NSError *error = nil;
            
            if (![privateContext save:&error]) {
                NSLog(@"Error saving: %@", error);
                NSLog(@"CallStack: %@", [NSThread callStackSymbols]);
            }
        }
        
        [self saveMainContext:^(BOOL success, NSError *error) {
            //Main Thread callback after saving main context.
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                
                if (completionHandler)
                {
                    completionHandler();
                }
            }];
            
            [self saveWriterContext:nil];
        }];
    }];
}

@end
