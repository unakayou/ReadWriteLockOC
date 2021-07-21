//
//  ViewController.m
//  Test_OC_App
//
//  Created by 高莹莹 on 2021/5/10.
//

#import "ViewController.h"

@interface ViewController ()
@property (assign, nonatomic) int reader_count;                         // 读者数量
@property (strong, nonatomic) dispatch_semaphore_t mutex_rw;            // 读写锁
@property (strong, nonatomic) dispatch_semaphore_t mutex_reader_count;  // 读者数量锁
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mutex_rw = dispatch_semaphore_create(1);
    self.mutex_reader_count = dispatch_semaphore_create(1);
    
    dispatch_queue_t launchQueue = dispatch_queue_create("launchQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(launchQueue, ^{
        [self readAction];
    });
    
    dispatch_async(launchQueue, ^{
        [self writeAction];
    });
}

// 每隔1秒尝试写, 写入耗时1秒
- (void)writeAction {
    while (1) {
        dispatch_async(dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL), ^{
            dispatch_semaphore_wait(self.mutex_rw, DISPATCH_TIME_FOREVER);
            NSLog(@"写入中... - %@",[NSThread currentThread]);
            sleep(1);

            dispatch_semaphore_signal(self.mutex_rw);
            NSLog(@"写完了");
        });
        sleep(1);
    }
}

// 尝试让5个人读,读取时间1秒
- (void)readAction {
    for (int i = 0; i < 5; i++) {
        dispatch_async(dispatch_queue_create("concurrentQueue", DISPATCH_QUEUE_CONCURRENT), ^{
            
            // 尝试拿 读者数信号量
            dispatch_semaphore_wait(self.mutex_reader_count, DISPATCH_TIME_FOREVER);
            
            if (self.reader_count == 0) {
                // 如果读者数量是0, 说明: 1.没有人读写 2.没人读,有人在写 (单写)
                // 所以尝试获取 读写信号量
                dispatch_semaphore_wait(self.mutex_rw, DISPATCH_TIME_FOREVER);
            }
            
            // 如果已经有人在读了,则直接读,并且读者数量+1 (多读)
            self.reader_count++;
            dispatch_semaphore_signal(self.mutex_reader_count);
            
            NSLog(@"读者%c读取中... - %@", self.reader_count + 64, [NSThread currentThread]);
            sleep(1);
            
            // 读完了
            dispatch_semaphore_wait(self.mutex_reader_count, DISPATCH_TIME_FOREVER);
            NSLog(@"读者%c完毕 - %@", self.reader_count + 64, [NSThread currentThread]);
            self.reader_count--;
            
            if (self.reader_count == 0) {
                dispatch_semaphore_signal(self.mutex_rw);
                NSLog(@"所有人都读取完毕 ✅");
                [self readAction];  // 再来5个读
            }
            dispatch_semaphore_signal(self.mutex_reader_count);
        });
    }
}

@end

