// P6.1: which files get a Quick Look preview in the panel. At 24 points a picture, a PDF's first page or a video frame
// is recognisable; a page of text, code or a spreadsheet is a blank white square, worse than the file's icon (seen on
// 2026-11-24 with a .txt and a .json). So: images, PDFs and video/audio only; everything else keeps its Finder icon.
import UniformTypeIdentifiers

public enum ThumbnailPolicy {
  public static func wantsThumbnail(_ type: UTType?) -> Bool {
    guard let type else { return false }
    return type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .audiovisualContent)
  }
}
