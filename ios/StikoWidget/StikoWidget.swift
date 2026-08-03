import WidgetKit
import SwiftUI

// Must match WidgetService.appGroupId on the Flutter side.
private let appGroupId = "group.io.github.sondahyun.stiko"

struct StikoEntry: TimelineEntry {
  let date: Date
  let count: Int
  let done: Int
  let total: Int
  let next: String
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> StikoEntry {
    StikoEntry(date: Date(), count: 3, done: 1, total: 4, next: "할 일 미리보기")
  }

  func getSnapshot(in context: Context, completion: @escaping (StikoEntry) -> Void) {
    completion(readEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StikoEntry>) -> Void) {
    completion(Timeline(entries: [readEntry()], policy: .atEnd))
  }

  private func readEntry() -> StikoEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    return StikoEntry(
      date: Date(),
      count: defaults?.integer(forKey: "count") ?? 0,
      done: defaults?.integer(forKey: "done") ?? 0,
      total: defaults?.integer(forKey: "total") ?? 0,
      next: defaults?.string(forKey: "next") ?? "할 일 없음"
    )
  }
}

struct StikoWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  var entry: Provider.Entry

  var body: some View {
    switch family {
    case .accessoryInline:
      Text("할 일 \(entry.count)개")

    case .accessoryCircular:
      Gauge(
        value: Double(entry.done),
        in: 0...Double(max(entry.total, 1))
      ) {
        Text("할일")
      } currentValueLabel: {
        Text("\(entry.count)")
      }
      .gaugeStyle(.accessoryCircular)

    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Text("stiko  \(entry.done)/\(entry.total)")
          .font(.headline)
        Text(entry.next)
          .font(.body)
          .lineLimit(2)
      }

    default:
      VStack(alignment: .leading, spacing: 6) {
        Text("stiko")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(entry.count)")
          .font(.system(size: 34, weight: .bold))
        Text(entry.next)
          .font(.footnote)
          .lineLimit(2)
        Spacer(minLength: 0)
      }
    }
  }
}

@main
struct StikoWidget: Widget {
  let kind = "StikoWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        StikoWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        StikoWidgetEntryView(entry: entry)
          .padding()
      }
    }
    .configurationDisplayName("stiko 할 일")
    .description("남은 할 일과 완료율을 봅니다.")
    .supportedFamilies([
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
      .systemSmall,
    ])
  }
}
