import SwiftUI

struct DisplayFieldView: View {
    enum Field: Hashable {
        case line1
        case line2
    }
    @Binding var line1: String
    @Binding var line2: String
    
     
    
    var onDone: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                ZStack {
                    Image("Image Asset 1")
                        .resizable()
                        .frame(width: 365, height: 171)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 5, height: 2.5)))
                    HStack {
                        
                        VStack {
                            
                            TextField("Row 1", text: $line1)
                                .font(.system(size: 28, weight: .regular, design: .monospaced))
                                .multilineTextAlignment(.leading)
                                .padding(2)
                                .offset(y: 5)
                                .focused($focusedField, equals: .line1)
                            
                            
                            
                            TextField("Row 2", text: $line2)
                                .font(.system(size: 28, weight: .regular, design: .monospaced))
                                .multilineTextAlignment(.leading)
                                .padding(2)
                                .offset(y: -5)
                                .focused($focusedField, equals: .line2)
                            
                        }
                        .frame(maxWidth: 365, maxHeight: 171)
                        .offset(x: 40)
                        
                    }
                    Spacer()
                    
                }
                Spacer()
                Button {
                    onDone?()
                } label: {
                    Text("Update")
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: 50)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 10)))
                        .shadow(color: .blue, radius: 1.2)
                        .padding()
                        
                }
            }
            
            .onChange(of: line1) { _, newValue in
                if newValue.count >= 16 {
                    line2.append(line1.last!)
                    line1.removeLast()
                    focusedField = .line2
                }
            }
            .onChange(of: line2) { _, newValue in
                if newValue.count >= 16 {
                    line2.removeLast()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Display")
        }
    }
}

#Preview {
    NavigationStack {
        DisplayFieldView(line1: .constant(""), line2: .constant(""))
    }
}
