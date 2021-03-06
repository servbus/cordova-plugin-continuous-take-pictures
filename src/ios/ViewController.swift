//
//  ViewController.swift
//  PhotoCollector
//
//  Created by servbus on 2017/5/22.
//  Copyright © 2017年 servbus. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

class CustomLine: UIView{
    override func draw(_ rect: CGRect) {
        
        let context = UIGraphicsGetCurrentContext()!
        
        context.setLineCap(.round)
        context.setLineWidth(1);  //线宽
        context.setAllowsAntialiasing(true);
        context.setStrokeColor(red: 70.0 / 255.0, green: 241.0 / 255.0, blue: 241.0 / 255.0, alpha: 0.6);  //线的颜色
        context.beginPath();
        
        context.move(to: CGPoint(x: 30, y: 0))   //起点坐标
        context.addLine(to: CGPoint(x: 30, y: self.frame.size.height))   //终点坐标
        
        context.move(to: CGPoint(x: 0, y: 30))   //起点坐标
        context.addLine(to: CGPoint(x: self.frame.size.width, y: 30))   //终点坐标
        
        context.move(to: CGPoint(x: self.frame.size.width - 30, y: 0))   //起点坐标
        context.addLine(to: CGPoint(x: self.frame.size.width - 30, y: self.frame.size.height))   //终点坐标
        
        context.strokePath();
        
    }
}

class ViewController: UIViewController {
    
    let captureSession = AVCaptureSession()
    let stillImageOutput = AVCaptureStillImageOutput()
    var captureDevice:AVCaptureDevice? = nil
    var previewLayer:AVCaptureVideoPreviewLayer? = nil
    let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    let btnThumbnail =  UIButton()
    let btnFlashMode = UIButton()
    var cameraPreview:UIView? = nil;
    
    var board:Board!
    var isDrawing = false
    var isNeedRecord = false
    let btnUndo = UIButton()
    let btnClear = UIButton()
    let btnNeedRecord = UIButton()
    
    open var successCallBack:((String?) -> Void)?
    open var cancelCallBack:(() -> Void)?
    open var childDir:String?
    open var tpls:[[String:Any]]?
    
    //禁止旋转，仅支持竖着的。其他的待研究实现方式
    open override var shouldAutorotate:Bool{
        return false
    }
    
    open override var supportedInterfaceOrientations:UIInterfaceOrientationMask{
        return .portrait
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        NotificationCenter.default.addObserver(self, selector: #selector(volumeChanged), name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
        let mpv = MPVolumeView(frame: CGRect(x: -20, y: -20, width: 0, height: 0))
        mpv.isHidden = false
        
        self.view.addSubview(mpv)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        
    }
    
    func volumeChanged() -> Void {
        btnTakePicAction("")
    }
    
    // MARK: - touches methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing == false {
            return
        }
        if board.drawingState != .ended {
            board.endPoint = board.lastPoint
            boardEndDraw()
        }
        board.lastPoint = nil
        board.beginPoint = touches.first!.location(in: self.board)
        board.endPoint = board.beginPoint
        board.drawingState = .began
        board.drawingImage()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing == false {
            return
        }
        
        board.endPoint = touches.first!.location(in: self.board)
        board.drawingState = .moved
        board.drawingImage()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing == false {
            return
        }
        
        board.endPoint = nil
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing == false {
            return
        }
        
        board.endPoint = touches.first!.location(in: self.board)
        boardEndDraw()
    }
    
    func boardEndDraw() -> Void {
        board.drawingState = .ended
        board.drawingImage()
        
        returnCoverTpls()
    }
    
    func returnCoverTpls() -> Void {
        let str = toJsonString(self.board.rects)
        self.successCallBack?(str)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        let devices = AVCaptureDevice.devices().filter{ ($0 as AnyObject).hasMediaType(AVMediaTypeVideo) && ($0 as AnyObject).position == AVCaptureDevicePosition.back }
        captureDevice = devices.first as? AVCaptureDevice
        if (captureDevice?.isFlashModeSupported(.auto))!{
            try? captureDevice?.lockForConfiguration()
            captureDevice?.flashMode = .auto
            captureDevice?.unlockForConfiguration()
        }
        
        
        captureSession.addInput(try? AVCaptureDeviceInput(device: captureDevice))
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        captureSession.startRunning()
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)!
        let pWidth = view.bounds.size.width;
        let pHeight = pWidth*(4.0/3.0)
        previewLayer?.bounds = CGRect(x: 0, y: 0, width: pWidth, height: pHeight)
        previewLayer?.position = CGPoint(x:(previewLayer?.bounds.midX)!, y:(previewLayer?.bounds.midY)!)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
        
        //对焦框
        focusView.layer.borderWidth = 1
        focusView.layer.borderColor = UIColor.green.cgColor
        focusView.backgroundColor = UIColor.clear
        focusView.isHidden = true
        
        cameraPreview = UIView(frame: CGRect(x:0.0, y:0, width:view.bounds.size.width, height:view.bounds.size.height))
        cameraPreview?.layer.addSublayer(previewLayer!)
        cameraPreview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(touchFocus)))
        
        
        
        let line = CustomLine()
        line.frame = (previewLayer?.frame)!
        line.backgroundColor = UIColor.clear
        cameraPreview?.addSubview(line)
        
        
        let btnTakePicture = UIButton()
        
        btnTakePicture.setImage(UIImage(named: "Camera.bundle/btn_camera"), for: .normal)
        
        let yMax = self.view.frame.maxY - self.view.frame.minY
        
        let size = CGSize(width:80, height:80);
        let bottomItemsViewHeight:CGFloat = 160
        let bottomItemsView = UIView(frame:CGRect( origin:CGPoint(x:0.0, y:yMax-bottomItemsViewHeight), size:CGSize(width:self.view.frame.size.width, height:bottomItemsViewHeight) ) )
        bottomItemsView.backgroundColor = UIColor.white
        
        //拍照行中心线
        let tCenterHeight = bottomItemsViewHeight - (size.height/2+20)
        btnTakePicture.bounds = CGRect(origin:CGPoint(x:0,y:0), size:size)
        btnTakePicture.center = CGPoint(x:bottomItemsView.frame.width/2, y:tCenterHeight)
        btnTakePicture.addTarget(self, action: #selector(btnTakePicAction), for: UIControlEvents.touchUpInside)
        
        bottomItemsView.addSubview(btnTakePicture)
        
        btnThumbnail.bounds = CGRect(x: 0, y: 0, width: size.width-30, height: size.height-30)
        btnThumbnail.center = CGPoint(x: btnThumbnail.bounds.width/2+10, y: tCenterHeight)
        btnThumbnail.clipsToBounds=true
        btnThumbnail.layer.cornerRadius = btnThumbnail.bounds.width/2
        btnThumbnail.setImage(UIImage(named: "Camera.bundle/image_default"), for: .normal)
        
        btnThumbnail.addTarget(self, action: #selector(btnCancelAction), for: UIControlEvents.touchUpInside)
        
        bottomItemsView.addSubview(btnThumbnail)
        
        let btnCancel = UIButton()
        btnCancel.setImage(UIImage(named: "Camera.bundle/btn_ok"), for: .normal)
        btnCancel.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        btnCancel.center = CGPoint(x: bottomItemsView.frame.width-btnCancel.bounds.width/2-10, y: tCenterHeight)
        btnCancel.addTarget(self, action: #selector(btnCancelAction), for: UIControlEvents.touchUpInside)
        
        bottomItemsView.addSubview(btnCancel)
        
        
        //闪光灯
        btnFlashMode.setImage(UIImage(named: "Camera.bundle/btn_camera_flash_auto"), for: .normal)
        
        btnFlashMode.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        btnFlashMode.center = CGPoint(x: self.view.frame.width-btnFlashMode.bounds.width/2-25, y: btnFlashMode.bounds.height/2 + 25)
        btnFlashMode.addTarget(self, action: #selector(btnFlashModeAction), for: .touchUpInside)
        
        board = Board(frame:(cameraPreview?.frame)!);
        board.contentMode = .scaleAspectFit
        board.isHidden = true
        
        //绘制按钮组中心线
        let dCenterY:CGFloat = 30;
        let dTitleColor = UIColor(red: 253/255.0, green: 154/255.0, blue: 0, alpha: 1)
        
        let btnDraw = UIButton()
        btnDraw.bounds = CGRect(x: 0, y: 0, width: 120, height: 40)
        btnDraw.center = CGPoint(x:bottomItemsView.frame.width/2,y:dCenterY)
        btnDraw.setTitle("进入遮盖模式", for: .normal)
        btnDraw.setTitleColor(dTitleColor, for: .normal)
        btnDraw.addTarget(self, action: #selector(btnDrawAction), for: UIControlEvents.touchUpInside)
        
        btnUndo.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        btnUndo.center = CGPoint(x:bottomItemsView.frame.width-40,y:dCenterY)
        btnUndo.setTitle("撤销", for: .normal)
        btnUndo.setTitleColor(dTitleColor, for: .normal)
        btnUndo.addTarget(self, action: #selector(btnUndoAction), for: UIControlEvents.touchUpInside)
        btnUndo.isHidden = true
        
        btnClear.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        btnClear.center = CGPoint(x:40,y:dCenterY)
        btnClear.setTitle("清空", for: .normal)
        btnClear.setTitleColor(dTitleColor, for: .normal)
        btnClear.addTarget(self, action: #selector(btnClearAction), for: UIControlEvents.touchUpInside)
        btnClear.isHidden = true
        
        btnNeedRecord.bounds = CGRect(x: 0, y: 0, width: 120, height: 40)
        btnNeedRecord.center = CGPoint(x: 80, y: 40)
        btnNeedRecord.setTitle("患者信息页", for: .normal)
        
        btnNeedRecord.addTarget(self, action: #selector(btnNeedRecordAction), for: .touchUpInside)
        btnNeedRecord.isHidden = true
        
        bottomItemsView.addSubview(btnDraw)
        bottomItemsView.addSubview(btnUndo)
        bottomItemsView.addSubview(btnClear)
        
        cameraPreview?.addSubview(board)
        cameraPreview?.addSubview(btnNeedRecord)
        cameraPreview?.addSubview(focusView)
        cameraPreview?.addSubview(bottomItemsView)
        cameraPreview?.addSubview(btnFlashMode)
        
        let jsonArr = tpls?[0]["rects"] as? [[String:CGFloat]]
        if jsonArr != nil {
            self.board.rects = toCGRectArr(jsonArr!)
            self.board.drawImage()
        }
        
        view.addSubview(cameraPreview!)
        
        if self.isDrawing {
            self.isDrawing = false
            btnDrawAction(btnDraw)
        }
        
        if self.isNeedRecord {
            self.isNeedRecord = false
            btnNeedRecordAction(btnNeedRecord)
        }
    }
    
    func btnNeedRecordAction(_ sender:UIButton){
        
        if self.isNeedRecord == false {
            sender.setTitleColor(UIColor.red, for: .normal)
            self.isNeedRecord = true
            
        }else{
            sender.setTitleColor(UIColor.white, for: .normal)
            self.isNeedRecord = false
        }
        var res = [String:Any]()
        res["type"] = ReturnType.NeedRecordStatus.rawValue
        res["status"] = self.isNeedRecord
        let data = try? JSONSerialization.data(withJSONObject: res, options: [])
        let str = String(data:data!, encoding: String.Encoding.utf8)
        
        self.successCallBack?(str)
    }
    
    func btnDrawAction(_ sender:UIButton){
        
        if self.isDrawing == false {
            sender.setTitle("退出遮盖模式", for: .normal)
            self.board.isHidden = false
            self.isDrawing = true
            self.btnClear.isHidden = false
            self.btnUndo.isHidden = false
            self.btnNeedRecord.isHidden = false
            
        }else{
            sender.setTitle("进入遮盖模式", for: .normal)
            self.board.isHidden = true
            self.isDrawing = false
            self.btnClear.isHidden = true
            self.btnUndo.isHidden = true
            self.btnNeedRecord.isHidden = true
        }
        var res = [String:Any]()
        res["type"] = ReturnType.DrawingStatus.rawValue
        res["status"] = self.isDrawing
        let data = try? JSONSerialization.data(withJSONObject: res, options: [])
        let str = String(data:data!, encoding: String.Encoding.utf8)
        
        self.successCallBack?(str)
    }
    
    func btnUndoAction(_ sender:Any){
        if self.board.rects.count != 0{
            self.board.rects.removeLast()
            self.board.drawImage()
            returnCoverTpls()
        }
    }
    
    func btnClearAction(_ sender:Any){
        self.board.rects.removeAll()
        self.board.drawImage()
        returnCoverTpls()
    }
    
    func touchFocus(sender: UITapGestureRecognizer) {
        if isDrawing == true {
            return
        }
        
        let point =   sender.location(in: self.cameraPreview)
        
        let cp =  self.previewLayer?.captureDevicePointOfInterest(for: point)
        if (cp?.x)! > CGFloat(1){
            return
        }
        
        try? self.captureDevice?.lockForConfiguration()
        if (self.captureDevice?.isFocusModeSupported(.autoFocus))!{
            
            self.captureDevice?.focusPointOfInterest = cp!
            self.captureDevice?.focusMode = .autoFocus
        }
        if (self.captureDevice?.isExposureModeSupported(.autoExpose))!{
            self.captureDevice?.exposurePointOfInterest = cp!
            self.captureDevice?.exposureMode = .autoExpose
        }
        self.captureDevice?.unlockForConfiguration()
        focusView.center = point
        focusView.isHidden = false
        
        UIView.animate(withDuration: 0.3, animations: {
            self.focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }) { (finished) in
            UIView.animate(withDuration: 0.5, animations: {
                self.focusView.transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: { (f) in
                self.focusView.isHidden = true
            })
        }
        
        
        
    }
    
    
    func btnCancelAction(_ sender:Any){
        //返回数据
        cancelCallBack?()
    }
    
    func btnTakePicAction(_ sender:Any){
        //可用存储空间
        let kv =  try? FileManager().attributesOfFileSystem(forPath: NSHomeDirectory())
        let size =  kv?[.systemFreeSize] as? Int
        //为了确保数据安全拍摄功能需要可用存储空间大于100MB才可以使用
        if (size ?? 0)/1024/1024 < 100 {
            let cv=UIAlertController(title: "拍摄失败", message: "可用存储空间不足", preferredStyle: .alert);
            let cancelAction=UIAlertAction(title: "知道了", style: .cancel, handler: nil);
            cv.addAction(cancelAction);
            self.present(cv, animated: false,completion: nil);
            return
        }
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 	1
        animation.toValue = 0
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        
        self.previewLayer?.add(animation, forKey: nil)
        
        
        let queue = DispatchQueue(label: "com.servbus.takePhoto")
        queue.async {
            if let videoConnection = self.stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
                self.stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                    (imageDataSampleBuffer, error) -> Void in
                    if imageDataSampleBuffer == nil {
                        return
                    }
                    
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                    let img=UIImage(data: imageData!)!
                    var zimage = img
                    
                    var tmpPath =  NSHomeDirectory()+"/Documents/"+self.childDir!;
                    let manager = FileManager.default;
                    let exist = manager.fileExists(atPath: tmpPath)
                    if !exist {
                        let url = URL(fileURLWithPath: tmpPath,isDirectory: true);
                        try! manager.createDirectory(at: url, withIntermediateDirectories: true,attributes: nil)
                    }
                    
                    tmpPath +=  "/"+String(Int(Date().timeIntervalSince1970*1000))
                    
                    let imagePath = tmpPath+".jpg"
                    
                    var res = [String:Any]()
                    res["type"] = ReturnType.TakePicture.rawValue
                    res["imagePath"] = imagePath
                    
                    if self.isDrawing && self.board.rects.count > 0 {
                        
                        self.board.image=img;
                        self.board.backgroundColor = UIColor(patternImage: self.board.takeImage())
                        self.board.image=nil
                        
                        self.board.drawImage()
                        zimage = self.board.takeImage()
                        
                        try? UIImageJPEGRepresentation(zimage, 0.7)?.write(to: URL(fileURLWithPath: tmpPath+"_z.jpg"))
                        
                        self.board.backgroundColor = UIColor.clear
                        
                        
                        if self.isNeedRecord == true {
                            res["needRecord"] = true
                        }
                        var rects = [[String:Int]]()
                        for rect in self.board.rects {
                            var r = [String:Int]()
                            r["x"] = Int(img.size.width/zimage.size.width*rect.origin.x)
                            r["y"] = Int(img.size.height/zimage.size.height*rect.origin.y)
                            r["width"] = Int(img.size.width/zimage.size.width*rect.size.width)
                            r["height"] = Int(img.size.height/zimage.size.height*rect.size.height)
                            
                            rects.append(r)
                        }
                        res["rects"] = rects
                    }
                    
                    
                    let timage = zimage.crop(to: CGSize(width: 200, height: 200))
                    
                    self.btnThumbnail.setImage(timage, for: UIControlState.normal)
                    
                    
                    try? UIImageJPEGRepresentation(img, 0.7)?.write(to: URL(fileURLWithPath: imagePath))
                    try? UIImageJPEGRepresentation(timage, 0.7)?.write(to: URL(fileURLWithPath: tmpPath+"_t.jpg"))
                    
                    
                    let data = try? JSONSerialization.data(withJSONObject: res, options: [])
                    let str = String(data:data!, encoding: String.Encoding.utf8)
                    
                    self.successCallBack?(str)
                }
            }
        }
        
        
        
    }
    
    func toJsonString(_ rects:[CGRect]) -> String {
        var res = [String:Any]()
        
        var rectsTmp = [[String:CGFloat]]()
        for rect in rects {
            var r = [String:CGFloat]()
            r["x"] = rect.origin.x
            r["y"] = rect.origin.y
            r["height"] = rect.size.height
            r["width"] = rect.size.width
            
            rectsTmp.append(r)
        }
        var tpls = [[String:Any]]()
        var tpl = [String:Any]()
        tpl["name"] = "默认模板"
        tpl["rects"] = rectsTmp
        tpls.append(tpl)
        
        res["type"] = ReturnType.Cover.rawValue
        res["tpls"] = [String:Any]()
        res["tpls"] = tpls
        
        //如果设置options为JSONSerialization.WritingOptions.prettyPrinted，则打印格式更好阅读
        let data = try? JSONSerialization.data(withJSONObject: res, options: [])
        let str = String(data:data!, encoding: String.Encoding.utf8)
        
        return str!
    }
    
    func toCGRectArr(_ jsonArr:[[String:CGFloat]]) -> [CGRect] {
        var rects = [CGRect]()
        
        for ja in jsonArr {
            var rect = CGRect()
            rect.origin.x = ja["x"]!
            rect.origin.y = ja["y"]!
            rect.size.height = ja["height"]!
            rect.size.width = ja["width"]!
            rects.append(rect)
        }
        return rects;
    }
    
    func btnFlashModeAction(_ sender:Any){
        
        try?  self.captureDevice?.lockForConfiguration()
        switch self.captureDevice!.flashMode {
        case .auto:
            self.captureDevice!.flashMode   = .on
            btnFlashMode.setImage(UIImage(named: "Camera.bundle/btn_camera_flash_on"), for: .normal)
        case .on:
            self.captureDevice!.flashMode = .off
            btnFlashMode.setImage(UIImage(named: "Camera.bundle/btn_camera_flash_off"), for: .normal)
        case .off:
            self.captureDevice!.flashMode  = .auto
            btnFlashMode.setImage(UIImage(named: "Camera.bundle/btn_camera_flash_auto"), for: .normal)
        }
        self.captureDevice?.unlockForConfiguration()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}


enum ReturnType :String{
    case TakePicture
    case Cover
    case DrawingStatus
    case NeedRecordStatus
}

extension UIImage {
    
    func crop(to:CGSize) -> UIImage {
        guard let cgimage = self.cgImage else { return self }
        
        let contextImage: UIImage = UIImage(cgImage: cgimage)
        
        let contextSize: CGSize = contextImage.size
        
        //Set to square
        var posX: CGFloat = 0.0
        var posY: CGFloat = 0.0
        let cropAspect: CGFloat = to.width / to.height
        
        var cropWidth: CGFloat = to.width
        var cropHeight: CGFloat = to.height
        
        if to.width > to.height { //Landscape
            cropWidth = contextSize.width
            cropHeight = contextSize.width / cropAspect
            posY = (contextSize.height - cropHeight) / 2
        } else if to.width < to.height { //Portrait
            cropHeight = contextSize.height
            cropWidth = contextSize.height * cropAspect
            posX = (contextSize.width - cropWidth) / 2
        } else { //Square
            if contextSize.width >= contextSize.height { //Square on landscape (or square)
                cropHeight = contextSize.height
                cropWidth = contextSize.height * cropAspect
                posX = (contextSize.width - cropWidth) / 2
            }else{ //Square on portrait
                cropWidth = contextSize.width
                cropHeight = contextSize.width / cropAspect
                posY = (contextSize.height - cropHeight) / 2
            }
        }
        
        let rect: CGRect = CGRect(x:posX, y:posY, width:cropWidth, height:cropHeight)
        
        // Create bitmap image from context using the rect
        let imageRef: CGImage = contextImage.cgImage!.cropping(to: rect)!
        
        // Create a new image based on the imageRef and rotate back to the original orientation
        let cropped: UIImage = UIImage(cgImage: imageRef, scale: self.scale, orientation: self.imageOrientation)
        
        UIGraphicsBeginImageContextWithOptions(to, true, self.scale)
        cropped.draw(in: CGRect(x:0, y:0,width:to.width, height:to.height))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resized!
    }
}

