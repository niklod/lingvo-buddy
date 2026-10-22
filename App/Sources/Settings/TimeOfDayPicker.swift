import LingvoCore
import SwiftUI

/// An hour-and-minute field for a `TimeOfDay`; the date part is irrelevant.
struct TimeOfDayPicker: View {
    @Binding var time: TimeOfDay

    var body: some View {
        DatePicker("", selection: date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.stepperField)
            .fixedSize()
    }

    private var date: Binding<Date> {
        Binding(
            get: { Self.calendar.date(from: DateComponents(hour: time.hour, minute: time.minute)) ?? SystemClock().now() },
            set: { date in
                let parts = Self.calendar.dateComponents([.hour, .minute], from: date)
                // The field only produces valid times; keep the old one if it ever does not.
                if let picked = try? TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0) {
                    time = picked
                }
            }
        )
    }

    private static let calendar = Calendar.current
}
