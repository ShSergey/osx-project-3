//
//  AppDelegate.m
//  DNA-project-3
//
//  Created by Sergey on 22.12.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "Cell.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize goalDNATextField;
@synthesize pauseButton;
@synthesize startButton;
@synthesize loadButton;
@synthesize populationSizeTextField;
@synthesize dnaLengthTextField;
@synthesize mutationRateTextField;
@synthesize populationSizeSlider;
@synthesize dnaLengthSlider;
@synthesize mutationRateSlider;

@synthesize generationTextField;
@synthesize bestMatchTextField;

//@synthesize undoManager;

static void *RMDocumentKVOContext;

- (NSUndoManager*) windowWillReturnUndoManager: (NSWindow*) window {
    return undoManager;
}

-(void) changeKeyPath:(NSString*)keyPath ofObject:(id)obj toValue:(id)newValue {
    [obj setValue:newValue forKeyPath:keyPath];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != &RMDocumentKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
    if (oldValue == [NSNull null])
        oldValue = nil;
    [[undoManager prepareWithInvocationTarget:self] changeKeyPath:keyPath ofObject:object toValue:oldValue];
    [undoManager setActionName:@"Edit"];
}

-(void)dealloc {
    [self removeObserver:self forKeyPath:@"populationSize"];
    [self removeObserver:self forKeyPath:@"dnaLength"];
    [self removeObserver:self forKeyPath:@"mutationRate"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

}

-(void)setPopulationSize:(int) x {
    populationSize = x;
}

-(NSInteger)populationSize  {
    return populationSize;
}

-(void)setDnaLength:(int) x {
    dnaLength = x;
    [goalDNA fillDNALenght:dnaLength];    
    [goalDNATextField setStringValue:[goalDNA stringDNA]];   
}

-(NSInteger)dnaLength{
    return dnaLength;
}

-(void)setMutationRate:(int) x {
    mutationRate = x;    
}

-(NSInteger)mutationRate {
    return mutationRate;
}

-(void)setGeneration:(int) x {
    generation = x;
}

-(NSInteger)generation {
    return generation;
}

-(void)setBestHammingDistance:(NSInteger)x {
    bestHammingDistance = x;
}

-(NSInteger)bestHammingDistance {
    return bestHammingDistance;
}


-(void)setVisible:(BOOL) v {
    [populationSizeTextField setEnabled:!v];
    [dnaLengthTextField setEnabled:!v];
    [mutationRateTextField setEnabled:!v];
    
    [populationSizeSlider setEnabled:!v];
    [dnaLengthSlider setEnabled:!v];
    [mutationRateSlider setEnabled:!v];
    
    [loadButton setEnabled:!v];
    [startButton setEnabled:!v];
    
     /*3. сделать активной кнопку Pause. */
    [pauseButton setEnabled:v];
}

-(void)processEvolution{
    /*2. сделать неактивными (disabled) три первых text field'а и их ползунки,
     а также кнопки "Start evolution" и "Load goal DNA"*/
    startEvolution = YES;
    [self setVisible:startEvolution];
    
    [self willChangeValueForKey:@"generation"];
    generation = 0;
    [self didChangeValueForKey:@"generation"];
    /*1. создать случайную популяцию ДНК. Размер популяции = значение первого text field'а.
     Размер каждого ДНК = значение второго text field'а.*/

    [population removeAllObjects]; //
    // заполняем новыми популяциями
    for (int i=0; i<populationSize; i++) {
        Cell* myCell = [[Cell alloc] init];
        [myCell fillDNALenght:dnaLength];
        [population addObject:myCell];
    }
    /*4. начать эволюцию.*/
    while (startEvolution == YES) {
        [self willChangeValueForKey:@"generation"];
        generation++;
        [self didChangeValueForKey:@"generation"];
       // NSLog(@"генерация = %i",generation);
        //4.1 Отсортировать популяцию по близости (hamming distance) к Goal DNA
        // вычисляем различия hammingDistance чтобы по нему отсортировать
        for (int i=0; i<populationSize; i++) {
            [[population objectAtIndex:i] calculateHammingDistance:goalDNA];
        }
        // сортируем объекты с массиве population по значению  hammingDistance
        // создаем объект класса NSSortDescriptor, который будет использоваться для сортировки
        NSSortDescriptor *aSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"hammingDistance" ascending:YES comparator:^(id obj1, id obj2) {
        
            if ([obj1 integerValue] > [obj2 integerValue]) {
                return (NSComparisonResult)NSOrderedDescending;
            }
            if ([obj1 integerValue] < [obj2 integerValue]) {
                return (NSComparisonResult)NSOrderedAscending;
            }
            return (NSComparisonResult)NSOrderedSame;
        }];
        // непостредственно сортируем массив, используя ранее созданные десктрипторы
        NSMutableArray* sortedArray = [NSMutableArray arrayWithArray:[population sortedArrayUsingDescriptors:[NSArray arrayWithObject:aSortDescriptor]] ];
        [population removeAllObjects];
        for (int i=0; i<populationSize; i++) {
            [population addObject:[sortedArray objectAtIndex:i]];
        }
        //4.2 Остановить эволюцию если есть ДНК полностью совпадающее с Goal DNA (hamming distance = 0)
        // вычисляем различия hammingDistance чтобы по нему отсортировать
        [self willChangeValueForKey:@"bestHammingDistance"];
        bestHammingDistance = 100 - [[population objectAtIndex:0] hammingDistance];
        [self didChangeValueForKey:@"bestHammingDistance"];
        
        if (bestHammingDistance == 100) {
            startEvolution = NO;
            [self setVisible:startEvolution];
            return;
        }
        //4.3 Скрестить кандидатов из топ 50% и заменить результатом оставшиеся 50%.
        //4.3.1 Взять два случайных ДНК
        for (int i=populationSize/2; i<populationSize; i++) {
            int num_int1 = arc4random() % dnaLength / 2;  // 1 из топ 50%
            int num_int2 = arc4random() % dnaLength / 2;  // 2 из топ 50%
            // смотрим чтобы ячейки не совпали
            while (num_int1 == num_int2)
                num_int2 = arc4random() % dnaLength / 2;  // 2 из топ 50%
            //4.3.2 Скомбинировать их содержание чтобы получить новую ДНК.
            NSMutableArray* NewDNA = [[NSMutableArray alloc]init];
            NewDNA = [[population objectAtIndex:num_int1] crossing:[population objectAtIndex:num_int2]];
            [[[population objectAtIndex:i] DNA] removeAllObjects];
            [[[population objectAtIndex:i] DNA] addObjectsFromArray:NewDNA];
        }
    
        //4.4 Мутировать популяцию (как в проекте 1) используя значение процента мутирования из третьего text field'а.
        for (int i=0; i<=populationSize-1; ++i)
            [[population objectAtIndex:i] mutate:mutationRate];
    
    }
}


- (IBAction)startEvolution:(id)sender {
    if ([[goalDNA DNA] count] != dnaLength) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Длина целевой ДНК и ДНК популяции не равны !"];
        [alert setInformativeText:@"Измените размер ДНК полуляции или загрузите другое целевое ДНК"];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        return;
    }
     [self performSelectorInBackground:@selector(processEvolution) withObject:nil];//стартуем новый поток
  }

- (IBAction)pauseEvolution:(id)sender {
    startEvolution = NO;
    //Эволюция идет пока не нажата кнопка Pause ИЛИ пока не достигнута цель эволюции.
    [self setVisible:startEvolution];
}

- (IBAction)loadGoalDNA:(id)sender {
    NSURL* filePath;
    NSOpenPanel *fileBrowser = [NSOpenPanel openPanel];
    [fileBrowser setCanChooseFiles:YES];
    [fileBrowser setCanChooseDirectories:YES];
    if ([fileBrowser runModal] == NSOKButton) {
        NSArray *files = [fileBrowser URLs];
        for ( int i = 0; i < [files count]; i++ ) {
            filePath = [files objectAtIndex:i];
            NSString *fileContents = [NSString stringWithContentsOfURL:filePath encoding:NSUTF8StringEncoding error:nil];
      //      NSLog(@"%@",fileContents);
            NSInteger maxDNAlenght = MAXDNALENGTH;
            if ([fileContents length]>maxDNAlenght) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"В загружаемом файле превышена максимальная длина ДНК !"];
                [alert setInformativeText:@"Выберите файл с нужной структурой ДНК"];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert runModal];
                return;
            }
            if ([goalDNA fillDNAString:fileContents]) {
                [goalDNATextField setStringValue:fileContents];
            }
            else {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"В загружаемом файле недопустимый символ !"];
                [alert setInformativeText:@"Выберите файл с нужной структурой ДНК"];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert runModal];
            }
        }
    }
}

-(id)init {
    NSLog(@"init");
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"populationSize" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
        [self addObserver:self forKeyPath:@"dnaLength" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
        [self addObserver:self forKeyPath:@"mutationRate" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
        undoManager = [[NSUndoManager alloc] init];
        
        [self willChangeValueForKey:@"populationSize"];
        populationSize = DEFAULTPOPULATIONSIZE;
        [self didChangeValueForKey:@"populationSize"];
        
        [self willChangeValueForKey:@"dnaLength"];
        dnaLength = DEFAULTDNALENGTH;
        [self didChangeValueForKey:@"dnaLength"];
        
        [self willChangeValueForKey:@"mutationRate"];
        mutationRate = DEFAULTMUTATIONRATE;
        [self didChangeValueForKey:@"mutationRate"];
        
        [self willChangeValueForKey:@"generation"];
        generation = 0;
        [self didChangeValueForKey:@"generation"];
        
        goalDNA = [[Cell alloc] init ];
        [goalDNA fillDNALenght:dnaLength];
        [goalDNATextField setStringValue:[goalDNA stringDNA]];
        
        population = [[NSMutableArray alloc] init];
        startEvolution = NO;
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)aCoder {
    NSLog(@"encodeWithCoder");
   [aCoder encodeInteger:populationSize forKey:@"populationSize"];
   [aCoder encodeInteger:dnaLength forKey:@"dnaLength"];
   [aCoder encodeInteger:mutationRate forKey:@"mutationRate"];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    NSLog(@"initWithCoder");
    self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"populationSize" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
        [self addObserver:self forKeyPath:@"dnaLength" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
        [self addObserver:self forKeyPath:@"mutationRate" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
        undoManager = [[NSUndoManager alloc] init];

        [self willChangeValueForKey:@"populationSize"];
        populationSize = [aDecoder decodeIntegerForKey:@"populationSize"];
        [self didChangeValueForKey:@"populationSize"];
        
        [self willChangeValueForKey:@"dnaLength"];
        dnaLength = [aDecoder decodeIntegerForKey:@"dnaLength"];
        [self didChangeValueForKey:@"dnaLength"];

        [self willChangeValueForKey:@"mutationRate"];
        mutationRate = [aDecoder decodeIntegerForKey:@"mutationRate"];
        [self didChangeValueForKey:@"mutationRate"];
        
        goalDNA = [[Cell alloc] init ];
        [goalDNA fillDNALenght:dnaLength];
        [goalDNATextField setStringValue:[goalDNA stringDNA]];
        
        population = [[NSMutableArray alloc] init];
        startEvolution = NO;
    }
    return self;
}
 

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSLog(@"dataOfType");
    [[populationSizeTextField window] endEditingFor:nil];
    [[populationSizeSlider window] endEditingFor:nil];
    [[dnaLengthTextField window] endEditingFor:nil];
    [[dnaLengthSlider window] endEditingFor:nil];
    [[mutationRateTextField window] endEditingFor:nil];
    [[mutationRateSlider window] endEditingFor:nil];
    return [NSKeyedArchiver archivedDataWithRootObject:population];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSLog(@"readFromData");
    NSMutableArray *newArray = nil;
    @try {
        newArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (NSException *e) {
        if (outError) {
            NSDictionary *d = [NSDictionary dictionaryWithObject:@"The file is valid" forKey:NSLocalizedFailureReasonErrorKey];
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:d];
            return NO;
        }
    }
    population = newArray;
    return YES;
}

+ (BOOL)autosavesInPlace
{
    return YES;
}



    
@end
