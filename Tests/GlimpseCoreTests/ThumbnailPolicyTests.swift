// P6.1: previews only where they're recognisable at 24 points.
import Testing
import UniformTypeIdentifiers
@testable import GlimpseCore

@Suite("Which files get a preview")
struct ThumbnailPolicyTests {
  @Test("pictures, PDFs and videos do", arguments: ["png", "jpg", "heic", "gif", "svg", "pdf", "mov", "mp4"])
  func previewed(ext: String) {
    #expect(ThumbnailPolicy.wantsThumbnail(UTType(filenameExtension: ext)))
  }

  @Test("text, code, data, archives and apps keep their icon",
        arguments: ["txt", "json", "md", "swift", "csv", "zip", "app", "dmg"])
  func iconOnly(ext: String) {
    #expect(!ThumbnailPolicy.wantsThumbnail(UTType(filenameExtension: ext)))
  }

  @Test("an unknown type keeps its icon")
  func unknown() {
    #expect(!ThumbnailPolicy.wantsThumbnail(UTType(filenameExtension: "bin")))
    #expect(!ThumbnailPolicy.wantsThumbnail(nil))
  }
}
