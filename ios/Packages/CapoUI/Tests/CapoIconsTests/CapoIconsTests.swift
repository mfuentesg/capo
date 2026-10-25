import Foundation
import SwiftUI
import Testing

@testable import CapoIcons

/// Every lucide name the web imports (`grep lucide-react` over the web sources + icon picker).
private let webIconNames = [
  "Album", "AlertCircle", "Anchor", "Archive", "ArchiveRestore", "ArrowLeft", "ArrowLeftRight",
  "ArrowRight", "ArrowRightFromLine", "Award", "Bell", "Bird", "Book", "BookOpen", "Briefcase",
  "Building", "Building2", "Calendar", "CalendarDays", "Camera", "Cat", "Check", "CheckCircle",
  "CheckCircle2", "ChevronDown", "ChevronLeft", "ChevronRight", "ChevronUp", "Circle",
  "CircleUserRound", "Clock", "Cloud", "CloudRain", "Coffee", "Columns2", "Compass", "Copy", "Crown",
  "Diamond", "Disc", "Disc3", "Dog", "Drum", "ExternalLink", "Eye", "FileEdit", "FileText", "Film",
  "Fish", "Flag", "Flame", "Flower2", "Gamepad2", "Gem", "Ghost", "Gift", "Github", "Globe", "Globe2",
  "GripVertical", "Guitar", "Headphones", "Heart", "Home", "Info", "KeyRound", "Languages", "Layers",
  "LayoutDashboard", "LayoutGrid", "LayoutList", "Leaf", "Lightbulb", "Link", "ListMusic", "Loader2",
  "Lock", "LogOut", "Mail", "MapPin", "Medal", "Menu", "Mic", "Mic2", "Minus", "Monitor", "Moon",
  "MoreHorizontal", "MoreVertical", "Mountain", "Music", "Music2", "Music3", "Music4", "Palette",
  "Pause", "Pencil", "Piano", "Play", "Plus", "Puzzle", "Rabbit", "Radio", "RefreshCw", "Repeat",
  "Repeat2", "Rocket", "RotateCcw", "ScanSearch", "Search", "Settings", "Settings2", "Share2",
  "Shield", "ShieldAlert", "ShieldCheck", "Ship", "SlidersHorizontal", "Smile", "Sparkle", "Sparkles",
  "Star", "Sun", "Sword", "Tag", "Target", "Trash2", "Trophy", "Turtle", "Type", "Umbrella", "User",
  "UserCircle", "UserLock", "UserPlus", "UserSearch", "Users", "Users2", "Volume2", "Wand2", "Waves",
  "X", "XCircle", "Zap"
]

@Suite struct CapoIconsTests {
  @Test func everyWebIconResolvesWithPath() {
    #expect(webIconNames.count >= 140)
    for name in webIconNames {
      let icon = CapoIconName.lookup(name)
      #expect(icon != nil, "missing \(name)")
      if let icon {
        #expect(!icon.pathData.isEmpty)
        #expect(!icon.path.isEmpty, "empty path for \(name)")
      }
    }
  }

  @Test func teamIconsAre80AndResolve() {
    #expect(CapoIconName.teamIcons.count == 80)
    #expect(Set(CapoIconName.teamIcons).count == 80)
    for icon in CapoIconName.teamIcons { #expect(CapoIconName.lookup(icon.rawValue) == icon) }
  }

  @Test func unknownNamesFallBack() {
    #expect(CapoIconName.named("NopeNotAnIcon") == .users)
    #expect(CapoIconName.named(nil) == .users)
    #expect(CapoIconName.named("Guitar") == .guitar)
    #expect(CapoIconName.lookup("") == nil)
  }

  @Test func allPathsStayWithinGrid() {
    for icon in CapoIconName.allCases {
      let box = icon.path.boundingRect
      #expect(box.minX >= -0.5 && box.minY >= -0.5 && box.maxX <= 24.5 && box.maxY <= 24.5, "\(icon)")
      #expect(box.width > 0 || box.height > 0, "\(icon)")
    }
  }

  @Test func shapeScalesAndCentersInRect() {
    let path = CapoIconShape(.circle).path(in: CGRect(x: 10, y: 20, width: 48, height: 48))
    let box = path.boundingRect
    #expect(abs(box.midX - 34) < 0.5 && abs(box.midY - 44) < 0.5)
    #expect(abs(box.width - 40) < 0.5)  // r=10 on a 24 grid -> 20 * 2
  }

  @Test func arcAndPackedFlagParsing() {
    let p = SVGPathParser.path(from: "M2 12a10 10 0 1 0 20 0 M4 4a2 2 0 011 1")
    #expect(abs(p.boundingRect.maxX - 22) < 0.1)
    #expect(!SVGPathParser.path(from: "M1.5.5L-2-3").isEmpty)
  }

  @Test func shapePathIsCallableOffMainActor() async {
    let box = await Task.detached {
      CapoIconShape(.guitar).path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).boundingRect
    }.value
    #expect(box.width > 10)
  }

  @Test func viewBuilds() {
    _ = CapoIcon(.users, size: 18).body
    _ = CapoIcon.named("Guitar", size: 20).body
  }
}
