import func CoreGraphics.CGColorSpaceCreateDeviceRGB
import struct CoreGraphics.CGRect
import struct CoreGraphics.CGSize
import class CoreImage.CIContext
import class CoreImage.CIImage
import class Foundation.ProcessInfo
import struct Foundation.URL
import typealias ImageSelectFn.ImageToRawImage
import func ImageSelectFn.ImgToRawImgNew
import struct ImageSelectFn.Point
import struct ImageSelectFn.RawSelector
import typealias ImageSelectFn.Rgba8
import struct ImageSelectFn.RgbaSelector8
import typealias ImageSelectFn.SelectPixel
import typealias ImageSelectFn.SelectRaw
import typealias ImageSelectFn.SelectRgbaByPoint

func selLatterOddY(_ f: Rgba8, _ l: Rgba8, _ pnt: Point) -> Rgba8 {
  let y: Int = pnt.y
  let even: Bool = 0 == (y & 1)
  return even ? f : l
}

func envValByKey(_ key: String) -> String? {
  let values: [String: String] = ProcessInfo.processInfo.environment
  return values[key]
}

func str2url(_ s: String) -> URL { URL(fileURLWithPath: s) }

func key2url(_ key: String) -> URL? {
  let oval: String? = envValByKey(key)
  return oval.map(str2url)
}

func url2img(_ u: URL) -> CIImage? { CIImage(contentsOf: u) }

func img1() -> CIImage? {
  let u1: URL? = key2url("ENV_IMG_NAME_A")
  return u1.flatMap(url2img)
}

func img2() -> CIImage? {
  let u2: URL? = key2url("ENV_IMG_NAME_B")
  return u2.flatMap(url2img)
}

typealias ImageWriter = (CIImage) -> Result<(), Error>
typealias ImageWriterFs = (URL) -> ImageWriter

func img2png2url(ictx: CIContext) -> ImageWriterFs {
  return {
    let outname: URL = $0
    return {
      let img: CIImage = $0
      return Result(catching: {
        try ictx.writePNGRepresentation(
          of: img,
          to: outname,
          format: .RGBA8,
          colorSpace: CGColorSpaceCreateDeviceRGB(),
          options: [:]
        )
      })
    }
  }
}

@main
struct ImgSelStripe {
  static func main() {
    let selp: SelectRgbaByPoint = selLatterOddY
    let rs8: RgbaSelector8 = .fromSelector(selp)
    let sr: SelectRaw = rs8.ToRawSelector()

    let ictx: CIContext = CIContext()

    let i2r: ImageToRawImage = ImgToRawImgNew(ictx: ictx)
    let img2png2fs: ImageWriterFs = img2png2url(ictx: ictx)

    let rs: RawSelector = .invalid()
      .WithSelector(sr)
      .WithConverter(i2r)

    let sp: SelectPixel = rs.ToSelectPixel()

    let img1: CIImage = img1() ?? .red
    let img2: CIImage = img2() ?? .green

    let size: CGSize = CGSize(width: 3, height: 5)
    let rct: CGRect = CGRect(
      origin: .zero,
      size: size
    )

    let a3x5: CIImage = img1.cropped(to: rct)
    let b3x5: CIImage = img2.cropped(to: rct)

    let o3x5: Result<CIImage, _> = sp(a3x5, b3x5)

    let oname: URL? = key2url("ENV_O_IMG_NAME")
    guard let name: URL = oname else {
      print("output name ENV_O_IMG_NAME unknown.")
      return
    }

    let iwtr: ImageWriter = img2png2fs(name)

    let wrote: Result<(), _> = o3x5.flatMap {
      let oimg: CIImage = $0
      return iwtr(oimg)
    }

    do {
      try wrote.get()
    } catch {
      print("\( error )")
    }
  }
}
