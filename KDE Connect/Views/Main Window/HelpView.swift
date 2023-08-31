//
//  HelpView.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2023/08/31.
//

import SwiftUI

struct LeadingText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(self.text).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HelpView: View {
    @Binding var showingHelpWindow: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(showingHelpWindow: Binding<Bool>) {
        self._showingHelpWindow = showingHelpWindow
    }
    
    func helpText() -> String {
        let file = Bundle.main.url(forResource: "HelpManual", withExtension: "md")
        let contents = try! String(contentsOf: file!, encoding: String.Encoding.utf8)
        return contents
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack {
                    Text("Playground").font(.title)
                    DevicesView(genMode: .demo).background(.brown)
                }
                
                HStack{
                    VStack(spacing: 5) {
                        Text("Help").font(.title)
                        Text(try! AttributedString(markdown: self.helpText(), options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))).fixedSize()
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.all)
        }.onAppear {
            self.showingHelpWindow = true
        }.onDisappear {
            self.showingHelpWindow = false
        }
    }
}

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView(showingHelpWindow: .constant(true))
    }
}
