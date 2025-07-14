import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("VTS - Voice to Text Service")
                .font(.largeTitle)
                .padding()
            
            Text("Configure your speech-to-text settings")
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}