//
//  PlayVC.m
//  iOSCamera
//
//  Created by BWF-HHW on 16/8/16.
//  Copyright © 2016年 HHW. All rights reserved.
//

#import "PlayVC.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>


@interface PlayVC (){
    AVPlayer *_player;
    AVPlayerItem *_playItem;
    AVPlayerLayer *_playerLayer;
    AVPlayerLayer *_fullPlayer;
    BOOL _isPlaying;
}

@property (strong, nonatomic) IBOutlet UIButton *saveBtn;

@end

@implementation PlayVC

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_player pause];
    _player = nil;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self create];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:)name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    //时间差
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
       // self.saveBtn.enabled = YES;
    });
    
}


- (void)create
{
    _playItem = [AVPlayerItem playerItemWithURL:self.videoUrl];
    _player = [AVPlayer playerWithPlayerItem:_playItem];
    _playerLayer =[AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.frame = CGRectMake(200, 200, 100, 100);
    _playerLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//视频填充模式
    [self.view.layer addSublayer:_playerLayer];
    [_player play];
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (!_isPlaying) {
        _playerLayer.frame = [UIScreen mainScreen].bounds;
    }else{
        _playerLayer.frame = CGRectMake(200, 200, 100, 100);
    }
    _isPlaying = !_isPlaying;
}

-(void)playbackFinished:(NSNotification *)notification
{
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player play];
}


#pragma mark 保存压缩
- (NSURL *)compressedURL
{
    //NSLog(@"时间戳----%ld", time(NULL));
    
    return [NSURL fileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) lastObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld_compressed.mp4", time(NULL)]]];
}

- (CGFloat)fileSize:(NSURL *)path
{
    return [[NSData dataWithContentsOfURL:path] length]/1024.00 /1024.00;
}

// 压缩视频
- (IBAction)compressVideo:(id)sender{
    NSLog(@"开始压缩,压缩前大小 %f MB",[self fileSize:self.videoUrl]);
    
    self.saveBtn.enabled = NO;
    //为了创建一个由URL标识的代表任何资源的assert对象，可以使用AVURLAssert，最简单的是从文件里创建一个assert对象：
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:self.videoUrl options:nil];
    
    //你可以对视频进行转码、裁剪，通过使用AVAssetExportSession对象。
    /**
     *  一个export session是一个控制对象，可以异步的生成一个asset。可以用你需要生成的asset和presetName来初始化一个session，presetName指明你要生成的asset的属性。接下来你可以配置export session，比如可以指定输出的URL和文件类型，以及其他的设置，比如metadata等等。
        你可以先检测设置的preset是否可用，通过使用exportPresetsCompatibleWithAsset:方法。
     */
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetLowQuality]) {
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPreset640x480];
        exportSession.outputURL = [self compressedURL];
        //优化网络
        exportSession.shouldOptimizeForNetworkUse = true;
        //转换后的格式
        exportSession.outputFileType = AVFileTypeMPEG4;
        //异步导出
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            // 如果导出的状态为完成
            if ([exportSession status] == AVAssetExportSessionStatusCompleted) {
                NSLog(@"压缩完毕,压缩后大小 %f MB",[self fileSize:[self compressedURL]]);
                [self saveVideo:[self compressedURL]];
            }else{
                NSLog(@"当前压缩进度:%f",exportSession.progress);
            }
            
            self.saveBtn.enabled = YES;
        }];
    }
}


//ALAssetsLibrary提供了我们对iOS设备中的相片、视频的访问。
- (void)saveVideo:(NSURL *)outputFileURL
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    if (error) {
                                        NSLog(@"保存视频失败:%@",error);
                                    } else {
                                        NSLog(@"保存视频到相册成功");
                                    }
                                }];
}





-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
