import WidgetKit
import SwiftUI
import AppIntents

// Must match WidgetService.appGroupId on the Flutter side.
private let appGroupId = "group.io.github.sondahyun.stiko"
private let widgetKind = "StikoWidget"
private let inkColor = Color(red: 0.43, green: 0.37, blue: 0.09)

// MARK: - Data

struct TodoItem: Identifiable {
  let id: String
  let content: String
  let done: Bool
}

private func loadTodos() -> [TodoItem] {
  let defaults = UserDefaults(suiteName: appGroupId)
  guard let raw = defaults?.string(forKey: "todos"),
        let data = raw.data(using: .utf8),
        let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
  else { return [] }
  return arr.compactMap { d in
    guard let id = d["id"] as? String, let content = d["content"] as? String else { return nil }
    return TodoItem(id: id, content: content, done: (d["done"] as? Bool) ?? false)
  }
}

// MARK: - Toggle intent (interactive, iOS 17+)

@available(iOS 17.0, *)
struct ToggleTodoIntent: AppIntent {
  static var title: LocalizedStringResource = "할 일 완료"

  @Parameter(title: "id")
  var id: String

  init() {}
  init(id: String) { self.id = id }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: appGroupId)

    // Flip the tapped todo's done state so it gets (or loses) a strikethrough
    // in place, instead of disappearing.
    var newDone = true
    if let raw = defaults?.string(forKey: "todos"),
       let data = raw.data(using: .utf8),
       var arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
      for i in arr.indices where (arr[i]["id"] as? String) == id {
        newDone = !((arr[i]["done"] as? Bool) ?? false)
        arr[i]["done"] = newDone
      }
      if let out = try? JSONSerialization.data(withJSONObject: arr),
         let str = String(data: out, encoding: .utf8) {
        defaults?.set(str, forKey: "todos")
      }
    }

    // Record the change so the app persists it to the cloud on its next resume.
    var pending: [[String: Any]] = []
    if let raw = defaults?.string(forKey: "pending"),
       let data = raw.data(using: .utf8),
       let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
      pending = arr.filter { ($0["id"] as? String) != id }
    }
    pending.append(["id": id, "done": newDone])
    if let out = try? JSONSerialization.data(withJSONObject: pending),
       let str = String(data: out, encoding: .utf8) {
      defaults?.set(str, forKey: "pending")
    }

    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    return .result()
  }
}

// MARK: - Timeline

struct StikoEntry: TimelineEntry {
  let date: Date
  let todos: [TodoItem]
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> StikoEntry {
    StikoEntry(date: Date(), todos: [TodoItem(id: "1", content: "할 일 미리보기", done: false)])
  }

  func getSnapshot(in context: Context, completion: @escaping (StikoEntry) -> Void) {
    completion(StikoEntry(date: Date(), todos: loadTodos()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StikoEntry>) -> Void) {
    completion(Timeline(entries: [StikoEntry(date: Date(), todos: loadTodos())], policy: .atEnd))
  }
}

// MARK: - Views

struct TodoRow: View {
  let todo: TodoItem

  @ViewBuilder
  private var circle: some View {
    Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
      .font(.system(size: 15))
      .foregroundStyle(todo.done ? inkColor : Color.secondary)
  }

  var body: some View {
    HStack(spacing: 8) {
      if #available(iOS 17.0, *) {
        Button(intent: ToggleTodoIntent(id: todo.id)) {
          circle
        }
        .buttonStyle(.plain)
      } else {
        circle
      }
      Text(todo.content)
        .font(.footnote)
        .strikethrough(todo.done)
        .foregroundStyle(todo.done ? Color.secondary : Color.primary)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }
}

struct StikoWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  var entry: Provider.Entry

  private var openCount: Int { entry.todos.filter { !$0.done }.count }

  private var limit: Int {
    switch family {
    case .systemSmall: return 4
    case .systemMedium: return 5
    case .systemLarge: return 12
    case .accessoryRectangular: return 2
    default: return 3
    }
  }

  /// How many todos are hidden beyond what this size can show.
  private var overflow: Int { max(0, entry.todos.count - limit) }

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(entry.todos.first(where: { !$0.done })?.content ?? "할 일 없음")

    case .accessoryCircular:
      VStack(spacing: 0) {
        Text("\(openCount)").font(.headline)
        Text("할일").font(.system(size: 9))
      }

    default:
      VStack(alignment: .leading, spacing: 4) {
        if entry.todos.isEmpty {
          Text("할 일 없음")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ForEach(entry.todos.prefix(limit)) { todo in
            TodoRow(todo: todo)
          }
          // iOS widgets can't scroll, so surface how many more remain; tapping
          // the widget opens the app to see the full list.
          if overflow > 0 {
            Text("+\(overflow)개 더")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }
    }
  }
}

@main
struct StikoWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: widgetKind, provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        StikoWidgetEntryView(entry: entry)
          .containerBackground(.fill.tertiary, for: .widget)
      } else {
        StikoWidgetEntryView(entry: entry)
          .padding()
      }
    }
    .configurationDisplayName("stiko 할 일")
    .description("할 일을 보고 눌러서 완료합니다.")
    .supportedFamilies([
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
      .systemSmall,
      .systemMedium,
      .systemLarge,
    ])
  }
}
