//
//  ViewController.swift
//  ReplaceColor
//
//  Created by Travis Ma on 9/9/15.
//  Copyright (c) 2015 IMSHealth. All rights reserved.
//

import UIKit

public struct PixelData {
    var a:UInt8 = 255
    var r:UInt8
    var g:UInt8
    var b:UInt8
}

public struct PixelRGB {
    var r:Float
    var g:Float
    var b:Float
}

private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
private let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)

public func HSVtoRGB(_ h : Float, s : Float, v : Float) -> (r : Float, g : Float, b : Float) {
    var r : Float = 0
    var g : Float = 0
    var b : Float = 0
    let C = s * v
    let HS = h * 6.0
    let X = C * (1.0 - fabsf(fmodf(HS, 2.0) - 1.0))
    if (HS >= 0 && HS < 1) {
        r = C
        g = X
        b = 0
    } else if (HS >= 1 && HS < 2) {
        r = X
        g = C
        b = 0
    } else if (HS >= 2 && HS < 3) {
        r = 0
        g = C
        b = X
    } else if (HS >= 3 && HS < 4) {
        r = 0
        g = X
        b = C
    } else if (HS >= 4 && HS < 5) {
        r = X
        g = 0
        b = C
    } else if (HS >= 5 && HS < 6) {
        r = C
        g = 0
        b = X
    }
    let m = v - C
    r += m
    g += m
    b += m
    return (r, g, b)
}


public func RGBtoHSV(_ r: Float, g: Float, b: Float) -> (h : Float, s : Float, v : Float) {
    var h : CGFloat = 0
    var s : CGFloat = 0
    var v : CGFloat = 0
    let col = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
    col.getHue(&h, saturation: &s, brightness: &v, alpha: nil)
    return (Float(h), Float(s), Float(v))
}


public func imageFromPixels(_ pixels:[PixelData], width:Int, height:Int)->UIImage {
    let bitsPerComponent:Int = 8
    let bitsPerPixel:Int = 32
    
    assert(pixels.count == Int(width * height))
    
    var data = pixels // Copy to mutable []
    let providerRef = CGDataProvider(
//        data: Data.init(bytes: UnsafeRawPointer(_ other: &data), count: data.count * sizeof(PixelData))
//        data: Data(: UnsafePointer<UInt8>(&data), count: data.count * sizeof(PixelData))

        data: Data(bytes: &data, count: data.count * MemoryLayout<PixelData>.size) as CFData
    )
    
    let cgim = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: width * Int(MemoryLayout<PixelData>.size),
        space: rgbColorSpace,
        bitmapInfo: bitmapInfo,
        provider: providerRef!,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
    return UIImage(cgImage: cgim!)
}


@objc class MysticLookupImage: NSObject {

//    var hue: Float = 208 //default color of blue truck
//    var range: Float = 60 //hue angle that we want to replace
//    var replace: Float = 184
//    var grayscale: Bool = false

    var brightest:Float = 0.0
    var darkest:Float = 1.0
    var changed: ((UIColor?, UIColor?, CGPoint, Int, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float) -> Void)?
    func renderMapColors(_ sources:[UIColor]?, rangeMin:Float, rangeMax:Float) -> UIImage? {
        
        
        var pixelData = MysticLookupImage.getRGBAsFromImage( UIImage.init(named: "lookup.png"))
        var newRGB: (r : Float, g : Float, b : Float)
        var mhsv:(h : Float, s : Float, v : Float) = (0.0,0.0,0.0)
        var i:Int = 0
        newRGB.r = 0.0
        newRGB.g = 0.0
        newRGB.b = 0.0
        
        for by in 0 ..< 8 {
            for bx in 0 ..< 8 {
                for g in 0 ..< 64 {
                    for r in 0 ..< 64 {
                        
                        
                        let xy = ((g + by * 64)*512)+(r + bx * 64)
                        let pxl = pixelData[xy]
                        let rgb = PixelRGB(r: Float(pxl.r)/255.0, g: Float(pxl.g)/255.0, b: Float(pxl.b)/255.0)
                        var source = sources![0]
                        var hue = Float((source.hue));
                        var saturation = Float((source.saturation));
                        var brightness = Float((source.brightness));
                        var srgb = HSVtoRGB(hue,s: saturation, v: brightness)
                        var lastDistance: Float = 0.0
                        newRGB.r = 0.0
                        newRGB.g = 0.0
                        newRGB.b = 0.0
                        
                        for si in 0 ..< sources!.count {
                            
                            source = sources![si]
                            hue = Float((source.hue));
                            saturation = Float((source.saturation));
                            brightness = Float((source.brightness));
                            srgb = HSVtoRGB(hue,s: saturation, v: brightness)
                            
                            let dr = max(rgb.r,srgb.r) - min(rgb.r,srgb.r)
                            let dg = max(rgb.g,srgb.g) - min(rgb.g,srgb.g)
                            let db = max(rgb.b,srgb.b) - min(rgb.b,srgb.b)
                            let diffc = min(1.0,max(0.0,sqrtf(dr + dg + db)))
                            let distance = 1.0-diffc
                            
                            if(lastDistance < distance)
                            {
                                newRGB.r = si == 0 ? distance : newRGB.r
                                newRGB.g = si == 1 ? distance : newRGB.g
                                newRGB.b = si == 2 ? distance : newRGB.b
                                
                                darkest = min(distance, darkest)
                                brightest = max(distance, brightest)
                            }
                            lastDistance = distance
                        }
                        
                        
                        let nr: Float = newRGB.r*255.0
                        let ng: Float = newRGB.g*255.0
                        let nb: Float = newRGB.b*255.0
                        
                        pixelData[xy].r = UInt8(nr)
                        pixelData[xy].g = UInt8(ng)
                        pixelData[xy].b = UInt8(nb)
                        i += 1
                        
                    }
                }
            }
        }
        if mhsv.h > 0
        {
            mhsv.h = 1
        }
        
        let img = imageFromPixels(pixelData,width: 512,height: 512)
        return img;
    }
        
    func renderMap(_ source:UIColor?, rangeMin:Float, rangeMax:Float) -> UIImage? {

        let hue = Float((source?.hue)!);
        let saturation = Float((source?.saturation)!);
        let brightness = Float((source?.brightness)!);
        let srgb = HSVtoRGB(hue,s: saturation, v: brightness)
        var pixelData = MysticLookupImage.getRGBAsFromImage( UIImage.init(named: "lookup.png"))
        var newRGB: (r : Float, g : Float, b : Float)
        var mhsv:(h : Float, s : Float, v : Float) = (0.0,0.0,0.0)
        var i:Int = 0
        
        for by in 0 ..< 8 {
            for bx in 0 ..< 8 {
                for g in 0 ..< 64 {
                    for r in 0 ..< 64 {

                        let xy = ((g + by * 64)*512)+(r + bx * 64)
                        let pxl = pixelData[xy]
                        let rgb = PixelRGB(r: Float(pxl.r)/255.0, g: Float(pxl.g)/255.0, b: Float(pxl.b)/255.0)
      
                        let dr = max(rgb.r,srgb.r) - min(rgb.r,srgb.r)
                        let dg = max(rgb.g,srgb.g) - min(rgb.g,srgb.g)
                        let db = max(rgb.b,srgb.b) - min(rgb.b,srgb.b)
                        let drgbc = sqrtf(dr + dg + db)
                        let diffc = min(1.0,max(0.0,drgbc))
                        let distance = 1.0-diffc
                    
                    
                        newRGB.r = distance
                        newRGB.g = distance
                        newRGB.b = distance
                    
                        darkest = min(distance, darkest)
                        brightest = max(distance, brightest)
                        
                        
                        let nr: Float = newRGB.r*255.0
                        let ng: Float = newRGB.g*255.0
                        let nb: Float = newRGB.b*255.0
 
                        pixelData[xy].r = UInt8(nr)
                        pixelData[xy].g = UInt8(ng)
                        pixelData[xy].b = UInt8(nb)
                        i += 1
                    }
                }
            }
        }
        if mhsv.h > 0
        {
            mhsv.h = 1
        }
        
        let img = imageFromPixels(pixelData,width: 512,height: 512)
        return img;
        
    }
    func render(_ hue: Float, replace:Float, range:Float, grayscale:Bool) -> UIImage? {
        let centerHueAngle: Float = hue/360.0
        var destCenterHueAngle: Float = replace/360.0
        let minHueAngle: Float = (hue - range/2.0) / 360
        let maxHueAngle: Float = (hue + range/2.0) / 360
        let hueAdjustment = centerHueAngle - destCenterHueAngle
        if destCenterHueAngle == 0 && !grayscale {
            destCenterHueAngle = 1 //force red if slider angle is 0
        }
        print("range \(range)  min \(minHueAngle)  <  \(hue)  >  \(maxHueAngle)")

//        let redPixel = PixelData(a: 255, r: 255, g: 0, b: 0)
//        var pixelData = [PixelData](count: Int(512 * 512), repeatedValue: redPixel)
        if hue == replace {
            
            return UIImage.init(named: "lookup.png")
        
        }
        var pixelData = MysticLookupImage.getRGBAsFromImage( UIImage.init(named: "lookup.png"))
        
        
//        let size = 64
//        var cubeData = [Float](count: size * size * size, repeatedValue: 0)
        var rgb: [Float] = [0, 0, 0]
        var hsv: (h : Float, s : Float, v : Float)
        var newRGB: (r : Float, g : Float, b : Float)
        var mhsv:(h : Float, s : Float, v : Float) = (0.0,0.0,0.0)
        var i:Int = 0
        
        for by in 0 ..< 8 {
            for bx in 0 ..< 8 {
                for g in 0 ..< 64 {
                    for r in 0 ..< 64 {
                        
                        let x = r + bx * 64
                        let y = g + by * 64
                        
                        let xy = ((y)*512)+x
                        let pxl = pixelData[xy]
                        
                        let pr:Float = Float(pxl.r)/255.0
                        let pg:Float = Float(pxl.g)/255.0
                        let pb:Float = Float(pxl.b)/255.0
                        var mm = 0
                        rgb = [pr,pg,pb]
                        hsv = RGBtoHSV(pr, g: pg, b: pb)
                        mhsv = (Float(hsv.h),Float(hsv.s),Float(hsv.v));
                        if hsv.h < minHueAngle || hsv.h > maxHueAngle {
                            
                            mm = 1
                            newRGB.r = rgb[0]
                            newRGB.g = rgb[1]
                            newRGB.b = rgb[2]
                        } else {
//                            print("             hsb \(hsv)")
                            if grayscale {
                                hsv.s = 0
                                hsv.v = hsv.v - hueAdjustment
                            } else {
                                hsv.h = destCenterHueAngle == 1 ? 0 : hsv.h - hueAdjustment //force red if slider angle is 360
                                newRGB = HSVtoRGB(hsv.h, s:hsv.s, v:hsv.v)
                            }
                            newRGB = HSVtoRGB(hsv.h, s:hsv.s, v:hsv.v)
                            
                        }
                        
  
                        let c1 = UIColor.init(colorLiteralRed: pr, green: pg, blue: pb, alpha: 1.0)
                        let c2 = UIColor.init(colorLiteralRed: newRGB.r, green: newRGB.g, blue: newRGB.b, alpha: 1.0)
                        
                        changed?((c1), (c2), CGPoint(x: CGFloat(x), y: CGFloat(y)), mm, centerHueAngle, destCenterHueAngle, minHueAngle, maxHueAngle, hueAdjustment, Float(hsv.h) , Float(hsv.s) , Float(hsv.v),Float(mhsv.h),Float(mhsv.s),Float(mhsv.v));
                        

                        
                        
                        let nr: Float = newRGB.r*255.0
                        let ng: Float = newRGB.g*255.0
                        let nb: Float = newRGB.b*255.0
                        
                        pixelData[xy].r = UInt8(nr)
                        pixelData[xy].g = UInt8(ng)
                        pixelData[xy].b = UInt8(nb)
                        i += 1
                    }
                }
            }
        }
        if mhsv.h > 0
        {
            mhsv.h = 1
        }

        let img = imageFromPixels(pixelData,width: 512,height: 512)
        return img;

    }
    
    
    static func getRGBAsFromImage (_ image: UIImage?) -> [PixelData]
    {
        
        var result  = [PixelData](repeating: PixelData(a:255, r: 255,g:0,b:0), count: 512*512);
        let imageRef: CGImage = (image?.cgImage)!
        let width = imageRef.width
        let height = imageRef.height;
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: height*width * 4)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let context = CGContext(data: &rawData, width: width, height: height,
                                            bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace,
                                            bitmapInfo: bitmapInfo.rawValue);
        context?.draw(imageRef, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        // Now your rawData contains the image data in the RGBA8888 pixel format.
        var  byteIndex = 0;
        for i in 0 ..< (width*height)
        {
            result[i].r = rawData[byteIndex]
            result[i].g = rawData[byteIndex + 1]
            result[i].b = rawData[byteIndex + 2]
            result[i].a = 255
            byteIndex += bytesPerPixel;
        }
        return result
    }
}


