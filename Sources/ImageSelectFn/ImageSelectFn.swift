import class CoreGraphics.CGColorSpace
import func CoreGraphics.CGColorSpaceCreateDeviceRGB
import struct CoreGraphics.CGRect
import struct CoreGraphics.CGSize
import class CoreImage.CIContext
import struct CoreImage.CIFormat
import class CoreImage.CIImage
import struct Foundation.Data

public enum ImgSelFnErr: Error {
  case fatal(String)
  case invalidArgument(String)
  case unimplemented(String)
}

/// Selects `CIImage`.
public typealias SelectPixel = (CIImage, CIImage) -> Result<CIImage, Error>

/// Converts `CIImage` to ``RawImageRgba8``.
public typealias ImageToRawImage = (CIImage) -> Result<RawImageRgba8, Error>

public func ImageToRawImageInvalid() -> ImageToRawImage {
  return {
    _ = $0
    return .failure(ImgSelFnErr.unimplemented("invalid converter"))
  }
}

/// A wrapped `CIImage`.
public struct ImageRgba8 {
  public let img: CIImage
  public let width: Int
  public let height: Int

  public static func fromImage(_ img: CIImage) -> Self {
    let size: CGSize = img.extent.size
    return Self(
      img: img,
      width: Int(size.width),
      height: Int(size.height)
    )
  }

  public func rowBytes() -> Int { 4 * self.width }
  public func byteCount() -> Int { self.height * self.rowBytes() }

  public func format() -> CIFormat { .RGBA8 }
  public func color() -> CGColorSpace { CGColorSpaceCreateDeviceRGB() }

  public func ToData(ictx: CIContext) -> Result<Data, Error> {
    var dat: Data = Data(count: self.byteCount())
    let res: Result<(), Error> = dat.withUnsafeMutableBytes {
      let buf: UnsafeMutableRawBufferPointer = $0
      let oraw: UnsafeMutableRawPointer? = buf.baseAddress
      guard let raw = oraw else {
        return .failure(ImgSelFnErr.fatal("invalid pointer got"))
      }

      ictx.render(
        self.img,
        toBitmap: raw,
        rowBytes: self.rowBytes(),
        bounds: self.img.extent,
        format: self.format(),
        colorSpace: self.color()
      )

      return .success(())
    }
    return res.map {
      _ = $0
      return dat
    }
  }

  public func ToRawImg(ictx: CIContext) -> Result<RawImageRgba8, Error> {
    let rdat: Result<Data, _> = self.ToData(ictx: ictx)
    return rdat.map {
      let dat: Data = $0
      return RawImageRgba8(
        img: dat,
        width: self.width,
        height: self.height
      )
    }
  }
}

/// A raw bitmap image(32-bit RGBA).
public struct RawImageRgba8 {
  public let img: Data
  public let width: Int
  public let height: Int

  public func isSameSize(other: Self) -> Bool {
    let w: Bool = self.width == other.width
    let h: Bool = self.height == other.height
    return w && h
  }

  public func rowBytes() -> Int { 4 * self.width }
  public func size() -> CGSize {
    CGSize(width: self.width, height: self.height)
  }

  public func totalByteCount() -> Int { self.height * self.rowBytes() }

  public func format() -> CIFormat { .RGBA8 }
  public func color() -> CGColorSpace { CGColorSpaceCreateDeviceRGB() }

  public func ToImage() -> CIImage {
    CIImage(
      bitmapData: self.img,
      bytesPerRow: self.rowBytes(),
      size: self.size(),
      format: self.format(),
      colorSpace: self.color()
    )
  }
}

/// Creates ``ImageToRawImage`` using the provided context.
public func ImgToRawImgNew(ictx: CIContext) -> ImageToRawImage {
  return {
    let img: CIImage = $0
    let i: ImageRgba8 = .fromImage(img)
    return i.ToRawImg(ictx: ictx)
  }
}

/// Selects ``RawImageRgba8``.
public typealias SelectRaw = (
  RawImageRgba8, RawImageRgba8
) -> Result<RawImageRgba8, Error>

public func SelectRawInvalid() -> SelectRaw {
  return {
    _ = $0
    _ = $1
    return .failure(ImgSelFnErr.unimplemented("invalid selector"))
  }
}

/// RGBA 32-bit pixel.
public typealias Rgba8 = (UInt8, UInt8, UInt8, UInt8)

/// Simple 2D Point.
public struct Point {
  public let x: Int
  public let y: Int
}

/// Selects RGBA.
public typealias SelectRgbaByPoint = (Rgba8, Rgba8, Point) -> Rgba8

/// Creates ``SelectPixel`` using ``SelectRaw`` and ``ImageToRawImage``.
public struct RawSelector {
  public let raw: SelectRaw
  public let i2raw: ImageToRawImage

  public static func invalid() -> Self {
    Self(
      raw: SelectRawInvalid(),
      i2raw: ImageToRawImageInvalid()
    )
  }

  public func WithSelector(_ raw: @escaping SelectRaw) -> Self {
    Self(raw: raw, i2raw: self.i2raw)
  }

  public func WithConverter(_ i2raw: @escaping ImageToRawImage) -> Self {
    Self(raw: self.raw, i2raw: i2raw)
  }

  public func ToSelectPixel() -> SelectPixel {
    return {
      let ca: CIImage = $0
      let cb: CIImage = $1

      let ra: Result<RawImageRgba8, _> = self.i2raw(ca)
      let rb: Result<RawImageRgba8, _> = self.i2raw(cb)

      let rab: Result<(_, _), _> = ra.flatMap {
        let a: RawImageRgba8 = $0
        return rb.map { (a, $0) }
      }

      let r: Result<RawImageRgba8, _> = rab.flatMap {
        let (a, b) = $0
        return self.raw(a, b)
      }

      return r.map { $0.ToImage() }
    }
  }
}

/// Creates ``SelectRaw`` using ``SelectRgbaByPoint``.
public struct RgbaSelector8 {
  public let selector: SelectRgbaByPoint

  public static func fromSelector(_ sel: @escaping SelectRgbaByPoint) -> Self {
    Self(selector: sel)
  }

  public func ToRawSelector() -> SelectRaw {
    return {
      let ra: RawImageRgba8 = $0
      let rb: RawImageRgba8 = $1
      guard ra.isSameSize(other: rb) else {
        return .failure(ImgSelFnErr.invalidArgument("incompatible images"))
      }

      let width: Int = ra.width
      let height: Int = ra.height

      let rowSize: Int = 4 * width
      let byteCount: Int = ra.totalByteCount()

      var odat: Data = Data(capacity: byteCount)

      for y in 0..<height {
        for x in 0..<width {
          let start: Int = y * rowSize + 4 * x
          let end: Int = start + 4

          let da: Data = ra.img.subdata(in: start..<end)
          let db: Data = rb.img.subdata(in: start..<end)

          let pa: Rgba8 = (da[0], da[1], da[2], da[3])
          let pb: Rgba8 = (db[0], db[1], db[2], db[3])

          let pnt: Point = Point(x: x, y: y)

          let selected: Rgba8 = self.selector(pa, pb, pnt)

          odat.append(contentsOf: [
            selected.0,
            selected.1,
            selected.2,
            selected.3,
          ])
        }
      }

      return .success(
        RawImageRgba8(
          img: odat,
          width: width,
          height: height
        )
      )
    }
  }
}
