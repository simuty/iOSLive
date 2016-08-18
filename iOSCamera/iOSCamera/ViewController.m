//
//  ViewController.m
//  iOSCamera
//
//  Created by BWF-HHW on 16/8/16.
//  Copyright © 2016年 HHW. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "PlayVC.h"

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>{
AVCaptureSession *_captureSession;
AVCaptureDevice *_videoDevice;
AVCaptureDevice *_audioDevice;
AVCaptureDeviceInput *_videoInput;
AVCaptureDeviceInput *_audioInput;
AVCaptureMovieFileOutput *_movieOutput;
AVCaptureVideoPreviewLayer *_captureVideoPreviewLayer;
}


@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, strong) dispatch_queue_t timerQueue;

@property (nonatomic,assign) BOOL canSave;
@property (nonatomic,weak) UIView *focusCircle;


@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (strong, nonatomic) IBOutlet UIButton *changeBtn;
@property (strong, nonatomic) IBOutlet UILabel *singleLab;
@property (strong, nonatomic) IBOutlet UILabel *doubleLab;
@property (strong, nonatomic) IBOutlet UILabel *timeLab;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view bringSubviewToFront:self.changeBtn];
    [self.view bringSubviewToFront:self.singleLab];
    [self.view bringSubviewToFront:self.doubleLab];
    
    //录制的区域添加视频
    [self addGenstureRecognizer];
    
    //设备授权
    [self judgeDeviceAuth];
    
}


#pragma mark 设备授权

- (void)judgeDeviceAuth{

    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:
            NSLog(@"已授权");
            [self initAVCapture];
            break;
     //未进行授权选择<例如: 没有选择退出APP, 再次打开提示>
        case AVAuthorizationStatusNotDetermined:
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    NSLog(@"已授权");
                    [self initAVCapture];

                }else{
                    NSLog(@"用户拒绝授权摄像头的使用权,返回上一页.请打开\n设置-->隐私/通用等权限设置");
                }
            }];
        }
            break;
   //一共四种情况, 只罗列两种, 所以在此判断
        default:{
             NSLog(@"用户拒绝授权摄像头的使用权,返回上一页.请打开\n设置-->隐私/通用等权限设置");
        }
            break;
    }
    
}


#pragma mark 手势相关

-(void)addGenstureRecognizer{
    
    UITapGestureRecognizer *singleTapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleTap:)];
    singleTapGesture.numberOfTapsRequired = 1;
    singleTapGesture.delaysTouchesBegan = YES;
    
    UITapGestureRecognizer *doubleTapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    doubleTapGesture.delaysTouchesBegan = YES;
    
    [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];
    [self.videoView addGestureRecognizer:singleTapGesture];
    [self.videoView addGestureRecognizer:doubleTapGesture];
}


- (void)singleTap:(UITapGestureRecognizer *)tap{
    
    NSLog(@"单击");
    CGPoint point= [tap locationInView:self.videoView];
    //将UI坐标转化为摄像头坐标,摄像头聚焦点范围0~1
    CGPoint cameraPoint= [_captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorAnimationWithPoint:point];
    
    [self changeDevicePropertySafety:^(AVCaptureDevice *captureDevice) {
        
        //聚焦
        //自动对焦一次,然后切换到焦距锁定
        //AVCaptureFocusModeContinuousAutoFocus 当需要时.自动调整焦距
        if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [captureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            NSLog(@"聚焦模式修改为%zd",AVCaptureFocusModeContinuousAutoFocus);
        }else{
            NSLog(@"聚焦模式修改失败");
        }
        
        //聚焦点的位置
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:cameraPoint];
        }
        
        /*
         @constant AVCaptureExposureModeLocked  曝光锁定在当前值
         Indicates that the exposure should be locked at its current value.
         
         @constant AVCaptureExposureModeAutoExpose 曝光自动调整一次然后锁定
         Indicates that the device should automatically adjust exposure once and then change the exposure mode to AVCaptureExposureModeLocked.
         
         @constant AVCaptureExposureModeContinuousAutoExposure 曝光自动调整
         Indicates that the device should automatically adjust exposure when needed.
         
         @constant AVCaptureExposureModeCustom 曝光只根据设定的值来
         Indicates that the device should only adjust exposure according to user provided ISO, exposureDuration values.
         
         */

        
        
        //曝光模式
        if ([captureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }else{
            NSLog(@"曝光模式修改失败");
        }
        
        //曝光点的位置
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:cameraPoint];
        }
        
        
    }];

        

}


- (void)doubleTap:(UITapGestureRecognizer *)tap{
    
    NSLog(@"双击");
    
    [self changeDevicePropertySafety:^(AVCaptureDevice *captureDevice) {
        if (captureDevice.videoZoomFactor == 1.0) {
            CGFloat current = 1.5;
            if (current < captureDevice.activeFormat.videoMaxZoomFactor) {
                [captureDevice rampToVideoZoomFactor:current withRate:10];
            }
        }else{
            [captureDevice rampToVideoZoomFactor:1.0 withRate:10];
        }
    }];

    
}


//光圈动画
-(void)setFocusCursorAnimationWithPoint:(CGPoint)point{
    self.focusCircle.center = point;
    self.focusCircle.transform = CGAffineTransformIdentity;
    self.focusCircle.alpha = 1.0;
    [UIView animateWithDuration:0.5 animations:^{
        self.focusCircle.transform=CGAffineTransformMakeScale(0.5, 0.5);
        self.focusCircle.alpha = 0.0;
    }];
}

//光圈
- (UIView *)focusCircle{
    if (!_focusCircle) {
        UIView *focusCircle = [[UIView alloc] init];
        focusCircle.frame = CGRectMake(0, 0, 100, 100);
        focusCircle.layer.borderColor = [UIColor orangeColor].CGColor;
        focusCircle.layer.borderWidth = 2;
        focusCircle.layer.cornerRadius = 50;
        focusCircle.layer.masksToBounds =YES;
        _focusCircle = focusCircle;
        [self.videoView addSubview:focusCircle];
    }
    return _focusCircle;
}



#pragma mark 初始化AVCapture

- (void)initAVCapture{
    
    _captureSession = [[AVCaptureSession alloc] init];
    //设置录像的分辨率
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480];
    }
    
    /**********************************************/

    //关于 beginConfiguration/commitConfiguration的苹果官方文档说明
    //https://developer.apple.com/reference/avfoundation/avcapturesession/1389174-beginconfiguration
    [_captureSession beginConfiguration];

    /*-----------------------------*/
    //摄像头<枚举值:前后>
    _videoDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
    //视频的输入输出
    [self videoIO];
    //音频的输入<录制视频时不需要输出>
    [self audioIO];
    //录制的同时播放
    [self previewLayer];
    /*-----------------------------*/

    [_captureSession commitConfiguration];

    //开启会话-->注意,不等于开始录制
    [_captureSession startRunning];

    
}



#pragma mark 视频的输入和输出
- (void)videoIO{
    /*---------------input-------------------------*/
    NSError *videoError;
    // 视频输入对象
    // 根据输入设备初始化输入对象，用户获取输入数据
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&videoError];
    if (videoError) {
        NSLog(@"---- 取得摄像头设备时出错 ------ %@",videoError);
        return;
    }
    // 将视频输入对象添加到会话 (AVCaptureSession) 中
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    
    /*---------------output------------------------*/
    // 拍摄视频输出对象
    // 初始化输出设备对象，用户获取输出数据
    _movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    if ([_captureSession canAddOutput:_movieOutput]) {
        [_captureSession addOutput:_movieOutput];
        AVCaptureConnection *captureConnection = [_movieOutput connectionWithMediaType:AVMediaTypeVideo];
        // 视频稳定设置
        if ([captureConnection isVideoStabilizationSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        captureConnection.videoScaleAndCropFactor = captureConnection.videoMaxScaleAndCropFactor;
    }
}

#pragma mark 音频的输入输出

- (void)audioIO{

    /*-------------input---------*/
    NSError *audioError;
    // 添加一个音频输入设备
    _audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    //  音频输入对象
    _audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:_audioDevice error:&audioError];
    if (audioError) {
        NSLog(@"取得录音设备时出错 ------ %@",audioError);
        return;
    }
    // 将音频输入对象添加到会话 (AVCaptureSession) 中
    if ([_captureSession canAddInput:_audioInput]) {
        [_captureSession addInput:_audioInput];
    }
}



#pragma mark previewLayer

- (void)previewLayer{
    [self.view layoutIfNeeded];
    
    // 通过会话 (AVCaptureSession) 创建预览层
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _captureVideoPreviewLayer.frame = self.view.layer.bounds;
    //有时候需要拍摄完整屏幕大小的时候可以修改这个
    //    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    // 如果预览图层和视频方向不一致,可以修改这个
    _captureVideoPreviewLayer.connection.videoOrientation = [_movieOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation;
    _captureVideoPreviewLayer.position = CGPointMake(self.videoView.frame.size.width*0.5,self.videoView.frame.size.height*0.5);
    
    // 显示在视图表面的图层
    CALayer *layer = self.videoView.layer;
    layer.masksToBounds = true;
    [self.view layoutIfNeeded];
    [layer addSublayer:_captureVideoPreviewLayer];
    
}



#pragma mark 获取摄像头-->前/后

- (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}


#pragma mark 摄像头切换

- (IBAction)changeCanmera:(id)sender {
    
    switch (_videoDevice.position) {
        case AVCaptureDevicePositionBack:
            _videoDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionFront];
            break;
        case AVCaptureDevicePositionFront:
            _videoDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
            break;
        default:
            return;
            break;
    }
    
    
    [self changeDevicePropertySafety:^(AVCaptureDevice *captureDevice) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
        
        if (newVideoInput != nil) {
            //必选先 remove 才能询问 canAdd
            [_captureSession removeInput:_videoInput];
            if ([_captureSession canAddInput:newVideoInput]) {
                [_captureSession addInput:newVideoInput];
                _videoInput = newVideoInput;
            }else{
                [_captureSession addInput:_videoInput];
            }
            
        } else if (error) {
            NSLog(@"切换前/后摄像头失败, error = %@", error);
        }
    }];


    
}



#pragma mark  更改设备属性前一定要锁上
-(void)changeDevicePropertySafety:(void (^)(AVCaptureDevice *captureDevice))propertyChange{
    //也可以直接用_videoDevice,但是下面这种更好
    AVCaptureDevice *captureDevice= [_videoInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁,意义是---进行修改期间,先锁定,防止多处同时修改
    BOOL lockAcquired = [captureDevice lockForConfiguration:&error];
    if (!lockAcquired) {
        NSLog(@"锁定设备过程error，错误信息：%@",error.localizedDescription);
    }else{
        
        //调整设备前后要调用beginConfiguration/commitConfiguration
        [_captureSession beginConfiguration];
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
        [_captureSession commitConfiguration];
    }
}



#pragma mark 代理相关

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@"---- 开始录制 ----");
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"---- 录制结束 ---%@-%@ ",outputFileURL,captureOutput.outputFileURL);
    
    if (outputFileURL.absoluteString.length == 0 && captureOutput.outputFileURL.absoluteString.length == 0 ) {
        //[self showMsgWithTitle:@"出错了" andContent:@"录制视频保存地址出错"];
        return;
    }
    
    if (self.canSave) {
        [self pushToPlay:outputFileURL];
        self.canSave = NO;
    }
}


#pragma mark 开始录制
- (IBAction)startCamera:(id)sender {
    
#define WeakSelf __weak typeof(self) weakSelf = self;

    [self startRecord];
    
    __block int startTimer = 0;

    __weak typeof(self) weakSelf = self;
    self.timerQueue = dispatch_queue_create("timerQueue", 0);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.timerQueue);
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_timer, ^{
        //回主线刷新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.timeLab.text = [NSString stringWithFormat:@"%d", startTimer++];
        });
    });
    dispatch_resume(_timer);
    
 }





#pragma  mark 结束录制
- (IBAction)stopCamera:(id)sender {
    [self stopRecord];
    dispatch_cancel(self.timer);
    self.canSave = YES;
}


- (void)pushToPlay:(NSURL *)url
{
    PlayVC *VC = [[PlayVC alloc] initWithNibName:@"PlayVC" bundle:nil];
    VC.videoUrl = url;
    [self.navigationController pushViewController:VC animated:YES];
    
}




#pragma mark 录制相关

- (NSURL *)outPutFileURL
{
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"outPut.mov"]];
}

- (void)startRecord
{
    [_movieOutput startRecordingToOutputFileURL:[self outPutFileURL] recordingDelegate:self];
}

- (void)stopRecord
{
    // 取消视频拍摄
    [_movieOutput stopRecording];
}

- (void)recordComplete
{
    self.canSave = YES;
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
